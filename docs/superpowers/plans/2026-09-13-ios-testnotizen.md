# Testnotizen in der Member-App — Umsetzungsplan

> **Für agentische Ausführung:** ERFORDERLICHE UNTER-SKILL: `superpowers:subagent-driven-development` (empfohlen) oder `superpowers:executing-plans`, Aufgabe für Aufgabe. Die Schritte tragen Checkboxen (`- [ ]`) zum Mitführen.

**Ziel:** Wer die App am Gerät testet, hält einen Fund mit zwei Tipps fest — Ausschnitt markieren oder Element antippen, Notiz tippen oder sprechen — und bekommt einen Ordner, den Claude Code ohne Nachfragen abarbeitet: Screenshot, Ausschnitt, Screen samt Quelldatei, Element samt Kennung und Fundstelle, Transkript, Protokoll der letzten Minuten.

**Architektur:** Ein Debug-Modul `FitnessMember/Testnotiz/`, jede Datei unter `#if DEBUG`. Ein zweites `UIWindow` über der App trägt Knopf, Menü und Auswahlmodi; in Ruhe lässt es jede Berührung außerhalb des Knopfrahmens durch. Der aktuelle Screen kommt aus einem Modifier an jeder Screen-Wurzel, der über `#filePath` die Quelldatei meldet. Elemente kommen aus dem Accessibility-Baum, den das Modul für die Dauer einer Suche per privater API einschaltet; ein zweiter Modifier setzt an wichtigen Knöpfen die Kennung und meldet Datei und Zeile. Es gibt keinen Server: Ablage ist ein Ordner unter `Documents`, der Weg zu Claude Code ist AirDrop oder die Dateien-App.

**Tech-Stack:** Swift 6 (Strict Concurrency) / SwiftUI / UIKit für Fenster und Foto / AVFoundation und Speech / OSLog / Swift Testing / XcodeGen.

**Spec:** `docs/superpowers/specs/2026-09-14-testnotiz-format.md` — der Format-Vertrag für `sitzung.json` und `sitzung.md`, den eine spätere Android-App genauso erfüllt.

**Stand:** Der Entwurf vom 13. September entstand ohne Mac. Diese Fassung ist am 14. September gegen Xcode 26.3 und den iPhone-17-Pro-Simulator (iOS 26.3) geprüft: Jede Aufgabe wurde in einem Wegwerf-Worktree der Reihe nach eingespielt, gebaut und getestet; der Code in diesem Plan ist genau der geprüfte. Nach Aufgabe 8 laufen alle 502 iOS-Tests grün, und der Release-Beweis aus Aufgabe 1 liefert überall 0. **Nicht** geprüft ist, was nur ein Gerät zeigt: Mikrofon, On-Device-Transkription, Dateien-App, AirDrop — und der Accessibility-Schalter auf echter Hardware (Aufgabe 6, Schritt 1).

---

## Globale Rahmenbedingungen

- **Kein Byte davon im Release.** Jede Datei des Moduls steht unter `#if DEBUG`. Wo die App eine Modul-Funktion aufruft, gibt es im `#else`-Zweig eine Attrappe **ohne** `#filePath`-Parameter, damit kein Pfad des Build-Macs ins Binary kommt. Beweis: Aufgabe 1, Schritt 7, noch einmal in Aufgabe 8.
- **Keine Personendaten im Ordner** (Blueprint, Architekturprinzip 6). Kein Feld trägt E-Mail, Token oder Anzeigenamen. Das Protokoll übernimmt nur Kategorien aus `TestnotizProtokoll.kategorien` (heute: `tag`) — im eigenen Prozess schwärzt OSLog `privacy: .private` **nicht**.
- **Kein Netz.** Das Modul sendet nichts.
- **Kommentare in Swift ohne Umlaute** (ASCII), wie im gesamten iOS-Ziel. Nutzertexte tragen Umlaute. Kommentare begründen, sie beschreiben nicht.
- **Design-Tokens aus `DesignSystem.swift`**, nie als Farb- oder Abstandsliteral. Trefferflächen nie unter 44 pt, höchstens eine Akzentfläche je Blatt.
- **Swift 6 Strict Concurrency.** Fenster, Knopf, Stapel, Register: `@MainActor`. Die Ablage ist ein `actor`. Callbacks, die das System auf fremden Queues ruft (Spracherkennung), werden in `nonisolated` Funktionen geschrieben — eine Closure aus dem MainActor erbt dessen Isolation und bricht in Swift 6 zur Laufzeit ab.
- **Swift Testing** (`import Testing`, `@Test`, `#expect`), `struct`-Suiten; Testdateien des Moduls stehen ebenfalls unter `#if DEBUG`, weil sie Debug-Typen nutzen.
- **Neue Dateien brauchen keinen pbxproj-Eingriff:** `project.yml` zieht Verzeichnisse. Nach jedem Anlegen `xcodegen generate`. Die JSON-Fixture im Testordner kopiert XcodeGen automatisch als Ressource ins Testbundle (geprüft).
- **Deutsche Bezeichner** wie im Bestand. JSON-Schlüssel im Ordner sind Englisch (Spec).
- **Anker statt Zeilennummern.** Jede Änderung an bestehenden Dateien nennt den exakten Text vorher und nachher. Der Branch `claude/ios-app-improvements-wd5egl` ändert parallel `SessionDetailView` und `KurseWochenView`; findet sich ein Anker dort nicht mehr wörtlich, gilt die Regel dahinter (Modifier ans Ende der Modifier-Kette der äußersten View in `body`).
- **Commits** je Aufgabe, Nachricht im Hausstil `feat(testnotiz): …`.

---

## Vorab geklärt

Der Entwurf markierte drei Annahmen und setzte in Aufgabe 1 und 5 Prüfschritte. Beide Prüfungen sind am 14. September im Simulator gelaufen, mit Wegwerf-Tests im App-Prozess.

| Frage | Ergebnis | Folge |
| --- | --- | --- |
| Feuert `onDisappear` für die überdeckte Wurzel beim `NavigationStack`-Push? | Ja. Reihenfolge: Ziel erscheint, **danach** verschwindet die Wurzel. Beim Pop umgekehrt. Tab-Wechsel wie Push. | Stapel mit Token-Zähler (Aufgabe 3). `stack` ist die sichtbare Ebenenfolge, kein Navigationsverlauf. |
| Liefert der Accessibility-Baum im Prozess etwas ohne VoiceOver? | **Nein, 0 Elemente.** Nach `_AXSApplicationAccessibilitySetEnabled(1)` aus `libAccessibility.dylib` sofort alle SwiftUI-Knoten mit Label, Traits, Bildschirmrahmen und `accessibilityIdentifier`. Der Schalter **bleibt je Bundle-ID über Neustarts gespeichert.** | Private API, Debug-only, nur für die Dauer einer Suche eingeschaltet und danach zurückgestellt (Aufgabe 6). Der Baum wird die Hauptquelle; das Register liefert nur noch Datei und Zeile. |
| Stimmen Element-Koordinaten in Sheets? | Ja. `.global`, Fenster- und Bildschirmkoordinaten sind im Sheet deckungsgleich. | Die Sheet-Korrektur aus dem Entwurf entfällt. |
| Gibt der Hosting-View in `hitTest` für leere Flächen sich selbst zurück? | Ja — **und für den Knopf auch.** Die Bedingung des Entwurfs hätte den Knopf taub gemacht. | `hitTest` entscheidet über den gemeldeten Knopfrahmen (Aufgabe 1). Aus demselben Grund kein SwiftUI-`Menu`: seine Einträge lägen außerhalb des Rahmens. |
| Kennt Xcode `INFOPLIST_KEY_UIFileSharingEnabled`? | Nein, der Schlüssel wird still verworfen. `LSSupportsOpeningDocumentsInPlace` und die beiden Usage-Texte gehen. | Debug-Konfiguration bekommt eine eigene Additions-Plist, die die vier bestehenden Schlüssel wiederholt (Aufgabe 1). |
| Beweist `strings` über das Release-Binary, dass nichts drin ist? | Nicht allein. Seit Xcode 16 liegt Debug-Code in `FitnessMember.debug.dylib`; `strings` auf die Hauptdatei zeigt auch im Debug 0. Unverstrippt stehen Objektdateinamen (`TestnotizScreenModifier.o`) im Release. | Beweis über die gestrippte Kopie plus Bundle-Suche plus Gegenprobe am Debug-Build (Aufgabe 1). |
| Liefert `#fileID` den Pfad? | Nein, nur `FitnessMember/GeraetView.swift`. | `#filePath`, ab `apps/ios-member/` repo-relativ gekürzt (`Quellpfad`). |
| Wandert eine Kennung von der Aufrufstelle auf den Knopf in der Komponente? | Ja, samt 64-pt-Rahmen; auch `.accessibilityLabel` wandert. | Die Design-System-Komponenten bleiben unverändert; markiert wird an der Aufrufstelle (Aufgabe 6). |
| Liest `OSLogStore(scope: .currentProcessIdentifier)` im Prozess? | Ja, auch im Test-Host. `privacy: .private`-Werte kommen im Klartext. | Kategorien-Liste als einzige Schranke (Aufgabe 4). |
| Fokus im `TextField` eines Nicht-Key-Fensters, Sheet aus dem Overlay? | Beides geht ohne `makeKey`. | Das Overlay wird nie Key-Window und stört den Fokus der App nicht. |
| `NSFileCoordinator` `.forUploading` im Simulator? | Liefert ein echtes Zip (`PK`). | Teilen ohne Fremdbibliothek (Aufgabe 2). |

---

## Entwurf

### Knopf und Fenster

`TestnotizFenster` hängt in derselben `UIWindowScene`, `windowLevel = .alert + 1`. In `.ruhe` fängt es nur Punkte im Knopfrahmen (plus 8 pt), alles andere geht an die App. In jedem anderen Modus fängt es die ganze Fläche. Der Knopf ist ein 44-pt-Kreis am rechten Rand, vertikal ziehbar; ein Tipp nimmt **sofort** das Bildschirmfoto und merkt sich den aktuellen Screen, dann öffnet sich das Menü. Da das Overlay-Fenster beim Foto ausgelassen wird, stehen weder Knopf noch Menü im Bild, und die App kann sich danach nicht mehr ändern, weil das Fenster alle Berührungen fängt.

| Menü | Modus | Ergebnis |
| --- | --- | --- |
| Ausschnitt | Rechteck ziehen | Eintrag `crop` mit Vollbild, Ausschnitt, beiden Rahmen |
| Element | Punkt tippen | Eintrag `element` mit Kennung, Label, Typ, Rahmen, Fundstelle |
| Nur Notiz | — | Eintrag `note` mit Vollbild |
| Sitzung (n) | Blatt | Teilen als Zip, Ordner in Dateien öffnen, neue Sitzung |

Nach Ausschnitt, Element und Nur Notiz öffnet sich das Notiz-Blatt: Textfeld, Sprachnotiz, „Sichern“. Das Blatt schließt beim Sichern sofort; geschrieben wird danach, das Transkript kommt Sekunden später nach.

### Screen-Erkennung

`.testnotizScreen(kontext:)` an jeder Screen-Wurzel. `onAppear` legt einen Eintrag mit festem Token auf den Stapel, `onDisappear` nimmt ihn herunter, `onChange(of: kontext)` zieht den Kontext nach. Gezählt wird je Token, weil ein Modifier an einer `Group` auf jedes Kind verteilt wird. Bei Screens mit eigenem `NavigationStack` (Home, Training) sitzt der Modifier **innerhalb** des Stacks, sonst verschwindet beim Push nichts. Der Dreischritt meldet seine drei Schritt-Screens einzeln statt `ErstkontaktFlow`.

### Element-Erkennung

Ein Tipp im Element-Modus schaltet den Accessibility-Baum ein (falls aus), wartet 150 ms, sucht und stellt zurück. Gesucht wird im obersten App-Fenster, das den Punkt per `hitTest` fängt, im Teilbaum unter dem Finger — so gewinnt ein Sheet gegen den Screen darunter, obwohl beide im selben Fenster hängen. Treffer ist das kleinste Element, das den Punkt enthält, sonst das nächste innerhalb von 22 pt. `.testnotizElement("geraet.satz-sichern", typ: "PrimaryButton")` an der Aufrufstelle setzt die Kennung und meldet Typ, Datei und Zeile an das Register; die Zeile ist die des Modifiers, eine unter dem Knopf.

### Sprachnotiz

`AVAudioRecorder` in `.m4a`. `SFSpeechRecognizer(de-DE)` mit `requiresOnDeviceRecognition`; ohne Modell bleibt das Audio, `transcript` ist `null`. Beide Usage-Texte stehen nur in der Debug-Konfiguration.

### Ablage

`Documents/Testnotizen/<yyyy-MM-dd-HHmm>/` mit `sitzung.md`, `sitzung.json` und nummerierten Dateien, Format laut Spec. `UIFileSharingEnabled` macht den Ordner in Dateien und Finder sichtbar. Im Repo ist `apps/ios-member/testnotizen/` der gitignorierte Eingang.

---

## Dateistruktur

### Modul — `apps/ios-member/FitnessMember/Testnotiz/`

| Datei | Verantwortung | Aufgabe |
| --- | --- | --- |
| `Testnotiz.swift` | `@MainActor @Observable` Singleton: Modus, Entwurf, Stapel, Register, Ablage; Ablauf vom Tipp bis zum Sichern; Installation und Release-Attrappe | 1, erweitert in 3, 5–8 |
| `TestnotizFenster.swift` | Overlay-`UIWindow`, `faengt(punkt:modus:knopfRahmen:)` | 1 |
| `TestnotizOberflaeche.swift` | Wurzel-View des Overlays: je Modus eine Ansicht, Blätter | 1, erweitert in 5–8 |
| `TestnotizKnopf.swift` | Kreis, Ziehen, `KnopfLage` | 1 |
| `TestnotizMenue.swift` | Menü-Panel | 1, erweitert in 3, 5–8 |
| `TestnotizEintrag.swift` | `Codable`-Werte der Spec, `JSONEncoder.testnotiz`, `JSONDecoder.testnotiz` | 2 |
| `Zeitformat.swift` | Ordnername und Uhrzeiten ohne Locale | 2 |
| `TestnotizMarkdown.swift` | `sitzung.md` aus den Werten | 2 |
| `TestnotizAblage.swift` | `actor`: Ordner, Nummern, Schreiben, Transkript nachtragen, Zip | 2 |
| `TestnotizScreenStapel.swift` | `ScreenEintrag`, Stapel, `Quellpfad` | 3 |
| `TestnotizScreenModifier.swift` | `.testnotizScreen(kontext:)` | 3 |
| `TestnotizProtokoll.swift` | OSLog-Auszug mit Kategorien-Liste | 4 |
| `Laufzeitkontext.swift` | Laufzeit je Eintrag, Sitzungskopf, Modellkennung | 4 |
| `Bildschirmfoto.swift` | Foto aller App-Fenster, `Ausschnitt` | 5 |
| `AuswahlOverlay.swift` | Rechteck ziehen, Punkt tippen | 5 |
| `AccessibilityBaum.swift` | Sammeln, Treffer, `AXSchalter` | 6 |
| `TestnotizElement.swift` | Register und `.testnotizElement(_:typ:)` | 6 |
| `Sprachnotiz.swift` | `Aufnahme`, `Transkription` | 7 |
| `NotizBlatt.swift` | Text, Aufnahme, Sichern | 7 |
| `SitzungBlatt.swift` | Zähler, Teilen, Dateien, neue Sitzung | 8 |

### App — Änderungen

| Datei | Änderung | Aufgabe |
| --- | --- | --- |
| `apps/ios-member/project.yml` | `configs.Debug`: Debug-Plist, zwei Usage-Texte | 1 |
| `apps/ios-member/FitnessMember/Info-Additions-Debug.plist` **(neu)** | vier bestehende Schlüssel plus `UIFileSharingEnabled`, `LSSupportsOpeningDocumentsInPlace` | 1 |
| `FitnessMemberApp.swift` | `.testnotizInstallieren(netz:katalog:session:)` | 1 |
| 26 Screen-Wurzeln | `.testnotizScreen(…)` | 3 |
| `GeraetView`, `TrainingRootView`, `HomeRootView`, `ProfilRootView` | 11 × `.testnotizElement(…)` | 6 |
| `.gitignore`, `apps/ios-member/testnotizen/README.md` **(neu)** | Eingang | 8 |

### Tests — `apps/ios-member/FitnessMemberTests/`

| Datei | Deckt | Aufgabe |
| --- | --- | --- |
| `TestnotizFensterTests.swift` | Durchlässigkeit, Knopflage | 1 |
| `Fixtures/testnotiz-beispiel.json` | Beispiel der Spec | 2 |
| `TestnotizEintragTests.swift` | Fixture lesen, `null` statt weglassen, Offset, Rundreise | 2 |
| `TestnotizMarkdownTests.swift` | alle Regeln aus der Spec-Tabelle | 2 |
| `TestnotizAblageTests.swift` | Ordnername, Suffix, Nummern, Audio, Nachtrag, Zip | 2 |
| `TestnotizScreenStapelTests.swift` | Push, Pop, Sheet, Tab, Group, Quellpfad | 3 |
| `TestnotizProtokollTests.swift` | Stufen, Kategorien-Filter gegen echtes OSLog, Modellkennung | 4 |
| `AusschnittTests.swift` | Pixelrechnung, Schneiden | 5 |
| `AccessibilityBaumTests.swift` | Treffer, Typ, Register, Rückstellung des Schalters, **echter Baum im Prozess** | 6 |

---

## Was dieser Plan bewusst nicht baut

- **Kein Overlay über fremde Apps.** iOS erlaubt es nicht.
- **Kein Upload, kein Ticket-System, kein Sentry, kein MCP-Server.** Erst muss sich zeigen, ob `sitzung.md` als Auftrag genügt.
- **Kein TestFlight-Build mit Testnotizen.** TestFlight baut Release; Pilotmitglieder sollen keinen Knopf sehen.
- **Keine Bildschirmaufnahme, kein Zeichnen auf dem Screenshot.**
- **Kein Hervorheben des gefundenen Elements** vor dem Blatt. Das Blatt zeigt die Element-Zeile; das genügt zur Kontrolle.
- **Kein Android.** Die Spec bereitet es vor.
- **Keine Serverstimme für die Transkription.** On-Device oder gar nicht.
- **Kein `.sql`, keine Änderung an `packages/domain` oder `apps/web`.**


---

## Aufgabe 1: Fenster, Knopf, Menü — und der Beweis, dass Release nichts davon hat

**Dateien:**
- Ändern: `apps/ios-member/project.yml`, `apps/ios-member/FitnessMember/FitnessMemberApp.swift`
- Anlegen: `apps/ios-member/FitnessMember/Info-Additions-Debug.plist`
- Anlegen: `Testnotiz/Testnotiz.swift`, `TestnotizFenster.swift`, `TestnotizKnopf.swift`, `TestnotizMenue.swift`, `TestnotizOberflaeche.swift`
- Test: `apps/ios-member/FitnessMemberTests/TestnotizFensterTests.swift`

**Schnittstellen:**
- Nutzt: `NetzwerkMonitor`, `CatalogStore`, `SessionStore` (alle `@MainActor`), `DesignSystem`
- Liefert:
  - `Testnotiz.shared` (`@MainActor @Observable final class Testnotiz`) mit `enum Modus { case ruhe, menue }` (spätere Aufgaben ergänzen Fälle), `var modus`, `var knopfRahmen: CGRect`, `private(set) var fenster: TestnotizFenster?`, schwache Referenzen `netz`, `katalog`, `session`, `func installieren(in:netz:katalog:session:)`, `func knopfGetippt()`, `func zurRuhe()`
  - `View.testnotizInstallieren(netz:katalog:session:) -> some View` — Release: gibt `self` zurück
  - `TestnotizFenster.faengt(punkt:modus:knopfRahmen:) -> Bool` (`@MainActor static`)
  - `KnopfLage.mitteY(gewuenscht:hoehe:)`, `KnopfLage.istTipp(_:)`
  - `struct TestnotizMenue: View` mit `struct Eintrag { id, titel, symbol, aktion }` und `private var eintraege: [Eintrag]`


- [ ] **Schritt 1: Debug-Konfiguration in `project.yml` und die Debug-Plist**

In `apps/ios-member/project.yml` ersetzen:

```yaml
        INFOPLIST_FILE: FitnessMember/Info-Additions.plist
    dependencies:
      - package: Supabase
```

durch

```yaml
        INFOPLIST_FILE: FitnessMember/Info-Additions.plist
      configs:
        # Nur der Entwicklungsbuild: Testnotiz-Modul (Mikrofon, Sprache,
        # Dateien-App). Release fragt nie nach einem Mikrofon.
        Debug:
          INFOPLIST_FILE: FitnessMember/Info-Additions-Debug.plist
          INFOPLIST_KEY_NSMicrophoneUsageDescription: "Nur im Entwicklungsbuild: Sprachnotizen zu Testfunden."
          INFOPLIST_KEY_NSSpeechRecognitionUsageDescription: "Nur im Entwicklungsbuild: Sprachnotizen werden auf dem Gerät in Text umgewandelt."
    dependencies:
      - package: Supabase
```

Anlegen: `apps/ios-member/FitnessMember/Info-Additions-Debug.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<!-- Wiederholt Info-Additions.plist: INFOPLIST_FILE gilt je Konfiguration nur einmal. -->
	<key>SUPABASE_URL</key>
	<string>$(SUPABASE_URL)</string>
	<key>SUPABASE_ANON_KEY</key>
	<string>$(SUPABASE_ANON_KEY)</string>
	<key>API_BASE_URL</key>
	<string>$(API_BASE_URL)</string>
	<key>DATENSCHUTZ_URL</key>
	<string>$(DATENSCHUTZ_URL)</string>
	<!-- Testnotiz: Ordner in der Dateien-App und im Finder. Xcode kennt
	     UIFileSharingEnabled nicht als INFOPLIST_KEY_ (Spike 2026-09-14). -->
	<key>UIFileSharingEnabled</key>
	<true/>
	<key>LSSupportsOpeningDocumentsInPlace</key>
	<true/>
</dict>
</plist>
```

Dann `cd apps/ios-member && xcodegen generate`.

- [ ] **Schritt 2: Der Test für Durchlässigkeit und Knopflage**

Anlegen: `apps/ios-member/FitnessMemberTests/TestnotizFensterTests.swift`

```swift
#if DEBUG
import CoreGraphics
import Testing
@testable import FitnessMember

@MainActor
struct TestnotizFensterTests {
    private let knopf = CGRect(x: 350, y: 500, width: 44, height: 44)

    @Test func inRuheFaengtNurDerKnopf() {
        #expect(TestnotizFenster.faengt(punkt: CGPoint(x: 372, y: 522), modus: .ruhe, knopfRahmen: knopf))
        #expect(!TestnotizFenster.faengt(punkt: CGPoint(x: 40, y: 300), modus: .ruhe, knopfRahmen: knopf))
    }

    @Test func einFingerbreitNebenDemKnopfFaengtNoch() {
        #expect(TestnotizFenster.faengt(punkt: CGPoint(x: 345, y: 522), modus: .ruhe, knopfRahmen: knopf))
        #expect(!TestnotizFenster.faengt(punkt: CGPoint(x: 340, y: 522), modus: .ruhe, knopfRahmen: knopf))
    }

    @Test func inJedemModusFaengtDieGanzeFlaeche() {
        #expect(TestnotizFenster.faengt(punkt: CGPoint(x: 40, y: 300), modus: .menue, knopfRahmen: knopf))
    }

    @Test func knopfBleibtGanzSichtbar() {
        #expect(KnopfLage.mitteY(gewuenscht: -50, hoehe: 700) == 22)
        #expect(KnopfLage.mitteY(gewuenscht: 900, hoehe: 700) == 678)
        #expect(KnopfLage.mitteY(gewuenscht: 300, hoehe: 700) == 300)
    }

    @Test func kleinerWegIstEinTipp() {
        #expect(KnopfLage.istTipp(CGSize(width: 3, height: -4)))
        #expect(!KnopfLage.istTipp(CGSize(width: 0, height: 12)))
    }
}
#endif
```

- [ ] **Schritt 3: Test laufen lassen — er darf nicht kompilieren**

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/TestnotizFensterTests 2>&1 | grep -E "✘|error:|Test run with"
```

Erwartet: `error: cannot find 'TestnotizFenster' in scope` und `cannot find 'KnopfLage'`.

- [ ] **Schritt 4: Fenster, Knopf, Menü, Oberfläche, Namespace**

Anlegen: `apps/ios-member/FitnessMember/Testnotiz/TestnotizFenster.swift`

```swift
#if DEBUG
import UIKit

/// Liegt ueber allem, auch ueber Alerts -- die will man festhalten koennen.
final class TestnotizFenster: UIWindow {
    override init(windowScene: UIWindowScene) {
        super.init(windowScene: windowScene)
        windowLevel = .alert + 1
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("nicht aus einem Storyboard") }

    /// In Ruhe faengt nur der Knopf (mit 8 pt Rand fuer den Finger). Nicht
    /// ueber super.hitTest entscheidbar: SwiftUIs Hosting-View gibt sich fuer
    /// die leere Flaeche UND fuer den Knopf selbst zurueck (Spike 2026-09-14).
    static func faengt(punkt: CGPoint, modus: Testnotiz.Modus, knopfRahmen: CGRect) -> Bool {
        modus != .ruhe || knopfRahmen.insetBy(dx: -8, dy: -8).contains(punkt)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let testnotiz = Testnotiz.shared
        guard Self.faengt(punkt: point, modus: testnotiz.modus, knopfRahmen: testnotiz.knopfRahmen) else { return nil }
        return super.hitTest(point, with: event)
    }
}
#endif
```

Anlegen: `apps/ios-member/FitnessMember/Testnotiz/TestnotizKnopf.swift`

```swift
#if DEBUG
import SwiftUI

