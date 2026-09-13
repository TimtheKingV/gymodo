# Testnotizen in der Member-App — Umsetzungsplan

> **Für agentische Ausführung:** ERFORDERLICHE UNTER-SKILL: `superpowers:subagent-driven-development` (empfohlen) oder `superpowers:executing-plans`, Aufgabe für Aufgabe. Die Schritte tragen Checkboxen (`- [ ]`) zum Mitführen.

**Ziel:** Wer die App am Gerät testet, hält einen Fund mit zwei Tipps fest — Ausschnitt markieren, Element antippen, Notiz sprechen — und bekommt am Ende der Sitzung einen Ordner, den Claude Code ohne Nachfragen lesen kann: Screenshot, Ausschnitt, Screen samt Quelldatei, Element samt Kennung, Transkript, Protokoll der letzten Minuten.

**Architektur:** Ein Debug-Modul `Testnotiz` im App-Ziel, jede Datei unter `#if DEBUG`. Ein eigenes `UIWindow` über der App trägt den schwebenden Knopf und die Auswahlmodi; das App-Fenster wird nicht angefasst. Der aktuelle Screen kommt aus einem Modifier, den jede Screen-Wurzel einmal trägt und der über `#fileID` die Quelldatei mitschreibt. Elemente kommen aus einem Register, das ein zweiter Modifier füllt; ein Gang durch den Accessibility-Baum ist der Rückfallweg für alles Unmarkierte. Es gibt keinen Server: die Ablage ist ein Ordner unter `Documents`, der Weg zu Claude Code ist die Files-App oder das Teilen-Blatt. Das Dateiformat (§2) ist der Vertrag, den die spätere Android-App genauso erfüllt.

**Tech-Stack:** Swift 6 (Strict Concurrency) / SwiftUI / UIKit für Fenster und Bildschirmfoto / AVFoundation und Speech für die Sprachnotiz / OSLog für das Protokoll / Swift Testing / XcodeGen (`apps/ios-member`).

**Spec:** keine eigene. §1 dieses Plans ist der Entwurf, §2 der Format-Vertrag; Aufgabe 9 hebt §2 in eine eigene Spec-Datei, sobald die Tests aus Aufgabe 2 ihn festnageln.

**Entstehung:** Dieser Plan wurde ohne Mac geschrieben. Kein Schritt darin wurde gebaut. Aufgabe 1 ist deshalb bewusst klein und beweist zuerst, dass Fenster, Knopf und `#if DEBUG` im echten Xcode-Build tun, was der Plan behauptet. Wo eine Annahme über SwiftUI-Interna steckt, steht sie als **Annahme** markiert, mit dem Rückfallweg daneben.

---

## Globale Rahmenbedingungen

- **Kein Byte davon im Release.** Jede Datei des Moduls beginnt mit `#if DEBUG` und endet mit `#endif`. Die Aufrufstellen in der App (`FitnessMemberApp`, die Screen-Modifier) stehen ebenfalls unter `#if DEBUG` oder rufen leere Release-Attrappen. Prüfbar: `strings` über das Release-Binary findet weder `Testnotiz` noch `NSSpeechRecognitionUsageDescription`.
- **Keine Personendaten im Ordner.** Blueprint, Architekturprinzip 6: *„Gesundheits- und Trainingsdaten nicht in Logs oder Analytics kopieren."* Der Screenshot zeigt, was auf dem Bildschirm steht — das ist der Zweck. Der Kontext daneben trägt aber **keine** E-Mail, keinen Access-Token, keinen Anzeigenamen; `angemeldet: true` und die `studioId` genügen. Das Protokoll übernimmt nur Zeilen mit `privacy: .public`, die OSLog ohnehin nicht schwärzt.
- **Kein Netz.** Das Modul sendet nichts, nirgendwohin. Wer später einen Upload will, schreibt einen eigenen Plan.
- **Kommentare in Swift ohne Umlaute** (ASCII), wie im gesamten iOS-Ziel. Nutzertexte tragen selbstverständlich Umlaute.
- **Kommentare begründen, sie beschreiben nicht.**
- **Design-Tokens aus `DesignSystem.swift`**, nie als Literal. Der Knopf und die Blätter sind Teil der App, auch wenn sie nur der Entwickler sieht: `surfaceRaised` als Fläche, `accent` für genau eine Hauptaktion je Blatt, Trefferflächen nie unter 44 pt.
- **Swift 6 Strict Concurrency.** Fenster, Knopf, Register, Stapel: `@MainActor`. Die Ablage schreibt Dateien und ist ein `actor`. Was über die Grenze geht, ist `Sendable` — die Einträge sind reine Werte.
- **Swift-Tests laufen mit Swift Testing** (`import Testing`, `@Test`, `#expect`), als `struct`-Suite. Getestet wird die reine Logik: Stapel, Register, Ausschnittsrechnung, JSON-Form, Markdown, Protokollfilter. Fenster, Foto und Sprache werden manuell abgenommen (letzter Abschnitt).
- **Neue Swift-Dateien brauchen keinen pbxproj-Eingriff:** `project.yml` zieht Verzeichnisse; nach dem Anlegen `xcodegen generate` laufen lassen.
- **Deutsche Bezeichner** wie im Bestand (`GeraetModel`, `KurseStore`). Die JSON-Schlüssel im Ordner sind Englisch, wie die DTOs der API — der Ordner ist ein Vertrag zwischen Plattformen, kein Oberflächentext.

---

## 1. Entwurf

### 1.1 Der Knopf

Ein zweites `UIWindow` in derselben `UIWindowScene`, `windowLevel = .alert + 1`, damit es auch über Sheets und Systemdialogen liegt. Sein `hitTest` gibt `nil` zurück, solange kein Modus aktiv ist und der Treffer nicht der Knopf selbst ist — so laufen alle Tipps ungestört an die App darunter. Der Knopf ist ein 44-pt-Kreis am rechten Rand, per Drag vertikal verschiebbar, rastet nach dem Loslassen wieder an den Rand. Ein Tipp öffnet ein Menü mit vier Einträgen:

| Eintrag | Modus | Ergebnis |
| --- | --- | --- |
| Ausschnitt | Das Fenster wird vollflächig, ein Rechteck wird gezogen | Eintrag mit Vollbild, Ausschnitt und Rechteck |
| Element | Vollflächig, ein Tipp | Eintrag mit Vollbild, Element (Kennung, Label, Typ, Rahmen, Quelldatei) |
| Nur Notiz | Blatt mit Textfeld und Aufnahmeknopf | Eintrag mit Vollbild, Text, Audio, Transkript |
| Sitzung… | Blatt | Neue Sitzung, Sitzung teilen, Anzahl der Einträge |

Nach „Ausschnitt" und „Element" öffnet sich dasselbe Notiz-Blatt wie bei „Nur Notiz", mit dem Ausschnitt oder Element als Kopf. Jeder Eintrag bekommt also den Screenshot **vor** der Auswahl (der Zustand, den man meinte) und danach die Notiz. Das Foto entsteht im Moment des Menü-Tipps, nicht erst nach dem Ziehen — sonst hätte man das Menü im Bild.

### 1.2 Was ein Eintrag enthält

| Feld | Woher |
| --- | --- |
| `id`, `createdAt` | UUID, ISO-8601 |
| `screen` | Der oberste Eintrag des Screen-Stapels (§1.3): Name, `file`, `context` |
| `screenshot`, `crop`, `cropRect` | §1.4 Bildschirmfoto, Ausschnitt in Punkten und Pixeln |
| `element` | §1.5 aus Register oder Accessibility-Baum |
| `note`, `audio`, `transcript` | §1.6 |
| `runtime` | Gerät, iOS, Build, Bildschirmgröße, online, offene Schreibvorgänge, `signedIn`, `studioId` |
| `log` | Die letzten fünf Minuten aus `OSLogStore`, Subsystem `de.gymtaro.member` |

### 1.3 Screen-Erkennung

SwiftUI kennt keine „aktuelle Seite". Der Plan erfindet sie auch nicht aus dem View-Baum (Typnamen wie `_UIHostingView<ModifiedContent<…>>` sind lesbar, aber nicht verlässlich), sondern lässt jede Screen-Wurzel sich einmal melden:

```swift
struct GeraetView: View {
    var body: some View {
        ScrollView { … }
            .testnotizScreen(kontext: ["machineId": modell.machineId, "exerciseId": modell.exerciseId])
    }
}
```

`testnotizScreen(_ name: String = #fileID, kontext: [String: String] = [:])` — `#fileID` als Vorgabewert wird **an der Aufrufstelle** aufgelöst und liefert `FitnessMember/Screens/Geraet/GeraetView.swift`. Der Name ist damit gratis, stimmt immer und ist genau das, was Claude Code öffnen soll. `onAppear` legt den Eintrag auf einen Stapel, `onDisappear` nimmt ihn wieder herunter, der oberste ist der aktuelle. Das deckt Tab-Wechsel (Erscheinen/Verschwinden), Pushes im `NavigationStack` (der Überdeckte verschwindet) und Sheets (beide bleiben, das Sheet ist oben) ab.

