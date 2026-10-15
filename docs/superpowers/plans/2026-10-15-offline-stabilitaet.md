# Offline-Stabilität der Member-App – Umsetzungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Kurze Funklöcher im Studio (Keller) frieren die Member-App nicht mehr ein. Suche, Einweisung (Text und Video) und Satz-Logging funktionieren ohne Netz, und niemand wird offline abgemeldet oder verliert Sätze.

**Architecture:** Die Netz-Schicht scheitert schnell: kurze Timeouts, sofort `.offline`, wenn der `NetzwerkMonitor` offline meldet, und kein Request ohne Token. Die App speichert den Bootstrap (als rohes Server-JSON pro User) und zeigt ihn beim Start sofort. Einweisungstexte kommen mit dem Bootstrap, und Videos und Fotos laufen aus der vorhandenen `Medienablage`, auch ohne frische URL. Bei der Auth bleibt eine abgelaufene Session bei einem Netzfehler erhalten, und ein 401 verwirft keine Sätze mehr.

**Tech Stack:** Swift 6 / SwiftUI (iOS 17+), Swift Testing, XcodeGen, supabase-swift Auth 2.55.1; TypeScript/Vitest in `packages/domain`.

**Spec:** `docs/superpowers/specs/2026-10-15-offline-stabilitaet-design.md`

## Global Constraints

- Deployment-Target bleibt iOS 17.0, `SWIFT_VERSION` 6.0, und es kommen keine neuen Abhängigkeiten dazu.
- **Timeouts:** API-Requests 10 s, Video- und Fotodownloads 20 s, Token-Refresh 10 s.
- **Retry-Abstand** der Warteschlange: 30 s. **Such-Debounce:** 150 ms. **Text „Verbindung ist langsam …“** nach 3 s.
- **Vorladen** der Videos auch über Mobilfunk.
- **Dauerhaft verworfen** werden nur noch `.validation` (422), `.notFound` (404), `.conflict` (409) und `.encodingFailed`. `.unauthorized` bleibt in der Warteschlange.
- Code-Kommentare deutsch mit ae/oe/ue/ss wie im Bestand. UI-Texte mit echten Umlauten.
- **Commits:** deutsch, Präfix `fix(ios):`, `feat(ios):` bzw. `feat(domain):`, und am Ende `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **Neue Swift-Dateien:** Danach in `apps/ios-member` `xcodegen generate` ausführen.
- **iOS-Tests** laufen aus `apps/ios-member`. Vorher mit `pgrep -lx xcodebuild` prüfen, dass kein anderer Build läuft:
  `xcodebuild test -scheme FitnessMember -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FitnessMemberTests/<Suite> -quiet`
  Gibt es den Simulator nicht, liefert `xcrun simctl list devices available` einen anderen. Im Plan steht dafür kurz `$TEST <Suite>`.
- **Domain-Tests:** `pnpm --filter @fitretro/domain test -- bootstrap`

## Review Focus

1. **Kontowechsel auf demselben Gerät:** User B darf nie den gespeicherten Bootstrap von User A sehen, auch nicht für einen Frame. Abgedeckt in Task 11 (`fremderUserSiehtKeinenCache`).
2. **App-Update mit geändertem Bootstrap-Format:** Eine nicht mehr dekodierbare Cache-Datei führt nicht zu Absturz oder Fehlerscreen, sondern wird verworfen. Abgedeckt in Task 11 (`kaputteDateiWirdVerworfen`).
3. **Retry-Timer nach dem Abmelden:** Offene Sätze von User A werden nie mit dem Token eines anderen gesendet. Nach `reset()` und ohne `anmelden` sendet `flushPending` nichts. Abgedeckt in Task 12 (`nachAbmeldenSendetNichts`).
4. **Bootstrap aus dem Cache und Server erreichbar:** Die App lädt trotzdem frisch nach und bleibt nicht auf dem alten Stand stehen. Abgedeckt in Task 11 (`anmeldenMeldetCacheNutzung`) und im RootView-Schritt.
5. **Abgelaufener Token bei Netz:** Der Token wird nicht verwendet, sondern das Backend erneuert ihn. Bei abgelaufenem Ergebnis gibt es keinen Request. Abgedeckt in Task 7 (`abgelaufenerTokenWirdNichtVerwendet`).

## Dateien

| Datei | Verantwortung | Task |
|---|---|---|
| `FitnessMember/Workout/Zeitpunkt.swift` (Pfad per `find` prüfen) | statische ISO-Parser | 2 |
| `FitnessMember/Screens/Geraet/GeraeteAuswahlView.swift` | Suchergebnis gecacht und entprellt | 3 |
| `FitnessMember/Catalog/CatalogStore.swift` | `bootstrapStand`, Cache, Warteschlangen-Besitzer, Retry, 401 | 3, 11, 12 |
| `FitnessMember/Networking/Medienablage.swift` | eine gemeinsame Session mit 20 s | 4 |
| `FitnessMember/DesignSystem/Components/Vorschaubild.swift` | `Geraetefoto` off-main, Schlüssel Modell-ID | 5 |
| `FitnessMember/Networking/APIClient.swift` | 10 s, offline sofort, kein Request ohne Token, Rohdaten | 6, 11 |
| `FitnessMember/FitnessMemberApp.swift` | Verdrahtung Monitor → Client und Vorrat | 6, 13 |
| `FitnessMember/Auth/SupabaseAuthBackend.swift` | Netzfehler-Fallback, Refresh-Timeout | 7 |
| `FitnessMember/Auth/SessionStore.swift` | abgelaufener Token → `nil` | 7 |
| `packages/domain/src/bootstrap.ts` | `description` pro Übung | 8 |
| `FitnessMember/Networking/DTOs/BootstrapResponse.swift` | `Exercise.description` | 9 |
| `FitnessMember/Screens/Geraet/GeraetModel.swift` | `beschreibung` | 9 |
| `FitnessMember/Screens/Geraet/EinweisungSchritt.swift` | Text- und Video-Fallback | 9, 10 |
| `FitnessMember/Screens/Geraet/EinweisungMedien.swift` (neu) | reine Entscheidung „Videokachel ja/nein“ | 10 |
| `FitnessMember/Catalog/BootstrapFileStore.swift` (neu) | Bootstrap pro User auf Platte | 11 |
| `FitnessMember/Navigation/RootView.swift` | `anmelden`, Nachladen, Spinner-Text | 11 |
| `FitnessMember/Networking/APIError.swift` | `istAnmeldefehler` | 12 |
| `FitnessMember/Workout/UebungsVideos.swift` | Vorladen | 13 |

Alle iOS-Pfade sind relativ zu `apps/ios-member/`.

---

### Task 1: Einfrieren messen (manuell, mit Tim)

Das ist kein Code-Task. Wird per Subagent ausgeführt, übernimmt den Task der Hauptagent mit Tim. Die anderen Tasks hängen nicht davon ab und dürfen parallel laufen. Was hier gefunden wird und nicht unter Task 2–5 fällt, kommt als neuer Task ans Ende dieses Plans.

- [ ] **Step 1: Network Link Conditioner bereitstellen**
  - Ist er nicht installiert: Xcode → Open Developer Tool → More Developer Tools → „Additional Tools for Xcode“, darin `Hardware/Network Link Conditioner.prefPane` doppelklicken.
  - Auf dem iPhone: Einstellungen → Entwickler → Network Link Conditioner.
- [ ] **Step 2: Debug-Build auf dem iPhone mit Instruments starten**
  - In Xcode: Product → Profile, Template „Time Profiler“, Instrument „Hangs“ hinzufügen.
- [ ] **Step 3: Drei Abläufe aufzeichnen, je einmal mit „100% Loss“ und mit „Very Bad Network“**
  1. Training-Tab → „Gerät wählen“ → „bein“ in die Suche tippen, Text löschen, „ruder“ tippen.
  2. Ein Gerät mit einer noch nie trainierten Übung öffnen, sodass die Einweisung erscheint.
  3. In „Gerät wählen“ durch eine Gruppe mit Videokacheln scrollen.
- [ ] **Step 4: Befund festhalten**
  - Jeden Hang über 250 ms mit Dauer und den obersten App-Frames als Tabelle unter `## Anhang: Messung` an dieses Dokument anhängen.
  - Fällt ein Hang nicht unter Task 2–5, kommt ein Task „Task 15: <Ursache>“ mit rotem Test dazu.
- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/plans/2026-10-15-offline-stabilitaet.md
git commit -m "docs(plan): Messung Offline-Haenger"
```

---

### Task 2: `Zeitpunkt` mit statischen Parsern

**Files:**
- Modify: `FitnessMember/**/Zeitpunkt.swift` (Pfad mit `find FitnessMember -name Zeitpunkt.swift`)
- Test: `FitnessMemberTests/ZeitpunktTests.swift` (neu)

**Interfaces:**
- Produces: `Zeitpunkt.parse(_:) -> Date?`, Signatur unverändert.

- [ ] **Step 1: Test schreiben**

```swift
import Foundation
import Testing
@testable import FitnessMember

/// Die Suche parst bei jedem Durchlauf alle letzten Saetze (Offline-Spec
/// 1b) -- das Ergebnis muss nach dem Umbau auf geteilte Parser gleich sein.
struct ZeitpunktTests {
    @Test func parstMitUndOhneBruchteile() {
        #expect(Zeitpunkt.parse("2026-10-15T18:00:00Z") == Date(timeIntervalSince1970: 1_792_087_200))
        #expect(Zeitpunkt.parse("2026-10-15T18:00:00.250Z") == Date(timeIntervalSince1970: 1_792_087_200.25))
        #expect(Zeitpunkt.parse("kein Datum") == nil)
    }