enum KnopfLage {
    static let durchmesser: CGFloat = 44

    /// Klemmt die Knopfmitte so, dass der ganze Kreis sichtbar bleibt.
    static func mitteY(gewuenscht: CGFloat, hoehe: CGFloat) -> CGFloat {
        let halb = durchmesser / 2
        return min(max(gewuenscht, halb), max(hoehe - halb, halb))
    }

    /// Unter 6 pt Weg ist es ein Tipp, kein Zug.
    static func istTipp(_ zug: CGSize) -> Bool {
        abs(zug.width) < 6 && abs(zug.height) < 6
    }
}

/// Der schwebende Kreis am rechten Rand, vertikal verschiebbar.
struct TestnotizKnopf: View {
    @State private var mitteY: CGFloat?
    @State private var startY: CGFloat?

    var body: some View {
        GeometryReader { geo in
            let y = mitteY ?? geo.size.height * 0.62
            Image(systemName: "note.text")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(DesignSystem.Color.accent)
                .frame(width: KnopfLage.durchmesser, height: KnopfLage.durchmesser)
                .background(DesignSystem.Color.surfaceRaised, in: Circle())
                .overlay(Circle().stroke(DesignSystem.Color.line, lineWidth: 1))
                .contentShape(Circle())
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { rahmen in
                    Testnotiz.shared.knopfRahmen = rahmen
                }
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .global)
                        .onChanged { wert in
                            let start = startY ?? y
                            startY = start
                            mitteY = KnopfLage.mitteY(gewuenscht: start + wert.translation.height, hoehe: geo.size.height)
                        }
                        .onEnded { wert in
                            startY = nil
                            if KnopfLage.istTipp(wert.translation) {
                                Testnotiz.shared.knopfGetippt()
                            }
                        }
                )
                .accessibilityLabel("Testnotiz")
                .accessibilityAddTraits(.isButton)
                .position(x: geo.size.width - KnopfLage.durchmesser / 2 - DesignSystem.Spacing.s8, y: y)
        }
    }
}
#endif
```

Anlegen: `apps/ios-member/FitnessMember/Testnotiz/TestnotizMenue.swift`

```swift
#if DEBUG
import SwiftUI

/// Ein eigenes Panel statt SwiftUI-Menu: dessen Eintraege laegen ausserhalb
/// des Knopfrahmens, und das durchlaessige Fenster liesse Tipps darauf zur
/// App durch. Im Modus .menue faengt das Fenster alles.
struct TestnotizMenue: View {
    private let testnotiz = Testnotiz.shared

    struct Eintrag: Identifiable {
        let id: String
        let titel: String
        let symbol: String
        let aktion: () -> Void
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            DesignSystem.Color.bg.opacity(0.5)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { testnotiz.zurRuhe() }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                Text(kopfzeile)
                    .font(DesignSystem.Typography.label)
                    .tracking(1.5)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .padding(DesignSystem.Spacing.s16)

                ForEach(eintraege) { eintrag in
                    zeile(titel: eintrag.titel, symbol: eintrag.symbol, farbe: DesignSystem.Color.text, aktion: eintrag.aktion)
                }

                Rectangle().fill(DesignSystem.Color.line).frame(height: 1)
                zeile(titel: "Schließen", symbol: "xmark", farbe: DesignSystem.Color.textMuted, aktion: testnotiz.zurRuhe)
            }
            .background(DesignSystem.Color.surfaceRaised, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.haupt))
            .padding(DesignSystem.Spacing.s16)
        }
    }

    private var kopfzeile: String {
        "TESTNOTIZ"
    }

    private var eintraege: [Eintrag] {
        // Aufgabe 5 bis 8 tragen hier je einen Modus ein.
        []
    }

    private func zeile(titel: String, symbol: String, farbe: Color, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Label(titel, systemImage: symbol)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(farbe)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.horizontal, DesignSystem.Spacing.s16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
#endif
```

Anlegen: `apps/ios-member/FitnessMember/Testnotiz/TestnotizOberflaeche.swift`

```swift
#if DEBUG
import SwiftUI

/// Der Inhalt des Overlay-Fensters: je Modus genau eine Ansicht.
struct TestnotizOberflaeche: View {
    private let testnotiz = Testnotiz.shared

    var body: some View {
        ZStack {
            switch testnotiz.modus {
            case .ruhe:
                TestnotizKnopf()
            case .menue:
                TestnotizMenue()
            }
        }
    }
}
#endif
```

Anlegen: `apps/ios-member/FitnessMember/Testnotiz/Testnotiz.swift`

```swift
import SwiftUI

#if DEBUG
import Observation

/// Der eine Ort, an dem das Modul lebt. Ein Singleton, weil das Fenster
/// eines ist: eine Szene, ein Knopf darueber.
@MainActor
@Observable
final class Testnotiz {
    static let shared = Testnotiz()

    enum Modus: Equatable {
        case ruhe, menue
    }

    var modus: Modus = .ruhe
    /// Bildschirmrahmen des Knopfs. Ausserhalb davon laesst das Fenster in
    /// Ruhe jede Beruehrung zur App durch.
    var knopfRahmen: CGRect = .zero

    @ObservationIgnored private(set) var fenster: TestnotizFenster?
    @ObservationIgnored private(set) weak var netz: NetzwerkMonitor?
    @ObservationIgnored private(set) weak var katalog: CatalogStore?
    @ObservationIgnored private(set) weak var session: SessionStore?

    /// Idempotent: RootView kann mehrfach in ein Fenster wandern
    /// (Session-Wechsel), das Overlay-Fenster darf es nur einmal geben.
    func installieren(in szene: UIWindowScene, netz: NetzwerkMonitor, katalog: CatalogStore, session: SessionStore) {
        self.netz = netz
        self.katalog = katalog
        self.session = session
        guard fenster == nil else { return }
        let neu = TestnotizFenster(windowScene: szene)
        let host = UIHostingController(rootView: TestnotizOberflaeche())
        host.view.backgroundColor = .clear
        neu.rootViewController = host
        neu.isHidden = false
        fenster = neu
    }

    func knopfGetippt() {
        modus = .menue
    }

    func zurRuhe() {
        modus = .ruhe
    }
}

/// Meldet das erste Fenster, in das RootView gelangt. didMoveToWindow statt
/// updateUIView: beim ersten Update haengt die View noch in keinem Fenster,
/// und ein weiteres Update ist nicht zugesichert.
private final class InstallationsAnker: UIView {
    var beiFenster: ((UIWindowScene) -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if let szene = window?.windowScene { beiFenster?(szene) }
    }
}

private struct TestnotizInstallation: UIViewRepresentable {
    let netz: NetzwerkMonitor
    let katalog: CatalogStore
    let session: SessionStore

    func makeUIView(context: Context) -> InstallationsAnker {
        let anker = InstallationsAnker()
        anker.isUserInteractionEnabled = false
        anker.beiFenster = { [netz, katalog, session] szene in
            Testnotiz.shared.installieren(in: szene, netz: netz, katalog: katalog, session: session)
        }
        return anker
    }

    func updateUIView(_ uiView: InstallationsAnker, context: Context) {}
}

extension View {
    func testnotizInstallieren(netz: NetzwerkMonitor, katalog: CatalogStore, session: SessionStore) -> some View {
        background(TestnotizInstallation(netz: netz, katalog: katalog, session: session))
    }
}
#else
extension View {
    /// Release: kein Fenster, kein Knopf.
    @inline(__always)
    func testnotizInstallieren(netz: NetzwerkMonitor, katalog: CatalogStore, session: SessionStore) -> some View { self }
}
#endif
```

- [ ] **Schritt 5: In die App einhängen**

In `apps/ios-member/FitnessMember/FitnessMemberApp.swift` ersetzen:

```swift
            RootView(apiClient: apiClient)
                .environment(sessionStore)
```

durch

```swift
            RootView(apiClient: apiClient)
                .testnotizInstallieren(netz: netzwerkMonitor, katalog: catalogStore, session: sessionStore)
                .environment(sessionStore)
```

Kein `#if DEBUG` an dieser Stelle: die Release-Attrappe in `Testnotiz.swift` gibt `self` zurück.

- [ ] **Schritt 6: Tests laufen lassen**

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/TestnotizFensterTests 2>&1 | grep -E "✘|error:|Test run with"
```

Erwartet: `Test run with 5 tests in 1 suite passed`.

- [ ] **Schritt 7: Release-Beweis**

```bash
cd apps/ios-member
xcodebuild -scheme FitnessMember -configuration Release -destination "generic/platform=iOS" \
  -derivedDataPath /tmp/dd-relproof CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "error:|BUILD"
APP=/tmp/dd-relproof/Build/Products/Release-iphoneos/FitnessMember.app
# Der Build-Pfad darf das Suchwort nicht enthalten, sonst liefern #file-Strings
# der Abhaengigkeiten Falschtreffer.
# Archivieren strippt die Debug-Symbole; unverstrippt stehen Objektdateinamen
# wie TestnotizScreenModifier.o in der Symboltabelle. Deshalb die gestrippte Kopie.
xcrun strip -S -x -o /tmp/FitnessMember-stripped "$APP/FitnessMember"
grep -a -i -c testnotiz /tmp/FitnessMember-stripped                                   # erwartet 0
grep -r -a -i -l testnotiz "$APP" | grep -v '/FitnessMember$' | wc -l                  # erwartet 0
grep -a -c _AXSApplicationAccessibility /tmp/FitnessMember-stripped                   # erwartet 0
plutil -p "$APP/Info.plist" | grep -c -E 'NSMicrophoneUsageDescription|NSSpeechRecognitionUsageDescription|UIFileSharingEnabled|LSSupportsOpeningDocumentsInPlace'   # erwartet 0
plutil -p "$APP/Info.plist" | grep -c SUPABASE_URL                                     # erwartet 1 (Gegenprobe: Additions-Plist greift)
```

Gegenprobe am Debug-Build, sonst beweisen die Nullen nichts. Seit Xcode 16 liegt der Debug-Code in `FitnessMember.debug.dylib`, die Hauptdatei ist nur ein Starter:

```bash
cd apps/ios-member
xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" -derivedDataPath /tmp/dd-relproof build 2>&1 | grep -E "error:|BUILD"
D=/tmp/dd-relproof/Build/Products/Debug-iphonesimulator/FitnessMember.app
grep -a -i -c testnotiz "$D/FitnessMember.debug.dylib"                                # erwartet > 0
plutil -p "$D/Info.plist" | grep -c -E 'NSMicrophoneUsageDescription|NSSpeechRecognitionUsageDescription|UIFileSharingEnabled|LSSupportsOpeningDocumentsInPlace'   # erwartet 4
```

Die fünf Werte gehören in die Commit-Nachricht.

- [ ] **Schritt 8: Simulator und Gerät**

App im Simulator starten, dann am Gerät (`Just4Us`):

- Der Knopf steht rechts auf etwa 60 % Höhe, lässt sich vertikal ziehen und bleibt ganz sichtbar.
- Tipps direkt neben dem Knopf und überall sonst erreichen die App (Tabs wechseln, Liste scrollen).
- Ein Tipp auf den Knopf öffnet das Panel mit „TESTNOTIZ“ und „Schließen“; Tipp auf die Abdunklung oder „Schließen“ schließt.
- Der Knopf liegt über der Tab-Leiste und über einem offenen Sheet (Scanner öffnen).
- Die Statusleiste sieht aus wie vorher.

- [ ] **Schritt 9: Commit**

```bash
git add apps/ios-member/project.yml apps/ios-member/FitnessMember/Info-Additions-Debug.plist apps/ios-member/FitnessMember/FitnessMemberApp.swift apps/ios-member/FitnessMember/Testnotiz apps/ios-member/FitnessMemberTests/TestnotizFensterTests.swift apps/ios-member/FitnessMember.xcodeproj
git commit -m "feat(testnotiz): Overlay-Fenster und Knopf, nur im Debug-Build" -m "Release-Beweis: Binary 0, Bundle 0, AX-API 0, Plist 0, SUPABASE_URL 1."
```

---

## Aufgabe 2: Werte, Markdown, Ablage

Das Datenmodell vor den Modi: die Tests nageln die Spec fest, bevor etwas sie befüllt. Die Fixture wird **dekodiert** — nicht nur der eigene Encoder gegen den eigenen Decoder geprüft.

**Dateien:**
- Anlegen: `Testnotiz/TestnotizEintrag.swift`, `Zeitformat.swift`, `TestnotizMarkdown.swift`, `TestnotizAblage.swift`
- Test: `FitnessMemberTests/Fixtures/testnotiz-beispiel.json`, `TestnotizEintragTests.swift`, `TestnotizMarkdownTests.swift`, `TestnotizAblageTests.swift`

**Schnittstellen:**
- Nutzt: nichts
- Liefert:
  - `struct TestnotizSitzung: Codable, Sendable, Equatable` — `format`, `platform`, `session: Kopf`, `entries`; `Kopf { id, startedAt, app: App, device: Geraet }`, `App { bundleId, version, build, configuration }`, `Geraet { model, os, screen: Bildschirm }`, `Bildschirm { width, height, scale: Double }`
  - `struct TestnotizEintrag: Codable, Sendable, Equatable, Identifiable` — Felder wie Spec; `enum Art { crop, element, note }`; `Screen { name, file, stack, context }`; `Rechteck { x, y, width, height: Double }` mit `init(_ r: CGRect)`; `Ausschnittsrahmen { points, pixels }`; `Element { source: Quelle, identifier, label, type, frame, file, line }` mit `enum Quelle { accessibility, semantics }`; `Laufzeit { online, pendingWrites, signedIn, studioId }`; `Protokollzeile { at, level, category, message }`
  - `JSONEncoder.testnotiz(zeitzone: TimeZone = .current)`, `JSONDecoder.testnotiz()`
  - `enum Zeitformat` — `ordnername(_:zeitzone:)`, `datumUhrzeit(_:zeitzone:)`, `uhrzeit(_:zeitzone:sekunden:)`
  - `enum TestnotizMarkdown` — `rendern(_:zeitzone:) -> String`, `elementZeile(_:) -> String`
  - `actor TestnotizAblage` — `init(wurzel: URL, kopf: TestnotizSitzung.Kopf, zeitzone: TimeZone = .current) throws`, `nonisolated let ordner: URL`, `sitzung`, `anzahl`, `schreiben(_:voll:ausschnitt:audio:) throws -> TestnotizEintrag`, `transkriptNachtragen(index:text:) throws`, `zipFuerTeilen() throws -> URL`


- [ ] **Schritt 1: Fixture und Test, der sie liest**

Anlegen: `apps/ios-member/FitnessMemberTests/Fixtures/testnotiz-beispiel.json`

```json
{
  "format": "gymodo.testnotiz/1",
  "platform": "ios",
  "session": {
    "id": "2026-09-13-1412",
    "startedAt": "2026-09-13T14:12:03+02:00",
    "app": { "bundleId": "de.gymtaro.member", "version": "1.0", "build": "42", "configuration": "Debug" },
    "device": { "model": "iPhone14,4", "os": "iOS 26.6.1", "screen": { "width": 375, "height": 812, "scale": 3 } }
  },
  "entries": [
    {
      "id": "8F0C2A4E-6B1D-4C3A-9E7F-1A2B3C4D5E6F",
      "index": 1,
      "createdAt": "2026-09-13T14:13:41+02:00",
      "kind": "crop",
      "screen": {
        "name": "GeraetView",
        "file": "apps/ios-member/FitnessMember/Screens/Geraet/GeraetView.swift",
        "stack": ["apps/ios-member/FitnessMember/Screens/Geraet/GeraetView.swift"],
        "context": { "machineId": "m_123", "exerciseId": "e_456", "phase": "eingabe" }
      },
      "screenshot": "01-voll.png",
      "crop": "01-ausschnitt.png",
      "cropRect": {
        "points": { "x": 20, "y": 412, "width": 335, "height": 96 },
        "pixels": { "x": 60, "y": 1236, "width": 1005, "height": 288 }
      },
      "element": null,
      "note": "Das Gewicht wird abgeschnitten wenn 100,5",
      "audio": "01-notiz.m4a",
      "transcript": "Das Gewicht wird abgeschnitten wenn hundert komma fünf drinsteht",
      "runtime": { "online": true, "pendingWrites": 0, "signedIn": true, "studioId": "s_789" },
      "log": [
        { "at": "2026-09-13T14:13:02+02:00", "level": "info", "category": "tag", "message": "Tab-Wechsel auf Training wegen offenem Tag-Eingang" }
      ]
    },
    {
      "id": "0B7E9C1D-2F3A-4B5C-8D6E-7F8091A2B3C4",
      "index": 2,
      "createdAt": "2026-09-13T14:15:10+02:00",
      "kind": "element",
      "screen": {
        "name": "UebungWechselnSheet",
        "file": "apps/ios-member/FitnessMember/Screens/Geraet/UebungWechselnSheet.swift",
        "stack": [
          "apps/ios-member/FitnessMember/Screens/Geraet/GeraetView.swift",
          "apps/ios-member/FitnessMember/Screens/Geraet/UebungWechselnSheet.swift"
        ],
        "context": { "machineId": "m_123" }
      },
      "screenshot": "02-voll.png",
      "crop": null,
      "cropRect": null,
      "element": {
        "source": "accessibility",
        "identifier": "geraet.satz-sichern",
        "label": "Satz 2 sichern, 42,5 Kilogramm",
        "type": "Button",
        "frame": { "x": 20, "y": 640, "width": 335, "height": 64 },
        "file": "apps/ios-member/FitnessMember/Screens/Geraet/GeraetView.swift",
        "line": 212
      },
      "note": "Knopf bleibt nach dem Tipp einen Moment grau",
      "audio": null,
      "transcript": null,
      "runtime": { "online": false, "pendingWrites": 2, "signedIn": true, "studioId": null },
      "log": []
    }
  ]
}
```

Anlegen: `apps/ios-member/FitnessMemberTests/TestnotizEintragTests.swift`

```swift
#if DEBUG
import Foundation
import Testing
@testable import FitnessMember

struct TestnotizEintragTests {
    private final class Marker {}

    static func beispiel() throws -> Data {
        let url = try #require(Bundle(for: Marker.self).url(forResource: "testnotiz-beispiel", withExtension: "json"))
        return try Data(contentsOf: url)
    }

    static func beispielSitzung() throws -> TestnotizSitzung {
        try JSONDecoder.testnotiz().decode(TestnotizSitzung.self, from: beispiel())
    }

    @Test func liestDieBeispieldateiVollstaendig() throws {
        let sitzung = try Self.beispielSitzung()
        #expect(sitzung.format == "gymodo.testnotiz/1")
        #expect(sitzung.session.device.screen.scale == 3)
        #expect(sitzung.entries.count == 2)

        let erster = sitzung.entries[0]
        #expect(erster.kind == .crop)
        #expect(erster.screen?.file == "apps/ios-member/FitnessMember/Screens/Geraet/GeraetView.swift")
        #expect(erster.screen?.context["phase"] == "eingabe")
        #expect(erster.cropRect?.pixels.width == 1005)
        #expect(erster.element == nil)

        let zweiter = sitzung.entries[1]
        #expect(zweiter.element?.source == .accessibility)
        #expect(zweiter.element?.line == 212)
        #expect(zweiter.crop == nil)
        #expect(zweiter.runtime.studioId == nil)
    }

    // Ein Feld, das der Encoder weglaesst, kostete einen Leser den Schluessel,
    // den er voraussetzt. Deshalb steht null drin -- auf jeder Ebene.
    @Test func schreibtNullStattWegzulassen() throws {
        let text = String(decoding: try JSONEncoder.testnotiz().encode(Self.beispielSitzung()), as: UTF8.self)
        #expect(text.contains("\"element\" : null"))
        #expect(text.contains("\"audio\" : null"))
        #expect(text.contains("\"studioId\" : null"))

        var ohneKennung = try #require(try Self.beispielSitzung().entries[1].element)
        ohneKennung.identifier = nil
        ohneKennung.file = nil
        ohneKennung.line = nil
        let element = String(decoding: try JSONEncoder.testnotiz().encode(ohneKennung), as: UTF8.self)
        #expect(element.contains("\"identifier\" : null"))
        #expect(element.contains("\"line\" : null"))
    }

    @Test func schreibtZeitpunkteMitOffset() throws {
        let berlin = try #require(TimeZone(identifier: "Europe/Berlin"))
        let text = String(decoding: try JSONEncoder.testnotiz(zeitzone: berlin).encode(Self.beispielSitzung()), as: UTF8.self)
        #expect(text.contains("\"startedAt\" : \"2026-09-13T14:12:03+02:00\""))
    }

    @Test func rundreiseVerliertNichts() throws {
        let a = try Self.beispielSitzung()
        let b = try JSONDecoder.testnotiz().decode(TestnotizSitzung.self, from: JSONEncoder.testnotiz().encode(a))
        #expect(a == b)
    }
}
#endif
```

Die Fixture ist das Beispiel aus der Spec, Zeichen für Zeichen. `xcodegen generate` kopiert sie als Ressource ins Testbundle.

- [ ] **Schritt 2: Test laufen lassen — er darf nicht kompilieren**

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/TestnotizEintragTests 2>&1 | grep -E "✘|error:|Test run with"
```

Erwartet: `cannot find type 'TestnotizSitzung' in scope`.

- [ ] **Schritt 3: Die Werte**

Anlegen: `apps/ios-member/FitnessMember/Testnotiz/TestnotizEintrag.swift`

```swift
#if DEBUG
import Foundation

/// Die Werte aus dem Format-Vertrag
/// (docs/superpowers/specs/2026-09-14-testnotiz-format.md). Die Schluessel
/// sind Englisch, weil der Ordner ein Vertrag zwischen Plattformen ist, kein
/// Oberflaechentext.
struct TestnotizSitzung: Codable, Sendable, Equatable {
    static let formatKennung = "gymodo.testnotiz/1"

    var format: String = TestnotizSitzung.formatKennung
    var platform: String = "ios"
    var session: Kopf
    var entries: [TestnotizEintrag]

    struct Kopf: Codable, Sendable, Equatable {
        var id: String
        var startedAt: Date
        var app: App
        var device: Geraet
    }

    struct App: Codable, Sendable, Equatable {
        var bundleId: String
        var version: String
        var build: String
        var configuration: String
    }

    struct Geraet: Codable, Sendable, Equatable {
        var model: String
        var os: String
        var screen: Bildschirm
    }

    struct Bildschirm: Codable, Sendable, Equatable {
        var width: Double
        var height: Double
        var scale: Double
    }
}

struct TestnotizEintrag: Codable, Sendable, Equatable, Identifiable {
    enum Art: String, Codable, Sendable {
        case crop, element, note
    }

    var id: UUID
    var index: Int
    var createdAt: Date
    var kind: Art
    var screen: Screen?
    var screenshot: String
    var crop: String?
    var cropRect: Ausschnittsrahmen?
    var element: Element?
    var note: String?
    var audio: String?
    var transcript: String?
    var runtime: Laufzeit
    var log: [Protokollzeile]

    struct Screen: Codable, Sendable, Equatable {
        var name: String
        var file: String
        var stack: [String]
        var context: [String: String]
    }

    struct Rechteck: Codable, Sendable, Equatable {
        var x: Double
        var y: Double
        var width: Double
        var height: Double
    }

    struct Ausschnittsrahmen: Codable, Sendable, Equatable {
        var points: Rechteck
        var pixels: Rechteck
    }

    struct Element: Codable, Sendable, Equatable {
        enum Quelle: String, Codable, Sendable {
            case accessibility, semantics
        }

        var source: Quelle
        var identifier: String?
        var label: String?
        var type: String
        var frame: Rechteck
        var file: String?
        var line: Int?

        // Synthetisiertes Codable laesst nil-Felder weg; der Vertrag
        // verlangt null, damit ein Leser beide Plattformen mit einem Schema
        // prueft.
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(source, forKey: .source)
            try c.encode(identifier, forKey: .identifier)
            try c.encode(label, forKey: .label)
            try c.encode(type, forKey: .type)
            try c.encode(frame, forKey: .frame)
            try c.encode(file, forKey: .file)
            try c.encode(line, forKey: .line)
        }
    }

    struct Laufzeit: Codable, Sendable, Equatable {
        var online: Bool
        var pendingWrites: Int
        var signedIn: Bool
        var studioId: String?

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(online, forKey: .online)
            try c.encode(pendingWrites, forKey: .pendingWrites)
            try c.encode(signedIn, forKey: .signedIn)
            try c.encode(studioId, forKey: .studioId)
        }
    }

    struct Protokollzeile: Codable, Sendable, Equatable {
        var at: Date
        var level: String
        var category: String
        var message: String
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(index, forKey: .index)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(kind, forKey: .kind)
        try c.encode(screen, forKey: .screen)
        try c.encode(screenshot, forKey: .screenshot)
        try c.encode(crop, forKey: .crop)
        try c.encode(cropRect, forKey: .cropRect)
        try c.encode(element, forKey: .element)
        try c.encode(note, forKey: .note)
        try c.encode(audio, forKey: .audio)
        try c.encode(transcript, forKey: .transcript)
        try c.encode(runtime, forKey: .runtime)
        try c.encode(log, forKey: .log)
    }
}

extension TestnotizEintrag.Rechteck {
    init(_ r: CGRect) {
        self.init(x: r.origin.x, y: r.origin.y, width: r.size.width, height: r.size.height)
    }
}

extension JSONEncoder {
    /// Zeitpunkte mit Offset statt "Z": wer den Ordner liest, sieht die
    /// Uhrzeit, die der Tester auf dem Telefon hatte.
    static func testnotiz(zeitzone: TimeZone = .current) -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let stil = Date.ISO8601FormatStyle(timeZoneSeparator: .colon, timeZone: zeitzone)
        encoder.dateEncodingStrategy = .custom { datum, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(datum.formatted(stil))
        }
        return encoder
    }
}

extension JSONDecoder {
    static func testnotiz() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
#endif
```

Warum eigene `encode(to:)`: die synthetisierte Konformität schreibt Optionals mit `encodeIfPresent` und lässt `nil` weg. Die Spec verlangt `null`. `Date.ISO8601FormatStyle` braucht `timeZoneSeparator: .colon`, sonst steht `+0200` statt `+02:00` im JSON (im Lauf aufgefallen).

- [ ] **Schritt 4: Test laufen lassen**

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/TestnotizEintragTests 2>&1 | grep -E "✘|error:|Test run with"
```

Erwartet: `4 tests in 1 suite passed`.

- [ ] **Schritt 5: Markdown-Test**

Anlegen: `apps/ios-member/FitnessMemberTests/TestnotizMarkdownTests.swift`

```swift
#if DEBUG
import Foundation
import Testing
@testable import FitnessMember

struct TestnotizMarkdownTests {
    private let berlin = TimeZone(identifier: "Europe/Berlin")!

    private func markdown() throws -> String {
        TestnotizMarkdown.rendern(try TestnotizEintragTests.beispielSitzung(), zeitzone: berlin)
    }

    @Test func kopfzeileNenntVersionBuildModellUndSystem() throws {
        let erste = try markdown().split(separator: "\n").first.map(String.init)
        #expect(erste == "# Testsitzung 2026-09-13 14:12 — gymodo Member 1.0 (42), iPhone14,4, iOS 26.6.1")
    }

    @Test func jeEintragEineUeberschriftMitNummerZeitArtUndScreen() throws {
        let md = try markdown()
        #expect(md.contains("## 1 · 14:13 · Ausschnitt · GeraetView"))
        #expect(md.contains("## 2 · 14:15 · Element · UebungWechselnSheet"))
    }

    @Test func screenZeileTraegtDateiUndSortiertenKontext() throws {
        #expect(try markdown().contains("**Screen:** `apps/ios-member/FitnessMember/Screens/Geraet/GeraetView.swift` (exerciseId e_456, machineId m_123, phase eingabe)"))
    }

    @Test func ebenenNurWennEsMehrAlsEineGibt() throws {
        let md = try markdown()
        #expect(md.contains("**Ebenen:** GeraetView → UebungWechselnSheet"))
        #expect(md.components(separatedBy: "**Ebenen:**").count == 2)
    }

    @Test func elementZeileMitKennungLabelTypUndFundstelle() throws {
        #expect(try markdown().contains("**Element:** `geraet.satz-sichern` — „Satz 2 sichern, 42,5 Kilogramm“, Button, `apps/ios-member/FitnessMember/Screens/Geraet/GeraetView.swift:212`"))
    }

    @Test func ausschnittVorVollbild() throws {
        let md = try markdown()
        let ausschnitt = try #require(md.range(of: "![Ausschnitt](01-ausschnitt.png)"))
        let vollbild = try #require(md.range(of: "![Vollbild](01-voll.png)"))
        #expect(ausschnitt.lowerBound < vollbild.lowerBound)
    }

    @Test func protokollImDetailsBlockNurWennEsZeilenGibt() throws {
        let md = try markdown()
        #expect(md.contains("<details><summary>Protokoll (letzte 5 min, 1 Zeile)</summary>\n\n14:13:02 info tag — Tab-Wechsel auf Training wegen offenem Tag-Eingang\n\n</details>"))
        #expect(md.components(separatedBy: "<details>").count == 2)
    }

    @Test func gesprochenMitTranskriptUndAudio() throws {
        #expect(try markdown().contains("**Gesprochen:** Das Gewicht wird abgeschnitten wenn hundert komma fünf drinsteht ([Audio](01-notiz.m4a))"))
    }

    @Test func transkriptFehltAberAudioLiegtBei() throws {
        var sitzung = try TestnotizEintragTests.beispielSitzung()
        sitzung.entries[0].transcript = nil
        let md = TestnotizMarkdown.rendern(sitzung, zeitzone: berlin)
        #expect(md.contains("**Gesprochen:** Transkript fehlt, Audio liegt bei: [01-notiz.m4a](01-notiz.m4a)"))
    }

    @Test func ohneScreenSagtEsDas() throws {
        var sitzung = try TestnotizEintragTests.beispielSitzung()
        sitzung.entries[0].screen = nil
        let md = TestnotizMarkdown.rendern(sitzung, zeitzone: berlin)
        #expect(md.contains("## 1 · 14:13 · Ausschnitt · unbekannter Screen"))
        #expect(md.contains("**Screen:** unbekannt — kein Screen hat sich gemeldet"))
    }
}
#endif
```

- [ ] **Schritt 6: Test laufen lassen — er darf nicht kompilieren**

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/TestnotizMarkdownTests 2>&1 | grep -E "✘|error:|Test run with"
```

Erwartet: `cannot find 'TestnotizMarkdown' in scope`.

- [ ] **Schritt 7: Zeitformat und Markdown**

Anlegen: `apps/ios-member/FitnessMember/Testnotiz/Zeitformat.swift`

```swift
#if DEBUG
import Foundation

/// Uhrzeiten fuer Ordnernamen und Markdown, ohne Locale: dieselbe Eingabe
/// ergibt auf jedem Geraet denselben Text, und die Tests brauchen keine
/// Formatter-Einstellungen.
enum Zeitformat {
    static func teile(_ datum: Date, zeitzone: TimeZone) -> DateComponents {
        var kalender = Calendar(identifier: .gregorian)
        kalender.timeZone = zeitzone
        return kalender.dateComponents([.year, .month, .day, .hour, .minute, .second], from: datum)
    }

    /// yyyy-MM-dd-HHmm
    static func ordnername(_ datum: Date, zeitzone: TimeZone) -> String {
        let t = teile(datum, zeitzone: zeitzone)
        return String(format: "%04d-%02d-%02d-%02d%02d", t.year!, t.month!, t.day!, t.hour!, t.minute!)
    }

    /// yyyy-MM-dd HH:mm
    static func datumUhrzeit(_ datum: Date, zeitzone: TimeZone) -> String {
        let t = teile(datum, zeitzone: zeitzone)
        return String(format: "%04d-%02d-%02d %02d:%02d", t.year!, t.month!, t.day!, t.hour!, t.minute!)
    }

    /// HH:mm oder HH:mm:ss
    static func uhrzeit(_ datum: Date, zeitzone: TimeZone, sekunden: Bool = false) -> String {
        let t = teile(datum, zeitzone: zeitzone)
        return sekunden
            ? String(format: "%02d:%02d:%02d", t.hour!, t.minute!, t.second!)
            : String(format: "%02d:%02d", t.hour!, t.minute!)
    }
}
#endif
```

Anlegen: `apps/ios-member/FitnessMember/Testnotiz/TestnotizMarkdown.swift`

```swift
#if DEBUG
import Foundation

/// sitzung.md -- die Datei, die Claude Code liest. Eine reine Funktion ueber
/// die Werte: kein Date(), kein Dateisystem.
enum TestnotizMarkdown {
    static func rendern(_ sitzung: TestnotizSitzung, zeitzone: TimeZone) -> String {
        var teile: [String] = [kopf(sitzung, zeitzone: zeitzone)]
        for eintrag in sitzung.entries {
            teile.append(abschnitt(eintrag, zeitzone: zeitzone))
        }
        return teile.joined(separator: "\n\n") + "\n"
    }

    static func kopf(_ sitzung: TestnotizSitzung, zeitzone: TimeZone) -> String {
        let s = sitzung.session
        return "# Testsitzung \(Zeitformat.datumUhrzeit(s.startedAt, zeitzone: zeitzone)) — gymodo Member \(s.app.version) (\(s.app.build)), \(s.device.model), \(s.device.os)"
    }

    static func artName(_ art: TestnotizEintrag.Art) -> String {
        switch art {
        case .crop: "Ausschnitt"
        case .element: "Element"
        case .note: "Notiz"
        }
    }

    static func abschnitt(_ e: TestnotizEintrag, zeitzone: TimeZone) -> String {
        var zeilen: [String] = []
        let screenName = e.screen?.name ?? "unbekannter Screen"
        zeilen.append("## \(e.index) · \(Zeitformat.uhrzeit(e.createdAt, zeitzone: zeitzone)) · \(artName(e.kind)) · \(screenName)")

        if let screen = e.screen {
            let kontext = screen.context.keys.sorted().map { "\($0) \(screen.context[$0]!)" }.joined(separator: ", ")
            zeilen.append("**Screen:** `\(screen.file)`" + (kontext.isEmpty ? "" : " (\(kontext))"))
            if screen.stack.count > 1 {
                let namen = screen.stack.map { (($0 as NSString).lastPathComponent as NSString).deletingPathExtension }
                zeilen.append("**Ebenen:** " + namen.joined(separator: " → "))
            }
        } else {
            zeilen.append("**Screen:** unbekannt — kein Screen hat sich gemeldet")
        }

        if let element = e.element {
            zeilen.append("**Element:** " + elementZeile(element))
        }

        if let notiz = e.note, !notiz.isEmpty {
            zeilen.append("**Notiz:** \(notiz)")
        }
        if let audio = e.audio {
            if let transkript = e.transcript {
                zeilen.append("**Gesprochen:** \(transkript) ([Audio](\(audio)))")
            } else {
                zeilen.append("**Gesprochen:** Transkript fehlt, Audio liegt bei: [\(audio)](\(audio))")
            }
        }

        var bilder: [String] = []
        if let crop = e.crop { bilder.append("![Ausschnitt](\(crop))") }
        bilder.append("![Vollbild](\(e.screenshot))")
        zeilen.append(bilder.joined(separator: "\n"))

        if !e.log.isEmpty {
            let anzahl = e.log.count == 1 ? "1 Zeile" : "\(e.log.count) Zeilen"
            let protokoll = e.log.map {
                "\(Zeitformat.uhrzeit($0.at, zeitzone: zeitzone, sekunden: true)) \($0.level) \($0.category) — \($0.message)"
            }.joined(separator: "\n")
            zeilen.append("<details><summary>Protokoll (letzte 5 min, \(anzahl))</summary>\n\n\(protokoll)\n\n</details>")
        }

        return zeilen.joined(separator: "\n\n")
    }

    static func elementZeile(_ e: TestnotizEintrag.Element) -> String {
        var teile: [String] = []
        if let kennung = e.identifier { teile.append("`\(kennung)`") }
        var beschreibung: [String] = []
        if let label = e.label { beschreibung.append("„\(label)“") }
        beschreibung.append(e.type)
        if let file = e.file, let line = e.line { beschreibung.append("`\(file):\(line)`") }
        teile.append(beschreibung.joined(separator: ", "))
        return teile.joined(separator: " — ")
    }
}
#endif
```

- [ ] **Schritt 8: Ablage-Test**

Anlegen: `apps/ios-member/FitnessMemberTests/TestnotizAblageTests.swift`

```swift
#if DEBUG
import Foundation
import Testing
@testable import FitnessMember

struct TestnotizAblageTests {
    private let berlin = TimeZone(identifier: "Europe/Berlin")!

    private func frischeWurzel() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("testnotiz-tests-\(UUID().uuidString)")
    }

    private func kopf() throws -> TestnotizSitzung.Kopf {
        var k = try TestnotizEintragTests.beispielSitzung().session
        k.id = ""
        return k
    }

    private func eintrag() throws -> TestnotizEintrag {
        var e = try TestnotizEintragTests.beispielSitzung().entries[1]
        e.index = 0
        e.screenshot = ""
        return e
    }

    @Test func ordnernameIstMinutengenauInDerZeitzone() throws {
        let kopf = try kopf()
        #expect(Zeitformat.ordnername(kopf.startedAt, zeitzone: berlin) == "2026-09-13-1412")
    }

    @Test func legtDenOrdnerMitLeererSitzungAn() async throws {
        let wurzel = frischeWurzel()
        let ablage = try TestnotizAblage(wurzel: wurzel, kopf: kopf(), zeitzone: berlin)
        #expect(ablage.ordner.lastPathComponent == "2026-09-13-1412")
        let json = try Data(contentsOf: ablage.ordner.appendingPathComponent("sitzung.json"))
        let gelesen = try JSONDecoder.testnotiz().decode(TestnotizSitzung.self, from: json)
        #expect(gelesen.session.id == "2026-09-13-1412")
        #expect(gelesen.entries.isEmpty)
        #expect(FileManager.default.fileExists(atPath: ablage.ordner.appendingPathComponent("sitzung.md").path))
    }

    @Test func zweiteSitzungInDerselbenMinuteBekommtEinSuffix() throws {
        let wurzel = frischeWurzel()
        _ = try TestnotizAblage(wurzel: wurzel, kopf: kopf(), zeitzone: berlin)
        let zweite = try TestnotizAblage(wurzel: wurzel, kopf: kopf(), zeitzone: berlin)
        #expect(zweite.ordner.lastPathComponent == "2026-09-13-1412-2")
    }

    @Test func nummeriertEintraegeUndBenenntDateien() async throws {
        let ablage = try TestnotizAblage(wurzel: frischeWurzel(), kopf: kopf(), zeitzone: berlin)
        let erster = try await ablage.schreiben(eintrag(), voll: Data([1]), ausschnitt: Data([2]), audio: nil)
        let zweiter = try await ablage.schreiben(eintrag(), voll: Data([3]), ausschnitt: nil, audio: nil)

        #expect(erster.index == 1)
        #expect(erster.screenshot == "01-voll.png")
        #expect(erster.crop == "01-ausschnitt.png")
        #expect(zweiter.index == 2)
        #expect(zweiter.screenshot == "02-voll.png")
        #expect(zweiter.crop == nil)

        let fm = FileManager.default
        #expect(fm.fileExists(atPath: ablage.ordner.appendingPathComponent("01-ausschnitt.png").path))
        #expect(fm.fileExists(atPath: ablage.ordner.appendingPathComponent("02-voll.png").path))
        #expect(await ablage.anzahl == 2)
    }

    @Test func schreibtJsonUndMarkdownNachJedemEintrag() async throws {
        let ablage = try TestnotizAblage(wurzel: frischeWurzel(), kopf: kopf(), zeitzone: berlin)
        _ = try await ablage.schreiben(eintrag(), voll: Data([1]), ausschnitt: nil, audio: nil)

        let json = try Data(contentsOf: ablage.ordner.appendingPathComponent("sitzung.json"))
        let gelesen = try JSONDecoder.testnotiz().decode(TestnotizSitzung.self, from: json)
        #expect(gelesen == (await ablage.sitzung))
        let md = try String(contentsOf: ablage.ordner.appendingPathComponent("sitzung.md"), encoding: .utf8)
        #expect(md.contains("## 1 · 14:15 · Element"))
    }

    @Test func verschiebtDasAudioInDenOrdner() async throws {
        let quelle = FileManager.default.temporaryDirectory.appendingPathComponent("aufnahme-\(UUID().uuidString).m4a")
        try Data([9, 9]).write(to: quelle)
        let ablage = try TestnotizAblage(wurzel: frischeWurzel(), kopf: kopf(), zeitzone: berlin)
        let gesichert = try await ablage.schreiben(eintrag(), voll: Data([1]), ausschnitt: nil, audio: quelle)

        #expect(gesichert.audio == "01-notiz.m4a")
        #expect(!FileManager.default.fileExists(atPath: quelle.path))
        #expect(FileManager.default.fileExists(atPath: ablage.ordner.appendingPathComponent("01-notiz.m4a").path))
    }

    @Test func transkriptWirdNachgetragen() async throws {
        let ablage = try TestnotizAblage(wurzel: frischeWurzel(), kopf: kopf(), zeitzone: berlin)
        let gesichert = try await ablage.schreiben(eintrag(), voll: Data([1]), ausschnitt: nil, audio: nil)
        try await ablage.transkriptNachtragen(index: gesichert.index, text: "hallo")

        let json = try Data(contentsOf: ablage.ordner.appendingPathComponent("sitzung.json"))
        #expect(try JSONDecoder.testnotiz().decode(TestnotizSitzung.self, from: json).entries[0].transcript == "hallo")
    }

    @Test func zipIstEinZipArchiv() async throws {
        let ablage = try TestnotizAblage(wurzel: frischeWurzel(), kopf: kopf(), zeitzone: berlin)
        _ = try await ablage.schreiben(eintrag(), voll: Data([1]), ausschnitt: nil, audio: nil)
        let zip = try await ablage.zipFuerTeilen()
        #expect(zip.pathExtension == "zip")
        let kopfbytes = try Data(contentsOf: zip).prefix(2)
        #expect(Array(kopfbytes) == [0x50, 0x4B])
    }
}
#endif
```

- [ ] **Schritt 9: Test laufen lassen — er darf nicht kompilieren**

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/TestnotizAblageTests 2>&1 | grep -E "✘|error:|Test run with"
```

Erwartet: `cannot find 'TestnotizAblage' in scope`.

- [ ] **Schritt 10: Ablage**

Anlegen: `apps/ios-member/FitnessMember/Testnotiz/TestnotizAblage.swift`

```swift
#if DEBUG
import Foundation

/// Ein Sitzungsordner auf der Platte. Actor, weil Bilder und Audio nicht auf
/// dem Main Thread geschrieben werden sollen und zwei schnelle Eintraege
/// sonst dieselbe Nummer bekaemen.
actor TestnotizAblage {
    nonisolated let ordner: URL
    private(set) var sitzung: TestnotizSitzung
    private let zeitzone: TimeZone

    /// Legt `wurzel/<yyyy-MM-dd-HHmm>` an. Existiert der Name schon (zwei
    /// Sitzungen in derselben Minute), bekommt der neue ein "-2", "-3" ...
    init(wurzel: URL, kopf: TestnotizSitzung.Kopf, zeitzone: TimeZone = .current) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: wurzel, withIntermediateDirectories: true)
        let basis = Zeitformat.ordnername(kopf.startedAt, zeitzone: zeitzone)
        var name = basis
        var zaehler = 2
        while fm.fileExists(atPath: wurzel.appendingPathComponent(name).path) {
            name = "\(basis)-\(zaehler)"
            zaehler += 1
        }
        let ordner = wurzel.appendingPathComponent(name)
        try fm.createDirectory(at: ordner, withIntermediateDirectories: false)

        var kopf = kopf
        kopf.id = name
        let sitzung = TestnotizSitzung(session: kopf, entries: [])
        try Self.sitzungSchreiben(sitzung, nach: ordner, zeitzone: zeitzone)
        self.ordner = ordner
        self.sitzung = sitzung
        self.zeitzone = zeitzone
    }

    var anzahl: Int { sitzung.entries.count }

    /// Vergibt Nummer und Dateinamen, schreibt die Dateien und danach
    /// sitzung.json und sitzung.md neu. Das Audio wird verschoben, nicht
    /// kopiert: die Aufnahme liegt vorher in tmp.
    func schreiben(_ eintrag: TestnotizEintrag, voll: Data, ausschnitt: Data?, audio: URL?) throws -> TestnotizEintrag {
        var e = eintrag
        e.index = sitzung.entries.count + 1
        let praefix = String(format: "%02d", e.index)

        e.screenshot = "\(praefix)-voll.png"
        try voll.write(to: ordner.appendingPathComponent(e.screenshot))

        if let ausschnitt {
            let name = "\(praefix)-ausschnitt.png"
            try ausschnitt.write(to: ordner.appendingPathComponent(name))
            e.crop = name
        } else {
            e.crop = nil
        }

        if let audio {
            let name = "\(praefix)-notiz.m4a"
            try FileManager.default.moveItem(at: audio, to: ordner.appendingPathComponent(name))
            e.audio = name
        } else {
            e.audio = nil
        }

        sitzung.entries.append(e)
        try Self.sitzungSchreiben(sitzung, nach: ordner, zeitzone: zeitzone)
        return e
    }

    /// Die Transkription laeuft nach dem Sichern; ihr Ergebnis kommt hier
    /// nachtraeglich in beide Dateien.
    func transkriptNachtragen(index: Int, text: String) throws {
        guard let i = sitzung.entries.firstIndex(where: { $0.index == index }) else { return }
        sitzung.entries[i].transcript = text
        try Self.sitzungSchreiben(sitzung, nach: ordner, zeitzone: zeitzone)
    }

    /// Zip ohne Fremdbibliothek: NSFileCoordinator packt einen Ordner beim
    /// Lesen mit .forUploading.
    func zipFuerTeilen() throws -> URL {
        let fm = FileManager.default
        let ziel = fm.temporaryDirectory.appendingPathComponent("\(ordner.lastPathComponent).zip")
        try? fm.removeItem(at: ziel)
        var koordinationsfehler: NSError?
        var kopierfehler: Error?
        NSFileCoordinator().coordinate(readingItemAt: ordner, options: .forUploading, error: &koordinationsfehler) { zip in
            do { try fm.copyItem(at: zip, to: ziel) } catch { kopierfehler = error }
        }
        if let koordinationsfehler { throw koordinationsfehler }
        if let kopierfehler { throw kopierfehler }
        return ziel
    }

    private static func sitzungSchreiben(_ sitzung: TestnotizSitzung, nach ordner: URL, zeitzone: TimeZone) throws {
        let json = try JSONEncoder.testnotiz(zeitzone: zeitzone).encode(sitzung)
        try json.write(to: ordner.appendingPathComponent("sitzung.json"), options: .atomic)
        let md = TestnotizMarkdown.rendern(sitzung, zeitzone: zeitzone)
        try Data(md.utf8).write(to: ordner.appendingPathComponent("sitzung.md"), options: .atomic)
    }
}
#endif
```

- [ ] **Schritt 11: Alle drei Suiten**

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/TestnotizEintragTests -only-testing:FitnessMemberTests/TestnotizMarkdownTests -only-testing:FitnessMemberTests/TestnotizAblageTests 2>&1 | grep -E "✘|error:|Test run with"
```