**Annahme:** `onDisappear` feuert für die überdeckte Ansicht eines `NavigationStack`-Pushs. Das gilt seit iOS 16; falls es auf einem Screen nicht greift, zeigt der Stapel den älteren Eintrag — sichtbar im Kopf des Notiz-Blatts, und die Abnahme (unten) prüft es an den vier Tabs und am Push zum Gerät.

### 1.4 Bildschirmfoto und Ausschnitt

`UIGraphicsImageRenderer` über die Fenstergröße mit der Bildschirm-Scale; jedes Fenster der Szene außer dem Testnotiz-Fenster wird in Reihenfolge seines `windowLevel` per `drawHierarchy(in:afterScreenUpdates:)` gezeichnet. Ein einzelnes `keyWindow` würde Alerts und Systemblätter verlieren, die als eigene Fenster liegen — und genau die will man oft festhalten.

Der Ausschnitt ist ein Rechteck in Punkten aus der Geste. Die Umrechnung in Pixel (mal Scale, auf ganze Pixel gerundet, auf die Bildgrenzen beschnitten) ist eine reine Funktion mit Tests — hier liegen die Fehler, die man erst am Gerät sieht (ein Ausschnitt, der um eine halbe Zeile verrutscht).

### 1.5 Element-Erkennung

Zwei Quellen, in dieser Reihenfolge:

1. **Das Register.** `.testnotizElement("geraet.satz-sichern")` auf einem Bedienelement setzt zugleich `accessibilityIdentifier` (nützt den XCUITests, die der Blueprint vorsieht und die es noch nicht gibt) und meldet mit `onGeometryChange` seinen Rahmen in Fensterkoordinaten an ein Register — samt `#fileID` und `#line` der Aufrufstelle. Ein Tipp sucht das kleinste registrierte Rechteck, das den Punkt enthält. Deterministisch, und das Ergebnis trägt die Zeile, in die Claude Code springen soll.
2. **Der Accessibility-Baum.** Für alles Unmarkierte läuft ein Gang über `accessibilityElementCount()` / `accessibilityElement(at:)` und `subviews` ab dem App-Fenster und sammelt `accessibilityFrame`, `accessibilityLabel`, `accessibilityIdentifier`, `accessibilityValue`, Typ. Wieder das kleinste Rechteck um den Punkt. So findet ein Tipp auf einen unmarkierten Knopf wenigstens sein Label („Satz 2 sichern").

**Annahme:** SwiftUI füllt den Accessibility-Baum seines Hosting-Views auch ohne laufendes VoiceOver, wenn man ihn im Prozess abfragt. Cash Apps `AccessibilitySnapshot` arbeitet genau so und deckt SwiftUI ab; Aufgabe 5 beginnt trotzdem mit einem Spike, der das am Gerät zeigt. Fällt der Spike durch, bleibt Quelle 1 — dann müssen mehr Elemente markiert werden, und der Plan sagt in Aufgabe 5, welche zuerst.

Warum kein `UIView.hitTest`: SwiftUI zeichnet in **einen** Hosting-View und macht seine Trefferprüfung intern. `hitTest` liefert immer den Hosting-View, nie den Knopf darin.

### 1.6 Sprachnotiz

`AVAudioRecorder` in `.m4a` (AAC, 44,1 kHz, mono). Nach dem Stopp läuft `SFSpeechRecognizer(locale: de-DE)` mit `requiresOnDeviceRecognition = true` über die Datei. Nur auf dem Gerät: die Aufnahme verlässt das Telefon nicht, und Apples Server sehen keine Trainingsbeschreibung. Ist das deutsche Modell nicht auf dem Gerät (`supportsOnDeviceRecognition == false`), bleibt das Audio erhalten, und `transcript` ist `null` — das Markdown sagt dann *„Transkript fehlt, Audio liegt bei"*. Das Transkript ist Komfort, die Aufnahme der Beleg.

Beide Berechtigungstexte (`NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`) stehen in `project.yml` **nur in der Debug-Konfiguration**. Der Release-Build fragt damit nie nach einem Mikrofon, das er nicht braucht.

### 1.7 Ablage und der Weg zu Claude Code

```
Documents/Testnotizen/
  2026-09-13-1412/
    sitzung.md          alle Einträge, neueste unten; das ist die Datei für Claude Code
    sitzung.json        dieselben Einträge als Daten (§2)
    01-voll.png
    01-ausschnitt.png
    01-notiz.m4a
    02-voll.png
    …
```

Mit `UIFileSharingEnabled` und `LSSupportsOpeningDocumentsInPlace` (wieder Debug-only) erscheint der Ordner in der Files-App und im Finder unter dem Gerät. „Sitzung teilen" packt den Ordner zusätzlich als Zip in das Teilen-Blatt — AirDrop an den Mac, fertig. Im Repo gibt es ab Aufgabe 8 den gitignorierten Eingang `apps/ios-member/testnotizen/`; ein Ordner dort hinein, und der Auftrag an Claude Code lautet: *„Lies `apps/ios-member/testnotizen/2026-09-13-1412/sitzung.md` und arbeite die Einträge ab."*

### 1.8 Android, später

Der Blueprint sagt native Android, kein Flutter. Geteilt wird deshalb nur §2. Die Kotlin-Fassung hat dieselben vier Modi mit denselben Bausteinen: ein Compose-Overlay im Activity-Fenster für den Knopf, `PixelCopy` für das Foto, der Semantics-Baum mit `testTag` und `testTagsAsResourceId` als Register, `MediaRecorder` plus `SpeechRecognizer` für die Notiz. Der Ordner landet unter `getExternalFilesDir` und kommt per Share-Intent auf den Rechner. Das ist ein eigener Plan, wenn Android kommt; §2 und die Beispieldatei aus Aufgabe 9 sind seine Testvorlage.

---

## 2. Format-Vertrag

`sitzung.json` — ein Objekt, `entries` chronologisch. Alle Pfade relativ zum Sitzungsordner. Felder, die nicht zutreffen, sind `null`, nie weggelassen — damit ein Leser beide Plattformen mit einem Schema prüft.

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
      "id": "8F0C…",
      "index": 1,
      "createdAt": "2026-09-13T14:13:41+02:00",
      "kind": "crop",
      "screen": {
        "name": "GeraetView",
        "file": "FitnessMember/Screens/Geraet/GeraetView.swift",
        "stack": ["FitnessMember/Screens/Training/TrainingRootView.swift", "FitnessMember/Screens/Geraet/GeraetView.swift"],
        "context": { "machineId": "m_123", "exerciseId": "e_456" }
      },
      "screenshot": "01-voll.png",
      "crop": "01-ausschnitt.png",
      "cropRect": { "points": { "x": 20, "y": 412, "width": 335, "height": 96 }, "pixels": { "x": 60, "y": 1236, "width": 1005, "height": 288 } },
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
      "id": "…", "index": 2, "createdAt": "…", "kind": "element",
      "screen": { "name": "GeraetView", "file": "…", "stack": ["…"], "context": {} },
      "screenshot": "02-voll.png", "crop": null, "cropRect": null,
      "element": {
        "source": "registry",
        "identifier": "geraet.satz-sichern",
        "label": "Satz 2 sichern",
        "type": "PrimaryButton",
        "frame": { "x": 20, "y": 640, "width": 335, "height": 64 },
        "file": "FitnessMember/Screens/Geraet/GeraetView.swift",
        "line": 212
      },
      "note": "Knopf bleibt nach dem Tipp einen Moment grau", "audio": null, "transcript": null,
      "runtime": { "…": "…" }, "log": []
    }
  ]
}
```

`kind` ∈ `crop | element | note`. `element.source` ∈ `registry | accessibility`; aus dem Accessibility-Baum sind `file` und `line` `null`.

`sitzung.md` — das, was Claude Code liest. Ein Abschnitt je Eintrag, die Bilder als Markdown-Bilder mit relativem Pfad, damit ein Betrachter sie einblendet:

```markdown
# Testsitzung 2026-09-13 14:12 — gymodo Member 1.0 (42), iPhone14,4, iOS 26.6.1

## 1 · 14:13 · Ausschnitt · GeraetView

**Screen:** `FitnessMember/Screens/Geraet/GeraetView.swift` (machineId m_123, exerciseId e_456)
**Pfad:** TrainingRootView → GeraetView

**Notiz:** Das Gewicht wird abgeschnitten wenn 100,5
**Gesprochen:** Das Gewicht wird abgeschnitten wenn hundert komma fünf drinsteht

![Ausschnitt](01-ausschnitt.png)
![Vollbild](01-voll.png)

<details><summary>Protokoll (letzte 5 min, 1 Zeile)</summary>

14:13:02 info tag — Tab-Wechsel auf Training wegen offenem Tag-Eingang

</details>