    @Test func parstNebenlaeufigGleich() async {
        let ergebnisse = await withTaskGroup(of: Date?.self) { gruppe in
            for _ in 0..<200 { gruppe.addTask { Zeitpunkt.parse("2026-10-15T18:00:00.250Z") } }
            return await gruppe.reduce(into: [Date?]()) { $0.append($1) }
        }
        #expect(Set(ergebnisse.compactMap { $0 }).count == 1)
    }
}
```

- [ ] **Step 2:** `xcodegen generate`, dann `$TEST ZeitpunktTests`. Das muss PASS ergeben: Hier wird nur Verhalten festgehalten, das schon stimmt. Der Zeitstempel ist geprüft, `1792087200` = 2026-10-15T18:00:00Z.
- [ ] **Step 3: Umsetzung**

```swift
enum Zeitpunkt {
    // Einmal angelegt statt je Aufruf: die Geraeteliste parst bei jedem
    // Tastendruck alle letzten Saetze, und zwei neue Formatter je Satz
    // haben die Suche spuerbar ausgebremst (Offline-Spec 1b).
    // ISO8601DateFormatter ist laut Apple-Doku threadsicher.
    nonisolated(unsafe) private static let mitBruchteilen: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    nonisolated(unsafe) private static let ohneBruchteile = ISO8601DateFormatter()

    static func parse(_ iso: String) -> Date? {
        mitBruchteilen.date(from: iso) ?? ohneBruchteile.date(from: iso)
    }
}
```

Der lange Doc-Kommentar über `enum Zeitpunkt` bleibt stehen.

- [ ] **Step 4:** `$TEST ZeitpunktTests` muss PASS ergeben.
- [ ] **Step 5: Commit**

```bash
git add FitnessMember FitnessMemberTests FitnessMember.xcodeproj
git commit -m "fix(ios): Zeitpunkt mit geteilten ISO-Parsern"
```

---

### Task 3: Suche entprellt und gecacht

**Files:**
- Modify: `FitnessMember/Catalog/CatalogStore.swift` (neue Property `bootstrapStand`)
- Modify: `FitnessMember/Screens/Geraet/GeraeteAuswahlView.swift:50-60, 140-165, 216-221`
- Test: `FitnessMemberTests/CatalogStoreTests.swift`

**Interfaces:**
- Produces: `CatalogStore.bootstrapStand: Int`. Er wird bei jeder Zuweisung an `bootstrap` um 1 erhöht und dient der View als billiger Änderungsschlüssel. Task 11 nutzt ihn ebenfalls.

- [ ] **Step 1: Test schreiben** (in `CatalogStoreTests`)

```swift
@Test("bootstrapStand zaehlt jede neue Fassung")
func bootstrapStandZaehlt() async {
    let loader = FakeBootstrapLoader()
    await loader.setBootstrapResult(.success(emptyBootstrap()))
    let store = CatalogStore(loader: loader, pendingWriteStore: PendingWriteStore(directory: tempDirectory()))
    #expect(store.bootstrapStand == 0)
    await store.load()
    await store.load()
    #expect(store.bootstrapStand == 2)
}
```

- [ ] **Step 2:** `$TEST CatalogStoreTests` muss FAIL ergeben (`bootstrapStand` fehlt).
- [ ] **Step 3: `CatalogStore` umsetzen.** `bootstrap` bekommt einen Beobachter:

```swift
private(set) var bootstrap: BootstrapResponse? {
    didSet { bootstrapStand += 1 }
}
/// Zaehlt jede Zuweisung an `bootstrap` -- ein billiger Schluessel fuer
/// Views, die daraus teuer ableiten (Geraetesuche, Offline-Spec 1b), statt
/// den ganzen Bootstrap bei jedem Durchlauf auf Gleichheit zu pruefen.
private(set) var bootstrapStand = 0
```

- [ ] **Step 4: `GeraeteAuswahlView` umsetzen.** Neuer State neben `suchtext`:

```swift
/// Das Suchergebnis, entprellt berechnet statt in jedem body-Durchlauf
/// (Offline-Spec 1b): vorher filterte jeder Tastendruck den ganzen
/// Katalog auf dem Main-Thread. nil bis zur ersten Berechnung --
/// `gruppen` rechnet dann einmal direkt, damit der erste Frame stimmt.
@State private var ergebnis: GeraeteAuswahl.Gruppen?
@State private var stationen: [Station] = []

private struct Suchschluessel: Equatable {
    let text: String
    let ort: Ort
    let gruppe: Geraetegruppe?
    let stand: Int
}
```

`gruppen` wird zu:

```swift
private var gruppen: GeraeteAuswahl.Gruppen {
    ergebnis ?? berechneGruppen(suchtext)
}

private func berechneGruppen(_ text: String) -> GeraeteAuswahl.Gruppen {
    guard let bootstrap = katalog.bootstrap else { return .leer }
    return GeraeteAuswahl.gruppen(bootstrap: bootstrap, ort: ort, suchtext: text, gruppe: gruppe)
}
```

In `untertitel` wird die Zeile `let stationen = katalog.bootstrap.map { GeraeteAuswahl.stationen(bootstrap: $0, ort: ort) } ?? []` gelöscht, sodass der `@State stationen` gilt. Am `body` kommt nach dem bestehenden `.task { … }` dazu:

```swift
.task(id: Suchschluessel(text: suchtext, ort: ort, gruppe: gruppe, stand: katalog.bootstrapStand)) {
    // Leeren und erster Durchlauf sofort, Tippen entprellt.
    if !suchtext.isEmpty && ergebnis != nil {
        try? await Task.sleep(for: .milliseconds(150))
        guard !Task.isCancelled else { return }
    }
    ergebnis = berechneGruppen(suchtext)
    stationen = katalog.bootstrap.map { GeraeteAuswahl.stationen(bootstrap: $0, ort: ort) } ?? []
}
```

`GeraeteAuswahl.zeigtKopf(suchtext:)` und das Suchfeld lesen weiter `suchtext` direkt, damit Eingabe und Kopf sofort reagieren.

- [ ] **Step 5:** `$TEST CatalogStoreTests` und `$TEST GeraeteAuswahlTests` müssen PASS ergeben. Danach im Simulator „Gerät wählen“ öffnen und tippen: Die Treffer erscheinen nach kurzer Pause, und Leeren zeigt sofort alles.
- [ ] **Step 6: Commit**

```bash
git add FitnessMember FitnessMemberTests
git commit -m "fix(ios): Geraetesuche entprellt statt je Tastendruck"
```

---

### Task 4: Medienablage mit einer Session und 20 s Timeout

**Files:**
- Modify: `FitnessMember/Networking/Medienablage.swift:52-59`
- Test: `FitnessMemberTests/UebungsVideosTests.swift` (Suite `MedienablageTests`)

**Interfaces:**
- Produces: `Medienablage.netzSession: URLSession` (static). `Medienablage.netz` bleibt die `Laden`-Closure.

- [ ] **Step 1: Test schreiben** (in `MedienablageTests`)

```swift
@Test func eineSessionMitKurzemTimeout() {
    #expect(Medienablage.netzSession === Medienablage.netzSession)
    #expect(Medienablage.netzSession.configuration.timeoutIntervalForRequest == 20)
}
```

- [ ] **Step 2:** `$TEST MedienablageTests` muss FAIL ergeben.
- [ ] **Step 3: Umsetzung**

```swift
// Ephemeral aus demselben Grund wie im VorschauLader: eine Antwort im
// URLCache traefe mit der naechsten Signatur nie wieder. EINE Session
// statt einer je Download, und 20 s statt 60 s: im Keller soll ein
// haengender Download die Kachel nicht eine Minute blockieren
// (Offline-Spec 2).
static let netzSession: URLSession = {
    let konfiguration = URLSessionConfiguration.ephemeral
    konfiguration.timeoutIntervalForRequest = 20
    return URLSession(configuration: konfiguration)
}()

static let netz: Laden = { url in
    guard let (daten, antwort) = try? await netzSession.data(from: url),
          (antwort as? HTTPURLResponse)?.statusCode == 200
    else { return nil }
    return daten
}
```

- [ ] **Step 4:** `$TEST MedienablageTests` muss PASS ergeben.
- [ ] **Step 5: Commit**

```bash
git add FitnessMember FitnessMemberTests
git commit -m "fix(ios): Medienablage mit einer Session und 20 s Timeout"
```

---

### Task 5: `Geraetefoto` dekodiert abseits des Main-Threads und findet das Foto offline

**Files:**
- Modify: `FitnessMember/DesignSystem/Components/Vorschaubild.swift:156-185` (`Geraetefoto`)
- Modify: `FitnessMember/Screens/Geraet/GeraetErkanntView.swift:56`, `FitnessMember/Screens/Geraet/EinweisungSchritt.swift:153`
- Test: `FitnessMemberTests/VorschaubildTests.swift`

**Interfaces:**
- Produces: `Geraetefoto(modellId: String, url: URL?, hoehe: CGFloat)` und `Geraetefoto.laden(modellId:url:kantePixel:ablage:) async -> UIImage?` (static, nonisolated).
- Der Schlüssel in `Medienablage.fotos` ist ab jetzt die Modell-ID. Das ist derselbe Schlüssel, den `VorschauLader` für die Liste nutzt.

- [ ] **Step 1: Test schreiben** (in `VorschaubildTests.swift`, eigene Suite)

```swift
import UIKit

struct GeraetefotoTests {
    private func png(_ groesse: CGSize) -> Data {
        UIGraphicsImageRenderer(size: groesse).image { kontext in
            UIColor.red.setFill(); kontext.fill(CGRect(origin: .zero, size: groesse))
        }.pngData()!
    }

    private func ablage(_ daten: Data) -> Medienablage {
        Medienablage(ordner: FileManager.default.temporaryDirectory
                        .appendingPathComponent("fotos-\(UUID().uuidString)"),
                     endung: "bild") { _ in daten }
    }

    /// Offline (ohne URL) kommt das Foto, das die Liste unter derselben
    /// Modell-ID abgelegt hat (Offline-Spec 3c).
    @Test func findetDasFotoOhneURLUeberDieModellId() async {
        let ablage = ablage(png(CGSize(width: 40, height: 20)))
        let url = URL(string: "https://example.test/geraete/em1.png?token=a")!
        _ = await ablage.datei(schluessel: "em1", quelle: Medienquelle(url: url, pfad: url.path))

        let bild = await Geraetefoto.laden(modellId: "em1", url: nil, kantePixel: 10, ablage: ablage)
        #expect(bild != nil)
    }

    @Test func verkleinertAufDieZielkante() async throws {
        let ablage = ablage(png(CGSize(width: 400, height: 200)))
        let url = URL(string: "https://example.test/geraete/em2.png")!
        let bild = try #require(await Geraetefoto.laden(modellId: "em2", url: url, kantePixel: 50, ablage: ablage))
        #expect(bild.cgImage!.height == 50)
    }