Erwartet: `22 tests in 3 suites passed`.

- [ ] **Schritt 12: Commit**

```bash
git add apps/ios-member/FitnessMember/Testnotiz apps/ios-member/FitnessMemberTests apps/ios-member/FitnessMember.xcodeproj
git commit -m "feat(testnotiz): Werte, Markdown und Ablage nach Format-Spec"
```

---

## Aufgabe 3: Screen-Stapel und 26 Wurzeln

**Dateien:**
- Anlegen: `Testnotiz/TestnotizScreenStapel.swift`, `TestnotizScreenModifier.swift`
- Ändern: `Testnotiz/Testnotiz.swift`, `Testnotiz/TestnotizMenue.swift`, 26 Screen-Dateien
- Test: `TestnotizScreenStapelTests.swift`

**Schnittstellen:**
- Nutzt: `Testnotiz.shared`
- Liefert:
  - `struct ScreenEintrag: Equatable, Sendable` — `init(token: UUID = UUID(), datei: String, kontext: [String: String] = [:])`, `token`, `datei` (repo-relativ), `kontext`, `name`
  - `struct TestnotizScreenStapel` — `erschienen(_:)`, `verschwunden(token:)`, `kontextAktualisieren(token:kontext:)`, `aktueller: ScreenEintrag?`, `pfad: [String]`
  - `enum Quellpfad { static func relativ(_ pfad: String) -> String }`
  - `View.testnotizScreen(kontext: [String: String] = [:], datei: String = #filePath)` — Release: `testnotizScreen(kontext:)` ohne `datei`
  - `Testnotiz.stapel: TestnotizScreenStapel`


- [ ] **Schritt 1: Stapeltests**

Anlegen: `apps/ios-member/FitnessMemberTests/TestnotizScreenStapelTests.swift`