## 2 · 14:15 · Element · GeraetView

**Element:** `geraet.satz-sichern` — „Satz 2 sichern", PrimaryButton, `GeraetView.swift:212`
…
```

---

## Dateistruktur

### Modul — `apps/ios-member/FitnessMember/Testnotiz/`

| Datei | Verantwortung |
| --- | --- |
| `Testnotiz.swift` **(neu)** | Namespace, `@MainActor` Singleton `Testnotiz.shared` mit Stapel, Register, Sitzung; `installieren(in:)` |
| `TestnotizFenster.swift` **(neu)** | Das `UIWindow` mit durchlässigem `hitTest`, Modus-Zustand |
| `TestnotizKnopf.swift` **(neu)** | Der schwebende Kreis, Drag, Menü |
| `TestnotizScreenStapel.swift` **(neu)** | Reine Stapellogik; `ScreenEintrag` |
| `TestnotizScreenModifier.swift` **(neu)** | `.testnotizScreen(_:kontext:)` |
| `TestnotizElementRegister.swift` **(neu)** | Reines Register; `ElementEintrag`, `treffer(punkt:)` |
| `TestnotizElementModifier.swift` **(neu)** | `.testnotizElement(_:)` |
| `AccessibilityBaum.swift` **(neu)** | Rückfallweg §1.5 |
| `Bildschirmfoto.swift` **(neu)** | Fensterweise zeichnen; `Ausschnitt` reine Rechnung |
| `AuswahlOverlay.swift` **(neu)** | Rechteck ziehen / Punkt tippen, vollflächig |
| `NotizBlatt.swift` **(neu)** | Text, Aufnahme, Kopf mit Ausschnitt oder Element |
| `Sprachnotiz.swift` **(neu)** | `Aufnahme` (AVAudioRecorder), `Transkription` (Speech) |
| `Laufzeitkontext.swift` **(neu)** | Gerät, Build, Zustand, `Protokoll.lesen(seit:)` |
| `TestnotizEintrag.swift` **(neu)** | Die `Codable`-Werte aus §2 |
| `TestnotizMarkdown.swift` **(neu)** | `sitzung.md` aus den Werten |
| `TestnotizAblage.swift` **(neu)** | `actor`: Ordner, Dateinamen, Schreiben, Zip |
| `SitzungBlatt.swift` **(neu)** | Neue Sitzung, Teilen, Zähler |

### App — Änderungen

| Datei | Änderung |
| --- | --- |
| `FitnessMemberApp.swift` | `.testnotizInstallieren()` an der `RootView`, unter `#if DEBUG` |
| `project.yml` | Debug-only: Berechtigungstexte, `UIFileSharingEnabled`, `LSSupportsOpeningDocumentsInPlace` |
| 24 Screen-Wurzeln (Aufgabe 3) | je ein `.testnotizScreen(…)` |
| `PrimaryButton`, `SecondaryButton`, `Stepper44`, `RastRad`, `Chip`, `MainTabView` (Aufgabe 5) | `kennung`-Parameter bzw. `.testnotizElement` |
| `.gitignore` | `apps/ios-member/testnotizen/` |

### Tests — `apps/ios-member/FitnessMemberTests/`

| Datei | Deckt |
| --- | --- |
| `TestnotizEintragTests.swift` **(neu)** | Aufgabe 2 — JSON-Form gegen die Beispieldatei, Rundreise |
| `TestnotizMarkdownTests.swift` **(neu)** | Aufgabe 2 |
| `TestnotizAblageTests.swift` **(neu)** | Aufgabe 2 — Ordnername, Nummerierung |
| `TestnotizScreenStapelTests.swift` **(neu)** | Aufgabe 3 |
| `AusschnittTests.swift` **(neu)** | Aufgabe 4 |
| `TestnotizElementRegisterTests.swift` **(neu)** | Aufgabe 5 |
| `ProtokollTests.swift` **(neu)** | Aufgabe 7 — Filter und Zeilenform |

---

## Was dieser Plan bewusst nicht baut

- **Kein Overlay über fremde Apps.** iOS erlaubt es nicht; das Modul lebt in der eigenen App. Das ist die Entscheidung aus dem Gespräch vom 13. September, kein Versehen.
- **Kein Upload, kein Ticket-System, kein Sentry.** Der Ordner ist das Produkt. Wer ihn irgendwohin schicken will, tut das von Hand.
- **Kein TestFlight-Build mit Testnotizen.** TestFlight baut Release. Eine dritte Konfiguration „Beta" mit dem Modul wäre ein kleiner Nachtrag in `project.yml`, gehört aber nicht hierher: Pilotmitglieder sollen keinen Knopf sehen.
- **Keine Bildschirmaufnahme (Video).** Ein Fund ist ein Moment. Wer einen Ablauf zeigen will, macht drei Einträge.
- **Kein Zeichnen auf dem Screenshot.** Der Ausschnitt ist die Markierung; Pfeile und Kreise bringen für einen Leser, der die Quelldatei und das Element bekommt, nichts mehr.
- **Kein MCP-Server, keine automatische Übergabe an Claude Code.** Erst muss sich zeigen, ob `sitzung.md` als Auftrag genügt. Wenn nicht, ist das ein Plan im Repo `app-improver`.
- **Kein Android.** §1.8 und §2 bereiten es vor, mehr nicht.
- **Keine Serverstimme für die Transkription.** On-device oder gar nicht.

---

## Aufgabe 1: Fenster und Knopf — und der Beweis, dass Release nichts davon hat

Die kleinste Aufgabe, aber die mit den meisten Annahmen über Xcode: ein zweites Fenster in der SwiftUI-App, Debug-only-Einstellungen in `project.yml`, und `#if DEBUG` an jeder Datei. Alles Weitere baut darauf.

**Dateien:**
- Anlegen: `FitnessMember/Testnotiz/Testnotiz.swift`
- Anlegen: `FitnessMember/Testnotiz/TestnotizFenster.swift`
- Anlegen: `FitnessMember/Testnotiz/TestnotizKnopf.swift`
- Ändern: `FitnessMember/FitnessMemberApp.swift`
- Ändern: `project.yml`

**Schnittstellen:**
- Nutzt: nichts
- Liefert:
  - `Testnotiz.shared: Testnotiz` (`@MainActor`, `@Observable`), mit `modus: Modus` (`.ruhe | .ausschnitt | .element | .notiz | .sitzung`)
  - `View.testnotizInstallieren() -> some View` — in Release eine Attrappe, die `self` zurückgibt
  - `TestnotizFenster.durchlaessig: Bool`

- [ ] **Schritt 1: `project.yml` — die Debug-Konfiguration bekommt ihre Schlüssel**

Unter `targets.FitnessMember.settings` neben `base:`:

```yaml
      configs:
        Debug:
          INFOPLIST_KEY_NSMicrophoneUsageDescription: "Nur im Entwicklungsbuild: Sprachnotizen zu Testfunden."
          INFOPLIST_KEY_NSSpeechRecognitionUsageDescription: "Nur im Entwicklungsbuild: Sprachnotizen werden auf dem Gerät in Text umgewandelt."
          INFOPLIST_KEY_UIFileSharingEnabled: YES
          INFOPLIST_KEY_LSSupportsOpeningDocumentsInPlace: YES
```

`INFOPLIST_KEY_UIFileSharingEnabled` und `LSSupportsOpeningDocumentsInPlace` sind wie die Kamera-Beschreibung Apples bekannte Schlüssel und laufen über `GENERATE_INFOPLIST_FILE`. Sollte Xcode einen der beiden nicht als `INFOPLIST_KEY_` kennen (die Liste ist nicht vollständig dokumentiert), wandern sie in eine zweite Additions-Datei `Info-Additions-Debug.plist`, die per `configs.Debug.INFOPLIST_FILE` eingemischt wird — dann muss die Datei die vier Schlüssel aus `Info-Additions.plist` wiederholen, weil `INFOPLIST_FILE` nur einmal gilt.

Dann: `cd apps/ios-member && xcodegen generate`.

- [ ] **Schritt 2: Der Namespace**

`Testnotiz.swift`:

```swift
#if DEBUG
import SwiftUI
import Observation

/// Der eine Ort, an dem das Modul lebt. Ein Singleton, weil das Fenster
/// eines ist: es gibt genau eine Szene und genau einen Knopf darueber.
/// Screen-Stapel und Element-Register kommen in Aufgabe 3 und 5 hierher.
@MainActor
@Observable
final class Testnotiz {
    static let shared = Testnotiz()

    enum Modus: Equatable {
        case ruhe, ausschnitt, element, notiz, sitzung
    }

    var modus: Modus = .ruhe

    @ObservationIgnored private var fenster: TestnotizFenster?

    /// Haengt das Fenster in die Szene, in der die App laeuft. Idempotent:
    /// RootView kann mehrfach erscheinen (Session-Wechsel), das Fenster
    /// darf es nicht.
    func installieren(in szene: UIWindowScene) {
        guard fenster == nil else { return }
        let neu = TestnotizFenster(windowScene: szene)
        neu.rootViewController = UIHostingController(rootView: TestnotizKnopf())
        neu.rootViewController?.view.backgroundColor = .clear
        neu.isHidden = false
        fenster = neu
    }
}

/// Holt die Szene ueber die UIView-Bruecke, weil SwiftUI sie nicht
/// herausgibt. Der Representable ist unsichtbar und misst nichts.
private struct TestnotizInstallation: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isHidden = true
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        // Beim ersten Aufruf haengt die View noch in keinem Fenster; der
        // naechste Layout-Durchlauf holt das nach.
        DispatchQueue.main.async {
            guard let szene = view.window?.windowScene else { return }
            Testnotiz.shared.installieren(in: szene)
        }
    }
}

extension View {
    func testnotizInstallieren() -> some View {
        background(TestnotizInstallation())
    }
}
#else
import SwiftUI

extension View {
    /// Release: kein Fenster, kein Knopf, kein Symbol.
    @inline(__always)
    func testnotizInstallieren() -> some View { self }
}
#endif
```

- [ ] **Schritt 3: Das durchlässige Fenster**

`TestnotizFenster.swift`:

```swift
#if DEBUG
import UIKit

/// Liegt ueber allem, auch ueber Alerts -- die will man festhalten koennen.
/// Der Preis: jede Beruehrung erreicht zuerst dieses Fenster. hitTest gibt
/// sie deshalb zurueck, sobald sie nicht dem Knopf gilt.
final class TestnotizFenster: UIWindow {
    /// true in Ruhe: nur der Knopf faengt. false in einem Modus: die ganze
    /// Flaeche faengt, die App darunter bekommt nichts.
    var durchlaessig = true

    override init(windowScene: UIWindowScene) {
        super.init(windowScene: windowScene)
        windowLevel = .alert + 1
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError("nicht aus einem Storyboard") }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let treffer = super.hitTest(point, with: event)
        // Der Hosting-View ist die ganze Flaeche; trifft es nur ihn, war
        // es die Leere neben dem Knopf.
        if durchlaessig, treffer === rootViewController?.view {
            return nil
        }
        return treffer
    }
}
#endif
```

**Annahme:** SwiftUIs Hosting-View gibt sich in `hitTest` für leere Flächen selbst zurück, nicht `nil`. Tut er das nicht, geht die Berührung ohnehin durch — dann ist die Bedingung nur überflüssig, nicht falsch. Gefährlich wäre nur das Gegenteil (die Leere fängt), und das sieht die Abnahme sofort: die App wäre unbedienbar.

- [ ] **Schritt 4: Der Knopf**

`TestnotizKnopf.swift` — ein `Circle` 44 pt, `DesignSystem.Color.accent`, `Image(systemName: "note.text")` in `onAccent`, rechts am Rand, `@State versatz: CGFloat` für die Höhe, `DragGesture` verschiebt nur vertikal, `.onEnded` klemmt auf den sichtbaren Bereich. Ein Tipp öffnet ein `Menu` mit den vier Einträgen aus §1.1; die Einträge setzen vorerst nur `Testnotiz.shared.modus` — die Modi selbst kommen in Aufgabe 4, 5, 6 und 8. Der Knopf nimmt `Testnotiz.shared` als `@State`-Referenz und blendet sich aus, solange `modus != .ruhe`.

Die Hosting-Fläche ist der ganze Bildschirm (`ignoresSafeArea`), damit der Knopf bis unter die Tab-Leiste kann; der Kreis selbst hält `safeAreaInsets` ein.

- [ ] **Schritt 5: Einhängen**

`FitnessMemberApp.swift`, an `RootView(apiClient:)`:

```swift
            RootView(apiClient: apiClient)
                .testnotizInstallieren()
                .environment(sessionStore)
```

Kein `#if DEBUG` an dieser Stelle — die Release-Attrappe aus Schritt 2 gibt `self` zurück und wird wegoptimiert. So bleibt die App-Datei frei von Präprozessor.

- [ ] **Schritt 6: Bauen, beide Konfigurationen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" build 2>&1 | tail -20
cd apps/ios-member && xcodebuild -scheme FitnessMember -configuration Release -destination "generic/platform=iOS" -derivedDataPath /tmp/dd-release CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -20
strings /tmp/dd-release/Build/Products/Release-iphoneos/FitnessMember.app/FitnessMember | grep -c Testnotiz
plutil -p /tmp/dd-release/Build/Products/Release-iphoneos/FitnessMember.app/Info.plist | grep -c NSSpeech
```

Beide `grep -c` müssen `0` liefern. Das ist der Beweis für die erste Rahmenbedingung, und er gehört in die Commit-Nachricht.

- [ ] **Schritt 7: Am Gerät** — Knopf sichtbar, verschiebbar, rastet ein; Tipps neben dem Knopf erreichen die App; Menü öffnet sich. Dann Commit: `Testnotiz: Fenster und Knopf, Debug-only`.

---

## Aufgabe 2: Die Werte, das Markdown, die Ablage

Das Datenmodell zuerst, weil §2 der Vertrag mit Android ist und die Tests ihn festnageln, bevor die Modi ihn befüllen. Die Beispieldatei aus §2 wird als Fixture ins Testziel gelegt und **dekodiert** — nicht nur der eigene Encoder gegen den eigenen Decoder.

**Dateien:**
- Anlegen: `FitnessMember/Testnotiz/TestnotizEintrag.swift`
- Anlegen: `FitnessMember/Testnotiz/TestnotizMarkdown.swift`
- Anlegen: `FitnessMember/Testnotiz/TestnotizAblage.swift`
- Anlegen: `FitnessMemberTests/Fixtures/testnotiz-beispiel.json` (§2, wörtlich, mit ausgefülltem zweiten Eintrag)
- Anlegen: `FitnessMemberTests/TestnotizEintragTests.swift`, `TestnotizMarkdownTests.swift`, `TestnotizAblageTests.swift`

**Schnittstellen:**
- Nutzt: nichts
- Liefert:
  - `struct TestnotizSitzung: Codable, Sendable` — `format`, `platform`, `session`, `entries`
  - `struct TestnotizEintrag: Codable, Sendable, Identifiable` — Felder wie §2; `Art` (`crop | element | note`), `Screen`, `Rechteck`, `Element`, `Laufzeit`, `Protokollzeile`
  - `enum TestnotizMarkdown { static func rendern(_ sitzung: TestnotizSitzung) -> String }`
  - `actor TestnotizAblage` — `init(wurzel: URL)`, `neueSitzung(app:geraet:jetzt:) -> URL`, `schreiben(eintrag:, voll: Data, ausschnitt: Data?, audio: URL?) async throws -> TestnotizEintrag` (setzt `index` und Dateinamen), `zipFuerTeilen() async throws -> URL`
  - `static func ordnername(_ datum: Date) -> String` — `yyyy-MM-dd-HHmm`, lokale Zeitzone

- [ ] **Schritt 1: Die Fixture und der Test, der sie liest**

`TestnotizEintragTests.swift`:

```swift
import Foundation
import Testing
@testable import FitnessMember

struct TestnotizEintragTests {
    private func beispiel() throws -> Data {
        let url = try #require(Bundle(for: Marker.self).url(forResource: "testnotiz-beispiel", withExtension: "json"))
        return try Data(contentsOf: url)
    }

    @Test func liestDieBeispieldateiVollstaendig() throws {
        let sitzung = try JSONDecoder.testnotiz.decode(TestnotizSitzung.self, from: beispiel())
        #expect(sitzung.format == "gymodo.testnotiz/1")
        #expect(sitzung.entries.count == 2)
        let erster = sitzung.entries[0]
        #expect(erster.kind == .crop)
        #expect(erster.screen.file == "FitnessMember/Screens/Geraet/GeraetView.swift")
        #expect(erster.cropRect?.pixels.width == 1005)
        #expect(erster.element == nil)
        let zweiter = sitzung.entries[1]
        #expect(zweiter.element?.source == .registry)
        #expect(zweiter.element?.line == 212)
        #expect(zweiter.crop == nil)
    }

    // Ein Feld, das der Encoder weglaesst, wuerde Android einen Schluessel
    // kosten, den es voraussetzt. Deshalb: null steht drin.
    @Test func schreibtNullStattWegzulassen() throws {
        let sitzung = try JSONDecoder.testnotiz.decode(TestnotizSitzung.self, from: beispiel())
        let text = String(decoding: try JSONEncoder.testnotiz.encode(sitzung), as: UTF8.self)
        #expect(text.contains("\"element\" : null"))
        #expect(text.contains("\"audio\" : null"))
    }

    @Test func rundreiseVerliertNichts() throws {
        let daten = try beispiel()
        let a = try JSONDecoder.testnotiz.decode(TestnotizSitzung.self, from: daten)
        let b = try JSONDecoder.testnotiz.decode(TestnotizSitzung.self, from: JSONEncoder.testnotiz.encode(a))
        #expect(a == b)
    }
}