    @Test func ohneDateiUndOhneURLKeinBild() async {
        let bild = await Geraetefoto.laden(modellId: "fehlt", url: nil, kantePixel: 10, ablage: ablage(Data()))
        #expect(bild == nil)
    }
}
```

- [ ] **Step 2:** `$TEST GeraetefotoTests` muss FAIL ergeben (`laden` fehlt).
- [ ] **Step 3: `Geraetefoto` ersetzen**

```swift
/// Das grosse Geraetefoto oben auf Geraeteseite und Einweisung, aus der
/// Fotoablage statt per AsyncImage (Testnotiz 11.10., #14).
///
/// Schluessel ist die Modell-ID wie im VorschauLader der Liste: offline
/// (ohne signierte URL) findet die Seite so das Foto, das die Liste schon
/// abgelegt hat. Dekodiert und verkleinert wird abseits des Main-Threads
/// -- die Originale sind bis 10 MB gross, und die Dekodierung beim
/// Zeichnen liess die Seite haengen (Offline-Spec 1b).
struct Geraetefoto: View {
    let modellId: String
    let url: URL?
    let hoehe: CGFloat

    @State private var bild: UIImage?

    /// Kurze Kante in Pixeln: reicht fuer die volle Breite bei 3x.
    private static let kantePixel = 1200

    var body: some View {
        ZStack {
            DesignSystem.Color.surfaceRaised
            if let bild {
                Image(uiImage: bild).resizable().aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 28))
                    .foregroundStyle(DesignSystem.Color.textFaint)
            }
        }
        .frame(height: hoehe)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        .accessibilityHidden(true)
        // Der Pfad gehoert zur id, nicht die URL: die Signatur wechselt bei
        // jedem Laden des Kontexts, das Foto nicht.
        .task(id: [modellId, url?.path]) {
            if let geladen = await Self.laden(modellId: modellId, url: url,
                                              kantePixel: Self.kantePixel, ablage: .fotos) {
                bild = geladen
            }
        }
    }

    nonisolated static func laden(modellId: String, url: URL?, kantePixel: Int,
                                  ablage: Medienablage) async -> UIImage? {
        let quelle = url.map { Medienquelle(url: $0, pfad: $0.path) }
        guard let datei = await ablage.datei(schluessel: modellId, quelle: quelle) else { return nil }
        return await Task.detached(priority: .userInitiated) {
            guard let daten = try? Data(contentsOf: datei),
                  let verkleinert = Vorschau.verkleinert(daten, kantePixel: kantePixel)
            else { return nil }
            return UIImage(cgImage: verkleinert)
        }.value
    }
}
```

- [ ] **Step 4: Aufrufer anpassen**
  - `GeraetErkanntView.swift:56`: `Geraetefoto(modellId: modell.station.equipmentModelId, url: modell.kontext?.equipmentModel.photoUrl.flatMap(URL.init(string:)), hoehe: 180)`
  - `EinweisungSchritt.swift:153`: dasselbe mit `hoehe: 200`.
- [ ] **Step 5:** `$TEST GeraetefotoTests` und `$TEST VorschaubildTests` müssen PASS ergeben.
- [ ] **Step 6: Commit**

```bash
git add FitnessMember FitnessMemberTests
git commit -m "fix(ios): Geraetefoto dekodiert abseits des Main-Threads und findet es offline"
```

---

### Task 6: APIClient scheitert schnell

**Files:**
- Modify: `FitnessMember/Networking/APIClient.swift:1-19, 226-290`
- Modify: `FitnessMember/FitnessMemberApp.swift:10, 53-58`
- Test: `FitnessMemberTests/APIClientTests.swift`

**Interfaces:**
- Produces: `APIClient.init(baseURL: URL, session: URLSession = APIClient.standardSession, istOnline: @escaping @Sendable () async -> Bool = { true }, tokenProvider: @escaping @Sendable () async -> String?)`
- Produces: `APIClient.standardSession` (static, Timeout 10 s).
- Verhalten: Ist `istOnline()` false oder `tokenProvider()` nil, wirft der Client `APIError.offline` **ohne Request**.

- [ ] **Step 1: Tests schreiben.** `stubbedClient` bekommt einen Parameter:

```swift
func stubbedClient(istOnline: @escaping @Sendable () async -> Bool = { true },
                   tokenProvider: @escaping @Sendable () async -> String? = { "test-token" }) -> APIClient {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubURLProtocol.self]
    let session = URLSession(configuration: configuration)
    return APIClient(baseURL: URL(string: "https://example.test/api/v1")!, session: session,
                     istOnline: istOnline, tokenProvider: tokenProvider)
}
```

Neue Tests in `APIClientTests`:

```swift
final class Zaehler: @unchecked Sendable { var anfragen = 0 }

@Test("offline laut Monitor: sofort .offline, kein Request")
func offlineOhneRequest() async {
    let zaehler = Zaehler()
    StubURLProtocol.handler = { _ in zaehler.anfragen += 1; return (200, Data("{}".utf8)) }
    let client = stubbedClient(istOnline: { false })
    await #expect(throws: APIError.offline) { try await client.bootstrap() }
    #expect(zaehler.anfragen == 0)
}

@Test("ohne Token: .offline, kein Request ohne Authorization")
func ohneTokenKeinRequest() async {
    let zaehler = Zaehler()
    StubURLProtocol.handler = { _ in zaehler.anfragen += 1; return (401, Data("{}".utf8)) }
    let client = stubbedClient(tokenProvider: { nil })
    await #expect(throws: APIError.offline) { try await client.bootstrap() }
    await #expect(throws: APIError.offline) { try await client.deleteSession(sessionId: "x") }
    #expect(zaehler.anfragen == 0)
}

@Test("Standard-Session wartet hoechstens 10 s")
func standardTimeout() {
    #expect(APIClient.standardSession.configuration.timeoutIntervalForRequest == 10)
    #expect(APIClient.standardSession.configuration.waitsForConnectivity == false)
}
```

- [ ] **Step 2:** `$TEST APIClientTests` muss FAIL ergeben (Kompilierfehler wegen `istOnline` und `standardSession`).
- [ ] **Step 3: Umsetzung.** Init und Properties:

```swift
private let istOnline: @Sendable () async -> Bool

/// 10 s statt der 60 s von URLSession.shared: im Keller mit halbem Netz
/// lief jeder Spinner eine Minute ins Leere (Offline-Spec 2).
static let standardSession: URLSession = {
    let konfiguration = URLSessionConfiguration.default
    konfiguration.timeoutIntervalForRequest = 10
    konfiguration.waitsForConnectivity = false
    return URLSession(configuration: konfiguration)
}()

init(
    baseURL: URL,
    session: URLSession = APIClient.standardSession,
    istOnline: @escaping @Sendable () async -> Bool = { true },
    tokenProvider: @escaping @Sendable () async -> String?
) {
    self.baseURL = baseURL
    self.session = session
    self.istOnline = istOnline
    self.tokenProvider = tokenProvider
}
```

Ein gemeinsamer Anfang für beide `execute`-Varianten:

```swift
/// Meldet der Monitor offline, gibt es keinen Versuch -- er endete erst
/// nach dem Timeout. Ohne Token auch nicht: ein Request ohne
/// Authorization kaeme als 401 zurueck, und die Warteschlange hielt das
/// fuer endgueltig (Offline-Spec 4b).
private func anfrage(url: URL, method: String) async throws(APIError) -> URLRequest {
    guard await istOnline() else { throw APIError.offline }
    guard let token = await tokenProvider() else { throw APIError.offline }
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    return request
}
```

In `execute(url:method:bodyData:)` werden die Zeilen von `var request = URLRequest(url: url)` bis zum `if let token … }`-Block ersetzt durch:

```swift
var request = try await anfrage(url: url, method: method)
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
```

In `executeNoContent` analog: `let request = try await anfrage(url: baseURL.appendingPathComponent(path), method: method)`.

- [ ] **Step 4: Verdrahtung in `FitnessMemberApp`**
  - `@State private var netzwerkMonitor = NetzwerkMonitor()` wird zu `@State private var netzwerkMonitor: NetzwerkMonitor`.
  - In `init()` vor `let session = …`:

```swift
let netz = NetzwerkMonitor()
_netzwerkMonitor = State(initialValue: netz)
```

  - Der Client wird zu:

```swift
let client = APIClient(baseURL: AppConfig.apiBaseURL, istOnline: { await netz.istOnline }) {
    await session.currentAccessToken()
}
```

- [ ] **Step 5:** `$TEST APIClientTests` muss PASS ergeben. Danach der ganze Lauf `xcodebuild test -scheme FitnessMember -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`, damit kein anderer Test an der Init-Signatur bricht.
- [ ] **Step 6: Commit**

```bash
git add FitnessMember FitnessMemberTests
git commit -m "fix(ios): APIClient scheitert offline sofort und nie ohne Token"
```

---

### Task 7: Offline-Start ohne Login, abgelaufener Token wird nicht verwendet

**Files:**
- Modify: `FitnessMember/Auth/SupabaseAuthBackend.swift:16-31`
- Modify: `FitnessMember/Auth/SessionStore.swift:23-25, 49-55`
- Test: `FitnessMemberTests/SessionStoreTests.swift`

**Interfaces:**
- Produces: `RefreshFehler.istVoruebergehend(status: Int?) -> Bool` (enum in `SupabaseAuthBackend.swift`). `nil` heißt keine Antwort, also ein Netzfehler.
- Produces: `SessionStore.init(backend: AuthBackend, jetzt: @escaping () -> Date = Date.init)`
- Verhalten: `currentAccessToken()` liefert `nil`, wenn `expiresAt <= jetzt()`.

**Hintergrund (geprüft an supabase-swift v2.55.1):**
- `client.session` refresht bei abgelaufener Session über `api.execute`.
- Netzfehler kommen als `URLError` durch.
- Antworten außerhalb von 2xx kommen als `AuthError.api(message:errorCode:underlyingData:underlyingResponse:)`.
- `client.currentSession` liefert die gespeicherte Session ohne Netz, auch wenn sie abgelaufen ist.
- `AuthClient.init` nimmt `fetch:`.

- [ ] **Step 1: Tests schreiben.** Im `FakeAuthBackend` kommt dazu: `func setStoredSession(_ session: Session?) { storedSession = session }`. Dann:

```swift
@Test("abgelaufener Token wird nicht verwendet")
func abgelaufenerTokenWirdNichtVerwendet() async {
    let backend = FakeAuthBackend()
    let jetzt = Date(timeIntervalSince1970: 1_000_000)
    await backend.setStoredSession(Session(accessToken: "alt", userId: "u1", email: "a@b.de",
                                           expiresAt: jetzt.addingTimeInterval(-1)))
    let store = SessionStore(backend: backend, jetzt: { jetzt })
    #expect(await store.currentAccessToken() == nil)
}