```swift
#if DEBUG
import Foundation
import Testing
@testable import FitnessMember

struct TestnotizScreenStapelTests {
    private let training = ScreenEintrag(datei: "apps/ios-member/FitnessMember/Screens/Training/TrainingRootView.swift")
    private let geraet = ScreenEintrag(datei: "apps/ios-member/FitnessMember/Screens/Geraet/GeraetView.swift")
    private let sheet = ScreenEintrag(datei: "apps/ios-member/FitnessMember/Screens/Geraet/UebungWechselnSheet.swift")

    @Test func nameIstDerDateinameOhneEndung() {
        #expect(geraet.name == "GeraetView")
    }

    // Beobachtete Reihenfolge beim Push (Spike 2026-09-14): das Ziel
    // erscheint, DANACH verschwindet die Wurzel.
    @Test func pushErsetztDieWurzel() {
        var s = TestnotizScreenStapel()
        s.erschienen(training)
        s.erschienen(geraet)
        s.verschwunden(token: training.token)
        #expect(s.aktueller?.name == "GeraetView")
        #expect(s.pfad == [geraet.datei])
    }

    // Beim Pop: die Wurzel erscheint wieder, danach verschwindet das Ziel.
    @Test func popLegtDieWurzelFrei() {
        var s = TestnotizScreenStapel()
        s.erschienen(training)
        s.erschienen(geraet)
        s.verschwunden(token: training.token)
        s.erschienen(training)
        s.verschwunden(token: geraet.token)
        #expect(s.aktueller?.name == "TrainingRootView")
        #expect(s.pfad == [training.datei])
    }

    // Ein Sheet ueberdeckt, ohne dass der Screen darunter verschwindet.
    @Test func sheetLiegtObenUndGehtWiederWeg() {
        var s = TestnotizScreenStapel()
        s.erschienen(geraet)
        s.erschienen(sheet)
        #expect(s.pfad == [geraet.datei, sheet.datei])
        s.verschwunden(token: sheet.token)
        #expect(s.aktueller?.name == "GeraetView")
    }

    // Tab-Wechsel in beiden denkbaren Reihenfolgen.
    @Test func tabwechselInBeidenReihenfolgen() {
        var a = TestnotizScreenStapel()
        a.erschienen(training)
        a.erschienen(geraet)
        a.verschwunden(token: training.token)
        #expect(a.aktueller?.name == "GeraetView")

        var b = TestnotizScreenStapel()
        b.erschienen(training)
        b.verschwunden(token: training.token)
        b.erschienen(geraet)
        #expect(b.aktueller?.name == "GeraetView")
        #expect(b.pfad == [geraet.datei])
    }

    // Modifier an einer Group werden auf jedes Kind verteilt: das neue Kind
    // erscheint mit demselben Token, bevor das alte verschwindet.
    @Test func gruppenwechselVerliertDenScreenNicht() {
        var s = TestnotizScreenStapel()
        let flow = ScreenEintrag(datei: "apps/ios-member/FitnessMember/Screens/Geraet/ErstkontaktFlow.swift")
        s.erschienen(flow)
        s.erschienen(flow)
        s.verschwunden(token: flow.token)
        #expect(s.aktueller?.name == "ErstkontaktFlow")
        s.verschwunden(token: flow.token)
        #expect(s.aktueller == nil)
    }

    @Test func unbekanntesVerschwindenAendertNichts() {
        var s = TestnotizScreenStapel()
        s.erschienen(geraet)
        s.verschwunden(token: UUID())
        #expect(s.pfad == [geraet.datei])
    }

    @Test func kontextWirdNachgezogen() {
        var s = TestnotizScreenStapel()
        s.erschienen(geraet)
        s.kontextAktualisieren(token: geraet.token, kontext: ["phase": "pause"])
        #expect(s.aktueller?.kontext == ["phase": "pause"])
    }

    @Test func quellpfadIstRepoRelativ() {
        #expect(Quellpfad.relativ("/Users/tim/Documents/fitness-app/apps/ios-member/FitnessMember/Screens/Home/HomeRootView.swift")
                == "apps/ios-member/FitnessMember/Screens/Home/HomeRootView.swift")
        #expect(Quellpfad.relativ("/Users/tim/Documents/fitness-app/.claude/worktrees/x/apps/ios-member/FitnessMember/A.swift")
                == "apps/ios-member/FitnessMember/A.swift")
        #expect(Quellpfad.relativ("/irgendwo/anders/B.swift") == "B.swift")
    }
}
#endif
```

Die Reihenfolgen in den Tests sind die beobachteten aus dem Spike, nicht ausgedachte.

- [ ] **Schritt 2: Test laufen lassen — er darf nicht kompilieren**

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/TestnotizScreenStapelTests 2>&1 | grep -E "✘|error:|Test run with"
```

Erwartet: `cannot find 'ScreenEintrag' in scope`.

- [ ] **Schritt 3: Stapel und Modifier**

Anlegen: `apps/ios-member/FitnessMember/Testnotiz/TestnotizScreenStapel.swift`

```swift
#if DEBUG
import Foundation

/// Ein Screen, der gerade sichtbar ist.
struct ScreenEintrag: Equatable, Sendable {
    let token: UUID
    /// Repo-relativ, z.B. apps/ios-member/FitnessMember/Screens/Geraet/GeraetView.swift
    let datei: String
    var kontext: [String: String]

    init(token: UUID = UUID(), datei: String, kontext: [String: String] = [:]) {
        self.token = token
        self.datei = datei
        self.kontext = kontext
    }

    var name: String {
        ((datei as NSString).lastPathComponent as NSString).deletingPathExtension
    }
}

/// Die sichtbaren Ebenen von unten nach oben: der Screen, darueber Sheets
/// und Cover. Ein Push ersetzt die Wurzel (die ueberdeckte meldet
/// onDisappear), er stapelt nicht.
///
/// Gezaehlt wird je Token, weil ein Modifier an einer Group auf jedes Kind
/// verteilt wird: beim Wechsel erscheint das neue Kind VOR dem Verschwinden
/// des alten, und ohne Zaehler naehme das Verschwinden den Eintrag mit.
struct TestnotizScreenStapel {
    private(set) var eintraege: [ScreenEintrag] = []
    private var zaehler: [UUID: Int] = [:]

    var aktueller: ScreenEintrag? { eintraege.last }
    var pfad: [String] { eintraege.map(\.datei) }

    mutating func erschienen(_ eintrag: ScreenEintrag) {
        zaehler[eintrag.token, default: 0] += 1
        eintraege.removeAll { $0.token == eintrag.token }
        eintraege.append(eintrag)
    }

    mutating func verschwunden(token: UUID) {
        guard let stand = zaehler[token] else { return }
        if stand > 1 {
            zaehler[token] = stand - 1
        } else {
            zaehler[token] = nil
            eintraege.removeAll { $0.token == token }
        }
    }

    mutating func kontextAktualisieren(token: UUID, kontext: [String: String]) {
        guard let i = eintraege.firstIndex(where: { $0.token == token }) else { return }
        eintraege[i].kontext = kontext
    }
}

/// #fileID liefert nur "Modul/Datei.swift" -- ohne Verzeichnis kann Claude
/// Code die Datei nicht oeffnen. #filePath liefert den absoluten Pfad auf
/// dem Build-Mac; ab "apps/ios-member/" ist er repo-relativ.
enum Quellpfad {
    static func relativ(_ pfad: String) -> String {
        if let treffer = pfad.range(of: "/apps/ios-member/") {
            return String(pfad[pfad.index(after: treffer.lowerBound)...])
        }
        return (pfad as NSString).lastPathComponent
    }
}
#endif
```

Anlegen: `apps/ios-member/FitnessMember/Testnotiz/TestnotizScreenModifier.swift`

```swift
import SwiftUI

#if DEBUG
private struct TestnotizScreen: ViewModifier {
    let datei: String
    let kontext: [String: String]
    /// Einmal je Modifier-Identitaet. Ein Token aus body waere bei jedem
    /// Neuaufbau neu, und onDisappear faende sein onAppear nicht mehr.
    @State private var token = UUID()

    func body(content: Content) -> some View {
        content
            .onAppear {
                Testnotiz.shared.stapel.erschienen(ScreenEintrag(token: token, datei: datei, kontext: kontext))
            }
            .onDisappear {
                Testnotiz.shared.stapel.verschwunden(token: token)
            }
            .onChange(of: kontext) { _, neu in
                Testnotiz.shared.stapel.kontextAktualisieren(token: token, kontext: neu)
            }
    }
}

extension View {
    /// An die aeusserste View des Screen-Inhalts -- bei Screens mit eigenem
    /// NavigationStack an die Wurzel INNERHALB des Stacks, sonst verschwindet
    /// beim Push nichts.
    func testnotizScreen(kontext: [String: String] = [:], datei: String = #filePath) -> some View {
        modifier(TestnotizScreen(datei: Quellpfad.relativ(datei), kontext: kontext))
    }
}
#else
extension View {
    /// Release: ohne #filePath, damit kein Pfad des Build-Macs ins Binary kommt.
    @inline(__always)
    func testnotizScreen(kontext: [String: String] = [:]) -> some View { self }
}
#endif
```

- [ ] **Schritt 4: Stapel ins Modul, Screen-Name in den Menükopf**

In `apps/ios-member/FitnessMember/Testnotiz/Testnotiz.swift` ersetzen:

```swift
    var knopfRahmen: CGRect = .zero
```

durch

```swift
    var knopfRahmen: CGRect = .zero
    var stapel = TestnotizScreenStapel()
```

In `apps/ios-member/FitnessMember/Testnotiz/TestnotizMenue.swift` ersetzen:

```swift
        "TESTNOTIZ"
```

durch

```swift
        (testnotiz.stapel.aktueller?.name ?? "Testnotiz").uppercased()
```

- [ ] **Schritt 5: Test laufen lassen**

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/TestnotizScreenStapelTests 2>&1 | grep -E "✘|error:|Test run with"
```

Erwartet: `9 tests in 1 suite passed`.

- [ ] **Schritt 6: Die Wurzeln markieren**

Regel: ans Ende der Modifier-Kette der äußersten View in `body`. Ausnahmen: Home und Training haben ihren `NavigationStack` im eigenen `body`, dort sitzt der Modifier an der View **innerhalb** des Stacks. `ErstkontaktFlow` bekommt keinen; seine drei Schritte melden sich selbst.

| Datei | Kontext |
| --- | --- |
| `Screens/Zugang/` — `LoginMailView`, `LoginCodeView`, `MemberRegistrierenView`, `MemberPasswortView`, `MemberPasswortAendernView`, `MemberPasswortZuruecksetzenView`, `MemberKeinStudioView` | – |
| `Screens/Home/HomeRootView` | – |
| `Screens/Home/SessionDetailView` | `sessionId` |
| `Screens/Home/UebungsfortschrittView` | `exerciseId` |
| `Screens/Training/TrainingRootView` | – |
| `Screens/Training/TrainingAbschlussView` | `sessionId` |
| `Screens/Geraet/GeraeteAuswahlView` | – |
| `Screens/Geraet/GeraetErkanntView` | `machineId` |
| `Screens/Geraet/GeraetView` | `machineId`, `exerciseId`, `phase` |
| `Screens/Geraet/EinweisungSchritt`, `KalibrierungSchritt`, `ErsteWerteSchritt` | – |
| `Screens/Geraet/UebungWechselnSheet`, `ProblemSheet` | `machineId` |
| `Screens/Kurse/KurseWochenView` | – |
| `Screens/Kurse/KursDetailView` | `sessionId` |
| `Screens/Profil/ProfilRootView`, `MemberStudiosView`, `NameSheet` | – |
| `DesignSystem/Components/ScannerSheet` | `titel` |

`phase` am Gerät zählt: der Satzpfad hat drei Zustände in einem Screen, und ein Fund „in der Pause“ ohne diesen Kontext ist ein halber Fund. Die exakten Ersetzungen, alle Pfade unter `apps/ios-member/FitnessMember/`:

In `apps/ios-member/FitnessMember/Screens/Zugang/LoginMailView.swift` ersetzen:

```swift
            .background(DesignSystem.Color.bg)
        }
    }
```

durch

```swift
            .background(DesignSystem.Color.bg)
        }
        .testnotizScreen()
    }
```

In `apps/ios-member/FitnessMember/Screens/Zugang/LoginCodeView.swift` ersetzen:

```swift
            if complete { Task { await submit() } }
        }
    }
```

durch

```swift
            if complete { Task { await submit() } }
        }
        .testnotizScreen()
    }
```

In `apps/ios-member/FitnessMember/Screens/Zugang/MemberRegistrierenView.swift` ersetzen:

```swift
            LoginCodeView(email: email, apiClient: apiClient)
        }
    }
```

durch

```swift
            LoginCodeView(email: email, apiClient: apiClient)
        }
        .testnotizScreen()
    }
```

In `apps/ios-member/FitnessMember/Screens/Zugang/MemberPasswortView.swift` ersetzen:

```swift
        }
    }
```

durch

```swift
        }
        .testnotizScreen()
    }
```

In `apps/ios-member/FitnessMember/Screens/Zugang/MemberPasswortAendernView.swift` ersetzen:

```swift
            .background(DesignSystem.Color.bg)
        }
    }
```

durch

```swift
            .background(DesignSystem.Color.bg)
        }
        .testnotizScreen()
    }
```

In `apps/ios-member/FitnessMember/Screens/Zugang/MemberPasswortZuruecksetzenView.swift` ersetzen:

```swift
            .background(DesignSystem.Color.bg)
        }
    }
```

durch

```swift
            .background(DesignSystem.Color.bg)
        }
        .testnotizScreen()
    }
```

In `apps/ios-member/FitnessMember/Screens/Zugang/MemberKeinStudioView.swift` ersetzen:

```swift
            )
        }
    }
```

durch

```swift
            )
        }
        .testnotizScreen()
    }
```

In `apps/ios-member/FitnessMember/Screens/Home/HomeRootView.swift` ersetzen — Innerhalb des NavigationStack am ScrollView -- sonst verschwindet beim Push nichts.:

```swift
            .refreshable { await neuLaden() }
```

durch

```swift
            .refreshable { await neuLaden() }
            .testnotizScreen()
```

In `apps/ios-member/FitnessMember/Screens/Home/SessionDetailView.swift` ersetzen:

```swift
        .navigationBarTitleDisplayMode(.inline)
    }
```

durch

```swift
        .navigationBarTitleDisplayMode(.inline)
        .testnotizScreen(kontext: ["sessionId": sessionId])
    }
```

In `apps/ios-member/FitnessMember/Screens/Home/UebungsfortschrittView.swift` ersetzen:

```swift
        .navigationBarTitleDisplayMode(.inline)
    }
```

durch

```swift
        .navigationBarTitleDisplayMode(.inline)
        .testnotizScreen(kontext: ["exerciseId": exerciseId])
    }
```

In `apps/ios-member/FitnessMember/Screens/Training/TrainingRootView.swift` ersetzen — Innerhalb des NavigationStack an der TimelineView -- sonst verschwindet beim Push nichts.:

```swift
            .background(DesignSystem.Color.bg)
            .navigationDestination(for: GeraetRoute.self, destination: ziel)
```

durch

```swift
            .background(DesignSystem.Color.bg)
            .testnotizScreen()
            .navigationDestination(for: GeraetRoute.self, destination: ziel)
```

In `apps/ios-member/FitnessMember/Screens/Training/TrainingAbschlussView.swift` ersetzen:

```swift
                ausfall = error == .offline ? .ohneEmpfang : .serverfehler(error.servertext)
            }
        }
    }
```

durch

```swift
                ausfall = error == .offline ? .ohneEmpfang : .serverfehler(error.servertext)
            }
        }
        .testnotizScreen(kontext: ["sessionId": sessionId.uuidString])
    }
```

In `apps/ios-member/FitnessMember/Screens/Geraet/GeraeteAuswahlView.swift` ersetzen:

```swift
        .navigationBarTitleDisplayMode(.inline)
    }
```

durch

```swift
        .navigationBarTitleDisplayMode(.inline)
        .testnotizScreen()
    }
```

In `apps/ios-member/FitnessMember/Screens/Geraet/GeraetErkanntView.swift` ersetzen:

```swift
        .navigationBarTitleDisplayMode(.inline)
    }
```

durch

```swift
        .navigationBarTitleDisplayMode(.inline)
        .testnotizScreen(kontext: ["machineId": modell.maschine.id])
    }
```

In `apps/ios-member/FitnessMember/Screens/Geraet/GeraetView.swift` ersetzen:

```swift
            geradeGesendet = false
        }
    }
```

durch

```swift
            geradeGesendet = false
        }
        .testnotizScreen(kontext: [
            "machineId": modell.maschine.id,
            "exerciseId": modell.uebungId,
            // Nur der Fallname: .pause traegt einen Timer, dessen Text sich jede Sekunde aendert.
            "phase": String(String(describing: modell.phase).prefix { $0 != "(" }),
        ])
    }
```

In `apps/ios-member/FitnessMember/Screens/Geraet/EinweisungSchritt.swift` ersetzen:

```swift
        .background(DesignSystem.Color.bg)
    }
```

durch

```swift
        .background(DesignSystem.Color.bg)
        .testnotizScreen()
    }
```

In `apps/ios-member/FitnessMember/Screens/Geraet/KalibrierungSchritt.swift` ersetzen:

```swift
        .onAppear { modell.kalibrierungVorbereiten() }
    }
```

durch

```swift
        .onAppear { modell.kalibrierungVorbereiten() }
        .testnotizScreen()
    }
```

In `apps/ios-member/FitnessMember/Screens/Geraet/ErsteWerteSchritt.swift` ersetzen:

```swift
        .onAppear { modell.radOeffnen() }
    }
```

durch

```swift
        .onAppear { modell.radOeffnen() }
        .testnotizScreen()
    }
```

In `apps/ios-member/FitnessMember/Screens/Geraet/UebungWechselnSheet.swift` ersetzen:

```swift
        .presentationDragIndicator(.visible)
    }
```

durch

```swift
        .presentationDragIndicator(.visible)
        .testnotizScreen(kontext: ["machineId": modell.maschine.id])
    }
```

In `apps/ios-member/FitnessMember/Screens/Geraet/ProblemSheet.swift` ersetzen:

```swift
        .presentationDragIndicator(.visible)
    }
```

durch

```swift
        .presentationDragIndicator(.visible)
        .testnotizScreen(kontext: ["machineId": modell.maschine.id])
    }
```

In `apps/ios-member/FitnessMember/Screens/Kurse/KurseWochenView.swift` ersetzen:

```swift
            screenInhalt(jetzt: context.date)
        }
    }
```

durch

```swift
            screenInhalt(jetzt: context.date)
        }
        .testnotizScreen()
    }
```

In `apps/ios-member/FitnessMember/Screens/Kurse/KursDetailView.swift` ersetzen:

```swift
            screenInhalt(jetzt: context.date)
        }
    }
```

durch

```swift
            screenInhalt(jetzt: context.date)
        }
        .testnotizScreen(kontext: ["sessionId": sessionId])
    }
```

In `apps/ios-member/FitnessMember/Screens/Profil/ProfilRootView.swift` ersetzen:

```swift
        }
    }
```

durch

```swift
        }
        .testnotizScreen()
    }
```

In `apps/ios-member/FitnessMember/Screens/Profil/MemberStudiosView.swift` ersetzen:

```swift
            Text("Ein Studio, das du verlässt, verliert dich als Mitglied — deine Sätze und dein Fortschritt bleiben bei dir.")
        }
    }
```

durch

```swift
            Text("Ein Studio, das du verlässt, verliert dich als Mitglied — deine Sätze und dein Fortschritt bleiben bei dir.")
        }
        .testnotizScreen()
    }
```

In `apps/ios-member/FitnessMember/Screens/Profil/NameSheet.swift` ersetzen:

```swift
        .onAppear { name = bisher ?? "" }
    }
```

durch

```swift
        .onAppear { name = bisher ?? "" }
        .testnotizScreen()
    }
```

In `apps/ios-member/FitnessMember/DesignSystem/Components/ScannerSheet.swift` ersetzen:

```swift
        .presentationCornerRadius(DesignSystem.Radius.haupt)
    }
```

durch

```swift
        .presentationCornerRadius(DesignSystem.Radius.haupt)
        .testnotizScreen(kontext: ["titel": titel])
    }
```

- [ ] **Schritt 7: Bauen und alle Tests**

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test  2>&1 | grep -E "✘|error:|Test run with"
```

Erwartet: alle Suiten grün, keine Warnung aus den 26 Dateien.

- [ ] **Schritt 8: Simulator**

Knopf tippen, Kopfzeile des Menüs lesen, schließen. Soll:

- Alle vier Tabs: `HOMEROOTVIEW`, `TRAININGROOTVIEW`, `KURSEWOCHENVIEW`, `PROFILROOTVIEW`.
- Training → Liste → Gerät → Übung: `GERAETVIEW`; zurück: `TRAININGROOTVIEW`.
- Am Gerät „andere Übung“ offen: `UEBUNGWECHSELNSHEET`; zu: `GERAETVIEW`.
- Profil → Studios: `MEMBERSTUDIOSVIEW`; zurück: `PROFILROOTVIEW`.
- Kurse → Kurs: `KURSDETAILVIEW`.

Weicht ein Screen ab, sitzt sein Modifier an der falschen View: prüfen, ob die Wurzel beim Push wirklich verschwindet.

- [ ] **Schritt 9: Commit**

```bash
git add apps/ios-member
git commit -m "feat(testnotiz): Screen-Stapel, 26 Wurzeln gemeldet"
```

---

## Aufgabe 4: Laufzeitkontext und Protokoll

**Dateien:**
- Anlegen: `Testnotiz/TestnotizProtokoll.swift`, `Testnotiz/Laufzeitkontext.swift`
- Test: `TestnotizProtokollTests.swift`

**Schnittstellen:**
- Nutzt: `NetzwerkMonitor.istOnline`, `CatalogStore.pendingWrites`, `CatalogStore.activeStudioId`, `SessionStore.session`, `TestnotizEintrag.Laufzeit`, `TestnotizEintrag.Protokollzeile`, `TestnotizSitzung.Kopf`
- Liefert:
  - `enum TestnotizProtokoll` — `subsystem`, `kategorien: Set<String>`, `stufe(_: OSLogEntryLog.Level) -> String`, `lesen(seit:bis:kategorien:) -> [Protokollzeile]`, `lesenImHintergrund(seit:bis:) async -> [Protokollzeile]`
  - `enum Laufzeitkontext` — `@MainActor laufzeit(netz:katalog:session:)`, `@MainActor sitzungskopf(jetzt:szene:)` (`id` leer, die Ablage vergibt ihn), `modellkennung() -> String`


- [ ] **Schritt 1: Test**

Anlegen: `apps/ios-member/FitnessMemberTests/TestnotizProtokollTests.swift`

```swift
#if DEBUG
import Foundation
import OSLog
import Testing
@testable import FitnessMember

struct TestnotizProtokollTests {
    @Test func stufenHabenFesteNamen() {
        #expect(TestnotizProtokoll.stufe(.info) == "info")
        #expect(TestnotizProtokoll.stufe(.error) == "error")
        #expect(TestnotizProtokoll.stufe(.fault) == "fault")
        #expect(TestnotizProtokoll.stufe(.debug) == "debug")
        #expect(TestnotizProtokoll.stufe(.notice) == "notice")
    }

    @Test func liestNurErlaubteKategorienDesEigenenSubsystems() throws {
        let marke = UUID().uuidString
        Logger(subsystem: TestnotizProtokoll.subsystem, category: "tag").notice("erlaubt \(marke, privacy: .public)")
        Logger(subsystem: TestnotizProtokoll.subsystem, category: "konto").notice("verboten \(marke, privacy: .public)")
        Logger(subsystem: "de.anderes.subsystem", category: "tag").notice("fremd \(marke, privacy: .public)")

        let zeilen = TestnotizProtokoll.lesen(seit: 60, bis: Date())
        let meine = zeilen.filter { $0.message.contains(marke) }
        #expect(meine.count == 1)
        #expect(meine.first?.message == "erlaubt \(marke)")
        #expect(meine.first?.category == "tag")
        #expect(meine.first?.level == "notice")
    }

    @Test func modellkennungIstKeineArchitektur() {
        let kennung = Laufzeitkontext.modellkennung()
        #expect(kennung.hasPrefix("iPhone") || kennung.hasPrefix("iPad"))
    }
}
#endif
```

Der Filtertest schreibt echte Zeilen in drei Kategorien und liest sie über `OSLogStore` zurück — das geht im Test-Host (geprüft) und ist der eigentliche Beweis für die Datenschutz-Schranke.

- [ ] **Schritt 2: Test laufen lassen — er darf nicht kompilieren**

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/TestnotizProtokollTests 2>&1 | grep -E "✘|error:|Test run with"
```

Erwartet: `cannot find 'TestnotizProtokoll' in scope`.

- [ ] **Schritt 3: Protokoll und Laufzeitkontext**

Anlegen: `apps/ios-member/FitnessMember/Testnotiz/TestnotizProtokoll.swift`

```swift
#if DEBUG
import OSLog

enum TestnotizProtokoll {
    static let subsystem = "de.gymtaro.member"

    /// Nur Kategorien, deren Zeilen nachweislich keine Personendaten tragen.
    /// Im eigenen Prozess schwaerzt OSLogStore privacy: .private NICHT (Spike
    /// 2026-09-14) -- eine neue Kategorie kommt erst nach einem Blick auf
    /// ihre Zeilen hierher.
    static let kategorien: Set<String> = ["tag"]

    static func stufe(_ level: OSLogEntryLog.Level) -> String {
        switch level {
        case .debug: "debug"
        case .info: "info"
        case .notice: "notice"
        case .error: "error"
        case .fault: "fault"
        case .undefined: "undefined"
        @unknown default: "undefined"
        }
    }

    /// Ein Lesefehler kostet das Protokoll, nie den Eintrag.
    static func lesen(seit sekunden: TimeInterval, bis jetzt: Date, kategorien: Set<String> = kategorien) -> [TestnotizEintrag.Protokollzeile] {
        do {
            let speicher = try OSLogStore(scope: .currentProcessIdentifier)
            let ab = speicher.position(date: jetzt.addingTimeInterval(-sekunden))
            let praedikat = NSPredicate(format: "subsystem == %@ AND category IN %@", subsystem, Array(kategorien))
            return try speicher.getEntries(at: ab, matching: praedikat)
                .compactMap { $0 as? OSLogEntryLog }
                .map { TestnotizEintrag.Protokollzeile(at: $0.date, level: stufe($0.level), category: $0.category, message: $0.composedMessage) }
        } catch {
            return []
        }
    }

    /// OSLogStore braucht bei vollem Speicher Sekunden; nicht auf dem Main Thread.
    static func lesenImHintergrund(seit sekunden: TimeInterval, bis jetzt: Date) async -> [TestnotizEintrag.Protokollzeile] {
        await Task.detached(priority: .userInitiated) {
            lesen(seit: sekunden, bis: jetzt)
        }.value
    }
}
#endif
```

Anlegen: `apps/ios-member/FitnessMember/Testnotiz/Laufzeitkontext.swift`