private final class Marker {}
```

`JSONEncoder.testnotiz`: `.sortedKeys`, `.prettyPrinted`, ISO-8601 mit Zeitzone. `JSONDecoder.testnotiz`: ISO-8601. Beide als `static let` in `TestnotizEintrag.swift`. Die Fixture kommt über `project.yml` ins Testziel: `FitnessMemberTests` listet `sources: - FitnessMemberTests`; ein `.json` darunter wird als Ressource kopiert.

Die Werte-Typen bekommen `Equatable` für die Rundreise. `null` statt Weglassen: Swift lässt `Optional` beim Encoden nur weg, wenn man `encodeIfPresent` nutzt — die synthetisierte `Codable`-Konformität tut genau das. Deshalb ein eigenes `encode(to:)` in `TestnotizEintrag`, das `encode(_:forKey:)` für jedes Optional ruft. Der Test aus Schritt 1 fällt sonst.

- [ ] **Schritt 2: Markdown**

`TestnotizMarkdownTests.swift` prüft an der Fixture: Kopfzeile mit Version, Build, Modell, iOS; je Eintrag eine `## n · HH:mm · Art · Screen`-Zeile; `**Element:**` nur bei `element`; `![Ausschnitt]` vor `![Vollbild]`; das Protokoll in `<details>`; bei `transcript == nil` und `audio != nil` der Satz *„Transkript fehlt, Audio liegt bei"*. Dann `TestnotizMarkdown.rendern` so lange, bis grün. Der Renderer ist eine Funktion über Werte, ohne Datum-Now, ohne Dateisystem.

- [ ] **Schritt 3: Ablage**

`TestnotizAblageTests.swift` arbeitet in `FileManager.default.temporaryDirectory` und prüft: `ordnername` liefert `2026-09-13-1412` für ein festes Datum in `Europe/Berlin`; zwei `schreiben`-Aufrufe ergeben `01-voll.png`, `02-voll.png` und `index` 1, 2; nach jedem `schreiben` liegen `sitzung.json` und `sitzung.md` neu geschrieben da und `sitzung.json` dekodiert zur erwarteten Sitzung; `zipFuerTeilen` liefert eine Datei mit Endung `.zip`, die größer als null ist.

Zip ohne Fremdbibliothek — `NSFileCoordinator` packt einen Ordner beim Lesen `.forUploading`:

```swift
    func zipFuerTeilen() throws -> URL {
        let ziel = FileManager.default.temporaryDirectory.appendingPathComponent("\(sitzungsordner.lastPathComponent).zip")
        try? FileManager.default.removeItem(at: ziel)
        var koordinationsfehler: NSError?
        var kopierfehler: Error?
        NSFileCoordinator().coordinate(readingItemAt: sitzungsordner, options: .forUploading, error: &koordinationsfehler) { zip in
            do { try FileManager.default.copyItem(at: zip, to: ziel) } catch { kopierfehler = error }
        }
        if let koordinationsfehler { throw koordinationsfehler }
        if let kopierfehler { throw kopierfehler }
        return ziel
    }
```