@Test("gueltiger Token wird verwendet")
func gueltigerTokenWirdVerwendet() async {
    let backend = FakeAuthBackend()
    let jetzt = Date(timeIntervalSince1970: 1_000_000)
    await backend.setStoredSession(Session(accessToken: "neu", userId: "u1", email: "a@b.de",
                                           expiresAt: jetzt.addingTimeInterval(600)))
    let store = SessionStore(backend: backend, jetzt: { jetzt })
    #expect(await store.currentAccessToken() == "neu")
}

/// Offline-Start (Offline-Spec 4a): eine abgelaufene Session aus der
/// Keychain meldet trotzdem an -- der Login-Screen kommt nur bei echtem
/// Auth-Fehler.
@Test("restoreSession uebernimmt auch eine abgelaufene Session")
func restoreMitAbgelaufenerSession() async {
    let backend = FakeAuthBackend()
    let alt = Session(accessToken: "alt", userId: "u1", email: "a@b.de", expiresAt: .distantPast)
    await backend.setStoredSession(alt)
    let store = SessionStore(backend: backend)
    await store.restoreSession()
    #expect(store.session == alt)
}

@Test("Refresh: keine Antwort und 5xx sind voruebergehend, 4xx nicht",
      arguments: [(Int?.none, true), (503, true), (500, true), (400, false), (401, false)])
func refreshFehler(_ fall: (Int?, Bool)) {
    #expect(RefreshFehler.istVoruebergehend(status: fall.0) == fall.1)
}
```

- [ ] **Step 2:** `$TEST SessionStoreTests` muss FAIL ergeben (`jetzt:` und `RefreshFehler` fehlen). `restoreMitAbgelaufenerSession` hält nur den Vertrag fest. Den eigentlichen Fallback in `SupabaseAuthBackend` prüft die Abnahme in Task 14, Punkt 1, weil der Test-Target supabase-swift nicht linkt.
- [ ] **Step 3: `SessionStore` umsetzen**

```swift
private let jetzt: () -> Date

init(backend: AuthBackend, jetzt: @escaping () -> Date = Date.init) {
    self.backend = backend
    self.jetzt = jetzt
}
```

```swift
/// Fuer den tokenProvider des APIClient: fragt immer das Backend, nie die
/// zwischengespeicherte `session`-Property. [bestehender Kommentar bleibt]
///
/// Ein abgelaufener Token kommt nie zurueck: offline liefert das Backend
/// die gespeicherte, abgelaufene Session (Offline-Spec 4a), und ihr Token
/// waere beim Server ein 401 (Offline-Spec 4b).
func currentAccessToken() async -> String? {
    guard let session = await backend.currentSession(), session.expiresAt > jetzt() else { return nil }
    return session.accessToken
}
```

- [ ] **Step 4: `SupabaseAuthBackend` umsetzen**

```swift
/// Ob ein gescheiterter Token-Refresh voruebergehend war (Offline-Spec 4a).
/// `status` ist der HTTP-Status der Antwort des Auth-Servers, nil heisst:
/// keine Antwort -- Funkloch, Timeout.
enum RefreshFehler {
    static func istVoruebergehend(status: Int?) -> Bool {
        guard let status else { return true }
        return status >= 500
    }
}
```

In `SupabaseAuthBackend`:

```swift
/// 10 s statt 60 s auch fuer den Token-Refresh (Offline-Spec 2).
private static let netz: URLSession = {
    let konfiguration = URLSessionConfiguration.default
    konfiguration.timeoutIntervalForRequest = 10
    return URLSession(configuration: konfiguration)
}()
```

`init()` bekommt beim `AuthClient(...)` zusätzlich, nach `localStorage:`, die Zeile `fetch: { try await SupabaseAuthBackend.netz.data(for: $0) }`.

```swift
/// Scheitert der Refresh am Netz, gilt die gespeicherte Session weiter --
/// auch abgelaufen. Sonst landete, wer im Keller die App oeffnet, auf dem
/// Login-Screen (Offline-Spec 4a). Den abgelaufenen Token gibt
/// SessionStore.currentAccessToken() nie an den Server weiter.
func currentSession() async -> Session? {
    do {
        return map(try await client.session)
    } catch {
        guard RefreshFehler.istVoruebergehend(status: Self.status(error)) else { return nil }
        return client.currentSession.map(map)
    }
}

/// nil = keine Antwort. Andere Auth-Fehler (keine Session, kaputter JWT)
/// zaehlen wie ein 401: dauerhaft.
private static func status(_ fehler: any Error) -> Int? {
    guard let auth = fehler as? Auth.AuthError else { return nil }
    if case .api(_, _, _, let antwort) = auth { return antwort.statusCode }
    return 401
}
```

Wichtig: `AuthError` kollidiert mit dem App-eigenen `AuthError`, deshalb immer `Auth.AuthError` schreiben.

- [ ] **Step 5:** `$TEST SessionStoreTests` muss PASS ergeben, danach der ganze Testlauf.
- [ ] **Step 6: Commit**

```bash
git add FitnessMember FitnessMemberTests
git commit -m "fix(ios): Offline-Start ohne Login-Screen, abgelaufener Token nie an den Server"
```

---

### Task 8: Server liefert die Übungsbeschreibung im Bootstrap

**Files:**
- Modify: `packages/domain/src/bootstrap.ts:166-172, 366-369, 419-439`
- Test: `packages/domain/src/bootstrap.test.ts`, `tests/integration/domain-bootstrap-katalog.test.ts`

**Interfaces:**
- Produces: `Uebung.description: string | null` in jeder Übung des Bootstraps (`machines[].exercises`, `catalog.equipmentTypes[].exercises`).
- Produces: `export function uebungAusZeile(z: UebungZeile): Uebung`.

- [ ] **Step 1: Unit-Test schreiben** (`bootstrap.test.ts`). `uebungAusZeile` kommt in den Import dazu:

```ts
describe("uebungAusZeile", () => {
  it("reicht die Beschreibung fuer die Einweisung offline durch", () => {
    expect(
      uebungAusZeile({ id: "e1", name: "Face Pull", description: "Ellbogen hoch.", volume_kind: "reps", target_min: 12, target_max: 15 }),
    ).toEqual({ id: "e1", name: "Face Pull", description: "Ellbogen hoch.", volumeKind: "reps", targetMin: 12, targetMax: 15 });
  });

  it("liefert null ohne gepflegte Beschreibung", () => {
    expect(
      uebungAusZeile({ id: "e2", name: "X", description: null, volume_kind: "reps", target_min: 8, target_max: 12 }).description,
    ).toBeNull();
  });
});
```

- [ ] **Step 2:** `pnpm --filter @fitretro/domain test -- bootstrap` muss FAIL ergeben.
- [ ] **Step 3: Umsetzung**

```ts
type Uebung = {
  id: string;
  name: string;
  /** "Worauf du achten musst" -- im Bootstrap, damit die Einweisung offline lesbar ist (Offline-Spec 3b). */
  description: string | null;
  volumeKind: VolumeKind;
  targetMin: number;
  targetMax: number;
};

type UebungZeile = {
  id: string;
  name: string;
  description: string | null;
  volume_kind: VolumeKind;
  target_min: number;
  target_max: number;
};