```swift
#if DEBUG
import UIKit

enum Laufzeitkontext {
    /// Bewusst ohne E-Mail, Token und Anzeigenamen (Architekturprinzip 6):
    /// angemeldet ja/nein und das Studio genuegen, um einen Fund einzuordnen.
    @MainActor
    static func laufzeit(netz: NetzwerkMonitor?, katalog: CatalogStore?, session: SessionStore?) -> TestnotizEintrag.Laufzeit {
        TestnotizEintrag.Laufzeit(
            online: netz?.istOnline ?? false,
            pendingWrites: katalog?.pendingWrites.count ?? 0,
            signedIn: session?.session != nil,
            studioId: katalog?.activeStudioId
        )
    }

    @MainActor
    static func sitzungskopf(jetzt: Date, szene: UIWindowScene?) -> TestnotizSitzung.Kopf {
        let info = Bundle.main.infoDictionary ?? [:]
        let bounds = szene?.screen.bounds ?? .zero
        let scale = szene?.screen.scale ?? 0
        return TestnotizSitzung.Kopf(
            id: "",
            startedAt: jetzt,
            app: TestnotizSitzung.App(
                bundleId: Bundle.main.bundleIdentifier ?? "",
                version: info["CFBundleShortVersionString"] as? String ?? "",
                build: info["CFBundleVersion"] as? String ?? "",
                configuration: "Debug"
            ),
            device: TestnotizSitzung.Geraet(
                model: modellkennung(),
                os: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)",
                screen: TestnotizSitzung.Bildschirm(
                    width: Double(bounds.width),
                    height: Double(bounds.height),
                    scale: Double(scale)
                )
            )
        )
    }

    /// "iPhone14,4" statt "iPhone": nur die Kennung unterscheidet Groesse
    /// und Aussparung. Im Simulator liefert uname "arm64".
    static func modellkennung() -> String {
        if let simuliert = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] { return simuliert }
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { puffer in
            String(decoding: puffer.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
    }
}
#endif
```

- [ ] **Schritt 4: Test laufen lassen**

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/TestnotizProtokollTests 2>&1 | grep -E "✘|error:|Test run with"
```

Erwartet: `3 tests in 1 suite passed`. Der Filtertest braucht einige Sekunden.

- [ ] **Schritt 5: Commit**

```bash
git add apps/ios-member
git commit -m "feat(testnotiz): Laufzeitkontext und OSLog-Auszug mit Kategorien-Liste"
```

---

## Aufgabe 5: Bildschirmfoto, Ausschnitt, erster Eintrag im Ordner

Ab hier entsteht ein Ordner. Bis zum Notiz-Blatt in Aufgabe 7 sichert der Ausschnitt sofort ohne Notiz.

**Dateien:**
- Anlegen: `Testnotiz/Bildschirmfoto.swift`, `Testnotiz/AuswahlOverlay.swift`
- Ganz ersetzen: `Testnotiz/Testnotiz.swift`, `Testnotiz/TestnotizOberflaeche.swift`, `Testnotiz/TestnotizMenue.swift`
- Test: `AusschnittTests.swift`

**Schnittstellen:**
- Nutzt: `TestnotizAblage`, `Laufzeitkontext`, `TestnotizProtokoll`, `Testnotiz.stapel`
- Liefert:
  - `enum Bildschirmfoto { @MainActor static func aufnehmen(szene:ohne:) -> UIImage }`
  - `enum Ausschnitt` — `pixelRechteck(punkte:scale:bildgroesse:) -> CGRect?`, `schneiden(_:punkte:) -> (bild: UIImage, rahmen: TestnotizEintrag.Ausschnittsrahmen)?`
  - `struct AuswahlOverlay: View` — `enum Art { rechteck, punkt }`, `beiRechteck`, `beiPunkt`, `beiAbbruch`
  - `Testnotiz`: `Modus.ausschnitt`; `struct Entwurf { zeitpunkt, vollbild, screen, art, ausschnitt, ausschnittsrahmen, element }`; `entwurf`, `eintragsanzahl`, `letzterFehler`, `ablage`; `knopfGetippt()` nimmt Foto und Screen; `ausschnittGewaehlt(_:)`; `sichern(notiz:audio:) async`


- [ ] **Schritt 1: Rechnungstests**

Anlegen: `apps/ios-member/FitnessMemberTests/AusschnittTests.swift`

```swift
#if DEBUG
import UIKit
import Testing
@testable import FitnessMember

struct AusschnittTests {
    private let iphone = CGSize(width: 1125, height: 2436)

    @Test func rechnetPunkteInPixelUm() {
        let r = Ausschnitt.pixelRechteck(punkte: CGRect(x: 20, y: 412, width: 335, height: 96), scale: 3, bildgroesse: iphone)
        #expect(r == CGRect(x: 60, y: 1236, width: 1005, height: 288))
    }

    // 10,4 pt * 2 = 20,8 px -> 20; (10,4 + 10,2) * 2 = 41,2 px -> 42.
    @Test func rundetAufGanzePixelNachAussen() {
        let r = Ausschnitt.pixelRechteck(punkte: CGRect(x: 10.4, y: 10.4, width: 10.2, height: 10.2), scale: 2, bildgroesse: CGSize(width: 100, height: 100))
        #expect(r == CGRect(x: 20, y: 20, width: 22, height: 22))
    }

    @Test func beschneidetAufDasBild() {
        let r = Ausschnitt.pixelRechteck(punkte: CGRect(x: -5, y: 790, width: 400, height: 60), scale: 3, bildgroesse: iphone)
        #expect(r == CGRect(x: 0, y: 2370, width: 1125, height: 66))
    }

    @Test func leererSchnittIstNil() {
        #expect(Ausschnitt.pixelRechteck(punkte: CGRect(x: 900, y: 0, width: 10, height: 10), scale: 3, bildgroesse: iphone) == nil)
    }

    // Von rechts unten nach links oben gezogen: negative Breite.
    @Test func normalisiertNegativeGesten() {
        let r = Ausschnitt.pixelRechteck(punkte: CGRect(x: 100, y: 100, width: -50, height: -50), scale: 2, bildgroesse: CGSize(width: 400, height: 400))
        #expect(r == CGRect(x: 100, y: 100, width: 100, height: 100))
    }

    @Test func schneidetDasBildUndMeldetBeideRahmen() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let bild = UIGraphicsImageRenderer(size: CGSize(width: 50, height: 40), format: format).image { kontext in
            UIColor.red.setFill()
            kontext.fill(CGRect(x: 0, y: 0, width: 50, height: 40))
        }
        let ergebnis = try #require(Ausschnitt.schneiden(bild, punkte: CGRect(x: 10, y: 5, width: 20, height: 10)))
        #expect(ergebnis.bild.size == CGSize(width: 20, height: 10))
        #expect(ergebnis.bild.scale == 2)
        #expect(ergebnis.rahmen.pixels == TestnotizEintrag.Rechteck(x: 20, y: 10, width: 40, height: 20))
        #expect(ergebnis.rahmen.points == TestnotizEintrag.Rechteck(x: 10, y: 5, width: 20, height: 10))
    }
}
#endif
```

Der Entwurf erwartete beim Aufrunden `21` Pixel; richtig ist `22` (20,8 → 20 und 41,2 → 42).

- [ ] **Schritt 2: Test laufen lassen — er darf nicht kompilieren**

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/AusschnittTests 2>&1 | grep -E "✘|error:|Test run with"
```

Erwartet: `cannot find 'Ausschnitt' in scope`.

- [ ] **Schritt 3: Foto und Auswahl**

Anlegen: `apps/ios-member/FitnessMember/Testnotiz/Bildschirmfoto.swift`

```swift
#if DEBUG
import UIKit

enum Bildschirmfoto {
    /// Fensterweise gezeichnet: Alerts und Systemblaetter liegen in eigenen
    /// Fenstern, ein keyWindow allein wuerde sie verlieren. Das eigene
    /// Fenster fehlt im Bild -- kein Knopf, kein Menue.
    @MainActor
    static func aufnehmen(szene: UIWindowScene, ohne eigenes: UIWindow) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = szene.screen.scale
        return UIGraphicsImageRenderer(bounds: szene.screen.bounds, format: format).image { _ in
            for fenster in szene.windows where fenster !== eigenes && !fenster.isHidden && fenster.alpha > 0 {
                fenster.drawHierarchy(in: fenster.frame, afterScreenUpdates: false)
            }
        }
    }
}

enum Ausschnitt {
    /// Punkte -> Pixel, nach aussen auf ganze Pixel gerundet und aufs Bild
    /// beschnitten. nil, wenn nichts uebrig bleibt.
    static func pixelRechteck(punkte: CGRect, scale: CGFloat, bildgroesse: CGSize) -> CGRect? {
        let r = punkte.standardized
        let minX = (r.minX * scale).rounded(.down)
        let minY = (r.minY * scale).rounded(.down)
        let maxX = (r.maxX * scale).rounded(.up)
        let maxY = (r.maxY * scale).rounded(.up)
        let roh = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        let geschnitten = roh.intersection(CGRect(origin: .zero, size: bildgroesse))
        guard !geschnitten.isNull, geschnitten.width >= 1, geschnitten.height >= 1 else { return nil }
        return geschnitten
    }

    static func schneiden(_ bild: UIImage, punkte: CGRect) -> (bild: UIImage, rahmen: TestnotizEintrag.Ausschnittsrahmen)? {
        guard let cg = bild.cgImage else { return nil }
        let groesse = CGSize(width: cg.width, height: cg.height)
        guard let pixel = pixelRechteck(punkte: punkte, scale: bild.scale, bildgroesse: groesse),
              let teil = cg.cropping(to: pixel)
        else { return nil }
        let rahmen = TestnotizEintrag.Ausschnittsrahmen(
            points: TestnotizEintrag.Rechteck(punkte.standardized),
            pixels: TestnotizEintrag.Rechteck(pixel)
        )
        return (UIImage(cgImage: teil, scale: bild.scale, orientation: .up), rahmen)
    }
}
#endif
```

Anlegen: `apps/ios-member/FitnessMember/Testnotiz/AuswahlOverlay.swift`

```swift
#if DEBUG
import SwiftUI

/// Vollflaechig: ein Rechteck ziehen oder einen Punkt tippen. Gezeichnet
/// wird in einem Canvas, der die Safe Area ignoriert -- so decken sich seine
/// Koordinaten mit .global und damit mit dem Bildschirmfoto.
struct AuswahlOverlay: View {
    enum Art { case rechteck, punkt }

    let art: Art
    let beiRechteck: (CGRect) -> Void
    let beiPunkt: (CGPoint) -> Void
    let beiAbbruch: () -> Void

    @State private var start: CGPoint?
    @State private var ende: CGPoint?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Canvas { kontext, groesse in
                var flaeche = Path(CGRect(origin: .zero, size: groesse))
                if art == .rechteck, let rechteck { flaeche.addRect(rechteck) }
                kontext.fill(flaeche, with: .color(DesignSystem.Color.bg.opacity(0.45)), style: FillStyle(eoFill: true))
                if art == .rechteck, let rechteck {
                    kontext.stroke(Path(rechteck), with: .color(DesignSystem.Color.accent), lineWidth: 2)
                }
                if art == .punkt, let ende {
                    let kreis = CGRect(x: ende.x - 22, y: ende.y - 22, width: 44, height: 44)
                    kontext.stroke(Path(ellipseIn: kreis), with: .color(DesignSystem.Color.accent), lineWidth: 2)
                }
            }
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { wert in
                        start = wert.startLocation
                        ende = wert.location
                    }
                    .onEnded { wert in
                        start = nil
                        ende = nil
                        abschliessen(von: wert.startLocation, bis: wert.location)
                    }
            )

            Button(action: beiAbbruch) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.text)
                    .frame(width: 44, height: 44)
                    .background(DesignSystem.Color.surfaceRaised, in: Circle())
            }
            .accessibilityLabel("Abbrechen")
            .padding(DesignSystem.Spacing.s16)
        }
    }

    private var rechteck: CGRect? {
        guard let start, let ende else { return nil }
        return CGRect(x: start.x, y: start.y, width: ende.x - start.x, height: ende.y - start.y).standardized
    }

    private func abschliessen(von a: CGPoint, bis b: CGPoint) {
        switch art {
        case .punkt:
            beiPunkt(b)
        case .rechteck:
            let r = CGRect(x: a.x, y: a.y, width: b.x - a.x, height: b.y - a.y).standardized
            // Ein Tipp ohne Zug bricht ab, statt einen 1-Pixel-Ausschnitt zu sichern.
            if r.width < 8 || r.height < 8 { beiAbbruch() } else { beiRechteck(r) }
        }
    }
}
#endif
```

- [ ] **Schritt 4: Der Ablauf im Modul**

Ganz ersetzen: `apps/ios-member/FitnessMember/Testnotiz/Testnotiz.swift`

```swift
import SwiftUI

#if DEBUG
import Observation

/// Der eine Ort, an dem das Modul lebt. Ein Singleton, weil das Fenster
/// eines ist: eine Szene, ein Knopf darueber.
@MainActor
@Observable
final class Testnotiz {
    static let shared = Testnotiz()

    enum Modus: Equatable {
        case ruhe, menue, ausschnitt
    }

    /// Was zwischen Knopf-Tipp und Sichern entsteht. Das Foto kommt beim
    /// Tipp auf den Knopf: danach aendert sich die App nicht mehr, weil das
    /// Fenster ab dann alle Beruehrungen faengt.
    struct Entwurf {
        var zeitpunkt: Date
        var vollbild: UIImage
        var screen: TestnotizEintrag.Screen?
        var art: TestnotizEintrag.Art = .note
        var ausschnitt: UIImage?
        var ausschnittsrahmen: TestnotizEintrag.Ausschnittsrahmen?
        var element: TestnotizEintrag.Element?
    }

    var modus: Modus = .ruhe
    /// Bildschirmrahmen des Knopfs. Ausserhalb davon laesst das Fenster in
    /// Ruhe jede Beruehrung zur App durch.
    var knopfRahmen: CGRect = .zero
    var stapel = TestnotizScreenStapel()
    var entwurf: Entwurf?
    private(set) var eintragsanzahl = 0
    private(set) var letzterFehler: String?

    @ObservationIgnored private(set) var ablage: TestnotizAblage?
    @ObservationIgnored private(set) var fenster: TestnotizFenster?
    @ObservationIgnored private(set) weak var netz: NetzwerkMonitor?
    @ObservationIgnored private(set) weak var katalog: CatalogStore?
    @ObservationIgnored private(set) weak var session: SessionStore?

    /// Idempotent: RootView kann mehrfach in ein Fenster wandern
    /// (Session-Wechsel), das Overlay-Fenster darf es nur einmal geben.
    func installieren(in szene: UIWindowScene, netz: NetzwerkMonitor, katalog: CatalogStore, session: SessionStore) {
        self.netz = netz
        self.katalog = katalog
        self.session = session
        guard fenster == nil else { return }
        let neu = TestnotizFenster(windowScene: szene)
        let host = UIHostingController(rootView: TestnotizOberflaeche())
        host.view.backgroundColor = .clear
        neu.rootViewController = host
        neu.isHidden = false
        fenster = neu
    }

    func knopfGetippt() {
        letzterFehler = nil
        guard let fenster, let szene = fenster.windowScene else { return }
        let screen = stapel.aktueller.map {
            TestnotizEintrag.Screen(name: $0.name, file: $0.datei, stack: stapel.pfad, context: $0.kontext)
        }
        entwurf = Entwurf(
            zeitpunkt: Date(),
            vollbild: Bildschirmfoto.aufnehmen(szene: szene, ohne: fenster),
            screen: screen
        )
        modus = .menue
    }

    func zurRuhe() {
        entwurf = nil
        modus = .ruhe
    }

    func ausschnittGewaehlt(_ punkte: CGRect) {
        guard var neu = entwurf, let geschnitten = Ausschnitt.schneiden(neu.vollbild, punkte: punkte) else {
            zurRuhe()
            return
        }
        neu.art = .crop
        neu.ausschnitt = geschnitten.bild
        neu.ausschnittsrahmen = geschnitten.rahmen
        entwurf = neu
        // Bis zum Notiz-Blatt (Aufgabe 7) wird ohne Notiz gesichert.
        Task { await sichern(notiz: nil, audio: nil) }
    }

    /// Das Blatt ist sofort zu; geschrieben wird danach. Wer testet, soll
    /// nicht auf PNG-Kodierung und Protokoll warten.
    func sichern(notiz: String?, audio: URL?) async {
        guard let entwurf else {
            zurRuhe()
            return
        }
        zurRuhe()
        let laufzeit = Laufzeitkontext.laufzeit(netz: netz, katalog: katalog, session: session)
        let protokoll = await TestnotizProtokoll.lesenImHintergrund(seit: 300, bis: entwurf.zeitpunkt)
        let eintrag = TestnotizEintrag(
            id: UUID(), index: 0, createdAt: entwurf.zeitpunkt, kind: entwurf.art,
            screen: entwurf.screen, screenshot: "", crop: nil, cropRect: entwurf.ausschnittsrahmen,
            element: entwurf.element, note: notiz, audio: nil, transcript: nil,
            runtime: laufzeit, log: protokoll
        )
        do {
            let ablage = try ablageHolen(jetzt: entwurf.zeitpunkt)
            _ = try await ablage.schreiben(
                eintrag,
                voll: entwurf.vollbild.pngData() ?? Data(),
                ausschnitt: entwurf.ausschnitt?.pngData(),
                audio: audio
            )
            eintragsanzahl = await ablage.anzahl
        } catch {
            letzterFehler = "Nicht gesichert: \(error.localizedDescription)"
        }
    }

    private func ablageHolen(jetzt: Date) throws -> TestnotizAblage {
        if let ablage { return ablage }
        let wurzel = URL.documentsDirectory.appendingPathComponent("Testnotizen")
        let neu = try TestnotizAblage(wurzel: wurzel, kopf: Laufzeitkontext.sitzungskopf(jetzt: jetzt, szene: fenster?.windowScene))
        ablage = neu
        return neu
    }
}

/// Meldet das erste Fenster, in das RootView gelangt. didMoveToWindow statt
/// updateUIView: beim ersten Update haengt die View noch in keinem Fenster,
/// und ein weiteres Update ist nicht zugesichert.
private final class InstallationsAnker: UIView {
    var beiFenster: ((UIWindowScene) -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if let szene = window?.windowScene { beiFenster?(szene) }
    }
}

private struct TestnotizInstallation: UIViewRepresentable {
    let netz: NetzwerkMonitor
    let katalog: CatalogStore
    let session: SessionStore

    func makeUIView(context: Context) -> InstallationsAnker {
        let anker = InstallationsAnker()
        anker.isUserInteractionEnabled = false
        anker.beiFenster = { [netz, katalog, session] szene in
            Testnotiz.shared.installieren(in: szene, netz: netz, katalog: katalog, session: session)
        }
        return anker
    }

    func updateUIView(_ uiView: InstallationsAnker, context: Context) {}
}

extension View {
    func testnotizInstallieren(netz: NetzwerkMonitor, katalog: CatalogStore, session: SessionStore) -> some View {
        background(TestnotizInstallation(netz: netz, katalog: katalog, session: session))
    }
}
#else
extension View {
    /// Release: kein Fenster, kein Knopf.
    @inline(__always)
    func testnotizInstallieren(netz: NetzwerkMonitor, katalog: CatalogStore, session: SessionStore) -> some View { self }
}
#endif
```

Ganz ersetzen: `apps/ios-member/FitnessMember/Testnotiz/TestnotizOberflaeche.swift`

```swift
#if DEBUG
import SwiftUI

/// Der Inhalt des Overlay-Fensters: je Modus genau eine Ansicht.
struct TestnotizOberflaeche: View {
    private let testnotiz = Testnotiz.shared

    var body: some View {
        ZStack {
            switch testnotiz.modus {
            case .ruhe:
                TestnotizKnopf()
            case .menue:
                TestnotizMenue()
            case .ausschnitt:
                AuswahlOverlay(art: .rechteck, beiRechteck: testnotiz.ausschnittGewaehlt, beiPunkt: { _ in }, beiAbbruch: testnotiz.zurRuhe)
            }
        }
    }
}
#endif
```

Ganz ersetzen: `apps/ios-member/FitnessMember/Testnotiz/TestnotizMenue.swift`

```swift
#if DEBUG
import SwiftUI

/// Ein eigenes Panel statt SwiftUI-Menu: dessen Eintraege laegen ausserhalb
/// des Knopfrahmens, und das durchlaessige Fenster liesse Tipps darauf zur
/// App durch. Im Modus .menue faengt das Fenster alles.
struct TestnotizMenue: View {
    private let testnotiz = Testnotiz.shared

    struct Eintrag: Identifiable {
        let id: String
        let titel: String
        let symbol: String
        let aktion: () -> Void
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            DesignSystem.Color.bg.opacity(0.5)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { testnotiz.zurRuhe() }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                Text(kopfzeile)
                    .font(DesignSystem.Typography.label)
                    .tracking(1.5)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .padding(DesignSystem.Spacing.s16)

                if let fehler = testnotiz.letzterFehler {
                    Text(fehler)
                        .font(DesignSystem.Typography.fliesstext)
                        .foregroundStyle(DesignSystem.Color.danger)
                        .padding(.horizontal, DesignSystem.Spacing.s16)
                        .padding(.bottom, DesignSystem.Spacing.s8)
                }

                ForEach(eintraege) { eintrag in
                    zeile(titel: eintrag.titel, symbol: eintrag.symbol, farbe: DesignSystem.Color.text, aktion: eintrag.aktion)
                }

                Rectangle().fill(DesignSystem.Color.line).frame(height: 1)
                zeile(titel: "Schließen", symbol: "xmark", farbe: DesignSystem.Color.textMuted, aktion: testnotiz.zurRuhe)
            }
            .background(DesignSystem.Color.surfaceRaised, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.haupt))
            .padding(DesignSystem.Spacing.s16)
        }
    }

    private var kopfzeile: String {
        (testnotiz.entwurf?.screen?.name ?? "Testnotiz").uppercased()
    }

    private var eintraege: [Eintrag] {
        [
            Eintrag(id: "ausschnitt", titel: "Ausschnitt", symbol: "crop") { testnotiz.modus = .ausschnitt },
        ]
    }

    private func zeile(titel: String, symbol: String, farbe: Color, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Label(titel, systemImage: symbol)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(farbe)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.horizontal, DesignSystem.Spacing.s16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
#endif
```

- [ ] **Schritt 5: Tests laufen lassen**

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/AusschnittTests 2>&1 | grep -E "✘|error:|Test run with"
```

Erwartet: `6 tests in 1 suite passed`.

- [ ] **Schritt 6: Simulator**

Am Gerät-Screen: Knopf → Ausschnitt → Rechteck über das Gewicht ziehen. Dann den Ordner im Simulator öffnen:

```bash
open "$(xcrun simctl get_app_container booted de.gymtaro.member data)/Documents/Testnotizen"
```

Soll: `01-voll.png` zeigt die App ohne Knopf und ohne Menü; `01-ausschnitt.png` genau den gezogenen Bereich (an einer Textkante prüfen); `sitzung.json` trägt beide Rahmen, `screen.context.phase` und `runtime`; `sitzung.md` beginnt mit `# Testsitzung`. Ein Tipp ohne Zug bricht ab, ohne etwas zu schreiben.

- [ ] **Schritt 7: Commit**

```bash
git add apps/ios-member
git commit -m "feat(testnotiz): Bildschirmfoto und Ausschnitt bis in den Sitzungsordner"
```

---

## Aufgabe 6: Element — Accessibility-Baum und Kennungen

**Dateien:**
- Anlegen: `Testnotiz/AccessibilityBaum.swift`, `Testnotiz/TestnotizElement.swift`
- Ganz ersetzen: `Testnotiz/Testnotiz.swift`, `TestnotizOberflaeche.swift`, `TestnotizMenue.swift`
- Ändern: `Screens/Geraet/GeraetView.swift`, `Screens/Training/TrainingRootView.swift`, `Screens/Home/HomeRootView.swift`, `Screens/Profil/ProfilRootView.swift`
- Test: `AccessibilityBaumTests.swift`

**Schnittstellen:**
- Nutzt: `AuswahlOverlay(.punkt)`, `Quellpfad`, `Testnotiz.entwurf`
- Liefert:
  - `struct AccessibilityKandidat: Equatable, Sendable` — `kennung`, `label`, `typ`, `rahmen` (Bildschirmkoordinaten)
  - `enum AccessibilityBaum` — `treffer(_:punkt:)`, `typ(traits:klasse:)`, `@MainActor sammeln(ab:)`, `@MainActor element(an:szene:ohne:) async`
  - `@MainActor enum AXSchalter` — `static var stand: Int32?`, `static func eingeschaltet<T>(_ arbeit: @MainActor () -> T) async -> T`
  - `struct ElementHerkunft { typ, datei, zeile }`, `struct TestnotizElementRegister` — `melden(kennung:herkunft:)`, `herkunft(kennung:)`, `element(aus:) -> TestnotizEintrag.Element`
  - `View.testnotizElement(_ kennung: String, typ: String, datei: String = #filePath, zeile: Int = #line)` — Release: `testnotizElement(_:typ:)`, setzt nur `accessibilityIdentifier`
  - `Testnotiz`: `Modus.element`, `register`, `elementGewaehlt(_:) async`

**Zur privaten API.** `_AXSApplicationAccessibilitySetEnabled` ist nicht dokumentiert. Sie steht nur im Debug-Build (Beweis in Aufgabe 8) und wird nie ohne Rückstellung gesetzt, weil der Wert je Bundle-ID gespeichert bleibt und ein später installierter Release-Build derselben ID sonst mit eingeschaltetem Baum liefe. Entschieden am 14. September.