- [ ] **Schritt 4: Tests laufen lassen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/TestnotizEintragTests -only-testing:FitnessMemberTests/TestnotizMarkdownTests -only-testing:FitnessMemberTests/TestnotizAblageTests 2>&1 | tail -30
```

Commit: `Testnotiz: Werte, Markdown und Ablage nach Format-Vertrag`.

---

## Aufgabe 3: Der Screen-Stapel und die 24 Wurzeln

**Dateien:**
- Anlegen: `FitnessMember/Testnotiz/TestnotizScreenStapel.swift`
- Anlegen: `FitnessMember/Testnotiz/TestnotizScreenModifier.swift`
- Anlegen: `FitnessMemberTests/TestnotizScreenStapelTests.swift`
- Ändern: `Testnotiz.swift` (`stapel`)
- Ändern: 24 Screen-Dateien (Liste unten)

**Schnittstellen:**
- Nutzt: `Testnotiz.shared`
- Liefert:
  - `struct ScreenEintrag: Equatable, Sendable` — `token: UUID`, `name: String` (letzte Pfadkomponente ohne `.swift`), `file: String`, `kontext: [String: String]`
  - `struct TestnotizScreenStapel` — `mutating func erschienen(_:)`, `mutating func verschwunden(token:)`, `var aktueller: ScreenEintrag?`, `var pfad: [String]` (Dateien von unten nach oben)
  - `View.testnotizScreen(_ file: String = #fileID, kontext: [String: String] = [:]) -> some View` — Release-Attrappe gibt `self`

- [ ] **Schritt 1: Stapeltests**

```swift
struct TestnotizScreenStapelTests {
    @Test func derZuletztErschieneneIstDerAktuelle() {
        var s = TestnotizScreenStapel()
        let training = ScreenEintrag(file: "FitnessMember/Screens/Training/TrainingRootView.swift")
        let geraet = ScreenEintrag(file: "FitnessMember/Screens/Geraet/GeraetView.swift")
        s.erschienen(training)
        s.erschienen(geraet)
        #expect(s.aktueller?.name == "GeraetView")
        #expect(s.pfad == [training.file, geraet.file])
    }

    // Ein Push ueberdeckt: der Untere verschwindet, aber erst NACH dem
    // Erscheinen des Oberen. Der Stapel darf davon nicht durcheinanderkommen.
    @Test func verschwindenDesUnterenAendertDenAktuellenNicht() {
        var s = TestnotizScreenStapel()
        let training = ScreenEintrag(file: "…/TrainingRootView.swift")
        let geraet = ScreenEintrag(file: "…/GeraetView.swift")
        s.erschienen(training); s.erschienen(geraet); s.verschwunden(token: training.token)
        #expect(s.aktueller?.name == "GeraetView")
    }

    // Sheet zu: der darunter ist wieder dran.
    @Test func verschwindenDesOberenLegtDenUnterenFrei() { … }

    // Tab-Wechsel: Home verschwindet, Training erscheint -- in welcher
    // Reihenfolge SwiftUI das ruft, ist nicht zugesichert. Beide Folgen
    // muessen Training ergeben.
    @Test func tabwechselInBeidenReihenfolgen() { … }

    @Test func nameIstDerDateinameOhneEndung() {
        #expect(ScreenEintrag(file: "FitnessMember/Screens/Home/HomeRootView.swift").name == "HomeRootView")
    }
}
```

- [ ] **Schritt 2: Stapel und Modifier**

Der Stapel ist ein Array; `verschwunden` entfernt nach `token`, nicht nach Datei — dieselbe Datei kann zweimal offen sein (Sheet über sich selbst ist selten, aber `GeraetView` unter `ErstkontaktFlow` ist real). Der Modifier:

```swift
private struct TestnotizScreen: ViewModifier {
    let eintrag: ScreenEintrag
    func body(content: Content) -> some View {
        content
            .onAppear { Testnotiz.shared.stapel.erschienen(eintrag) }
            .onDisappear { Testnotiz.shared.stapel.verschwunden(token: eintrag.token) }
    }
}

extension View {
    func testnotizScreen(_ file: String = #fileID, kontext: [String: String] = [:]) -> some View {
        modifier(TestnotizScreen(eintrag: ScreenEintrag(file: file, kontext: kontext)))
    }
}
```

`ScreenEintrag` wird in `body` der aufrufenden View jedes Mal neu gebaut, mit neuem `token` — dann fände `onDisappear` sein `onAppear` nicht mehr. Deshalb hält der Modifier den Eintrag in `@State` und erzeugt das Token einmal beim ersten `body`; `kontext` wird bei jedem Update nachgezogen (`onChange`), damit ein Übungswechsel im Gerät den Kontext aktualisiert.

- [ ] **Schritt 3: Die Wurzeln markieren**

Je eine Zeile, an die äußerste View des `body`, **nicht** an Unter-Views:

| Datei | `kontext` |
| --- | --- |
| `Screens/Zugang/LoginMailView.swift`, `LoginCodeView.swift`, `MemberRegistrierenView.swift`, `MemberPasswortView.swift`, `MemberPasswortAendernView.swift`, `MemberPasswortZuruecksetzenView.swift`, `MemberKeinStudioView.swift` | – |
| `Screens/Home/HomeRootView.swift` | – |
| `Screens/Home/SessionDetailView.swift` | `sessionId` |
| `Screens/Home/UebungsfortschrittView.swift` | `exerciseId` |
| `Screens/Training/TrainingRootView.swift`, `TrainingAbschlussView.swift` | – |
| `Screens/Geraet/GeraeteAuswahlView.swift` | – |
| `Screens/Geraet/GeraetErkanntView.swift` | `machineId` |
| `Screens/Geraet/GeraetView.swift` | `machineId`, `exerciseId`, `phase` (`String(describing: modell.phase)`) |
| `Screens/Geraet/ErstkontaktFlow.swift` | `schritt` |
| `Screens/Geraet/UebungWechselnSheet.swift`, `ProblemSheet.swift` | `machineId` |
| `Screens/Kurse/KurseWochenView.swift` | – |
| `Screens/Kurse/KursDetailView.swift` | `sessionId` |
| `Screens/Profil/ProfilRootView.swift`, `MemberStudiosView.swift`, `NameSheet.swift` | – |
| `DesignSystem/Components/ScannerSheet.swift` | `titel` |

`phase` am Gerät ist wichtig: der Satzpfad-Feinschliff (Plan vom 11. September) hat vier Zustände in einem Screen, und ein Fund „in der Pause" ohne diesen Kontext ist ein halber Fund.

- [ ] **Schritt 4: Tests, Build, Gerät** — alle vier Tabs, Push zum Gerät, Sheet auf und zu; im Kopf des Knopf-Menüs steht vorerst der aktuelle Name als Text (`Testnotiz.shared.stapel.aktueller?.name`), damit man es ohne Notiz-Blatt sieht. Commit: `Testnotiz: Screen-Stapel, 24 Wurzeln gemeldet`.

---

## Aufgabe 4: Bildschirmfoto und Ausschnitt

**Dateien:**
- Anlegen: `FitnessMember/Testnotiz/Bildschirmfoto.swift`
- Anlegen: `FitnessMember/Testnotiz/AuswahlOverlay.swift`
- Anlegen: `FitnessMemberTests/AusschnittTests.swift`
- Ändern: `TestnotizKnopf.swift`, `Testnotiz.swift`

**Schnittstellen:**
- Nutzt: `Testnotiz.shared.modus`, `TestnotizFenster.durchlaessig`
- Liefert:
  - `enum Bildschirmfoto { @MainActor static func aufnehmen(szene: UIWindowScene, ohne: UIWindow) -> UIImage }`
  - `struct Ausschnitt` — `static func pixelRechteck(punkte: CGRect, scale: CGFloat, bildgroesse: CGSize) -> CGRect?` (nil bei leerem Schnitt), `static func schneiden(_ bild: UIImage, punkte: CGRect) -> UIImage?`
  - `struct AuswahlOverlay: View` — `art: .rechteck | .punkt`, `beiRechteck: (CGRect) -> Void`, `beiPunkt: (CGPoint) -> Void`, `beiAbbruch`

- [ ] **Schritt 1: Die Rechnung testen**

```swift
struct AusschnittTests {
    @Test func rechnetPunkteInPixelUm() {
        let r = Ausschnitt.pixelRechteck(punkte: CGRect(x: 20, y: 412, width: 335, height: 96), scale: 3, bildgroesse: CGSize(width: 1125, height: 2436))
        #expect(r == CGRect(x: 60, y: 1236, width: 1005, height: 288))
    }

    @Test func rundetAufGanzePixelNachAussen() {
        let r = Ausschnitt.pixelRechteck(punkte: CGRect(x: 10.4, y: 10.4, width: 10.2, height: 10.2), scale: 2, bildgroesse: CGSize(width: 100, height: 100))
        #expect(r == CGRect(x: 20, y: 20, width: 21, height: 21))
    }

    @Test func beschneidetAufDasBild() {
        let r = Ausschnitt.pixelRechteck(punkte: CGRect(x: -5, y: 790, width: 400, height: 60), scale: 3, bildgroesse: CGSize(width: 1125, height: 2436))
        #expect(r == CGRect(x: 0, y: 2370, width: 1125, height: 66))
    }

    @Test func leererSchnittIstNil() {
        #expect(Ausschnitt.pixelRechteck(punkte: CGRect(x: 900, y: 0, width: 10, height: 10), scale: 3, bildgroesse: CGSize(width: 1125, height: 2436)) == nil)
    }

    // Eine Geste von rechts unten nach links oben liefert negative Breite;
    // standardized() vorher, sonst schneidet CGImage nichts.
    @Test func normalisiertNegativeGesten() { … }
}
```

- [ ] **Schritt 2: Foto**

```swift
    static func aufnehmen(szene: UIWindowScene, ohne eigenes: UIWindow) -> UIImage {
        let grenzen = szene.screen.bounds
        let format = UIGraphicsImageRendererFormat()
        format.scale = szene.screen.scale
        return UIGraphicsImageRenderer(bounds: grenzen, format: format).image { _ in
            // Alerts und Systemblaetter sind eigene Fenster; nur das
            // keyWindow zu zeichnen wuerde sie verlieren.
            for fenster in szene.windows where fenster !== eigenes && !fenster.isHidden && fenster.alpha > 0 {
                fenster.drawHierarchy(in: fenster.frame, afterScreenUpdates: false)
            }
        }
    }
```

`szene.windows` kommt bereits nach `windowLevel` sortiert. `afterScreenUpdates: false`, weil das Menü gerade erst zugegangen ist und der Rest steht — `true` würde einen Frame warten und kann in einer laufenden Animation (Pausenrad) ein Zwischenbild liefern; die Abnahme prüft beide Fälle, falls `false` das Menü noch im Bild hat, kippt es auf `true` mit einem `Task.yield()` davor.

- [ ] **Schritt 3: Der Modus im Knopf**

Menü „Ausschnitt": Foto aufnehmen → `modus = .ausschnitt` → `fenster.durchlaessig = false` → `AuswahlOverlay(.rechteck)` ersetzt den Knopf im Hosting-View (abgedunkelt mit `Color.black.opacity(0.35)`, das gezogene Rechteck als Loch, Rand in `accent`) → `beiRechteck` schneidet, hält Vollbild, Ausschnitt und Rechteck als `Entwurf` in `Testnotiz.shared` und setzt `modus = .notiz` (Aufgabe 6 füllt das Blatt; bis dahin speichert der Modus sofort mit leerer Notiz über die Ablage aus Aufgabe 2). Abbruch über einen Knopf oben rechts, 44 pt, oder Tipp ohne Zug.

- [ ] **Schritt 4: Gerät** — Ausschnitt ziehen, in Files nachsehen: `01-voll.png` zeigt die App ohne Menü und ohne Knopf, `01-ausschnitt.png` genau den gezogenen Bereich, `sitzung.json` trägt beide Rechtecke. Commit: `Testnotiz: Bildschirmfoto und Ausschnitt`.

---

## Aufgabe 5: Element-Register und der Accessibility-Rückfall

Beginnt mit dem Spike für die Annahme aus §1.5, damit der Rest der Aufgabe weiß, worauf er bauen kann.

**Dateien:**
- Anlegen: `FitnessMember/Testnotiz/TestnotizElementRegister.swift`
- Anlegen: `FitnessMember/Testnotiz/TestnotizElementModifier.swift`
- Anlegen: `FitnessMember/Testnotiz/AccessibilityBaum.swift`
- Anlegen: `FitnessMemberTests/TestnotizElementRegisterTests.swift`
- Ändern: `DesignSystem/Components/PrimaryButton.swift`, `SecondaryButton.swift`, `Stepper44.swift`, `RastRad.swift`, `Chip.swift`; `Navigation/MainTabView.swift`; Aufrufstellen in `GeraetView.swift`, `TrainingRootView.swift`, `HomeRootView.swift`, `KurseWochenView.swift`, `ProfilRootView.swift`

**Schnittstellen:**
- Nutzt: `AuswahlOverlay(.punkt)`, `Bildschirmfoto`
- Liefert:
  - `struct ElementEintrag: Sendable` — `kennung`, `typ`, `rahmen: CGRect` (Fensterkoordinaten), `file`, `line`
  - `struct TestnotizElementRegister` — `mutating func melden(_:)`, `mutating func entfernen(kennung:)`, `func treffer(punkt: CGPoint) -> ElementEintrag?`
  - `View.testnotizElement(_ kennung: String, typ: String = "View", file: String = #fileID, line: Int = #line) -> some View` — setzt auch `accessibilityIdentifier`; Release: nur `accessibilityIdentifier`
  - `enum AccessibilityBaum { @MainActor static func element(an punkt: CGPoint, in fenster: UIWindow) -> TestnotizEintrag.Element? }`
  - `PrimaryButton(title:kennung:…)` — neuer optionaler Parameter `kennung: String? = nil`, ebenso bei den anderen vier Komponenten

- [ ] **Schritt 1: Spike — liefert der Accessibility-Baum im Prozess etwas?**

Ein Wegwerf-Knopf im Menü „AX-Baum zählen", der `AccessibilityBaum.alle(in: appFenster).count` in ein `print` schreibt. Erwartung auf dem Gerät-Screen: mehr als zehn Elemente, darunter eines mit `label == "Satz 1 sichern"`. Ergebnis als Satz in die Commit-Nachricht dieser Aufgabe. Wenn null: `UIAccessibility.isVoiceOverRunning` ist nicht der Hebel, den man im Prozess ziehen kann — dann streicht Schritt 4 den Rückfall, und die Komponentenliste in Schritt 5 wird länger (alle `Button` in den Screens, nicht nur die Design-System-Komponenten).

- [ ] **Schritt 2: Registertests**

```swift
struct TestnotizElementRegisterTests {
    @Test func findetDasKleinsteRechteckUmDenPunkt() {
        var r = TestnotizElementRegister()
        r.melden(ElementEintrag(kennung: "karte", typ: "Card", rahmen: CGRect(x: 0, y: 0, width: 300, height: 200), file: "a", line: 1))
        r.melden(ElementEintrag(kennung: "knopf", typ: "PrimaryButton", rahmen: CGRect(x: 20, y: 120, width: 260, height: 64), file: "a", line: 9))
        #expect(r.treffer(punkt: CGPoint(x: 100, y: 150))?.kennung == "knopf")
        #expect(r.treffer(punkt: CGPoint(x: 100, y: 20))?.kennung == "karte")
        #expect(r.treffer(punkt: CGPoint(x: 400, y: 400)) == nil)
    }

    @Test func neueMeldungErsetztDenRahmenDerselbenKennung() { … }
    @Test func entfernenLoeschtDenEintrag() { … }
}
```

- [ ] **Schritt 3: Der Modifier**

```swift
private struct TestnotizElement: ViewModifier {
    let kennung: String, typ: String, file: String, line: Int
    func body(content: Content) -> some View {
        content
            .accessibilityIdentifier(kennung)
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .global)
            } action: { rahmen in
                Testnotiz.shared.register.melden(ElementEintrag(kennung: kennung, typ: typ, rahmen: rahmen, file: file, line: line))
            }
            .onDisappear { Testnotiz.shared.register.entfernen(kennung: kennung) }
    }
}
```

`.global` in SwiftUI ist der Koordinatenraum des Hosting-Views, nicht des Bildschirms; für die App-Wurzel im `WindowGroup` fallen beide zusammen, für ein Sheet nicht. Das Register speichert deshalb zusätzlich den Ursprung des Hosting-Fensters — `AuswahlOverlay` liefert Punkte in Fensterkoordinaten des Testnotiz-Fensters, das den ganzen Bildschirm füllt. **Annahme:** Für Sheets stimmt der Versatz nicht ohne Korrektur. Die Abnahme prüft `UebungWechselnSheet`; weicht es ab, wird die Korrektur über `UIView.convert` aus dem Hosting-View berechnet, den `TestnotizInstallation` ohnehin kennt.

`onGeometryChange(for:of:action:)` ist ab iOS 16 rückwirkend verfügbar (Xcode 16); Deployment Target ist iOS 17.

- [ ] **Schritt 4: Der Rückfall**

`AccessibilityBaum.alle(in:)` läuft rekursiv über `UIView`: ist `isAccessibilityElement`, aufnehmen; sonst `accessibilityElementCount()` / `accessibilityElement(at:)` (kann `NSObject`-Container liefern, die selbst wieder Elemente haben) und `subviews`. Rahmen ist `accessibilityFrame` (bereits Bildschirmkoordinaten). `element(an:in:)` nimmt das kleinste Rechteck um den Punkt und baut `TestnotizEintrag.Element(source: .accessibility, identifier: accessibilityIdentifier, label: accessibilityLabel, type: String(describing: type(of: element)), frame:, file: nil, line: nil)`.

- [ ] **Schritt 5: Markieren**

Die fünf Design-System-Komponenten bekommen `kennung: String? = nil` und rufen `.testnotizElement(kennung, typ: "PrimaryButton")` nur, wenn gesetzt — `#fileID` und `#line` zeigen dann auf die Komponente, nicht die Aufrufstelle. Deshalb reicht die Komponente beide **durch**: `PrimaryButton(title:kennung:file:line:)` mit `file: String = #fileID, line: Int = #line` als Vorgabewerte, die an der Aufrufstelle aufgelöst werden. So steht in der Notiz `GeraetView.swift:212`, nicht `PrimaryButton.swift:19`.

Kennungen, Punkt-Notation `screen.aktion`:

| Wo | Kennung |
| --- | --- |
| `MainTabView` Tabs | `tab.home`, `tab.training`, `tab.kurse`, `tab.profil` (`.accessibilityIdentifier` reicht hier — die Tab-Leiste ist UIKit und im AX-Baum) |
| `GeraetView` | `geraet.satz-sichern`, `geraet.abschliessen`, `geraet.weiterer-satz`, `geraet.uebung-wechseln`, `geraet.problem`, `geraet.rad-gewicht`, `geraet.rad-wiederholungen` |
| `TrainingRootView` | `training.scannen`, `training.geraet-waehlen`, `training.beenden` |
| `HomeRootView` | `home.scannen` |
| `KurseWochenView` | `kurse.woche-vor`, `kurse.woche-zurueck` |
| `ProfilRootView` | `profil.abmelden`, `profil.name`, `profil.satzziel` |

- [ ] **Schritt 6: Modus** — Menü „Element": Foto → `modus = .element` → `AuswahlOverlay(.punkt)` mit einem Fadenkreuz unter dem Finger → `beiPunkt`: erst Register, dann Baum; das gefundene Rechteck wird 400 ms in `accent` umrandet gezeigt (Bestätigung), dann `modus = .notiz`.

- [ ] **Schritt 7: Tests, Gerät, Commit** — `Testnotiz: Element-Register, AX-Rueckfall, 20 Kennungen`.

---

## Aufgabe 6: Notiz-Blatt und Sprachnotiz

**Dateien:**
- Anlegen: `FitnessMember/Testnotiz/NotizBlatt.swift`
- Anlegen: `FitnessMember/Testnotiz/Sprachnotiz.swift`
- Ändern: `Testnotiz.swift` (der `Entwurf` aus Aufgabe 4/5 wird hier zum Eintrag)

**Schnittstellen:**
- Nutzt: `Entwurf` (Vollbild, Ausschnitt, Element, Screen), `TestnotizAblage`
- Liefert:
  - `struct NotizBlatt: View` — Kopf (Screen-Name, Ausschnitt-Vorschau oder Element-Zeile), `TextField` mehrzeilig, Aufnahmeknopf (Halten oder Tippen-Tippen), „Sichern" als einzige Akzentfläche, „Verwerfen"
  - `final class Aufnahme` (`@MainActor`) — `starten() throws -> URL`, `stoppen() -> URL?`, `laeuft`
  - `enum Transkription { static func transkribieren(_ audio: URL) async -> String? }`

- [ ] **Schritt 1: Berechtigungen** — `AVAudioApplication.requestRecordPermission()` und `SFSpeechRecognizer.requestAuthorization` beim ersten Tipp auf den Aufnahmeknopf, nicht beim Start. Abgelehnt: der Knopf bleibt, mit dem Satz „Mikrofon in den Einstellungen freigeben" darunter (designsystem §5: nie stumm).

- [ ] **Schritt 2: Aufnahme** — `AVAudioSession` `.playAndRecord`, `.defaultToSpeaker`; `AVAudioRecorder` mit `kAudioFormatMPEG4AAC`, 44 100 Hz, 1 Kanal, in `temporaryDirectory`; die Ablage verschiebt die Datei beim Sichern nach `NN-notiz.m4a`.

- [ ] **Schritt 3: Transkription**

```swift
    static func transkribieren(_ audio: URL) async -> String? {
        guard let erkenner = SFSpeechRecognizer(locale: Locale(identifier: "de-DE")),
              erkenner.isAvailable, erkenner.supportsOnDeviceRecognition
        else { return nil }
        let anfrage = SFSpeechURLRecognitionRequest(url: audio)
        anfrage.requiresOnDeviceRecognition = true
        anfrage.shouldReportPartialResults = false
        return await withCheckedContinuation { fortsetzung in
            // Der Callback kommt mehrfach; nur das finale Ergebnis zaehlt,
            // und die Continuation darf genau einmal laufen.
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
```

Die Transkription läuft **nach** „Sichern" im Hintergrund; der Eintrag wird sofort mit `transcript: null` geschrieben und danach über `TestnotizAblage.transkriptNachtragen(index:text:)` neu geschrieben. So wartet niemand auf das Modell, und ein Absturz der Erkennung kostet nur das Transkript.

- [ ] **Schritt 4: Blatt** — als `.sheet` über dem Hosting-View des Testnotiz-Fensters, `presentationDetents([.medium, .large])`. Kopf zeigt den Ausschnitt in 96 pt Höhe oder die Element-Zeile in `Typography.body`; darunter der aktuelle Screen in `textMuted`. „Sichern" schreibt über die Ablage und setzt `modus = .ruhe`, `durchlaessig = true`.

- [ ] **Schritt 5: Gerät** — Ausschnitt, sprechen, sichern; nach ein paar Sekunden steht das Transkript in `sitzung.md`. Ohne deutsches Modell (Einstellungen → Allgemein → Tastatur → Diktat-Sprachen prüfen): der Satz „Transkript fehlt, Audio liegt bei". Commit: `Testnotiz: Notiz-Blatt, Sprachnotiz, On-Device-Transkript`.

---

## Aufgabe 7: Laufzeitkontext und Protokoll

**Dateien:**
- Anlegen: `FitnessMember/Testnotiz/Laufzeitkontext.swift`
- Anlegen: `FitnessMemberTests/ProtokollTests.swift`
- Ändern: `Testnotiz.swift` (beim Sichern befüllen), `FitnessMemberApp.swift` (die Stores hereinreichen)

**Schnittstellen:**
- Nutzt: `NetzwerkMonitor.istOnline`, `CatalogStore.pendingWrites.count`, `SessionStore.session != nil`, `CatalogStore`-Studio-ID
- Liefert:
  - `enum Laufzeitkontext { @MainActor static func jetzt(netz:, katalog:, session:) -> TestnotizEintrag.Laufzeit }`
  - `enum Protokoll { static func lesen(seit: TimeInterval, subsystem: String) throws -> [TestnotizEintrag.Protokollzeile]`, `static func zeile(aus: OSLogEntryLog) -> Protokollzeile` }
  - `TestnotizSitzung.Geraet.jetzt()`, `TestnotizSitzung.App.jetzt()` — `utsname` für das Modell (`iPhone14,4`, nicht „iPhone"), `Bundle.main` für Version und Build, `"Debug"` fest

- [ ] **Schritt 1: Zeilenform testen** — `zeile(aus:)` bekommt im Test keinen `OSLogEntryLog` (nicht konstruierbar); getestet wird die Stufe daneben: `Protokollzeile(level:)` aus `OSLogEntryLog.Level` (`.info → "info"`, `.error → "error"`, `.fault → "fault"`, `.debug → "debug"`, `.notice → "notice"`) und das Markdown-Zeitformat `HH:mm:ss`. Klein, aber es ist die Stelle, an der eine unbekannte Stufe sonst `"undefined"` schriebe.

- [ ] **Schritt 2: Lesen**

```swift
    static func lesen(seit sekunden: TimeInterval, subsystem: String) throws -> [TestnotizEintrag.Protokollzeile] {
        let speicher = try OSLogStore(scope: .currentProcessIdentifier)
        let ab = speicher.position(date: Date().addingTimeInterval(-sekunden))
        let praedikat = NSPredicate(format: "subsystem == %@", subsystem)
        return try speicher.getEntries(at: ab, matching: praedikat)
            .compactMap { $0 as? OSLogEntryLog }
            .map(zeile(aus:))
    }
```

Fünf Minuten, Subsystem `de.gymtaro.member`. `composedMessage` liefert geschwärzte Werte als `<private>` — genau richtig, siehe Rahmenbedingung 2.

- [ ] **Schritt 3: Stores hereinreichen** — `Testnotiz.shared.quellen = Quellen(netz:, katalog:, session:)` in `FitnessMemberApp.init` unter `#if DEBUG`; `Testnotiz` hält sie `weak`, damit ein Reset der Stores nicht am Modul hängt.

- [ ] **Schritt 4: Gerät, Commit** — `Testnotiz: Laufzeitkontext und OSLog-Auszug je Eintrag`.

---

## Aufgabe 8: Sitzungen, Teilen, der Eingang im Repo

**Dateien:**
- Anlegen: `FitnessMember/Testnotiz/SitzungBlatt.swift`
- Anlegen: `apps/ios-member/testnotizen/README.md`
- Ändern: `.gitignore`, `TestnotizKnopf.swift`, `TestnotizAblage.swift`

**Schnittstellen:**
- Nutzt: `TestnotizAblage.zipFuerTeilen()`
- Liefert: Menü „Sitzung…" → Blatt mit Zähler, „Neue Sitzung beginnen", „Sitzung teilen" (`UIActivityViewController` mit der Zip), „Ordner in Files öffnen" (`shareddocuments://`-URL auf den Sitzungsordner)

- [ ] **Schritt 1: Sitzung im Modul** — beim ersten Eintrag nach App-Start oder nach „Neue Sitzung" legt die Ablage den Ordner an; `Testnotiz.shared.sitzung` hält URL und Zähler, `@Observable`, damit das Blatt live zählt.

- [ ] **Schritt 2: `.gitignore`**

```
# Testsitzungen vom Geraet (Testnotiz-Modul) -- lokaler Eingang fuer Claude Code
apps/ios-member/testnotizen/*
!apps/ios-member/testnotizen/README.md
```

- [ ] **Schritt 3: README im Eingang** — drei Absätze: wie der Ordner vom Telefon hierher kommt (Finder → Gerät → Dateien → FitnessMember, oder AirDrop der Zip), der Auftrag an Claude Code als ein Satz zum Kopieren, und der Hinweis, dass alles hier gitignoriert ist, weil Screenshots Trainingsdaten zeigen.

- [ ] **Schritt 4: Gerät** — zwei Sitzungen anlegen, eine teilen, per AirDrop auf den Mac, in den Eingang, `sitzung.md` in Claude Code lesen lassen. Das ist der eigentliche Abnahmetest des ganzen Plans: **Kommt eine brauchbare Änderung heraus, ohne dass man den Fund noch einmal erklären muss?** Ergebnis als Satz in die Commit-Nachricht. Commit: `Testnotiz: Sitzungen, Zip-Teilen, Eingang im Repo`.

---

## Aufgabe 9: Den Vertrag herausheben

**Dateien:**
- Anlegen: `docs/superpowers/specs/2026-09-13-testnotiz-format.md` — §2 dieses Plans, plus: die Fixture aus Aufgabe 2 als verbindliches Beispiel (Verweis auf `FitnessMemberTests/Fixtures/testnotiz-beispiel.json`), die Regel „`null` statt weglassen", `format`-Versionierung (`/1`; jede brechende Änderung zählt hoch, und Leser prüfen den String), und der Android-Abschnitt aus §1.8 als „so erfüllt Android denselben Vertrag".
- Ändern: dieser Plan — §2 wird durch einen Verweis auf die Spec ersetzt, damit es genau eine Fassung gibt.

- [ ] **Schritt 1: Spec schreiben, Verweise setzen, Commit** — `Testnotiz: Format-Vertrag als Spec, Android-Vorbereitung`.

---

## Manuelle Abnahme

Alles, was Fenster, Foto, Berührung oder Mikrofon anfasst, beweist kein Test. Am Gerät, nicht im Simulator (Mikrofon, Files-App, Modellverfügbarkeit der Spracherkennung):

- [ ] Debug-Build: Knopf sichtbar, über der Tab-Leiste und über einem Alert; verschiebbar; die App darunter ist überall bedienbar, auch direkt neben dem Knopf.
- [ ] Release-Build (`strings`, `plutil`, Schritt 6 von Aufgabe 1): nichts.
- [ ] Screen-Name stimmt auf allen vier Tabs, nach dem Push zum Gerät, nach dem Zurück, mit offenem und geschlossenem `UebungWechselnSheet`, im `ErstkontaktFlow` je Schritt.
- [ ] Ausschnitt: Vollbild ohne Menü und Knopf; Ausschnitt deckt sich pixelgenau mit dem gezogenen Rechteck (an einer Textzeile prüfen); Alert im Bild, wenn einer offen ist.
- [ ] Element: Tipp auf „Satz sichern" liefert `geraet.satz-sichern` mit `GeraetView.swift:<Zeile>`; Tipp auf einen unmarkierten Text liefert sein Label aus dem AX-Baum (oder, falls der Spike durchfiel, „kein Element").
- [ ] Element im Sheet: Rahmen stimmt (Annahme aus Aufgabe 5, Schritt 3).
- [ ] Sprachnotiz: Aufnahme, Transkript in Deutsch; ohne Modell der Ersatzsatz.
- [ ] Protokoll: nach einem Tag-Scan stehen die `TagProtokoll`-Zeilen im Eintrag.
- [ ] Sitzung teilen → AirDrop → Eingang → Claude Code: eine Änderung ohne Rückfrage.
- [ ] Kein Anzeigename, keine E-Mail, kein Token in `sitzung.json` (`grep -i` über den Ordner nach der eigenen Adresse).

---

## Selbstprüfung

- Jede Aufgabe endet mit einem Build oder Test **und** einem Blick aufs Gerät; keine schließt mit „sollte funktionieren".
- Die drei Annahmen (Push-`onDisappear`, AX-Baum im Prozess, Sheet-Koordinaten) haben je einen Prüfschritt und einen Rückfallweg.
- Der Vertrag (§2) hat einen Test, der ihn liest, nicht nur einen, der ihn schreibt.
- Rahmenbedingung 1 (kein Byte im Release) hat einen maschinellen Beweis in Aufgabe 1.
- Rahmenbedingung 2 (keine Personendaten) hat einen Abnahmepunkt mit `grep`.
- Nichts in diesem Plan legt eine `.sql`-Datei an, ändert `packages/domain` oder `apps/web`.