export function uebungAusZeile(z: UebungZeile): Uebung {
  return {
    id: z.id,
    name: z.name,
    description: z.description,
    volumeKind: z.volume_kind,
    targetMin: z.target_min,
    targetMax: z.target_max,
  };
}
```

- Der Select wird zu `"equipment_model_id, sort_order, exercises (id, name, description, volume_kind, target_min, target_max)"`.
- Im Cast wird der Typ von `exercises` zu `UebungZeile`.
- Der Push wird zu `list.push(uebungAusZeile(row.exercises));`.
- `pnpm typecheck` aus der Wurzel zeigt, ob weitere Stellen `Uebung` ohne `description` bauen. Jede so gemeldete Stelle bekommt `description: null` oder den echten Wert.

- [ ] **Step 4: Integrationstest erweitern** (`domain-bootstrap-katalog.test.ts`)
  - Beim Insert der ersten Katalogübung kommt `description: "Ellbogen hoch."` dazu.
  - Im Test, der `kabelzug?.exercises` prüft, kommt dazu:

```ts
expect(kabelzug?.exercises[0]?.description).toBe("Ellbogen hoch.");
expect(kabelzug?.exercises[1]?.description).toBeNull();
```

- [ ] **Step 5: Prüfen**
  - `pnpm --filter @fitretro/domain test -- bootstrap` muss PASS ergeben.
  - Läuft ein lokales Supabase (`supabase status`), zusätzlich `pnpm test:integration -- domain-bootstrap-katalog`. Ohne lokales Supabase im Commit-Text vermerken, dass die CI den Integrationstest prüft.
  - Größe: `grep -o '"description": *"[^"]*"' catalog/gymtavo.json | wc -c` ergab am 15.10. etwa 114 KB für alle 162 Katalogübungen. Das kommt als Byte-Schätzung in den Commit-Text.
- [ ] **Step 6: Commit**

```bash
git add packages/domain tests/integration
git commit -m "feat(domain): Uebungsbeschreibung im Bootstrap fuer die Offline-Einweisung"
```

---

### Task 9: App zeigt den Einweisungstext aus dem Bootstrap

**Files:**
- Modify: `FitnessMember/Networking/DTOs/BootstrapResponse.swift:142-150`
- Modify: `FitnessMember/Screens/Geraet/GeraetModel.swift` (nach `aktiveUebung`, ca. Zeile 290)
- Modify: `FitnessMember/Screens/Geraet/EinweisungSchritt.swift:43-44`
- Test: `FitnessMemberTests/GeraetModelTests.swift`, `FitnessMemberTests/DTOTests.swift`

**Interfaces:**
- Consumes: `description` aus Task 8.
- Produces: `BootstrapResponse.Exercise.description: String?` (var, Default `nil`) und `GeraetModel.beschreibung: String?`.

- [ ] **Step 1: Tests schreiben.** In `DTOTests`:

```swift
@Test func uebungMitUndOhneBeschreibung() throws {
    let mit = #"{"id":"e1","name":"A","description":"Ellbogen hoch.","volumeKind":"reps","targetMin":8,"targetMax":12}"#
    let ohne = #"{"id":"e1","name":"A","volumeKind":"reps","targetMin":8,"targetMax":12}"#
    #expect(try JSONDecoder().decode(BootstrapResponse.Exercise.self, from: Data(mit.utf8)).description == "Ellbogen hoch.")
    #expect(try JSONDecoder().decode(BootstrapResponse.Exercise.self, from: Data(ohne.utf8)).description == nil)
}
```

In `GeraetModelTests`:

```swift
/// Offline-Spec 3b: ohne Kontext (kein Netz) kommt der Text aus dem Bootstrap.
@Test func beschreibungOhneKontextAusDemBootstrap() {
    let station = Station(typ: GeraetTestdaten.dekodiere("""
    {"id":"em7","name":"Beinpresse","manufacturer":null,"photoPath":null,
     "category":"kraft","loadUnit":"kg","loadStep":2.5,"loadMin":5.0,"loadMax":150.0,
     "settingDefinitions":[],
     "exercises":[{"id":"e1","name":"Beidbeinig","description":"Knie nicht durchdruecken.",
                   "volumeKind":"reps","targetMin":8,"targetMax":12}]}
    """), studioId: "s1")
    let sut = GeraetModel(
        station: station, uebungId: "e1", token: nil,
        bootstrap: GeraetTestdaten.bootstrap(lastSets: []), loader: FakeGeraetLoader(),
        sessions: WorkoutSessionStore(fileStore: SessionFileStore(
            directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))),
        enqueue: { _ in }, satzZiel: { Einstellungen.satzZielVorgabe },
        mitschnitt: nil, zaehler: nil, startwerte: nil)
    #expect(sut.kontext == nil)
    #expect(sut.beschreibung == "Knie nicht durchdruecken.")
}
```

Passt die Init-Signatur nicht genau, gilt die des Helpers `modell(maschine:…)` oben in der Datei als Vorlage.

- [ ] **Step 2:** `$TEST DTOTests` und `$TEST GeraetModelTests` müssen FAIL ergeben.
- [ ] **Step 3: Umsetzung.** In `Exercise`:

```swift
/// "Worauf du achten musst" -- im Bootstrap, damit die Einweisung offline
/// lesbar ist (Offline-Spec 3b). Optional mit Default: alte Server und
/// gespeicherte Bootstraps kennen das Feld nicht, und bestehende
/// memberwise-Aufrufe bleiben gueltig.
var description: String? = nil
```

In `GeraetModel`:

```swift
/// Der Text der Einweisung: aus dem Kontext, sonst aus dem Bootstrap --
/// offline gibt es keinen Kontext (Offline-Spec 3b).
var beschreibung: String? {
    if let text = kontext?.exercises.first(where: { $0.id == uebungId })?.description { return text }
    return station.exercises.first { $0.id == uebungId }?.description
}
```

In `EinweisungSchritt` wird `if let beschreibung = modell.kontext?.exercises.first(where: { $0.id == modell.uebungId })?.description {` ersetzt durch `if let beschreibung = modell.beschreibung {`.

- [ ] **Step 4:** `$TEST DTOTests` und `$TEST GeraetModelTests` müssen PASS ergeben.
- [ ] **Step 5: Commit**

```bash
git add FitnessMember FitnessMemberTests
git commit -m "feat(ios): Einweisungstext offline aus dem Bootstrap"
```

---

### Task 10: Einweisungsvideo aus dem Vorrat, auch ohne URL

**Files:**
- Create: `FitnessMember/Screens/Geraet/EinweisungMedien.swift`
- Modify: `FitnessMember/Screens/Geraet/EinweisungSchritt.swift:112-150` (`medien`)
- Test: `FitnessMemberTests/EinweisungMedienTests.swift` (neu)

**Interfaces:**
- Produces: `EinweisungMedien.zeigtVideokachel(kontextGeladen: Bool, kontextVideo: URL?, vorratKennt: Bool) -> Bool`

- [ ] **Step 1: Test schreiben**

```swift
import Foundation
import Testing
@testable import FitnessMember

/// Offline-Spec 3c: die Kachel sucht selbst in der Ablage. Nur wenn der
/// Kontext feststeht und es nirgends ein Video gibt, kommt die Fotovariante.
struct EinweisungMedienTests {
    private let url = URL(string: "https://example.test/v.mp4")!

    @Test func offlineZeigtDieKachel() {
        #expect(EinweisungMedien.zeigtVideokachel(kontextGeladen: false, kontextVideo: nil, vorratKennt: false))
    }

    @Test func kontextMitVideoZeigtDieKachel() {
        #expect(EinweisungMedien.zeigtVideokachel(kontextGeladen: true, kontextVideo: url, vorratKennt: false))
    }

    @Test func vorratSchlaegtKontextOhneVideo() {
        #expect(EinweisungMedien.zeigtVideokachel(kontextGeladen: true, kontextVideo: nil, vorratKennt: true))
    }

    @Test func ohneVideoNirgendsDieFotovariante() {
        #expect(!EinweisungMedien.zeigtVideokachel(kontextGeladen: true, kontextVideo: nil, vorratKennt: false))
    }
}
```

- [ ] **Step 2:** `xcodegen generate`, dann `$TEST EinweisungMedienTests`. Muss FAIL ergeben.
- [ ] **Step 3: `EinweisungMedien.swift` anlegen**

```swift
import Foundation

/// Was die Einweisung an Medien zeigt (Offline-Spec 3c).
///
/// Vorher hing die Videokachel an der URL aus dem Geraetekontext -- offline
/// gibt es keinen, und die Einweisung sagte "braucht Empfang", obwohl die
/// Schleife laengst auf der Platte lag. Die Kachel sucht jetzt selbst in
/// der Ablage; nur wenn der Kontext feststeht und es nirgends ein Video
/// gibt, kommt die Fotovariante.
enum EinweisungMedien {
    static func zeigtVideokachel(kontextGeladen: Bool, kontextVideo: URL?, vorratKennt: Bool) -> Bool {
        kontextVideo != nil || vorratKennt || !kontextGeladen
    }
}
```

- [ ] **Step 4: `EinweisungSchritt.medien` umbauen.** Neu im Struct ist `@Environment(UebungsVideoVorrat.self) private var vorrat`. Der Body von `medien` wird zu:

```swift
@ViewBuilder
private var medien: some View {
    let video = modell.aktiveUebung?.videoURL
    if EinweisungMedien.zeigtVideokachel(kontextGeladen: modell.kontext != nil,
                                         kontextVideo: video,
                                         vorratKennt: vorrat.quellen[modell.uebungId] != nil) {
        // Stumm in Schleife und sofort (Testnotiz 11.10., #7). Ohne URL
        // findet die Kachel die zuletzt abgelegte Datei; der Hinweis liegt
        // darunter und bleibt nur sichtbar, wenn keine da ist.
        UebungsVideoKachel(exerciseId: modell.uebungId, hoehe: 200, ersatz: video) {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                .fill(DesignSystem.Color.surfaceRaised)
                .overlay {
                    if modell.kontext == nil {
                        Text("Einweisungsvideo braucht Empfang.")
                            .font(.system(size: 13))
                            .foregroundStyle(DesignSystem.Color.textFaint)
                    }
                }
        }
    } else {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
            geraetefoto
            Text("Für diese Übung hat dein Studio kein Video hinterlegt.")
                .font(.system(size: 13))
                .foregroundStyle(DesignSystem.Color.textFaint)
        }
    }
}
```

Der Doc-Kommentar über `medien` wird um einen Satz ergänzt: „Offline läuft das Video aus der Ablage (Offline-Spec 3c).“

- [ ] **Step 5:** `$TEST EinweisungMedienTests` muss PASS ergeben. Außerdem ein Build.
- [ ] **Step 6: Commit**

```bash
git add FitnessMember FitnessMemberTests FitnessMember.xcodeproj
git commit -m "feat(ios): Einweisungsvideo offline aus der Ablage"
```

---

### Task 11: Bootstrap wird pro User gespeichert und beim Start sofort gezeigt

**Files:**
- Create: `FitnessMember/Catalog/BootstrapFileStore.swift`
- Modify: `FitnessMember/Catalog/CatalogStore.swift` (Protokoll, Init, `anmelden`, `load`, `reset`)
- Modify: `FitnessMember/Networking/APIClient.swift` (`bootstrapMitRohdaten`, `executeRoh`)
- Modify: `FitnessMember/FitnessMemberApp.swift:55` (CatalogStore mit FileStore)
- Modify: `FitnessMember/Navigation/RootView.swift:50-63, 89-95`
- Test: `FitnessMemberTests/CatalogStoreTests.swift`, `FitnessMemberTests/APIClientTests.swift`

**Abweichung von der Spec:**
- Gespeichert wird das **rohe Server-JSON**. `BootstrapResponse` ist nur `Decodable`, und ein Encodable-Umbau aller DTOs wäre groß und fehleranfällig. Dekodiert wird der Cache mit demselben Decoder wie die Netzantwort.
- Die User-ID steht im Dateinamen (`bootstrap-<userId>.json`).
- Einen Zeitpunkt `geladenAm` gibt es nicht, weil ihn nichts liest (YAGNI).

**Interfaces:**
- Produces: `struct GeladenerBootstrap: Sendable { let antwort: BootstrapResponse; let rohdaten: Data? }`
- Produces: `BootstrapLoading.bootstrapMitRohdaten() async throws(APIError) -> GeladenerBootstrap`. Default per Extension aus `bootstrap()` mit `rohdaten: nil`, damit bestehende Fakes unverändert bleiben.
- Produces: `BootstrapFileStore(directory:)` mit `load(userId:) -> BootstrapResponse?`, `save(_ rohdaten: Data, userId:)` und `loeschen()`.
- Produces: `CatalogStore.init(loader:pendingWriteStore:bootstrapFileStore: BootstrapFileStore? = nil, defaults:)`
- Produces: `CatalogStore.anmelden(userId: String) -> Bool`. Liefert `true`, wenn der Bootstrap aus dem Cache kam. Task 12 erweitert diese Methode.
- Produces: `CatalogStore.userId: String?` (private(set)).

- [ ] **Step 1: Tests schreiben.** Der `FakeBootstrapLoader` bekommt dazu:

```swift
var rohdaten: Data?
func setRohdaten(_ daten: Data?) { rohdaten = daten }

func bootstrapMitRohdaten() async throws(APIError) -> GeladenerBootstrap {
    if let rohdaten, case .success = bootstrapResult {
        return GeladenerBootstrap(antwort: try! JSONDecoder().decode(BootstrapResponse.self, from: rohdaten),
                                  rohdaten: rohdaten)
    }
    return GeladenerBootstrap(antwort: try await bootstrap(), rohdaten: nil)
}
```

Neue Tests in `CatalogStoreTests`:

```swift
private let bootstrapJSON = #"{"member":{"displayName":null,"goals":{"weeklyDays":null,"targetWeight":null}},"studios":[{"id":"s1","name":"Keller-Gym","timezone":"Europe/Berlin"}],"machines":[],"calibrations":[],"lastSets":[]}"#

@Test("offline-Start zeigt den gespeicherten Bootstrap")
func offlineStartAusCache() async {
    let verzeichnis = tempDirectory()
    let online = FakeBootstrapLoader()
    await online.setBootstrapResult(.success(emptyBootstrap()))
    await online.setRohdaten(Data(bootstrapJSON.utf8))
    let erster = CatalogStore(loader: online, pendingWriteStore: PendingWriteStore(directory: verzeichnis),
                              bootstrapFileStore: BootstrapFileStore(directory: verzeichnis))
    _ = erster.anmelden(userId: "u1")
    await erster.load()

    let offline = FakeBootstrapLoader() // scheitert mit .offline
    let zweiter = CatalogStore(loader: offline, pendingWriteStore: PendingWriteStore(directory: verzeichnis),
                               bootstrapFileStore: BootstrapFileStore(directory: verzeichnis))
    #expect(zweiter.anmelden(userId: "u1") == true)
    #expect(zweiter.loadState == .loaded)
    await zweiter.load()
    #expect(zweiter.loadState == .loaded)
    #expect(zweiter.bootstrap?.studios.first?.name == "Keller-Gym")
}

@Test("fremder User sieht keinen Cache")
func fremderUserSiehtKeinenCache() {
    let verzeichnis = tempDirectory()
    let ablage = BootstrapFileStore(directory: verzeichnis)
    ablage.save(Data(bootstrapJSON.utf8), userId: "u1")
    let store = CatalogStore(loader: FakeBootstrapLoader(), pendingWriteStore: PendingWriteStore(directory: verzeichnis),
                             bootstrapFileStore: ablage)
    #expect(store.anmelden(userId: "u2") == false)
    #expect(store.bootstrap == nil)
}

@Test("kaputte Datei wird verworfen")
func kaputteDateiWirdVerworfen() {
    let verzeichnis = tempDirectory()
    let ablage = BootstrapFileStore(directory: verzeichnis)
    ablage.save(Data("{\"alt\":true}".utf8), userId: "u1")
    #expect(ablage.load(userId: "u1") == nil)
    #expect(!FileManager.default.fileExists(atPath: verzeichnis.appendingPathComponent("bootstrap-u1.json").path))
}

@Test("anmelden meldet Cache-Nutzung nur ohne Bootstrap im Speicher")
func anmeldenMeldetCacheNutzung() async {
    let verzeichnis = tempDirectory()
    let ablage = BootstrapFileStore(directory: verzeichnis)
    ablage.save(Data(bootstrapJSON.utf8), userId: "u1")
    let loader = FakeBootstrapLoader()
    await loader.setBootstrapResult(.success(emptyBootstrap()))
    let store = CatalogStore(loader: loader, pendingWriteStore: PendingWriteStore(directory: verzeichnis),
                             bootstrapFileStore: ablage)
    #expect(store.anmelden(userId: "u1") == true)
    await store.load()
    // Neue Session desselben Users (Passwortwechsel): kein erneuter Cache.
    #expect(store.anmelden(userId: "u1") == false)
}

@Test("reset loescht den gespeicherten Bootstrap")
func resetLoeschtCache() {
    let verzeichnis = tempDirectory()
    let ablage = BootstrapFileStore(directory: verzeichnis)
    ablage.save(Data(bootstrapJSON.utf8), userId: "u1")
    let store = CatalogStore(loader: FakeBootstrapLoader(), pendingWriteStore: PendingWriteStore(directory: verzeichnis),
                             bootstrapFileStore: ablage)
    store.reset()
    #expect(ablage.load(userId: "u1") == nil)
}
```

In `APIClientTests`:

```swift
@Test("bootstrapMitRohdaten liefert die Bytes der Antwort")
func bootstrapRohdaten() async throws {
    let json = #"{"member":{"displayName":null,"goals":{"weeklyDays":null,"targetWeight":null}},"studios":[],"machines":[],"calibrations":[],"lastSets":[]}"#
    StubURLProtocol.handler = { _ in (200, Data(json.utf8)) }
    let geladen = try await stubbedClient().bootstrapMitRohdaten()
    #expect(geladen.rohdaten == Data(json.utf8))
    #expect(geladen.antwort.studios.isEmpty)
}
```

- [ ] **Step 2:** `xcodegen generate`, dann `$TEST CatalogStoreTests` und `$TEST APIClientTests`. Beide müssen FAIL ergeben (Kompilierfehler).
- [ ] **Step 3: `BootstrapFileStore.swift` anlegen**

```swift
import Foundation

/// Der Bootstrap auf Platte, als rohes Server-JSON -- damit die App im
/// Keller ohne Netz startet statt auf "NICHT GELADEN" (Offline-Spec 3a).
///
/// Roh statt neu kodiert: BootstrapResponse ist nur Decodable, und der
/// Cache wird so mit genau demselben Decoder gelesen wie die Netzantwort.
/// Die User-ID steht im Dateinamen: ein anderes Konto auf demselben Geraet
/// findet die Datei nie. Es liegt hoechstens eine Datei da.
final class BootstrapFileStore {
    private let directory: URL
    private static let praefix = "bootstrap-"

    init(directory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.directory = directory
    }

    private func datei(_ userId: String) -> URL {
        directory.appendingPathComponent("\(Self.praefix)\(userId).json")
    }

    /// Eine Datei, die nicht mehr dekodiert (alte App-Fassung), wird
    /// verworfen -- wie ohne Cache, kein Fehlerscreen.
    func load(userId: String) -> BootstrapResponse? {
        guard let daten = try? Data(contentsOf: datei(userId)) else { return nil }
        guard let antwort = try? JSONDecoder().decode(BootstrapResponse.self, from: daten) else {
            try? FileManager.default.removeItem(at: datei(userId))
            return nil
        }
        return antwort
    }

    func save(_ rohdaten: Data, userId: String) {
        loeschen()
        try? rohdaten.write(to: datei(userId), options: .atomic)
    }

    func loeschen() {
        let dateien = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        for name in dateien where name.hasPrefix(Self.praefix) && name.hasSuffix(".json") {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
        }
    }
}
```

- [ ] **Step 4: Protokoll und APIClient anpassen.** In `CatalogStore.swift`:

```swift
/// Der Bootstrap samt der Bytes, aus denen er kam -- die Bytes landen im
/// BootstrapFileStore (Offline-Spec 3a). nil bei Fakes ohne Netz.
struct GeladenerBootstrap: Sendable {
    let antwort: BootstrapResponse
    let rohdaten: Data?
}
```

Im Protokoll `BootstrapLoading` kommt `func bootstrapMitRohdaten() async throws(APIError) -> GeladenerBootstrap` dazu, außerdem:

```swift
extension BootstrapLoading {
    func bootstrapMitRohdaten() async throws(APIError) -> GeladenerBootstrap {
        GeladenerBootstrap(antwort: try await bootstrap(), rohdaten: nil)
    }
}
```

In `APIClient` wird `execute(url:method:bodyData:)` geteilt:

```swift
func bootstrapMitRohdaten() async throws(APIError) -> GeladenerBootstrap {
    let rohdaten = try await executeRoh(url: baseURL.appendingPathComponent("me/bootstrap"), method: "GET", bodyData: nil)
    do { return GeladenerBootstrap(antwort: try decoder.decode(BootstrapResponse.self, from: rohdaten), rohdaten: rohdaten) }
    catch { throw APIError.decodingFailed }
}

private func execute<T: Decodable>(url: URL, method: String, bodyData: Data?) async throws(APIError) -> T {
    let data = try await executeRoh(url: url, method: method, bodyData: bodyData)
    do { return try decoder.decode(T.self, from: data) }
    catch { throw APIError.decodingFailed }
}

/// Der Request bis zur 2xx-Antwort, ohne Dekodieren.
private func executeRoh(url: URL, method: String, bodyData: Data?) async throws(APIError) -> Data {
    var request = try await anfrage(url: url, method: method)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    if let bodyData { request.httpBody = bodyData }

    let data: Data
    let response: URLResponse
    do {
        (data, response) = try await session.data(for: request)
    } catch {
        throw APIError.offline
    }

    guard let http = response as? HTTPURLResponse else { throw APIError.server(message: "Unerwartete Antwort.") }
    if (200..<300).contains(http.statusCode) { return data }

    if let envelope = try? decoder.decode(ErrorEnvelope.self, from: data) {
        throw APIError.map(code: envelope.error.code, message: envelope.error.message)
    }
    throw APIError.server(message: "Unerwarteter Fehler.")
}
```

- [ ] **Step 5: `CatalogStore` erweitern**

```swift
private let bootstrapFileStore: BootstrapFileStore?
/// Wer angemeldet ist -- Schluessel fuer den Bootstrap-Cache und Besitzer
/// der Warteschlange (Offline-Spec 3a, 4c).
private(set) var userId: String?
```

Init-Signatur: `init(loader: any BootstrapLoading, pendingWriteStore: PendingWriteStore, bootstrapFileStore: BootstrapFileStore? = nil, defaults: UserDefaults = .standard)`, dazu `self.bootstrapFileStore = bootstrapFileStore`.

```swift
/// Die Wurzel meldet hier, wer angemeldet ist -- vor dem ersten load().
/// Ohne Bootstrap im Speicher kommt der gespeicherte sofort: die App
/// startet im Keller nicht auf "NICHT GELADEN" (Offline-Spec 3a).
/// Gibt zurueck, ob der Cache genutzt wurde -- dann laedt die Wurzel
/// trotzdem frisch nach.
@discardableResult
func anmelden(userId: String) -> Bool {
    self.userId = userId
    guard bootstrap == nil, let gespeichert = bootstrapFileStore?.load(userId: userId) else { return false }
    bootstrap = gespeichert
    loadState = .loaded
    repariereOrt(studios: gespeichert.studios)
    return true
}
```

In `load()` wird `let response = try await loader.bootstrap()` ersetzt durch:

```swift
let geladen = try await loader.bootstrapMitRohdaten()
let response = geladen.antwort
if let rohdaten = geladen.rohdaten, let userId {
    bootstrapFileStore?.save(rohdaten, userId: userId)
}
```

In `reset()` kommt dazu: `bootstrapFileStore?.loeschen()` und `userId = nil`.

- [ ] **Step 6: Verdrahtung.** In `FitnessMemberApp` wird der CatalogStore zu `CatalogStore(loader: client, pendingWriteStore: PendingWriteStore(), bootstrapFileStore: BootstrapFileStore())`. In `RootView` wird der `if sessionStore.session != nil {`-Zweig zu:

```swift
if let session = sessionStore.session {
    hatteSession = true
    // Erst anmelden: ohne Bootstrap im Speicher steht der gespeicherte
    // sofort da (Offline-Spec 3a). Kam er aus dem Cache, wird trotzdem
    // nachgeladen -- er kann Stunden alt sein.
    let ausCache = catalogStore.anmelden(userId: session.userId)
    // [bestehender Kommentar zu .idle/.failed bleibt]
    if ausCache || catalogStore.loadState == .idle || catalogStore.loadState == .failed {
        await catalogStore.load()
    }
}
```

`ladeschirm` wird zu:

```swift
private var ladeschirm: some View {
    VStack(spacing: DesignSystem.Spacing.s16) {
        ProgressView()
            .tint(DesignSystem.Color.accent)
        // Nach 3 s ein ehrlicher Satz statt eines stummen Spinners
        // (Offline-Spec 2).
        if verbindungLangsam {
            Text("Verbindung ist langsam …")
                .font(.system(size: 13))
                .foregroundStyle(DesignSystem.Color.textFaint)
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(DesignSystem.Color.bg)
    .task {
        try? await Task.sleep(for: .seconds(3))
        verbindungLangsam = true
    }
    .testnotizScreen()
}
```

Dazu kommt `@State private var verbindungLangsam = false` neben `hatteSession`.

- [ ] **Step 7:** `$TEST CatalogStoreTests`, `$TEST APIClientTests` und `$TEST RootDestinationTests` müssen PASS ergeben, danach der ganze Lauf.
- [ ] **Step 8: Commit**

```bash
git add FitnessMember FitnessMemberTests FitnessMember.xcodeproj
git commit -m "feat(ios): Bootstrap je User gespeichert, Start ohne Netz"
```

---

### Task 12: Warteschlange: 401 vorübergehend, gehört einem User, Retry alle 30 s

**Files:**
- Modify: `FitnessMember/Networking/APIError.swift` (nach `istDauerhaft`)
- Modify: `FitnessMember/Catalog/CatalogStore.swift` (`init`, `anmelden`, `reset`, `flushPending`)
- Modify: `FitnessMember/Navigation/RootView.swift` (nach `load()`)
- Test: `FitnessMemberTests/CatalogStoreTests.swift`

**Interfaces:**
- Consumes: `CatalogStore.anmelden(userId:)` und `userId` aus Task 11.
- Produces: `APIError.istAnmeldefehler: Bool`
- Produces: `CatalogStore.init(…, wiederholungsAbstand: Duration = .seconds(30))`
- Verhalten:
  - `flushPending` sendet nur, wenn der gespeicherte Besitzer der Warteschlange `nil` ist oder gleich `userId`.
  - Es läuft nie mehr als ein Flush gleichzeitig.
  - Bleiben Einträge offen, plant der Store einen Retry.
  - `reset()` löscht die Warteschlange **nicht** mehr. Das passiert erst bei `anmelden` mit einer anderen User-ID.

- [ ] **Step 1: Tests schreiben.** Zuerst die zwei bestehenden Tests suchen, die `store.reset()` aufrufen (`CatalogStoreTests.swift:388, 416`). Der Test, der „reset leert pendingWrites“ erwartet, wird umgeschrieben zu:

```swift
@Test("reset behaelt die Warteschlange, ein anderer User loescht sie")
func warteschlangeUeberlebtAbmelden() async {
    let verzeichnis = tempDirectory()
    let store = CatalogStore(loader: FakeBootstrapLoader(), pendingWriteStore: PendingWriteStore(directory: verzeichnis))
    store.anmelden(userId: "u1")
    store.enqueue(testWrite())
    store.reset()
    #expect(store.pendingWrites.count == 1)
    store.anmelden(userId: "u1")
    #expect(store.pendingWrites.count == 1)
    store.anmelden(userId: "u2")
    #expect(store.pendingWrites.isEmpty)
}
```

`testWrite()` steht für den Helper, mit dem die bestehenden Flush-Tests ein `PendingSetWrite` bauen. Den Namen per `grep -n "PendingSetWrite(" FitnessMemberTests/CatalogStoreTests.swift` ermitteln und hier verwenden. Gibt es keinen, wird der Ausdruck aus dem ersten Flush-Test in eine `private func testWrite() -> PendingSetWrite` gezogen.

Prüft der zweite reset-Test `verworfeneWrites`, gilt dieselbe Umstellung.

Neue Tests:

```swift
@Test("401 laesst den Satz in der Warteschlange")
func unauthorizedBleibt() async {
    let loader = FakeBootstrapLoader()
    await loader.setPutSetResult(.failure(.unauthorized(message: "x")))
    let store = CatalogStore(loader: loader, pendingWriteStore: PendingWriteStore(directory: tempDirectory()))
    store.enqueue(testWrite())
    await store.flushPending()
    #expect(store.pendingWrites.count == 1)
    #expect(store.verworfeneWrites.isEmpty)
}

@Test("422, 404 und 409 verwerfen weiterhin",
      arguments: [APIError.validation(message: "v"), .notFound(message: "n"), .conflict(message: "c")])
func echteDatenfehlerVerwerfen(_ fehler: APIError) async {
    let loader = FakeBootstrapLoader()
    await loader.setPutSetResult(.failure(fehler))
    let store = CatalogStore(loader: loader, pendingWriteStore: PendingWriteStore(directory: tempDirectory()))
    store.enqueue(testWrite())
    await store.flushPending()
    #expect(store.pendingWrites.isEmpty)
    #expect(store.verworfeneWrites.count == 1)
}

@Test("nach dem Abmelden sendet die Warteschlange nichts")
func nachAbmeldenSendetNichts() async {
    let loader = FakeBootstrapLoader()
    let store = CatalogStore(loader: loader, pendingWriteStore: PendingWriteStore(directory: tempDirectory()))
    store.anmelden(userId: "u1")
    store.enqueue(testWrite())
    store.reset()
    await store.flushPending()
    #expect(await loader.putSetCalls.isEmpty)
}

@Test("zwei gleichzeitige Flushs senden einmal")
func keinDoppelterFlush() async {
    let loader = FakeBootstrapLoader()
    await loader.setPutSetResult(.failure(.offline))
    let store = CatalogStore(loader: loader, pendingWriteStore: PendingWriteStore(directory: tempDirectory()),
                             wiederholungsAbstand: .seconds(60))
    store.enqueue(testWrite())
    async let a: Void = store.flushPending()
    async let b: Void = store.flushPending()
    _ = await (a, b)
    #expect(await loader.putSetCalls.count == 1)
}

@Test("offene Eintraege werden nach dem Abstand erneut gesendet")
func wiederholtNachAbstand() async throws {
    let loader = FakeBootstrapLoader()
    await loader.setPutSetResult(.failure(.offline))
    let store = CatalogStore(loader: loader, pendingWriteStore: PendingWriteStore(directory: tempDirectory()),
                             wiederholungsAbstand: .milliseconds(50))
    store.enqueue(testWrite())
    await store.flushPending()
    #expect(await loader.putSetCalls.count == 1)
    try await Task.sleep(for: .milliseconds(300))
    #expect(await loader.putSetCalls.count >= 2)
}
```

Die Erfolgsantwort von `putSet` wird in diesen Tests nicht gebraucht. Der Retry-Test prüft nur, dass erneut gesendet wird.

Falls die `APIError`-Fälle anders heißen (`.validation(message:)` u. a.), gilt die Definition in `APIError.swift`.

- [ ] **Step 2:** `$TEST CatalogStoreTests` muss FAIL ergeben.
- [ ] **Step 3: `APIError` erweitern**

```swift
/// 401 -- in der Warteschlange voruebergehend: offline gibt es keinen
/// gueltigen Token, und der Satz darf deshalb nicht verloren gehen
/// (Offline-Spec 4c). `istDauerhaft` bleibt fuer andere Aufrufer gleich.
var istAnmeldefehler: Bool {
    if case .unauthorized = self { true } else { false }
}
```

- [ ] **Step 4: `CatalogStore` umsetzen**

```swift
private let wiederholungsAbstand: Duration
private var flushLaeuft = false
private var wiederholung: Task<Void, Never>?
private let besitzerDatei: URL

/// Wem die Warteschlange gehoert. Auf Platte neben ihr, weil sie ein
/// Abmelden ueberlebt (Offline-Spec 4c): erst ein anderes Konto loescht sie.
private var warteschlangenBesitzer: String? {
    get { (try? String(contentsOf: besitzerDatei, encoding: .utf8)).flatMap { $0.isEmpty ? nil : $0 } }
    set {
        if let newValue { try? Data(newValue.utf8).write(to: besitzerDatei, options: .atomic) }
        else { try? FileManager.default.removeItem(at: besitzerDatei) }
    }
}
```

Im Init: Parameter `wiederholungsAbstand: Duration = .seconds(30)` (nach `defaults`), dazu `self.wiederholungsAbstand = wiederholungsAbstand` und `besitzerDatei = pendingWriteStore.directory.appendingPathComponent("warteschlange-besitzer.txt")`.

`anmelden(userId:)` beginnt, vor dem Cache-Teil aus Task 11, mit:

```swift
if let besitzer = warteschlangenBesitzer, besitzer != userId {
    // Saetze eines anderen Kontos -- mit diesem Token abgelehnt.
    pendingWrites = []
    pendingWriteStore.save([])
    verworfeneWrites = []
    verworfeneWriteStore.save([])
}
warteschlangenBesitzer = userId
```

In `reset()` werden die vier Zeilen zu `pendingWrites`, `pendingWriteStore`, `verworfeneWrites` und `verworfeneWriteStore` entfernt. Dazu kommt `wiederholung?.cancel(); wiederholung = nil`. Der Doc-Kommentar über `reset()` wird angepasst: „Die offenen Schreibvorgaenge bleiben -- sie gehoeren dem Konto (Besitzer) und gehen nach erneutem Anmelden desselben Kontos raus; ein anderes Konto loescht sie in `anmelden` (Offline-Spec 4c).“

`flushPending()`:

```swift
func flushPending() async {
    // Nach dem Abmelden oder vor dem Anmelden: nicht mit fremdem Token senden.
    if let besitzer = warteschlangenBesitzer, besitzer != userId { return }
    guard !flushLaeuft else { return }
    flushLaeuft = true
    defer {
        flushLaeuft = false
        wiederholungPlanen()
    }
    for write in pendingWrites {
        // [bestehender Kommentar]
        guard pendingWrites.contains(where: { $0.id == write.id }) else { continue }
        do {
            _ = try await loader.putSet(sessionId: write.sessionId, setId: write.setId, write.body)
            entferneAusPendingWrites(write)
        } catch {
            // 401 ist hier voruebergehend: offline ohne gueltigen Token
            // (Offline-Spec 4c).
            if error.istDauerhaft && !error.istAnmeldefehler {
                // [bestehender Kommentar]
                verworfeneWrites.append(write)
                verworfeneWriteStore.save(verworfeneWrites)
                entferneAusPendingWrites(write)
            }
        }
    }
}

/// Bei halbem Netz meldet der Monitor "online", und der naechste Wechsel
/// kommt vielleicht nie -- deshalb ein eigener Versuch nach
/// `wiederholungsAbstand`, solange etwas offen ist (Offline-Spec 2).
private func wiederholungPlanen() {
    guard !pendingWrites.isEmpty else {
        wiederholung?.cancel()
        wiederholung = nil
        return
    }
    guard wiederholung == nil else { return }
    wiederholung = Task { [weak self, wiederholungsAbstand] in
        try? await Task.sleep(for: wiederholungsAbstand)
        guard !Task.isCancelled, let self else { return }
        self.wiederholung = nil
        await self.flushPending()
    }
}
```

Hinweis: Ohne `anmelden` bleibt `warteschlangenBesitzer` `nil`. Damit verhalten sich bestehende Tests und Bestandsinstallationen wie bisher.

- [ ] **Step 5: RootView.** Nach dem `load()`-Block aus Task 11, noch im `if let session`-Zweig, kommt dazu:

```swift
// Der Besitzer der Warteschlange steht erst jetzt fest -- der Flush beim
// App-Start lief davor ins Leere (Offline-Spec 4c).
await catalogStore.flushPending()
```

- [ ] **Step 6:** `$TEST CatalogStoreTests` muss PASS ergeben, danach der ganze Lauf.
- [ ] **Step 7: Commit**

```bash
git add FitnessMember FitnessMemberTests
git commit -m "fix(ios): Warteschlange verwirft bei 401 nichts mehr und versucht alle 30 s erneut"
```

---

### Task 13: Videos vorladen

**Files:**
- Modify: `FitnessMember/Workout/UebungsVideos.swift:53-80` (`UebungsVideoVorrat`)
- Modify: `FitnessMember/FitnessMemberApp.swift:15` (Vorrat mit `istOnline`)
- Test: `FitnessMemberTests/UebungsVideosTests.swift`

**Interfaces:**
- Consumes: `NetzwerkMonitor`-Instanz `netz` aus Task 6 (in `FitnessMemberApp.init`).
- Produces: `UebungsVideoVorrat.init(ablage: Medienablage = Medienablage(), istOnline: @escaping @MainActor () -> Bool = { true })`
- Produces: `UebungsVideoVorrat.vorladenAbwarten() async`, nur für Tests und ohne Seiteneffekt.

- [ ] **Step 1: Tests schreiben** (neue Suite in `UebungsVideosTests.swift`)

```swift
@MainActor
struct VideoVorladenTests {
    private actor Zaehler {
        var abrufe: [URL] = []
        func laden(_ url: URL) -> Data? { abrufe.append(url); return Data("v".utf8) }
    }

    private struct Fake: UebungsvideosLoading {
        let antwort: ExerciseVideosResponse
        func exerciseVideos() async throws(APIError) -> ExerciseVideosResponse { antwort }
    }

    private func antwort(_ ids: [String]) -> ExerciseVideosResponse {
        ExerciseVideosResponse(videos: ids.map {
            .init(exerciseId: $0, url: "https://example.test/\($0).mp4?token=a", pfad: "gymtavo/\($0).mp4")
        })
    }

    private func ablage(_ zaehler: Zaehler) -> Medienablage {
        Medienablage(ordner: FileManager.default.temporaryDirectory
                        .appendingPathComponent("vorladen-\(UUID().uuidString)")) { await zaehler.laden($0) }
    }

    @Test func laedtAlleFehlendenEinmal() async {
        let zaehler = Zaehler()
        let vorrat = UebungsVideoVorrat(ablage: ablage(zaehler))
        await vorrat.laden(von: Fake(antwort: antwort(["u1", "u2"])))
        await vorrat.vorladenAbwarten()
        #expect(await zaehler.abrufe.count == 2)

        await vorrat.laden(von: Fake(antwort: antwort(["u1", "u2"])))
        await vorrat.vorladenAbwarten()
        #expect(await zaehler.abrufe.count == 2)
    }

    @Test func offlineLaedtNichts() async {
        let zaehler = Zaehler()
        let vorrat = UebungsVideoVorrat(ablage: ablage(zaehler), istOnline: { false })
        await vorrat.laden(von: Fake(antwort: antwort(["u1"])))
        await vorrat.vorladenAbwarten()
        #expect(await zaehler.abrufe.isEmpty)
    }
}
```

- [ ] **Step 2:** `$TEST VideoVorladenTests` muss FAIL ergeben.
- [ ] **Step 3: Umsetzung**

```swift
@ObservationIgnored private let istOnline: @MainActor () -> Bool
@ObservationIgnored private var vorladen: Task<Void, Never>?

init(ablage: Medienablage = Medienablage(), istOnline: @escaping @MainActor () -> Bool = { true }) {
    self.ablage = ablage
    self.istOnline = istOnline
}

/// [bestehender Kommentar]
func laden(von loader: any UebungsvideosLoading) async {
    let neu = await UebungsVideos.laden(von: loader)
    if !neu.isEmpty {
        quellen = neu
        vorladenStarten()
    }
}

/// Holt alle Schleifen, die noch nicht auf der Platte liegen -- die erste
/// Einweisung an einem Geraet ist sonst genau die, die im Keller kein
/// Video hat (Offline-Spec 3d). Nacheinander, niedrige Prioritaet, auch
/// ueber Mobilfunk (~35 KB je Video). Offline bricht es ab; der naechste
/// erfolgreiche Abruf der Quellen startet es neu.
private func vorladenStarten() {
    guard vorladen == nil else { return }
    let liste = quellen.sorted { $0.key < $1.key }
    vorladen = Task(priority: .background) { [weak self] in
        for (exerciseId, quelle) in liste {
            guard let self, !Task.isCancelled, self.istOnline() else { break }
            _ = await self.ablage.datei(schluessel: exerciseId, quelle: quelle)
        }
        self?.vorladen = nil
    }
}

func vorladenAbwarten() async {
    await vorladen?.value
}
```

- [ ] **Step 4: Verdrahtung in `FitnessMemberApp`**
  - `@State private var videoVorrat = UebungsVideoVorrat()` wird zu `@State private var videoVorrat: UebungsVideoVorrat`.
  - In `init()` nach `let netz = …` kommt `_videoVorrat = State(initialValue: UebungsVideoVorrat(istOnline: { netz.istOnline }))` dazu.
- [ ] **Step 5:** `$TEST VideoVorladenTests` und `$TEST MedienablageTests` müssen PASS ergeben.
- [ ] **Step 6: Commit**

```bash
git add FitnessMember FitnessMemberTests
git commit -m "feat(ios): Uebungsvideos im Hintergrund vorladen"
```

---

### Task 14: Gesamtlauf und Abnahme

- [ ] **Step 1: Alle Tests**
  - `xcodebuild test -scheme FitnessMember -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet` muss PASS ergeben.
  - `pnpm --filter @fitretro/domain test` und `pnpm typecheck` müssen PASS ergeben.
- [ ] **Step 2: Abnahme auf dem iPhone mit Tim** (Network Link Conditioner, siehe Task 1)
  1. **Kaltstart:** App > 1 h nicht genutzt, „100% Loss“, App aus dem App-Switcher beenden und starten. Home und Training sind sofort da, kein Login, kein „NICHT GELADEN“.
  2. **Suche und Einweisung** bei „100% Loss“ und bei „Very Bad Network“: kein Einfrieren. Text und Video der Einweisung sind sichtbar, wenn das Video vorher vorgeladen war (einmal online Home geöffnet). Instruments „Hangs“ zeigt nichts über 250 ms.
  3. **Sätze:** Drei Sätze bei „100% Loss“ loggen, dann den Conditioner ausschalten. Nach höchstens 30 s sind alle drei auf dem Server (Verlauf in der App, oder im Trainerportal), und keiner landet als „nicht gespeichert“.
- [ ] **Step 3:** Befund der Abnahme als `## Anhang: Abnahme` an diesen Plan hängen und committen.

```bash
git add docs/superpowers/plans/2026-10-15-offline-stabilitaet.md
git commit -m "docs(plan): Abnahme Offline-Stabilitaet"
```