- [ ] **Schritt 1: Am Gerät gegenprüfen, was der Simulator gezeigt hat**

Der Spike lief im Simulator. Bevor die Aufgabe darauf baut, einmal am Gerät (`Just4Us`): Schritt 2 bis 4 umsetzen, dann nur `AccessibilityBaumTests` **auf dem Gerät** laufen lassen:

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember -destination "platform=iOS,name=Just4Us" test -only-testing:FitnessMemberTests/AccessibilityBaumTests 2>&1 | grep -E "✘|error:|Test run with"
```

Grün: weiter mit Schritt 5. Rot bei `findetSwiftUIElementMitKennungImProzess`: **anhalten und melden.** Der Rückfallweg (Rahmen je markiertem Element per `onGeometryChange` ins Register, Treffer nur unter markierten Elementen) ist dann ein Nachtrag zu diesem Plan, nicht etwas, das ein Umsetzer allein entscheidet.

- [ ] **Schritt 2: Tests**

Anlegen: `apps/ios-member/FitnessMemberTests/AccessibilityBaumTests.swift`

```swift
#if DEBUG
import SwiftUI
import Testing
@testable import FitnessMember

@MainActor
struct AccessibilityBaumTests {
    private let karte = AccessibilityKandidat(kennung: nil, label: "Karte", typ: "Text", rahmen: CGRect(x: 0, y: 0, width: 300, height: 200))
    private let knopf = AccessibilityKandidat(kennung: "geraet.satz-sichern", label: "Satz 2 sichern", typ: "Button", rahmen: CGRect(x: 20, y: 120, width: 260, height: 64))

    @Test func kleinstesRechteckUmDenPunktGewinnt() {
        #expect(AccessibilityBaum.treffer([karte, knopf], punkt: CGPoint(x: 100, y: 150)) == knopf)
        #expect(AccessibilityBaum.treffer([karte, knopf], punkt: CGPoint(x: 100, y: 20)) == karte)
    }

    @Test func nebenDemTextTrifftEsInnerhalbEinerFingerbreite() {
        #expect(AccessibilityBaum.treffer([knopf], punkt: CGPoint(x: 100, y: 200)) == knopf)
        #expect(AccessibilityBaum.treffer([knopf], punkt: CGPoint(x: 100, y: 210)) == nil)
    }

    @Test func typKommtAusDenTraits() {
        #expect(AccessibilityBaum.typ(traits: [.button, .staticText], klasse: "AccessibilityNode") == "Button")
        #expect(AccessibilityBaum.typ(traits: .staticText, klasse: "AccessibilityNode") == "Text")
        #expect(AccessibilityBaum.typ(traits: [], klasse: "UISwitch") == "UISwitch")
    }

    @Test func registerReichertDenKandidatenAn() {
        var register = TestnotizElementRegister()
        register.melden(kennung: "geraet.satz-sichern", herkunft: ElementHerkunft(typ: "PrimaryButton", datei: "apps/ios-member/FitnessMember/Screens/Geraet/GeraetView.swift", zeile: 246))
        let element = register.element(aus: knopf)
        #expect(element.type == "PrimaryButton")
        #expect(element.line == 246)
        #expect(element.frame == TestnotizEintrag.Rechteck(x: 20, y: 120, width: 260, height: 64))

        let unmarkiert = register.element(aus: karte)
        #expect(unmarkiert.type == "Text")
        #expect(unmarkiert.file == nil)
    }

    // Der Schalter bleibt je Bundle-ID gespeichert. Bliebe er nach der
    // Suche an, liefe ein spaeter installierter Release-Build mit Baum.
    @Test func stelltDenSchalterZurueck() async throws {
        let vorher = try #require(AXSchalter.stand)
        let waehrend = await AXSchalter.eingeschaltet { AXSchalter.stand }
        #expect(waehrend == 1)
        #expect(AXSchalter.stand == vorher)
    }

    // Der Beweis aus dem Spike, im echten Ziel: ohne VoiceOver liefert der
    // Baum nach dem Einschalten Label UND die Kennung von der Aufrufstelle.
    @Test func findetSwiftUIElementMitKennungImProzess() async throws {
        let szene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let fenster = UIWindow(windowScene: szene)
        fenster.rootViewController = UIHostingController(rootView: VStack(spacing: 40) {
            Text("Oben")
            PrimaryButton(title: "Satz 2 sichern") {}
                .testnotizElement("geraet.satz-sichern", typ: "PrimaryButton")
        }.padding())
        fenster.windowLevel = .alert
        fenster.isHidden = false
        defer { fenster.isHidden = true }
        try await Task.sleep(for: .milliseconds(500))

        let alle = await AXSchalter.eingeschaltet { AccessibilityBaum.sammeln(ab: fenster) }
        let knopfRahmen = try #require(alle.first { $0.kennung == "geraet.satz-sichern" }?.rahmen)
        let punkt = CGPoint(x: knopfRahmen.midX, y: knopfRahmen.midY)

        let gefunden = await AccessibilityBaum.element(an: punkt, szene: szene, ohne: UIWindow())
        #expect(gefunden?.kennung == "geraet.satz-sichern")
        #expect(gefunden?.label == "Satz 2 sichern")
        #expect(gefunden?.typ == "Button")
    }
}
#endif
```

Der letzte Test ist der Spike im echten Ziel: ein Fenster mit `PrimaryButton` und `.testnotizElement`, dann die Suche unter dem Knopfmittelpunkt.

- [ ] **Schritt 3: Test laufen lassen — er darf nicht kompilieren**

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/AccessibilityBaumTests 2>&1 | grep -E "✘|error:|Test run with"
```

Erwartet: `cannot find type 'AccessibilityKandidat' in scope`.

- [ ] **Schritt 4: Baum, Schalter, Register, Modifier**

Anlegen: `apps/ios-member/FitnessMember/Testnotiz/AccessibilityBaum.swift`

```swift
#if DEBUG
import UIKit

struct AccessibilityKandidat: Equatable, Sendable {
    var kennung: String?
    var label: String?
    var typ: String
    /// Bildschirmkoordinaten, wie accessibilityFrame sie liefert.
    var rahmen: CGRect
}

/// Findet das Element unter einem Finger ueber den Accessibility-Baum.
enum AccessibilityBaum {
    static let toleranz: CGFloat = 22

    /// Das kleinste Element, das den Punkt enthaelt; sonst das naechste
    /// innerhalb einer Fingerbreite. SwiftUI-Textknoten sind oft nur so gross
    /// wie der Text, ein Tipp daneben soll trotzdem treffen.
    static func treffer(_ kandidaten: [AccessibilityKandidat], punkt: CGPoint) -> AccessibilityKandidat? {
        if let kleinstes = kandidaten
            .filter({ $0.rahmen.contains(punkt) })
            .min(by: { flaeche($0.rahmen) < flaeche($1.rahmen) }) {
            return kleinstes
        }
        return kandidaten
            .map { ($0, abstand(punkt, $0.rahmen)) }
            .filter { $0.1 <= toleranz }
            .min(by: { $0.1 < $1.1 })?.0
    }

    static func flaeche(_ r: CGRect) -> CGFloat { r.width * r.height }

    static func abstand(_ p: CGPoint, _ r: CGRect) -> CGFloat {
        let dx = max(r.minX - p.x, 0, p.x - r.maxX)
        let dy = max(r.minY - p.y, 0, p.y - r.maxY)
        return (dx * dx + dy * dy).squareRoot()
    }

    /// SwiftUI-Knoten heissen alle "AccessibilityNode"; die Traits sagen mehr.
    static func typ(traits: UIAccessibilityTraits, klasse: String) -> String {
        if traits.contains(.button) { return "Button" }
        if traits.contains(.link) { return "Link" }
        if traits.contains(.adjustable) { return "Adjustable" }
        if traits.contains(.header) { return "Header" }
        if traits.contains(.image) { return "Image" }
        if traits.contains(.staticText) { return "Text" }
        return klasse
    }

    @MainActor
    static func sammeln(ab wurzel: NSObject) -> [AccessibilityKandidat] {
        var ergebnis: [AccessibilityKandidat] = []
        var gesehen = Set<ObjectIdentifier>()

        func gehen(_ objekt: NSObject, tiefe: Int) {
            // Ein UIButton ist ueber accessibilityElements UND subviews
            // erreichbar; ohne diese Menge stuende er doppelt drin.
            guard tiefe < 60, gesehen.insert(ObjectIdentifier(objekt)).inserted else { return }
            if let view = objekt as? UIView, view.isHidden || view.alpha < 0.01 { return }
            if objekt.accessibilityElementsHidden { return }

            if objekt.isAccessibilityElement {
                ergebnis.append(AccessibilityKandidat(
                    kennung: kennung(von: objekt),
                    label: objekt.accessibilityLabel,
                    typ: typ(traits: objekt.accessibilityTraits, klasse: String(describing: type(of: objekt))),
                    rahmen: objekt.accessibilityFrame
                ))
            }
            if let elemente = objekt.accessibilityElements {
                for case let kind as NSObject in elemente { gehen(kind, tiefe: tiefe + 1) }
            } else {
                let anzahl = objekt.accessibilityElementCount()
                if anzahl != NSNotFound, anzahl > 0 {
                    for i in 0..<anzahl {
                        if let kind = objekt.accessibilityElement(at: i) as? NSObject { gehen(kind, tiefe: tiefe + 1) }
                    }
                }
            }
            if let view = objekt as? UIView {
                for sub in view.subviews { gehen(sub, tiefe: tiefe + 1) }
            }
        }

        gehen(wurzel, tiefe: 0)
        return ergebnis
    }

    /// SwiftUI-Knoten tragen die Kennung, ohne UIAccessibilityIdentification
    /// zu erklaeren; sie antworten aber auf den Selektor.
    @MainActor
    private static func kennung(von objekt: NSObject) -> String? {
        let wert: String?
        if let identifizierbar = objekt as? UIAccessibilityIdentification {
            wert = identifizierbar.accessibilityIdentifier
        } else {
            let selektor = NSSelectorFromString("accessibilityIdentifier")
            wert = objekt.responds(to: selektor) ? objekt.perform(selektor)?.takeUnretainedValue() as? String : nil
        }
        guard let wert, !wert.isEmpty else { return nil }
        return wert
    }

    /// Das oberste App-Fenster, das den Punkt faengt, und darin der Teilbaum
    /// unter dem Finger. So gewinnt ein Sheet gegen den Screen darunter,
    /// obwohl beide im selben Fenster haengen.
    @MainActor
    static func element(an punkt: CGPoint, szene: UIWindowScene, ohne eigenes: UIWindow) async -> AccessibilityKandidat? {
        await AXSchalter.eingeschaltet {
            for fenster in szene.windows.reversed() where fenster !== eigenes && !fenster.isHidden {
                let lokal = fenster.convert(punkt, from: szene.screen.coordinateSpace)
                guard var knoten = fenster.hitTest(lokal, with: nil) else { continue }
                while true {
                    if let gefunden = treffer(sammeln(ab: knoten), punkt: punkt) { return gefunden }
                    guard let darueber = knoten.superview else { return nil }
                    knoten = darueber
                }
            }
            return nil
        }
    }
}

/// SwiftUI fuellt seinen Accessibility-Baum nur, wenn ein Assistenzdienst
/// laeuft -- im Prozess abgefragt liefert er sonst null Elemente. Dieser
/// Schalter ist private API aus libAccessibility, deshalb nur im Debug-Build.
///
/// Der Schalter bleibt fuer die Bundle-ID ueber Neustarts gespeichert (Spike
/// 2026-09-14). Er wird darum nur fuer die Dauer einer Suche gesetzt und
/// danach auf den vorigen Stand zurueckgestellt -- sonst liefe ein spaeter
/// installierter Release-Build mit derselben Bundle-ID dauerhaft mit
/// eingeschaltetem Baum.
@MainActor
enum AXSchalter {
    private typealias Lesen = @convention(c) () -> Int32
    private typealias Setzen = @convention(c) (Int32) -> Void

    private static func funktionen() -> (lesen: Lesen, setzen: Setzen)? {
        guard let bibliothek = dlopen("/usr/lib/libAccessibility.dylib", RTLD_NOW),
              let lesenZeiger = dlsym(bibliothek, "_AXSApplicationAccessibilityEnabled"),
              let setzenZeiger = dlsym(bibliothek, "_AXSApplicationAccessibilitySetEnabled")
        else { return nil }
        return (unsafeBitCast(lesenZeiger, to: Lesen.self), unsafeBitCast(setzenZeiger, to: Setzen.self))
    }

    /// nil, wenn die Bibliothek fehlt -- dann laeuft die Suche ohne Schalter.
    static var stand: Int32? {
        funktionen()?.lesen()
    }

    static func eingeschaltet<T>(_ arbeit: @MainActor () -> T) async -> T {
        guard let schalter = funktionen() else { return arbeit() }
        let lesen = schalter.lesen
        let setzen = schalter.setzen

        let vorher = lesen()
        if vorher == 0 {
            setzen(1)
            // Ein Runloop-Durchlauf, damit SwiftUI den Baum aufbaut.
            try? await Task.sleep(for: .milliseconds(150))
        }
        let ergebnis = arbeit()
        if vorher == 0 { setzen(0) }
        return ergebnis
    }
}
#endif
```

Anlegen: `apps/ios-member/FitnessMember/Testnotiz/TestnotizElement.swift`

```swift
import SwiftUI

#if DEBUG
/// Wo ein markiertes Element im Code steht.
struct ElementHerkunft: Equatable, Sendable {
    let typ: String
    let datei: String
    let zeile: Int
}

/// Kennung -> Herkunft. Rahmen braucht es nicht: die liefert der
/// Accessibility-Baum, samt Kennung (Spike 2026-09-14).
struct TestnotizElementRegister {
    private var herkuenfte: [String: ElementHerkunft] = [:]

    mutating func melden(kennung: String, herkunft: ElementHerkunft) {
        herkuenfte[kennung] = herkunft
    }

    func herkunft(kennung: String?) -> ElementHerkunft? {
        kennung.flatMap { herkuenfte[$0] }
    }

    func element(aus kandidat: AccessibilityKandidat) -> TestnotizEintrag.Element {
        let herkunft = herkunft(kennung: kandidat.kennung)
        return TestnotizEintrag.Element(
            source: .accessibility,
            identifier: kandidat.kennung,
            label: kandidat.label,
            type: herkunft?.typ ?? kandidat.typ,
            frame: TestnotizEintrag.Rechteck(kandidat.rahmen),
            file: herkunft?.datei,
            line: herkunft?.zeile
        )
    }
}

extension View {
    /// An der Aufrufstelle, nicht in der Komponente: die Kennung wandert vom
    /// Container auf den Knopf darin, und #filePath/#line zeigen so auf den
    /// Screen statt auf PrimaryButton.swift.
    func testnotizElement(_ kennung: String, typ: String, datei: String = #filePath, zeile: Int = #line) -> some View {
        accessibilityIdentifier(kennung)
            .onAppear {
                Testnotiz.shared.register.melden(
                    kennung: kennung,
                    herkunft: ElementHerkunft(typ: typ, datei: Quellpfad.relativ(datei), zeile: zeile)
                )
            }
    }
}
#else
extension View {
    /// Release: die Kennung bleibt -- sie ist fuer XCUITests ohnehin richtig.
    @inline(__always)
    func testnotizElement(_ kennung: String, typ: String) -> some View {
        accessibilityIdentifier(kennung)
    }
}
#endif
```

- [ ] **Schritt 5: Der Modus im Modul**

Ganz ersetzen: `apps/ios-member/FitnessMember/Testnotiz/Testnotiz.swift`

```swift
import SwiftUI

#if DEBUG
import Observation

/// Der eine Ort, an dem das Modul lebt. Ein Singleton, weil das Fenster
/// eines ist: eine Szene, ein Knopf darueber.
@MainActor
@Observable
final class Testnotiz {
    static let shared = Testnotiz()

    enum Modus: Equatable {
        case ruhe, menue, ausschnitt, element
    }

    /// Was zwischen Knopf-Tipp und Sichern entsteht. Das Foto kommt beim
    /// Tipp auf den Knopf: danach aendert sich die App nicht mehr, weil das
    /// Fenster ab dann alle Beruehrungen faengt.
    struct Entwurf {
        var zeitpunkt: Date
        var vollbild: UIImage
        var screen: TestnotizEintrag.Screen?
        var art: TestnotizEintrag.Art = .note
        var ausschnitt: UIImage?
        var ausschnittsrahmen: TestnotizEintrag.Ausschnittsrahmen?
        var element: TestnotizEintrag.Element?
    }

    var modus: Modus = .ruhe
    /// Bildschirmrahmen des Knopfs. Ausserhalb davon laesst das Fenster in
    /// Ruhe jede Beruehrung zur App durch.
    var knopfRahmen: CGRect = .zero
    var stapel = TestnotizScreenStapel()
    var register = TestnotizElementRegister()
    var entwurf: Entwurf?
    private(set) var eintragsanzahl = 0
    private(set) var letzterFehler: String?

    @ObservationIgnored private(set) var ablage: TestnotizAblage?
    @ObservationIgnored private(set) var fenster: TestnotizFenster?
    @ObservationIgnored private(set) weak var netz: NetzwerkMonitor?
    @ObservationIgnored private(set) weak var katalog: CatalogStore?
    @ObservationIgnored private(set) weak var session: SessionStore?

    /// Idempotent: RootView kann mehrfach in ein Fenster wandern
    /// (Session-Wechsel), das Overlay-Fenster darf es nur einmal geben.
    func installieren(in szene: UIWindowScene, netz: NetzwerkMonitor, katalog: CatalogStore, session: SessionStore) {
        self.netz = netz
        self.katalog = katalog
        self.session = session
        guard fenster == nil else { return }
        let neu = TestnotizFenster(windowScene: szene)
        let host = UIHostingController(rootView: TestnotizOberflaeche())
        host.view.backgroundColor = .clear
        neu.rootViewController = host
        neu.isHidden = false
        fenster = neu
    }

    func knopfGetippt() {
        letzterFehler = nil
        guard let fenster, let szene = fenster.windowScene else { return }
        let screen = stapel.aktueller.map {
            TestnotizEintrag.Screen(name: $0.name, file: $0.datei, stack: stapel.pfad, context: $0.kontext)
        }
        entwurf = Entwurf(
            zeitpunkt: Date(),
            vollbild: Bildschirmfoto.aufnehmen(szene: szene, ohne: fenster),
            screen: screen
        )
        modus = .menue
    }

    func zurRuhe() {
        entwurf = nil
        modus = .ruhe
    }

    func ausschnittGewaehlt(_ punkte: CGRect) {
        guard var neu = entwurf, let geschnitten = Ausschnitt.schneiden(neu.vollbild, punkte: punkte) else {
            zurRuhe()
            return
        }
        neu.art = .crop
        neu.ausschnitt = geschnitten.bild
        neu.ausschnittsrahmen = geschnitten.rahmen
        entwurf = neu
        // Bis zum Notiz-Blatt (Aufgabe 7) wird ohne Notiz gesichert.
        Task { await sichern(notiz: nil, audio: nil) }
    }

    func elementGewaehlt(_ punkt: CGPoint) async {
        guard var neu = entwurf, let fenster, let szene = fenster.windowScene else {
            zurRuhe()
            return
        }
        let kandidat = await AccessibilityBaum.element(an: punkt, szene: szene, ohne: fenster)
        neu.art = .element
        neu.element = kandidat.map { register.element(aus: $0) }
        entwurf = neu
        // Bis zum Notiz-Blatt (Aufgabe 7) wird ohne Notiz gesichert.
        await sichern(notiz: nil, audio: nil)
    }

    /// Das Blatt ist sofort zu; geschrieben wird danach. Wer testet, soll
    /// nicht auf PNG-Kodierung und Protokoll warten.
    func sichern(notiz: String?, audio: URL?) async {
        guard let entwurf else {
            zurRuhe()
            return
        }
        zurRuhe()
        let laufzeit = Laufzeitkontext.laufzeit(netz: netz, katalog: katalog, session: session)
        let protokoll = await TestnotizProtokoll.lesenImHintergrund(seit: 300, bis: entwurf.zeitpunkt)
        let eintrag = TestnotizEintrag(
            id: UUID(), index: 0, createdAt: entwurf.zeitpunkt, kind: entwurf.art,
            screen: entwurf.screen, screenshot: "", crop: nil, cropRect: entwurf.ausschnittsrahmen,
            element: entwurf.element, note: notiz, audio: nil, transcript: nil,
            runtime: laufzeit, log: protokoll
        )
        do {
            let ablage = try ablageHolen(jetzt: entwurf.zeitpunkt)
            _ = try await ablage.schreiben(
                eintrag,
                voll: entwurf.vollbild.pngData() ?? Data(),
                ausschnitt: entwurf.ausschnitt?.pngData(),
                audio: audio
            )
            eintragsanzahl = await ablage.anzahl
        } catch {
            letzterFehler = "Nicht gesichert: \(error.localizedDescription)"
        }
    }

    private func ablageHolen(jetzt: Date) throws -> TestnotizAblage {
        if let ablage { return ablage }
        let wurzel = URL.documentsDirectory.appendingPathComponent("Testnotizen")
        let neu = try TestnotizAblage(wurzel: wurzel, kopf: Laufzeitkontext.sitzungskopf(jetzt: jetzt, szene: fenster?.windowScene))
        ablage = neu
        return neu
    }
}

/// Meldet das erste Fenster, in das RootView gelangt. didMoveToWindow statt
/// updateUIView: beim ersten Update haengt die View noch in keinem Fenster,
/// und ein weiteres Update ist nicht zugesichert.
private final class InstallationsAnker: UIView {
    var beiFenster: ((UIWindowScene) -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if let szene = window?.windowScene { beiFenster?(szene) }
    }
}

private struct TestnotizInstallation: UIViewRepresentable {
    let netz: NetzwerkMonitor
    let katalog: CatalogStore
    let session: SessionStore

    func makeUIView(context: Context) -> InstallationsAnker {
        let anker = InstallationsAnker()
        anker.isUserInteractionEnabled = false
        anker.beiFenster = { [netz, katalog, session] szene in
            Testnotiz.shared.installieren(in: szene, netz: netz, katalog: katalog, session: session)
        }
        return anker
    }

    func updateUIView(_ uiView: InstallationsAnker, context: Context) {}
}

extension View {
    func testnotizInstallieren(netz: NetzwerkMonitor, katalog: CatalogStore, session: SessionStore) -> some View {
        background(TestnotizInstallation(netz: netz, katalog: katalog, session: session))
    }
}
#else
extension View {
    /// Release: kein Fenster, kein Knopf.
    @inline(__always)
    func testnotizInstallieren(netz: NetzwerkMonitor, katalog: CatalogStore, session: SessionStore) -> some View { self }
}
#endif
```

Ganz ersetzen: `apps/ios-member/FitnessMember/Testnotiz/TestnotizOberflaeche.swift`

```swift
#if DEBUG
import SwiftUI

/// Der Inhalt des Overlay-Fensters: je Modus genau eine Ansicht.
struct TestnotizOberflaeche: View {
    private let testnotiz = Testnotiz.shared

    var body: some View {
        ZStack {
            switch testnotiz.modus {
            case .ruhe:
                TestnotizKnopf()
            case .menue:
                TestnotizMenue()
            case .ausschnitt:
                AuswahlOverlay(art: .rechteck, beiRechteck: testnotiz.ausschnittGewaehlt, beiPunkt: { _ in }, beiAbbruch: testnotiz.zurRuhe)
            case .element:
                AuswahlOverlay(art: .punkt, beiRechteck: { _ in }, beiPunkt: { punkt in
                    Task { await testnotiz.elementGewaehlt(punkt) }
                }, beiAbbruch: testnotiz.zurRuhe)
            }
        }
    }
}
#endif
```

Ganz ersetzen: `apps/ios-member/FitnessMember/Testnotiz/TestnotizMenue.swift`

```swift
#if DEBUG
import SwiftUI

/// Ein eigenes Panel statt SwiftUI-Menu: dessen Eintraege laegen ausserhalb
/// des Knopfrahmens, und das durchlaessige Fenster liesse Tipps darauf zur
/// App durch. Im Modus .menue faengt das Fenster alles.
struct TestnotizMenue: View {
    private let testnotiz = Testnotiz.shared

    struct Eintrag: Identifiable {
        let id: String
        let titel: String
        let symbol: String
        let aktion: () -> Void
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            DesignSystem.Color.bg.opacity(0.5)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { testnotiz.zurRuhe() }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                Text(kopfzeile)
                    .font(DesignSystem.Typography.label)
                    .tracking(1.5)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .padding(DesignSystem.Spacing.s16)

                if let fehler = testnotiz.letzterFehler {
                    Text(fehler)
                        .font(DesignSystem.Typography.fliesstext)
                        .foregroundStyle(DesignSystem.Color.danger)
                        .padding(.horizontal, DesignSystem.Spacing.s16)
                        .padding(.bottom, DesignSystem.Spacing.s8)
                }

                ForEach(eintraege) { eintrag in
                    zeile(titel: eintrag.titel, symbol: eintrag.symbol, farbe: DesignSystem.Color.text, aktion: eintrag.aktion)
                }

                Rectangle().fill(DesignSystem.Color.line).frame(height: 1)
                zeile(titel: "Schließen", symbol: "xmark", farbe: DesignSystem.Color.textMuted, aktion: testnotiz.zurRuhe)
            }
            .background(DesignSystem.Color.surfaceRaised, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.haupt))
            .padding(DesignSystem.Spacing.s16)
        }
    }

    private var kopfzeile: String {
        (testnotiz.entwurf?.screen?.name ?? "Testnotiz").uppercased()
    }

    private var eintraege: [Eintrag] {
        [
            Eintrag(id: "ausschnitt", titel: "Ausschnitt", symbol: "crop") { testnotiz.modus = .ausschnitt },
            Eintrag(id: "element", titel: "Element", symbol: "hand.tap") { testnotiz.modus = .element },
        ]
    }

    private func zeile(titel: String, symbol: String, farbe: Color, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Label(titel, systemImage: symbol)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(farbe)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.horizontal, DesignSystem.Spacing.s16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
#endif
```

- [ ] **Schritt 6: Kennungen an den Aufrufstellen**

Punkt-Notation `screen.aktion`. Zwei Knöpfe dürfen dieselbe Kennung tragen, wenn sie nie gleichzeitig sichtbar sind (`geraet.abschliessen` in Eingabe und Abschluss); das Register behält die zuletzt erschienene Herkunft. Alle Pfade unter `apps/ios-member/FitnessMember/`:

In `apps/ios-member/FitnessMember/Screens/Geraet/GeraetView.swift` ersetzen:

```swift
            PrimaryButton(title: hauptaktion) {
                await modell.satzSichern(problemFlag: false, problemReason: nil)
            }
```

durch

```swift
            PrimaryButton(title: hauptaktion) {
                await modell.satzSichern(problemFlag: false, problemReason: nil)
            }
            .testnotizElement("geraet.satz-sichern", typ: "PrimaryButton")
```

In `apps/ios-member/FitnessMember/Screens/Geraet/GeraetView.swift` ersetzen:

```swift
            SecondaryButton(title: "Gerät abschließen", action: beiZurueckZumTraining)
```

durch

```swift
            SecondaryButton(title: "Gerät abschließen", action: beiZurueckZumTraining)
                .testnotizElement("geraet.abschliessen", typ: "SecondaryButton")
```

In `apps/ios-member/FitnessMember/Screens/Geraet/GeraetView.swift` ersetzen:

```swift
            PrimaryButton(title: "Gerät abschließen") { beiZurueckZumTraining() }
            SecondaryButton(title: "Weiterer Satz") { modell.weitererSatz() }
```

durch

```swift
            PrimaryButton(title: "Gerät abschließen") { beiZurueckZumTraining() }
                .testnotizElement("geraet.abschliessen", typ: "PrimaryButton")
            SecondaryButton(title: "Weiterer Satz") { modell.weitererSatz() }
                .testnotizElement("geraet.weiterer-satz", typ: "SecondaryButton")
```

In `apps/ios-member/FitnessMember/Screens/Geraet/GeraetView.swift` ersetzen:

```swift
        Button("Problem melden", action: beiProblem)
```

durch

```swift
        Button("Problem melden", action: beiProblem)
            .testnotizElement("geraet.problem", typ: "Button")
```

In `apps/ios-member/FitnessMember/Screens/Geraet/GeraetView.swift` ersetzen:

```swift
                Button("andere Übung", action: beiUebungWechseln)
```

durch

```swift
                Button("andere Übung", action: beiUebungWechseln)
                    .testnotizElement("geraet.uebung-wechseln", typ: "Button")
```

In `apps/ios-member/FitnessMember/Screens/Geraet/GeraetView.swift` ersetzen:

```swift
        Button("ändern") { modell.kalibrierungOeffnen() }
```

durch

```swift
        Button("ändern") { modell.kalibrierungOeffnen() }
            .testnotizElement("geraet.kalibrierung-aendern", typ: "Button")
```

In `apps/ios-member/FitnessMember/Screens/Training/TrainingRootView.swift` ersetzen:

```swift
            PrimaryButton(title: "Training beenden") { beenden() }
```

durch

```swift
            PrimaryButton(title: "Training beenden") { beenden() }
                .testnotizElement("training.beenden", typ: "PrimaryButton")
```

In `apps/ios-member/FitnessMember/Screens/Training/TrainingRootView.swift` ersetzen:

```swift
                : { pfad.append(.auswahl) }
        )
```

durch

```swift
                : { pfad.append(.auswahl) }
        )
        .testnotizElement("training.scanwege", typ: "ScanWege")
```

In `apps/ios-member/FitnessMember/Screens/Home/HomeRootView.swift` ersetzen:

```swift
            PrimaryButton(title: "Erstes Gerät") { scannerOffen = true }
```

durch

```swift
            PrimaryButton(title: "Erstes Gerät") { scannerOffen = true }
                .testnotizElement("home.erstes-geraet", typ: "PrimaryButton")
```

In `apps/ios-member/FitnessMember/Screens/Profil/ProfilRootView.swift` ersetzen:

```swift
                Task { await sessionStore.signOut() }
            }
```

durch

```swift
                Task { await sessionStore.signOut() }
            }
            .testnotizElement("profil.abmelden", typ: "Button")
```

In `apps/ios-member/FitnessMember/Screens/Profil/ProfilRootView.swift` ersetzen:

```swift
            }
            Toggle("Vibration beim Sichern", isOn: $vibrationBeimSichern)
```

durch

```swift
            }
            .testnotizElement("profil.satzziel", typ: "Picker")
            Toggle("Vibration beim Sichern", isOn: $vibrationBeimSichern)
```

- [ ] **Schritt 7: Tests laufen lassen**

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/AccessibilityBaumTests 2>&1 | grep -E "✘|error:|Test run with"
```

Erwartet: `6 tests in 1 suite passed`.

- [ ] **Schritt 8: Simulator**

Knopf → Element, dann tippen und in `sitzung.md` nachsehen:

- „Satz N sichern“: `` `geraet.satz-sichern` — „Satz 1 sichern, …“, PrimaryButton, `apps/ios-member/FitnessMember/Screens/Geraet/GeraetView.swift:<Zeile>` ``
- Die Übungszeile (unmarkiert): Label aus dem Baum, Typ `Text`, ohne Fundstelle.
- Im offenen „andere Übung“-Sheet eine Übung: das Element aus dem Sheet, nicht aus dem Screen darunter.
- Tab „Kurse“ in der Tab-Leiste: Label `Kurse`, Typ `Button`.
- Dass der Schalter danach wieder aus ist, belegt der Test `stelltDenSchalterZurueck`; sichtbar ist es nicht.

- [ ] **Schritt 9: Commit**

```bash
git add apps/ios-member
git commit -m "feat(testnotiz): Element ueber den Accessibility-Baum, 11 Kennungen" -m "Accessibility-Baum am Geraet geprueft: <Ergebnis aus Schritt 1>."
```

---

## Aufgabe 7: Notiz-Blatt und Sprachnotiz

**Dateien:**
- Anlegen: `Testnotiz/Sprachnotiz.swift`, `Testnotiz/NotizBlatt.swift`
- Ganz ersetzen: `Testnotiz/Testnotiz.swift`, `TestnotizOberflaeche.swift`, `TestnotizMenue.swift`

**Schnittstellen:**
- Nutzt: `Testnotiz.entwurf`, `Testnotiz.sichern(notiz:audio:)`, `TestnotizAblage.transkriptNachtragen`, `TestnotizMarkdown.elementZeile`, `PrimaryButton`, `SecondaryButton`
- Liefert:
  - `@MainActor @Observable final class Aufnahme` — `erlaubnis`, `laeuft`, `datei`, `fehler`, `umschalten() async`, `abgeben() -> URL?`, `verwerfen()`
  - `enum Transkription { static func transkribieren(_ audio: URL) async -> String? }`
  - `struct NotizBlatt: View`
  - `Testnotiz`: `Modus.notiz`, `nurNotiz()`; Ausschnitt und Element öffnen jetzt das Blatt; `sichern` trägt das Transkript nach

Kein Unit-Test: Mikrofon, Berechtigungen und Spracherkennung beweist nur das Gerät. Die reine Logik dahinter (Nachtragen, Markdown ohne Transkript) testet Aufgabe 2.


- [ ] **Schritt 1: Aufnahme und Transkription**

Anlegen: `apps/ios-member/FitnessMember/Testnotiz/Sprachnotiz.swift`

```swift
#if DEBUG
import AVFoundation
import Speech

/// Die Aufnahme ist der Beleg, das Transkript Komfort.
@MainActor
@Observable
final class Aufnahme {
    enum Erlaubnis { case offen, erteilt, verweigert }

    private(set) var erlaubnis: Erlaubnis = .offen
    private(set) var laeuft = false
    private(set) var datei: URL?
    private(set) var fehler: String?
    @ObservationIgnored private var rekorder: AVAudioRecorder?

    /// Erster Tipp fragt nach dem Mikrofon -- nicht beim App-Start.
    func umschalten() async {
        if laeuft {
            stoppen()
            return
        }
        if erlaubnis == .offen {
            let mikrofon = await AVAudioApplication.requestRecordPermission()
            // Ohne Spracherkennung wird trotzdem aufgenommen; nur das
            // Transkript fehlt dann.
            _ = await Self.spracherkennungErlauben()
            erlaubnis = mikrofon ? .erteilt : .verweigert
        }
        guard erlaubnis == .erteilt else { return }
        do {
            try starten()
        } catch {
            fehler = "Aufnahme ließ sich nicht starten: \(error.localizedDescription)"
        }
    }

    /// Uebergibt die Datei an die Ablage; danach gehoert sie nicht mehr hierher.
    func abgeben() -> URL? {
        stoppen()
        let ergebnis = datei
        datei = nil
        return ergebnis
    }

    func verwerfen() {
        stoppen()
        if let datei { try? FileManager.default.removeItem(at: datei) }
        datei = nil
    }

    private func starten() throws {
        if let datei { try? FileManager.default.removeItem(at: datei) }
        let sitzung = AVAudioSession.sharedInstance()
        try sitzung.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try sitzung.setActive(true)
        let ziel = FileManager.default.temporaryDirectory.appendingPathComponent("testnotiz-\(UUID().uuidString).m4a")
        let einstellungen: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        let neu = try AVAudioRecorder(url: ziel, settings: einstellungen)
        guard neu.record() else {
            throw CocoaError(.fileWriteUnknown)
        }
        rekorder = neu
        datei = ziel
        laeuft = true
        fehler = nil
    }

    private func stoppen() {
        guard laeuft else { return }
        rekorder?.stop()
        rekorder = nil
        laeuft = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// nonisolated: der Callback kommt auf einer beliebigen Queue. Aus dem
    /// MainActor heraus geschrieben erbte die Closure dessen Isolation, und
    /// Swift 6 bricht beim Aufruf ab.
    nonisolated private static func spracherkennungErlauben() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { fortsetzung in
            SFSpeechRecognizer.requestAuthorization { fortsetzung.resume(returning: $0) }
        }
    }
}

enum Transkription {
    /// Nur auf dem Geraet: die Aufnahme verlaesst das Telefon nicht. Ohne
    /// deutsches On-Device-Modell nil.
    static func transkribieren(_ audio: URL) async -> String? {
        guard let erkenner = SFSpeechRecognizer(locale: Locale(identifier: "de-DE")),
              erkenner.isAvailable, erkenner.supportsOnDeviceRecognition
        else { return nil }
        let anfrage = SFSpeechURLRecognitionRequest(url: audio)
        anfrage.requiresOnDeviceRecognition = true
        anfrage.shouldReportPartialResults = false
        return await withCheckedContinuation { fortsetzung in
            // Der Callback kommt mehrfach; die Continuation darf genau einmal laufen.
            var erledigt = false
            erkenner.recognitionTask(with: anfrage) { ergebnis, fehler in
                guard !erledigt else { return }
                if let ergebnis, ergebnis.isFinal {
                    erledigt = true
                    fortsetzung.resume(returning: ergebnis.bestTranscription.formattedString)
                } else if fehler != nil {
                    erledigt = true
                    fortsetzung.resume(returning: nil)
                }
            }
        }
    }
}
#endif
```

`spracherkennungErlauben` ist `nonisolated`, weil `SFSpeechRecognizer.requestAuthorization` seinen Callback auf einer fremden Queue ruft.

- [ ] **Schritt 2: Das Blatt**

Anlegen: `apps/ios-member/FitnessMember/Testnotiz/NotizBlatt.swift`

```swift
#if DEBUG
import SwiftUI

struct NotizBlatt: View {
    private let testnotiz = Testnotiz.shared
    @State private var text = ""
    @State private var aufnahme = Aufnahme()
    @State private var sichert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
                    kopf

                    TextField("Was stimmt hier nicht?", text: $text, axis: .vertical)
                        .lineLimit(3...8)
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(DesignSystem.Color.text)
                        .padding(DesignSystem.Spacing.s12)
                        .background(DesignSystem.Color.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.card))

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
                        SecondaryButton(title: aufnahmeTitel) { await aufnahme.umschalten() }
                        if aufnahme.erlaubnis == .verweigert {
                            hinweis("Mikrofon in den Einstellungen freigeben")
                        }
                        if let fehler = aufnahme.fehler {
                            hinweis(fehler)
                        }
                    }

                    PrimaryButton(title: "Sichern", isLoading: sichert) { await sichern() }
                }
                .padding(DesignSystem.Spacing.s16)
            }
            .background(DesignSystem.Color.bg)
            .navigationTitle(titel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Verwerfen") {
                        aufnahme.verwerfen()
                        testnotiz.zurRuhe()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var titel: String {
        switch testnotiz.entwurf?.art ?? .note {
        case .crop: "Ausschnitt"
        case .element: "Element"
        case .note: "Notiz"
        }
    }

    private var aufnahmeTitel: String {
        if aufnahme.laeuft { return "Aufnahme beenden" }
        return aufnahme.datei == nil ? "Sprachnotiz aufnehmen" : "Neu aufnehmen"
    }

    @ViewBuilder
    private var kopf: some View {
        if let entwurf = testnotiz.entwurf {
            if let bild = entwurf.ausschnitt {
                Image(uiImage: bild)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 96, alignment: .leading)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
            }
            if entwurf.art == .element {
                Text(entwurf.element.map(TestnotizMarkdown.elementZeile) ?? "Kein Element unter dem Finger")
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Color.text)
            }
            Text(entwurf.screen?.file ?? "Kein Screen gemeldet")
                .font(DesignSystem.Typography.fliesstext)
                .foregroundStyle(DesignSystem.Color.textMuted)
        }
    }

    private func hinweis(_ text: String) -> some View {
        Text(text)
            .font(DesignSystem.Typography.fliesstext)
            .foregroundStyle(DesignSystem.Color.textMuted)
    }

    private func sichern() async {
        sichert = true
        let audio = aufnahme.abgeben()
        let notiz = text.trimmingCharacters(in: .whitespacesAndNewlines)
        await testnotiz.sichern(notiz: notiz.isEmpty ? nil : notiz, audio: audio)
    }
}
#endif
```

- [ ] **Schritt 3: Das Modul öffnet das Blatt**

Ganz ersetzen: `apps/ios-member/FitnessMember/Testnotiz/Testnotiz.swift`

```swift
import SwiftUI

#if DEBUG
import Observation

/// Der eine Ort, an dem das Modul lebt. Ein Singleton, weil das Fenster
/// eines ist: eine Szene, ein Knopf darueber.
@MainActor
@Observable
final class Testnotiz {
    static let shared = Testnotiz()

    enum Modus: Equatable {
        case ruhe, menue, ausschnitt, element, notiz
    }

    /// Was zwischen Knopf-Tipp und Sichern entsteht. Das Foto kommt beim
    /// Tipp auf den Knopf: danach aendert sich die App nicht mehr, weil das
    /// Fenster ab dann alle Beruehrungen faengt.
    struct Entwurf {
        var zeitpunkt: Date
        var vollbild: UIImage
        var screen: TestnotizEintrag.Screen?
        var art: TestnotizEintrag.Art = .note
        var ausschnitt: UIImage?
        var ausschnittsrahmen: TestnotizEintrag.Ausschnittsrahmen?
        var element: TestnotizEintrag.Element?
    }

    var modus: Modus = .ruhe
    /// Bildschirmrahmen des Knopfs. Ausserhalb davon laesst das Fenster in
    /// Ruhe jede Beruehrung zur App durch.
    var knopfRahmen: CGRect = .zero
    var stapel = TestnotizScreenStapel()
    var register = TestnotizElementRegister()
    var entwurf: Entwurf?
    private(set) var eintragsanzahl = 0
    private(set) var letzterFehler: String?

    @ObservationIgnored private(set) var ablage: TestnotizAblage?
    @ObservationIgnored private(set) var fenster: TestnotizFenster?
    @ObservationIgnored private(set) weak var netz: NetzwerkMonitor?
    @ObservationIgnored private(set) weak var katalog: CatalogStore?
    @ObservationIgnored private(set) weak var session: SessionStore?

    /// Idempotent: RootView kann mehrfach in ein Fenster wandern
    /// (Session-Wechsel), das Overlay-Fenster darf es nur einmal geben.
    func installieren(in szene: UIWindowScene, netz: NetzwerkMonitor, katalog: CatalogStore, session: SessionStore) {
        self.netz = netz
        self.katalog = katalog
        self.session = session
        guard fenster == nil else { return }
        let neu = TestnotizFenster(windowScene: szene)
        let host = UIHostingController(rootView: TestnotizOberflaeche())
        host.view.backgroundColor = .clear
        neu.rootViewController = host
        neu.isHidden = false
        fenster = neu
    }

    func knopfGetippt() {
        letzterFehler = nil
        guard let fenster, let szene = fenster.windowScene else { return }
        let screen = stapel.aktueller.map {
            TestnotizEintrag.Screen(name: $0.name, file: $0.datei, stack: stapel.pfad, context: $0.kontext)
        }
        entwurf = Entwurf(
            zeitpunkt: Date(),
            vollbild: Bildschirmfoto.aufnehmen(szene: szene, ohne: fenster),
            screen: screen
        )
        modus = .menue
    }

    func zurRuhe() {
        entwurf = nil
        modus = .ruhe
    }

    func ausschnittGewaehlt(_ punkte: CGRect) {
        guard var neu = entwurf, let geschnitten = Ausschnitt.schneiden(neu.vollbild, punkte: punkte) else {
            zurRuhe()
            return
        }
        neu.art = .crop
        neu.ausschnitt = geschnitten.bild
        neu.ausschnittsrahmen = geschnitten.rahmen
        entwurf = neu
        modus = .notiz
    }

    func elementGewaehlt(_ punkt: CGPoint) async {
        guard var neu = entwurf, let fenster, let szene = fenster.windowScene else {
            zurRuhe()
            return
        }
        let kandidat = await AccessibilityBaum.element(an: punkt, szene: szene, ohne: fenster)
        neu.art = .element
        neu.element = kandidat.map { register.element(aus: $0) }
        entwurf = neu
        modus = .notiz
    }

    func nurNotiz() {
        entwurf?.art = .note
        modus = .notiz
    }

    /// Das Blatt ist sofort zu; geschrieben wird danach. Wer testet, soll
    /// nicht auf PNG-Kodierung und Protokoll warten.
    func sichern(notiz: String?, audio: URL?) async {
        guard let entwurf else {
            zurRuhe()
            return
        }
        zurRuhe()
        let laufzeit = Laufzeitkontext.laufzeit(netz: netz, katalog: katalog, session: session)
        let protokoll = await TestnotizProtokoll.lesenImHintergrund(seit: 300, bis: entwurf.zeitpunkt)
        let eintrag = TestnotizEintrag(
            id: UUID(), index: 0, createdAt: entwurf.zeitpunkt, kind: entwurf.art,
            screen: entwurf.screen, screenshot: "", crop: nil, cropRect: entwurf.ausschnittsrahmen,
            element: entwurf.element, note: notiz, audio: nil, transcript: nil,
            runtime: laufzeit, log: protokoll
        )
        do {
            let ablage = try ablageHolen(jetzt: entwurf.zeitpunkt)
            let gesichert = try await ablage.schreiben(
                eintrag,
                voll: entwurf.vollbild.pngData() ?? Data(),
                ausschnitt: entwurf.ausschnitt?.pngData(),
                audio: audio
            )
            eintragsanzahl = await ablage.anzahl
            if let name = gesichert.audio {
                let datei = ablage.ordner.appendingPathComponent(name)
                let index = gesichert.index
                Task {
                    guard let text = await Transkription.transkribieren(datei) else { return }
                    try? await ablage.transkriptNachtragen(index: index, text: text)
                }
            }
        } catch {
            letzterFehler = "Nicht gesichert: \(error.localizedDescription)"
        }
    }

    private func ablageHolen(jetzt: Date) throws -> TestnotizAblage {
        if let ablage { return ablage }
        let wurzel = URL.documentsDirectory.appendingPathComponent("Testnotizen")
        let neu = try TestnotizAblage(wurzel: wurzel, kopf: Laufzeitkontext.sitzungskopf(jetzt: jetzt, szene: fenster?.windowScene))
        ablage = neu
        return neu
    }
}

/// Meldet das erste Fenster, in das RootView gelangt. didMoveToWindow statt
/// updateUIView: beim ersten Update haengt die View noch in keinem Fenster,
/// und ein weiteres Update ist nicht zugesichert.
private final class InstallationsAnker: UIView {
    var beiFenster: ((UIWindowScene) -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if let szene = window?.windowScene { beiFenster?(szene) }
    }
}

private struct TestnotizInstallation: UIViewRepresentable {
    let netz: NetzwerkMonitor
    let katalog: CatalogStore
    let session: SessionStore

    func makeUIView(context: Context) -> InstallationsAnker {
        let anker = InstallationsAnker()
        anker.isUserInteractionEnabled = false
        anker.beiFenster = { [netz, katalog, session] szene in
            Testnotiz.shared.installieren(in: szene, netz: netz, katalog: katalog, session: session)
        }
        return anker
    }

    func updateUIView(_ uiView: InstallationsAnker, context: Context) {}
}

extension View {
    func testnotizInstallieren(netz: NetzwerkMonitor, katalog: CatalogStore, session: SessionStore) -> some View {
        background(TestnotizInstallation(netz: netz, katalog: katalog, session: session))
    }
}
#else
extension View {
    /// Release: kein Fenster, kein Knopf.
    @inline(__always)
    func testnotizInstallieren(netz: NetzwerkMonitor, katalog: CatalogStore, session: SessionStore) -> some View { self }
}
#endif
```

Ganz ersetzen: `apps/ios-member/FitnessMember/Testnotiz/TestnotizOberflaeche.swift`

```swift
#if DEBUG
import SwiftUI

/// Der Inhalt des Overlay-Fensters: je Modus genau eine Ansicht.
struct TestnotizOberflaeche: View {
    private let testnotiz = Testnotiz.shared

    private enum Blatt: String, Identifiable {
        case notiz
        var id: String { rawValue }
    }

    var body: some View {
        ZStack {
            switch testnotiz.modus {
            case .ruhe:
                TestnotizKnopf()
            case .menue:
                TestnotizMenue()
            case .ausschnitt:
                AuswahlOverlay(art: .rechteck, beiRechteck: testnotiz.ausschnittGewaehlt, beiPunkt: { _ in }, beiAbbruch: testnotiz.zurRuhe)
            case .element:
                AuswahlOverlay(art: .punkt, beiRechteck: { _ in }, beiPunkt: { punkt in
                    Task { await testnotiz.elementGewaehlt(punkt) }
                }, beiAbbruch: testnotiz.zurRuhe)
            case .notiz:
                Color.clear
            }
        }
        .sheet(item: blatt) { blatt in
            switch blatt {
            case .notiz: NotizBlatt()
            }
        }
    }

    private var blatt: Binding<Blatt?> {
        Binding(
            get: {
                switch testnotiz.modus {
                case .notiz: .notiz
                default: nil
                }
            },
            set: { neu in
                // Wischen schliesst das Blatt; das verwirft den Entwurf.
                if neu == nil, testnotiz.modus == .notiz {
                    testnotiz.zurRuhe()
                }
            }
        )
    }
}
#endif
```

Ganz ersetzen: `apps/ios-member/FitnessMember/Testnotiz/TestnotizMenue.swift`

```swift
#if DEBUG
import SwiftUI

/// Ein eigenes Panel statt SwiftUI-Menu: dessen Eintraege laegen ausserhalb
/// des Knopfrahmens, und das durchlaessige Fenster liesse Tipps darauf zur
/// App durch. Im Modus .menue faengt das Fenster alles.
struct TestnotizMenue: View {
    private let testnotiz = Testnotiz.shared

    struct Eintrag: Identifiable {
        let id: String
        let titel: String
        let symbol: String
        let aktion: () -> Void
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            DesignSystem.Color.bg.opacity(0.5)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { testnotiz.zurRuhe() }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                Text(kopfzeile)
                    .font(DesignSystem.Typography.label)
                    .tracking(1.5)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .padding(DesignSystem.Spacing.s16)

                if let fehler = testnotiz.letzterFehler {
                    Text(fehler)
                        .font(DesignSystem.Typography.fliesstext)
                        .foregroundStyle(DesignSystem.Color.danger)
                        .padding(.horizontal, DesignSystem.Spacing.s16)
                        .padding(.bottom, DesignSystem.Spacing.s8)
                }

                ForEach(eintraege) { eintrag in
                    zeile(titel: eintrag.titel, symbol: eintrag.symbol, farbe: DesignSystem.Color.text, aktion: eintrag.aktion)
                }

                Rectangle().fill(DesignSystem.Color.line).frame(height: 1)
                zeile(titel: "Schließen", symbol: "xmark", farbe: DesignSystem.Color.textMuted, aktion: testnotiz.zurRuhe)
            }
            .background(DesignSystem.Color.surfaceRaised, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.haupt))
            .padding(DesignSystem.Spacing.s16)
        }
    }

    private var kopfzeile: String {
        (testnotiz.entwurf?.screen?.name ?? "Testnotiz").uppercased()
    }

    private var eintraege: [Eintrag] {
        [
            Eintrag(id: "ausschnitt", titel: "Ausschnitt", symbol: "crop") { testnotiz.modus = .ausschnitt },
            Eintrag(id: "element", titel: "Element", symbol: "hand.tap") { testnotiz.modus = .element },
            Eintrag(id: "notiz", titel: "Nur Notiz", symbol: "square.and.pencil") { testnotiz.nurNotiz() },
        ]
    }

    private func zeile(titel: String, symbol: String, farbe: Color, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Label(titel, systemImage: symbol)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(farbe)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.horizontal, DesignSystem.Spacing.s16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
#endif
```

- [ ] **Schritt 4: Bauen und alle Tests**

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test  2>&1 | grep -E "✘|error:|Test run with"
```

Erwartet: alle Suiten grün.

- [ ] **Schritt 5: Gerät**

Am Gerät, nicht im Simulator:

- Ausschnitt ziehen → Blatt mit Vorschau und Dateipfad. Text tippen: die Tastatur erscheint, obwohl das Overlay nicht Key-Window ist.
- „Sprachnotiz aufnehmen“ beim ersten Mal: Mikrofon- und Spracherkennungs-Dialog. Sprechen, „Aufnahme beenden“, „Sichern“. Das Blatt schließt sofort.
- Nach einigen Sekunden steht in `sitzung.md` „**Gesprochen:** …“ mit dem Transkript. Ohne deutsches Diktat-Modell (Einstellungen → Allgemein → Tastatur → Diktat-Sprachen): „Transkript fehlt, Audio liegt bei“.
- Mikrofon verweigert: der Knopf bleibt, darunter „Mikrofon in den Einstellungen freigeben“.
- „Verwerfen“ und Wischen nach unten schreiben nichts.
- Nur Notiz: Blatt ohne Vorschau, Eintrag `note`.

- [ ] **Schritt 6: Commit**

```bash
git add apps/ios-member
git commit -m "feat(testnotiz): Notiz-Blatt, Sprachnotiz, On-Device-Transkript"
```

---

## Aufgabe 8: Sitzungen, Teilen, Eingang im Repo

**Dateien:**
- Anlegen: `Testnotiz/SitzungBlatt.swift`, `apps/ios-member/testnotizen/README.md`
- Ganz ersetzen: `Testnotiz/Testnotiz.swift`, `TestnotizOberflaeche.swift`, `TestnotizMenue.swift`
- Ändern: `.gitignore`

**Schnittstellen:**
- Nutzt: `TestnotizAblage.zipFuerTeilen()`, `Testnotiz.ablage`, `Testnotiz.eintragsanzahl`
- Liefert: `struct SitzungBlatt: View`; `Testnotiz`: `Modus.sitzung`, `neueSitzung()`


- [ ] **Schritt 1: Das Blatt**

Anlegen: `apps/ios-member/FitnessMember/Testnotiz/SitzungBlatt.swift`

```swift
#if DEBUG
import SwiftUI

struct SitzungBlatt: View {
    private let testnotiz = Testnotiz.shared
    @State private var zip: URL?
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
                Text(zusammenfassung)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Color.text)

                if let ordner = testnotiz.ablage?.ordner {
                    Text(ordner.lastPathComponent)
                        .font(DesignSystem.Typography.fliesstext)
                        .foregroundStyle(DesignSystem.Color.textMuted)

                    if let zip {
                        ShareLink(item: zip) {
                            Text("Sitzung teilen")
                                .font(.system(size: 19, weight: .heavy))
                                .foregroundStyle(DesignSystem.Color.onAccent)
                                .frame(maxWidth: .infinity)
                                .frame(height: 64)
                                .background(DesignSystem.Color.accent, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.haupt))
                        }
                    } else {
                        ProgressView().tint(DesignSystem.Color.accent)
                    }

                    SecondaryButton(title: "Ordner in Dateien öffnen") {
                        // shareddocuments:// oeffnet die Dateien-App am Ordner;
                        // das geht nur mit UIFileSharingEnabled (Debug-Plist).
                        if let url = URL(string: "shareddocuments://" + ordner.path) { openURL(url) }
                    }
                }

                SecondaryButton(title: "Neue Sitzung beginnen") {
                    testnotiz.neueSitzung()
                    zip = nil
                }

                Spacer()
            }
            .padding(DesignSystem.Spacing.s16)
            .background(DesignSystem.Color.bg)
            .navigationTitle("Sitzung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { testnotiz.zurRuhe() }
                }
            }
        }
        .presentationDetents([.medium])
        .task(id: testnotiz.eintragsanzahl) {
            zip = try? await testnotiz.ablage?.zipFuerTeilen()
        }
    }

    private var zusammenfassung: String {
        switch testnotiz.eintragsanzahl {
        case 0: "Noch kein Eintrag in dieser Sitzung."
        case 1: "1 Eintrag in dieser Sitzung."
        default: "\(testnotiz.eintragsanzahl) Einträge in dieser Sitzung."
        }
    }
}
#endif
```

- [ ] **Schritt 2: Endstand des Moduls**

Ganz ersetzen: `apps/ios-member/FitnessMember/Testnotiz/Testnotiz.swift`

```swift
import SwiftUI

#if DEBUG
import Observation

/// Der eine Ort, an dem das Modul lebt. Ein Singleton, weil das Fenster
/// eines ist: eine Szene, ein Knopf darueber.
@MainActor
@Observable
final class Testnotiz {
    static let shared = Testnotiz()

    enum Modus: Equatable {
        case ruhe, menue, ausschnitt, element, notiz, sitzung
    }

    /// Was zwischen Knopf-Tipp und Sichern entsteht. Das Foto kommt beim
    /// Tipp auf den Knopf: danach aendert sich die App nicht mehr, weil das
    /// Fenster ab dann alle Beruehrungen faengt.
    struct Entwurf {
        var zeitpunkt: Date
        var vollbild: UIImage
        var screen: TestnotizEintrag.Screen?
        var art: TestnotizEintrag.Art = .note
        var ausschnitt: UIImage?
        var ausschnittsrahmen: TestnotizEintrag.Ausschnittsrahmen?
        var element: TestnotizEintrag.Element?
    }

    var modus: Modus = .ruhe
    /// Bildschirmrahmen des Knopfs. Ausserhalb davon laesst das Fenster in
    /// Ruhe jede Beruehrung zur App durch.
    var knopfRahmen: CGRect = .zero
    var stapel = TestnotizScreenStapel()
    var register = TestnotizElementRegister()
    var entwurf: Entwurf?
    private(set) var eintragsanzahl = 0
    private(set) var letzterFehler: String?

    @ObservationIgnored private(set) var ablage: TestnotizAblage?
    @ObservationIgnored private(set) var fenster: TestnotizFenster?
    @ObservationIgnored private(set) weak var netz: NetzwerkMonitor?
    @ObservationIgnored private(set) weak var katalog: CatalogStore?
    @ObservationIgnored private(set) weak var session: SessionStore?

    /// Idempotent: RootView kann mehrfach in ein Fenster wandern
    /// (Session-Wechsel), das Overlay-Fenster darf es nur einmal geben.
    func installieren(in szene: UIWindowScene, netz: NetzwerkMonitor, katalog: CatalogStore, session: SessionStore) {
        self.netz = netz
        self.katalog = katalog
        self.session = session
        guard fenster == nil else { return }
        let neu = TestnotizFenster(windowScene: szene)
        let host = UIHostingController(rootView: TestnotizOberflaeche())
        host.view.backgroundColor = .clear
        neu.rootViewController = host
        neu.isHidden = false
        fenster = neu
    }

    func knopfGetippt() {
        letzterFehler = nil
        guard let fenster, let szene = fenster.windowScene else { return }
        let screen = stapel.aktueller.map {
            TestnotizEintrag.Screen(name: $0.name, file: $0.datei, stack: stapel.pfad, context: $0.kontext)
        }
        entwurf = Entwurf(
            zeitpunkt: Date(),
            vollbild: Bildschirmfoto.aufnehmen(szene: szene, ohne: fenster),
            screen: screen
        )
        modus = .menue
    }

    func zurRuhe() {
        entwurf = nil
        modus = .ruhe
    }

    func ausschnittGewaehlt(_ punkte: CGRect) {
        guard var neu = entwurf, let geschnitten = Ausschnitt.schneiden(neu.vollbild, punkte: punkte) else {
            zurRuhe()
            return
        }
        neu.art = .crop
        neu.ausschnitt = geschnitten.bild
        neu.ausschnittsrahmen = geschnitten.rahmen
        entwurf = neu
        modus = .notiz
    }

    func elementGewaehlt(_ punkt: CGPoint) async {
        guard var neu = entwurf, let fenster, let szene = fenster.windowScene else {
            zurRuhe()
            return
        }
        let kandidat = await AccessibilityBaum.element(an: punkt, szene: szene, ohne: fenster)
        neu.art = .element
        neu.element = kandidat.map { register.element(aus: $0) }
        entwurf = neu
        modus = .notiz
    }

    func nurNotiz() {
        entwurf?.art = .note
        modus = .notiz
    }

    func neueSitzung() {
        ablage = nil
        eintragsanzahl = 0
    }

    /// Das Blatt ist sofort zu; geschrieben wird danach. Wer testet, soll
    /// nicht auf PNG-Kodierung und Protokoll warten.
    func sichern(notiz: String?, audio: URL?) async {
        guard let entwurf else {
            zurRuhe()
            return
        }
        zurRuhe()
        let laufzeit = Laufzeitkontext.laufzeit(netz: netz, katalog: katalog, session: session)
        let protokoll = await TestnotizProtokoll.lesenImHintergrund(seit: 300, bis: entwurf.zeitpunkt)
        let eintrag = TestnotizEintrag(
            id: UUID(), index: 0, createdAt: entwurf.zeitpunkt, kind: entwurf.art,
            screen: entwurf.screen, screenshot: "", crop: nil, cropRect: entwurf.ausschnittsrahmen,
            element: entwurf.element, note: notiz, audio: nil, transcript: nil,
            runtime: laufzeit, log: protokoll
        )
        do {
            let ablage = try ablageHolen(jetzt: entwurf.zeitpunkt)
            let gesichert = try await ablage.schreiben(
                eintrag,
                voll: entwurf.vollbild.pngData() ?? Data(),
                ausschnitt: entwurf.ausschnitt?.pngData(),
                audio: audio
            )
            eintragsanzahl = await ablage.anzahl
            if let name = gesichert.audio {
                let datei = ablage.ordner.appendingPathComponent(name)
                let index = gesichert.index
                Task {
                    guard let text = await Transkription.transkribieren(datei) else { return }
                    try? await ablage.transkriptNachtragen(index: index, text: text)
                }
            }
        } catch {
            letzterFehler = "Nicht gesichert: \(error.localizedDescription)"
        }
    }

    private func ablageHolen(jetzt: Date) throws -> TestnotizAblage {
        if let ablage { return ablage }
        let wurzel = URL.documentsDirectory.appendingPathComponent("Testnotizen")
        let neu = try TestnotizAblage(wurzel: wurzel, kopf: Laufzeitkontext.sitzungskopf(jetzt: jetzt, szene: fenster?.windowScene))
        ablage = neu
        return neu
    }
}

/// Meldet das erste Fenster, in das RootView gelangt. didMoveToWindow statt
/// updateUIView: beim ersten Update haengt die View noch in keinem Fenster,
/// und ein weiteres Update ist nicht zugesichert.
private final class InstallationsAnker: UIView {
    var beiFenster: ((UIWindowScene) -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if let szene = window?.windowScene { beiFenster?(szene) }
    }
}

private struct TestnotizInstallation: UIViewRepresentable {
    let netz: NetzwerkMonitor
    let katalog: CatalogStore
    let session: SessionStore

    func makeUIView(context: Context) -> InstallationsAnker {
        let anker = InstallationsAnker()
        anker.isUserInteractionEnabled = false
        anker.beiFenster = { [netz, katalog, session] szene in
            Testnotiz.shared.installieren(in: szene, netz: netz, katalog: katalog, session: session)
        }
        return anker
    }

    func updateUIView(_ uiView: InstallationsAnker, context: Context) {}
}

extension View {
    func testnotizInstallieren(netz: NetzwerkMonitor, katalog: CatalogStore, session: SessionStore) -> some View {
        background(TestnotizInstallation(netz: netz, katalog: katalog, session: session))
    }
}
#else
extension View {
    /// Release: kein Fenster, kein Knopf.
    @inline(__always)
    func testnotizInstallieren(netz: NetzwerkMonitor, katalog: CatalogStore, session: SessionStore) -> some View { self }
}
#endif
```

Ganz ersetzen: `apps/ios-member/FitnessMember/Testnotiz/TestnotizOberflaeche.swift`

```swift
#if DEBUG
import SwiftUI

/// Der Inhalt des Overlay-Fensters: je Modus genau eine Ansicht.
struct TestnotizOberflaeche: View {
    private let testnotiz = Testnotiz.shared

    private enum Blatt: String, Identifiable {
        case notiz, sitzung
        var id: String { rawValue }
    }

    var body: some View {
        ZStack {
            switch testnotiz.modus {
            case .ruhe:
                TestnotizKnopf()
            case .menue:
                TestnotizMenue()
            case .ausschnitt:
                AuswahlOverlay(art: .rechteck, beiRechteck: testnotiz.ausschnittGewaehlt, beiPunkt: { _ in }, beiAbbruch: testnotiz.zurRuhe)
            case .element:
                AuswahlOverlay(art: .punkt, beiRechteck: { _ in }, beiPunkt: { punkt in
                    Task { await testnotiz.elementGewaehlt(punkt) }
                }, beiAbbruch: testnotiz.zurRuhe)
            case .notiz, .sitzung:
                Color.clear
            }
        }
        .sheet(item: blatt) { blatt in
            switch blatt {
            case .notiz: NotizBlatt()
            case .sitzung: SitzungBlatt()
            }
        }
    }

    private var blatt: Binding<Blatt?> {
        Binding(
            get: {
                switch testnotiz.modus {
                case .notiz: .notiz
                case .sitzung: .sitzung
                default: nil
                }
            },
            set: { neu in
                // Wischen schliesst das Blatt; das verwirft den Entwurf.
                if neu == nil, testnotiz.modus == .notiz || testnotiz.modus == .sitzung {
                    testnotiz.zurRuhe()
                }
            }
        )
    }
}
#endif
```

Ganz ersetzen: `apps/ios-member/FitnessMember/Testnotiz/TestnotizMenue.swift`

```swift
#if DEBUG
import SwiftUI

/// Ein eigenes Panel statt SwiftUI-Menu: dessen Eintraege laegen ausserhalb
/// des Knopfrahmens, und das durchlaessige Fenster liesse Tipps darauf zur
/// App durch. Im Modus .menue faengt das Fenster alles.
struct TestnotizMenue: View {
    private let testnotiz = Testnotiz.shared

    struct Eintrag: Identifiable {
        let id: String
        let titel: String
        let symbol: String
        let aktion: () -> Void
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            DesignSystem.Color.bg.opacity(0.5)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { testnotiz.zurRuhe() }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                Text(kopfzeile)
                    .font(DesignSystem.Typography.label)
                    .tracking(1.5)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .padding(DesignSystem.Spacing.s16)

                if let fehler = testnotiz.letzterFehler {
                    Text(fehler)
                        .font(DesignSystem.Typography.fliesstext)
                        .foregroundStyle(DesignSystem.Color.danger)
                        .padding(.horizontal, DesignSystem.Spacing.s16)
                        .padding(.bottom, DesignSystem.Spacing.s8)
                }

                ForEach(eintraege) { eintrag in
                    zeile(titel: eintrag.titel, symbol: eintrag.symbol, farbe: DesignSystem.Color.text, aktion: eintrag.aktion)
                }

                Rectangle().fill(DesignSystem.Color.line).frame(height: 1)
                zeile(titel: "Schließen", symbol: "xmark", farbe: DesignSystem.Color.textMuted, aktion: testnotiz.zurRuhe)
            }
            .background(DesignSystem.Color.surfaceRaised, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.haupt))
            .padding(DesignSystem.Spacing.s16)
        }
    }

    private var kopfzeile: String {
        (testnotiz.entwurf?.screen?.name ?? "Testnotiz").uppercased()
    }

    private var eintraege: [Eintrag] {
        [
            Eintrag(id: "ausschnitt", titel: "Ausschnitt", symbol: "crop") { testnotiz.modus = .ausschnitt },
            Eintrag(id: "element", titel: "Element", symbol: "hand.tap") { testnotiz.modus = .element },
            Eintrag(id: "notiz", titel: "Nur Notiz", symbol: "square.and.pencil") { testnotiz.nurNotiz() },
            Eintrag(id: "sitzung", titel: "Sitzung (\(testnotiz.eintragsanzahl))", symbol: "folder") { testnotiz.modus = .sitzung },
        ]
    }

    private func zeile(titel: String, symbol: String, farbe: Color, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Label(titel, systemImage: symbol)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(farbe)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.horizontal, DesignSystem.Spacing.s16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
#endif
```

- [ ] **Schritt 3: Eingang im Repo**

In `.gitignore` ersetzen:

```
# Isolierte Arbeitsbereiche (superpowers:using-git-worktrees)
.worktrees/
```

durch

```
# Isolierte Arbeitsbereiche (superpowers:using-git-worktrees)
.worktrees/

# Testsitzungen vom Geraet (Testnotiz-Modul): Screenshots zeigen
# Trainingsdaten, deshalb nur lokal. Die README erklaert den Weg hierher.
apps/ios-member/testnotizen/*
!apps/ios-member/testnotizen/README.md
```

Anlegen: `apps/ios-member/testnotizen/README.md`

````markdown
# Testnotizen — Eingang für Claude Code

Hier landen Testsitzungen aus dem Debug-Build der Member-App. Jede Sitzung ist
ein Ordner `yyyy-MM-dd-HHmm` mit `sitzung.md`, `sitzung.json`, Screenshots und
Sprachnotizen. Das Format beschreibt
`docs/superpowers/specs/2026-09-14-testnotiz-format.md`.

**Vom Telefon hierher:** In der App Testnotiz-Knopf → Sitzung → „Sitzung
teilen“ → AirDrop an den Mac, die Zip hier entpacken. Oder mit dem Kabel:
Finder → iPhone → Dateien → FitnessMember → `Testnotizen`, den Ordner hierher
ziehen.

**Der Auftrag an Claude Code**, mit dem Ordnernamen der Sitzung:

```
Lies apps/ios-member/testnotizen/2026-09-13-1412/sitzung.md und arbeite die Einträge ab.
```

Alles in diesem Ordner außer dieser Datei ist gitignoriert: Die Screenshots
zeigen Trainingsdaten echter Konten und gehören nicht ins Repository.
````

- [ ] **Schritt 4: Bauen, alle Tests, Release-Beweis**

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test  2>&1 | grep -E "✘|error:|Test run with"
```

Erwartet: `Test run with 502 tests in 66 suites passed` (Stand 14. September; mit neuen Tests aus anderen Branches entsprechend mehr).

```bash
cd apps/ios-member
xcodebuild -scheme FitnessMember -configuration Release -destination "generic/platform=iOS" \
  -derivedDataPath /tmp/dd-relproof CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "error:|BUILD"
APP=/tmp/dd-relproof/Build/Products/Release-iphoneos/FitnessMember.app
# Der Build-Pfad darf das Suchwort nicht enthalten, sonst liefern #file-Strings
# der Abhaengigkeiten Falschtreffer.
# Archivieren strippt die Debug-Symbole; unverstrippt stehen Objektdateinamen
# wie TestnotizScreenModifier.o in der Symboltabelle. Deshalb die gestrippte Kopie.
xcrun strip -S -x -o /tmp/FitnessMember-stripped "$APP/FitnessMember"
grep -a -i -c testnotiz /tmp/FitnessMember-stripped                                   # erwartet 0
grep -r -a -i -l testnotiz "$APP" | grep -v '/FitnessMember$' | wc -l                  # erwartet 0
grep -a -c _AXSApplicationAccessibility /tmp/FitnessMember-stripped                   # erwartet 0
plutil -p "$APP/Info.plist" | grep -c -E 'NSMicrophoneUsageDescription|NSSpeechRecognitionUsageDescription|UIFileSharingEnabled|LSSupportsOpeningDocumentsInPlace'   # erwartet 0
plutil -p "$APP/Info.plist" | grep -c SUPABASE_URL                                     # erwartet 1 (Gegenprobe: Additions-Plist greift)
```

Gegenprobe am Debug-Build, sonst beweisen die Nullen nichts. Seit Xcode 16 liegt der Debug-Code in `FitnessMember.debug.dylib`, die Hauptdatei ist nur ein Starter:

```bash
cd apps/ios-member
xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" -derivedDataPath /tmp/dd-relproof build 2>&1 | grep -E "error:|BUILD"
D=/tmp/dd-relproof/Build/Products/Debug-iphonesimulator/FitnessMember.app
grep -a -i -c testnotiz "$D/FitnessMember.debug.dylib"                                # erwartet > 0
plutil -p "$D/Info.plist" | grep -c -E 'NSMicrophoneUsageDescription|NSSpeechRecognitionUsageDescription|UIFileSharingEnabled|LSSupportsOpeningDocumentsInPlace'   # erwartet 4
```

- [ ] **Schritt 5: Der eigentliche Abnahmetest**

Am Gerät zwei Sitzungen mit je zwei, drei Funden aus dem echten Training anlegen. Eine über „Sitzung teilen“ per AirDrop an den Mac, nach `apps/ios-member/testnotizen/` entpacken, dann in Claude Code:

```
Lies apps/ios-member/testnotizen/<ordner>/sitzung.md und arbeite die Einträge ab.
```

**Kommt eine brauchbare Änderung heraus, ohne dass man den Fund noch einmal erklären muss?** Das Ergebnis als Satz in die Commit-Nachricht. `git status` zeigt vom Eingang nur die README.

- [ ] **Schritt 6: Commit**

```bash
git add .gitignore apps/ios-member
git commit -m "feat(testnotiz): Sitzungen teilen, Eingang im Repo" -m "Abnahme: <Satz aus Schritt 5>"
```

---

## Manuelle Abnahme

Was Fenster, Foto, Berührung oder Mikrofon anfasst, beweist kein Test. Am Gerät:

- [ ] Debug: Knopf über Tab-Leiste, Sheet und Alert; ziehbar; die App ist überall bedienbar, auch direkt neben dem Knopf; Statusleiste unverändert.
- [ ] Release (Aufgabe 8, Schritt 4): alle Nullen, `SUPABASE_URL` 1; Debug-Gegenprobe positiv.
- [ ] Screen-Name auf allen Tabs, nach Push und Zurück, mit offenem und geschlossenem Sheet, in jedem Schritt des Dreischritts.
- [ ] Ausschnitt: Vollbild ohne Knopf und Menü; Ausschnitt pixelgenau; ein offener Alert steht im Vollbild.
- [ ] Element: markierter Knopf mit Kennung und Fundstelle; unmarkierter Text mit Label; im Sheet das Sheet-Element; danach Accessibility-Schalter wieder aus.
- [ ] Sprachnotiz: Transkript auf Deutsch; ohne Modell der Ersatzsatz; verweigert der Hinweis.
- [ ] Protokoll: nach einem Tag-Scan stehen `tag`-Zeilen im Eintrag.
- [ ] Teilen → AirDrop → Eingang → Claude Code: eine Änderung ohne Rückfrage.
- [ ] Keine Personendaten: `grep -ri "<eigene Adresse>" <ordner>` findet nichts; der Anzeigename steht in `sitzung.json` nur in Einträgen, deren Element (`element.label`) oder Notiz ihn zeigt.

---

## Selbstprüfung

- **Spec-Deckung.** Jedes Feld der Spec hat einen Erzeuger: Kopf `Laufzeitkontext.sitzungskopf` (4), `screen` Stapel (3), `screenshot`/`crop`/`cropRect` (5), `element` (6), `note`/`audio`/`transcript` (7), `runtime`/`log` (4), Dateinamen und `index` Ablage (2). Die Markdown-Regeln der Spec-Tabelle haben je einen Test (2).
- **Die Annahmen des Entwurfs** sind geprüft und stehen oben mit Ergebnis. Offen bleibt nur der Accessibility-Schalter auf echter Hardware; Aufgabe 6, Schritt 1 prüft ihn zuerst und hält bei Rot an.
- **Typkonsistenz.** `Testnotiz.swift`, `TestnotizOberflaeche.swift` und `TestnotizMenue.swift` wachsen über fünf Aufgaben; jede Fassung ist in ihrer Aufgabe vollständig abgedruckt und in dieser Reihenfolge gebaut worden.
- **Kein Byte im Release** hat einen maschinellen Beweis mit Gegenprobe (1, 8).
- **Keine Personendaten** hat einen Test gegen echtes OSLog (4) und einen Abnahmepunkt.
- **Abweichungen vom Entwurf, absichtlich:** kein SwiftUI-`Menu`; Foto beim Knopf-Tipp statt beim Menü-Tipp; Accessibility-Baum als Hauptquelle, Register ohne Rahmen; keine Änderung an den Design-System-Komponenten; `#filePath` statt `#fileID`; Spec vorab statt Aufgabe 9; Laufzeit und Protokoll vor die Modi gezogen, damit Aufgabe 5 schon vollständige Einträge schreibt; der Dreischritt meldet Schritte statt `ErstkontaktFlow`; keine Kennungen für die Wochen-Pfeile in Kurse, die es seit dem Kalender nicht mehr gibt.
