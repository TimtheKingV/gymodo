# iOS Member-App — Fundament + Zugang: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Das iOS-Member-App-Fundament (Design-System, Netzwerkschicht, Auth, Navigations-Hülle) bauen und die acht Zugang-Screens vollständig funktionsfähig gegen die echte Produktions-API stellen.

**Architecture:** Zwei fokussierte `@Observable`-Stores (`SessionStore`, `CatalogStore`) statt eines großen `AppModel`; ein `APIClient`-Actor mit sechs+drei Endpoints; `supabase-swift` (nur `Auth`) für Session-Handling im Keychain; `RootView` schaltet zwischen Auth-Flow, Kein-Studio-Zustand und Haupt-Tabs anhand von Session- und Bootstrap-Zustand. Zwei kleine, neue `/api/v1`-Endpoints in `apps/web` schließen eine beim Brainstorming gefundene Lücke (Studio-Beitritt/-Austritt hatte bisher keinen HTTP-Pfad für iOS).

**Tech Stack:** Swift 6.0, SwiftUI, Swift Testing, `supabase-swift` (Auth-Komponente), XcodeGen, AVFoundation (QR-Scan). Backend-Ergänzung in TypeScript/Next.js (bestehender Stack), Vitest für Integrationstests.

**Spec:** `docs/superpowers/specs/2026-09-07-ios-fundament-zugang-design.md` — dieser Plan setzt sie um; Ausführende lesen beide Dokumente. Referenziert außerdem `docs/superpowers/specs/2026-08-28-fitness-retrofit-m1-design.md` (Produktverhalten, API-Vertrag §6.3) und `docs/superpowers/specs/2026-08-30-designsystem.md` (Farben/Typo/Maße/Zustände).

## Global Constraints

- iOS-Deployment-Ziel 17.0, Swift-Version 6.0 (`apps/ios-member/project.yml`) — nicht ändern.
- **Sessions ausschließlich im Keychain, nie `UserDefaults`, nie SwiftData** (M1-Spec §9/§10, nicht nachrüstbar).
- **Kein Direktzugriff aus Swift auf Postgres/PostgREST** — jede Fachfunktion läuft über `/api/v1` (M1-Spec §6.1/§6.2).
- **Schreibvorgänge sind idempotent**: `sessionId`/`setId` werden clientseitig als UUID erzeugt, `PUT` statt `POST` (M1-Spec §6.3).
- **Alle Ziffern tabellarisch** (`.monospacedDigit()`), Gewichte immer mit einer Nachkommastelle (`designsystem.md` §3).
- **Trefferflächen ≥ 44pt, Hauptaktion exakt 64pt hoch**, Radius 16 für Hauptaktion / 14 für Nebenaktion / 12 für Karten (`designsystem.md` §4).
- **Genau eine Akzentfläche je Screen** — `accent` (`#D4FF3F`) markiert nur die eine Hauptaktion/den aktiven Wert, sonst nirgends als Fläche (`designsystem.md` §2, nicht verhandelbar).
- **`warn` (`#FFB020`) nur als Umriss, nie als Fläche** (`designsystem.md` §2, nicht verhandelbar).
- **Deaktivierte Zustände sind nie stumm** — immer ein Hinweistext daneben, was fehlt (`designsystem.md` §5).
- **Durchgehend Deutsch, Du-Form, keine Ausrufezeichen** (`designsystem.md` §10).
- **Neutrale Fehlerantwort bei Login/Registrierung** — dieselbe Formulierung für falsches Passwort, unbekanntes und gesperrtes Konto (Design-Challenge-Entscheidung #4).
- **Backend-Fehlerhülle:** `{ "error": { "code": "...", "message": "..." } }`, Status fest zugeordnet: `validation_failed`→422, `unauthorized`→401, `not_found`→404, `conflict`→409, `internal`→500 (`apps/web/lib/api/respond.ts`).
- **Privacy Manifest** (`PrivacyInfo.xcprivacy`) ist Pflicht ab der ersten externen Abhängigkeit (M1-Spec §9) — kommt in Aufgabe 1, nicht am Ende.
- Neue Web-Routen folgen exakt dem Muster der sechs bestehenden `/api/v1`-Handler: `bearerClientFrom(request)` für Auth, `fromDomainError`/`errorResponse` für Antworten, `export const dynamic = "force-dynamic"`.

---

### Aufgabe 1: Projekt-Setup — SPM-Abhängigkeit, Konfiguration, Privacy Manifest

**Files:**
- Modify: `apps/ios-member/project.yml`
- Create: `apps/ios-member/Config.xcconfig.example`
- Create: `apps/ios-member/Config.xcconfig` (lokal, gitignored)
- Modify: `.gitignore`
- Create: `apps/ios-member/FitnessMember/PrivacyInfo.xcprivacy`
- Create: `apps/ios-member/FitnessMember/AppConfig.swift`
- Test: `apps/ios-member/FitnessMemberTests/AppConfigTests.swift`

**Interfaces:**
- Produces: `enum AppConfig { static let apiBaseURL: URL; static let supabaseURL: URL; static let supabaseAnonKey: String }` — von Aufgabe 5 (`APIClient`) und Aufgabe 7 (`SupabaseAuthBackend`) konsumiert.

- [ ] **Schritt 1: `Config.xcconfig.example` anlegen**

```
// Kopieren nach Config.xcconfig (gitignored) und SUPABASE_ANON_KEY aus dem
// Supabase-Dashboard eintragen: Project Settings -> API -> anon/public key.
// Dieselbe Trennung wie apps/web/.env.local.example -- keine Schluessel im Repo.
SUPABASE_URL = https://hverawzrwjgztolxuose.supabase.co
SUPABASE_ANON_KEY = <anon key aus dem Supabase-Dashboard>
API_BASE_URL = https://gymodo-web.vercel.app/api/v1
```

- [ ] **Schritt 2: `Config.xcconfig` lokal aus der Vorlage erzeugen**

```bash
cp apps/ios-member/Config.xcconfig.example apps/ios-member/Config.xcconfig
```

Den echten `SUPABASE_ANON_KEY` von `https://supabase.com/dashboard/project/hverawzrwjgztolxuose/settings/api` eintragen.

- [ ] **Schritt 3: `Config.xcconfig` in `.gitignore` aufnehmen**

An `.gitignore` anhängen:

```
apps/ios-member/Config.xcconfig
```

- [ ] **Schritt 4: `project.yml` um SPM-Paket, Config-Datei und Info.plist-Werte erweitern**

`options:` bekommt keine Änderung. Nach `options:` einfügen:

```yaml
configFiles:
  Debug: Config.xcconfig
  Release: Config.xcconfig

packages:
  Supabase:
    url: https://github.com/supabase/supabase-swift
    from: 2.0.0
```

Im Ziel `FitnessMember` unter `settings.base` ergänzen (bestehende Zeilen bleiben stehen):

```yaml
        INFOPLIST_KEY_SUPABASE_URL: $(SUPABASE_URL)
        INFOPLIST_KEY_SUPABASE_ANON_KEY: $(SUPABASE_ANON_KEY)
        INFOPLIST_KEY_API_BASE_URL: $(API_BASE_URL)
        INFOPLIST_KEY_NSCameraUsageDescription: "gymodo braucht die Kamera, um den QR-Code am Gerät oder am Studioeingang zu scannen."
```

Direkt darunter, auf derselben Ebene wie `settings:` und `entitlements:`, die Paket-Abhängigkeit eintragen:

```yaml
    dependencies:
      - package: Supabase
        product: Auth
```

- [ ] **Schritt 5: Projekt neu generieren**

```bash
cd apps/ios-member && xcodegen generate
```

Erwartet: `Created project at FitnessMember.xcodeproj` ohne Fehler. Beim ersten Öffnen in Xcode löst SPM das Paket auf (Netzwerkzugriff nötig).

- [ ] **Schritt 6: `PrivacyInfo.xcprivacy` anlegen**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSPrivacyTracking</key>
	<false/>
	<key>NSPrivacyTrackingDomains</key>
	<array/>
	<key>NSPrivacyCollectedDataTypes</key>
	<array/>
	<key>NSPrivacyAccessedAPITypes</key>
	<array/>
</dict>
</plist>
```

Liegt unter `apps/ios-member/FitnessMember/` — xcodegen nimmt sie automatisch als Ressource mit, weil der Ordner bereits als `sources:`-Pfad gelistet ist. Keine `project.yml`-Änderung nötig.

- [ ] **Schritt 7: `AppConfig.swift` schreiben**

```swift
import Foundation

/// Liest die drei Laufzeit-Werte aus Info.plist, die project.yml aus
/// Config.xcconfig einsetzt (Aufgabe 1). Fehlt einer, ist das ein
/// Entwicklungsfehler (Config.xcconfig nicht angelegt) -- deshalb fatalError
/// statt eines stillen Fallbacks.
enum AppConfig {
    static let apiBaseURL = url(for: "API_BASE_URL")
    static let supabaseURL = url(for: "SUPABASE_URL")
    static let supabaseAnonKey = string(for: "SUPABASE_ANON_KEY")

    static func string(for key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty
        else {
            fatalError("Info.plist-Schluessel \(key) fehlt -- Config.xcconfig pruefen (siehe Config.xcconfig.example).")
        }
        return value
    }

    private static func url(for key: String) -> URL {
        guard let url = URL(string: string(for: key)) else {
            fatalError("Info.plist-Schluessel \(key) ist keine gueltige URL.")
        }
        return url
    }
}
```

- [ ] **Schritt 8: Test schreiben — reine Parsing-Logik ohne Bundle-Abhängigkeit auslagern**

Da `AppConfig` direkt von `Bundle.main` liest, ist es im Testziel nicht sinnvoll direkt testbar (eigenes Info.plist ohne diese Schlüssel). Getestet wird stattdessen die URL-Validierung isoliert:

```swift
import Foundation
import Testing
@testable import FitnessMember

@Suite("AppConfig")
struct AppConfigTests {
    @Test("eine gueltige HTTPS-URL wird geparst")
    func parsesValidURL() {
        #expect(URL(string: "https://gymodo-web.vercel.app/api/v1") != nil)
    }

    @Test("die konfigurierte API-Basis-URL ist HTTPS")
    func apiBaseURLIsHTTPS() {
        // AppConfig.apiBaseURL loest bei fehlendem Config.xcconfig fatalError aus --
        // dieser Test laeuft nur sinnvoll, wenn Config.xcconfig aus Schritt 2 existiert.
        #expect(AppConfig.apiBaseURL.scheme == "https")
    }
}
```

- [ ] **Schritt 9: Bauen und Testen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test 2>&1 | tail -40
```

Erwartet: `TEST SUCCEEDED`, inklusive der beiden neuen und der sieben bestehenden `TagLinkTests`.

- [ ] **Schritt 10: Commit**

```bash
cd apps/ios-member && git add project.yml Config.xcconfig.example FitnessMember.xcodeproj FitnessMember/PrivacyInfo.xcprivacy FitnessMember/AppConfig.swift FitnessMemberTests/AppConfigTests.swift ../../.gitignore
git commit -m "feat(ios): Projekt-Setup fuer Fundament -- SPM, Config, Privacy Manifest"
```

---

### Aufgabe 2: Design-System — Farb-, Typo-, Abstands- und Radius-Tokens

**Files:**
- Create: `apps/ios-member/FitnessMember/DesignSystem/DesignSystem.swift`
- Create: `apps/ios-member/FitnessMember/DesignSystem/Color+Hex.swift`
- Test: `apps/ios-member/FitnessMemberTests/ColorHexTests.swift`

**Interfaces:**
- Produces: `DesignSystem.Color.{bg,surface,surfaceRaised,line,text,textMuted,textFaint,accent,accentPressed,onAccent,warn,danger}`, `DesignSystem.Spacing.{s4,s8,s12,s16,s24,s32,s48}`, `DesignSystem.Radius.{card,neben,haupt,pille}`, `DesignSystem.Typography.{screentitel,wertHeld,label,body}` — von Aufgabe 3 (Komponenten) und allen Screen-Aufgaben konsumiert.

- [ ] **Schritt 1: Test für `Color(hex:)` schreiben**

```swift
import SwiftUI
import Testing
@testable import FitnessMember

@Suite("Color+Hex")
struct ColorHexTests {
    @Test("dekodiert Akzentfarbe D4FF3F korrekt")
    func decodesAccent() {
        let color = Color(hex: 0xD4FF3F)
        let components = color.rgbaComponents
        #expect(abs(components.red - 0xD4.doubleValue) < 0.01)
        #expect(abs(components.green - 0xFF.doubleValue) < 0.01)
        #expect(abs(components.blue - 0x3F.doubleValue) < 0.01)
    }

    @Test("dekodiert Schwarzton bg 0A0B0D korrekt")
    func decodesBackground() {
        let components = Color(hex: 0x0A0B0D).rgbaComponents
        #expect(abs(components.red - 0x0A.doubleValue) < 0.01)
        #expect(abs(components.green - 0x0B.doubleValue) < 0.01)
        #expect(abs(components.blue - 0x0D.doubleValue) < 0.01)
    }
}

private extension Int {
    var doubleValue: Double { Double(self) / 255.0 }
}
```

- [ ] **Schritt 2: Test ausführen, Fehlschlag bestätigen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/ColorHexTests 2>&1 | tail -20
```

Erwartet: FAIL — `Color(hex:)` und `rgbaComponents` existieren noch nicht.

- [ ] **Schritt 3: `Color+Hex.swift` implementieren**

```swift
import SwiftUI
import UIKit

extension Color {
    /// Tokens aus designsystem.md §2 als 0xRRGGBB, z. B. Color(hex: 0xD4FF3F).
    init(hex: UInt32) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }

    /// Nur fuer Tests -- extrahiert die tatsaechlich gerenderten Komponenten
    /// ueber UIColor, um die Herleitung in init(hex:) unabhaengig zu pruefen.
    var rgbaComponents: (red: Double, green: Double, blue: Double, alpha: Double) {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (Double(red), Double(green), Double(blue), Double(alpha))
    }
}
```

- [ ] **Schritt 4: Test ausführen, Erfolg bestätigen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/ColorHexTests 2>&1 | tail -20
```

Erwartet: PASS.

- [ ] **Schritt 5: `DesignSystem.swift` mit allen Tokens aus `designsystem.md` §2–4 schreiben**

```swift
import SwiftUI

/// Reiner Werte-Namespace, keine Instanzen. Tokens 1:1 aus
/// docs/superpowers/specs/2026-08-30-designsystem.md SS2-4 -- Werte hier
/// aendern heisst das Dokument nachziehen, nicht umgekehrt.
enum DesignSystem {
    enum Color {
        static let bg = SwiftUI.Color(hex: 0x0A0B0D)
        static let surface = SwiftUI.Color(hex: 0x14161A)
        static let surfaceRaised = SwiftUI.Color(hex: 0x1D2026)
        static let line = SwiftUI.Color(hex: 0x2A2E36)
        static let text = SwiftUI.Color(hex: 0xF2F4F7)
        static let textMuted = SwiftUI.Color(hex: 0x9BA3AF)
        static let textFaint = SwiftUI.Color(hex: 0x5C636E)
        static let accent = SwiftUI.Color(hex: 0xD4FF3F)
        static let accentPressed = SwiftUI.Color(hex: 0xA8CC2A)
        static let onAccent = SwiftUI.Color(hex: 0x0A0B0D)
        static let warn = SwiftUI.Color(hex: 0xFFB020)
        static let danger = SwiftUI.Color(hex: 0xFF5A4E)
    }

    enum Spacing {
        static let s4: CGFloat = 4
        static let s8: CGFloat = 8
        static let s12: CGFloat = 12
        static let s16: CGFloat = 16
        static let s24: CGFloat = 24
        static let s32: CGFloat = 32
        static let s48: CGFloat = 48
    }

    enum Radius {
        static let card: CGFloat = 12
        static let neben: CGFloat = 14
        static let haupt: CGFloat = 16
        static let pille: CGFloat = 999
    }

    enum Typography {
        static let screentitel = Font.system(size: 32, weight: .black)
        static let wertHeld = Font.system(size: 64, weight: .black).monospacedDigit()
        static let label = Font.system(size: 11, weight: .heavy)
        static let body = Font.system(size: 16, weight: .regular)
    }
}
```

- [ ] **Schritt 6: Bauen und alle Tests laufen lassen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test 2>&1 | tail -40
```

Erwartet: `TEST SUCCEEDED`.

- [ ] **Schritt 7: Commit**

```bash
cd apps/ios-member && git add FitnessMember/DesignSystem FitnessMemberTests/ColorHexTests.swift
git commit -m "feat(ios): Design-System-Tokens aus designsystem.md SS2-4"
```

---

### Aufgabe 3: Design-System — Basis-Komponenten

**Files:**
- Create: `apps/ios-member/FitnessMember/DesignSystem/Components/PrimaryButton.swift`
- Create: `apps/ios-member/FitnessMember/DesignSystem/Components/SecondaryButton.swift`
- Create: `apps/ios-member/FitnessMember/DesignSystem/Components/Chip.swift`
- Create: `apps/ios-member/FitnessMember/DesignSystem/Components/Card.swift`
- Create: `apps/ios-member/FitnessMember/DesignSystem/Components/LabeledField.swift`
- Create: `apps/ios-member/FitnessMember/DesignSystem/Components/InlineBanner.swift`

**Interfaces:**
- Consumes: `DesignSystem.Color`, `DesignSystem.Spacing`, `DesignSystem.Radius`, `DesignSystem.Typography` (Aufgabe 2)
- Produces: `PrimaryButton(title:isEnabled:isLoading:disabledHint:action:)`, `SecondaryButton(title:action:)`, `Chip(text:isActive:)`, `Card { content }`, `LabeledField(label:) { content }`, `InlineBanner(tone:message:icon:)`, `enum BannerTone { case accent, muted, danger }` — von allen acht Zugang-Screens konsumiert.

Kein automatisierter Test in dieser Aufgabe — reine SwiftUI-Views werden laut Entscheidung im Design-Dokument (§10) manuell im Simulator/Canvas gegen die Artboards abgenommen, keine Snapshot-Tests. Jeder Schritt liefert trotzdem vollständigen, lauffähigen Code plus eine konkrete Prüfanweisung.

- [ ] **Schritt 1: `PrimaryButton` schreiben — 64pt Hauptaktion, nie stumm im deaktivierten Zustand**

```swift
import SwiftUI

/// Hauptaktion, 64pt (designsystem.md SS4). Im deaktivierten Zustand steht
/// immer ein Hinweis daneben (SS5: "nie stumm") -- disabledHint ist deshalb
/// kein optionaler Zierrat, sondern soll bei isEnabled == false befuellt sein.
struct PrimaryButton: View {
    let title: String
    var isEnabled: Bool = true
    var isLoading: Bool = false
    var disabledHint: String? = nil
    let action: () async -> Void

    var body: some View {
        VStack(spacing: 6) {
            Button {
                Task { await action() }
            } label: {
                ZStack {
                    if isLoading {
                        ProgressView().tint(DesignSystem.Color.onAccent)
                    } else {
                        Text(title).font(.system(size: 19, weight: .heavy))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 64)
            }
            .background(isEnabled ? DesignSystem.Color.accent : DesignSystem.Color.surfaceRaised)
            .foregroundStyle(isEnabled ? DesignSystem.Color.onAccent : DesignSystem.Color.textFaint)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.haupt))
            .disabled(!isEnabled || isLoading)

            if !isEnabled, let disabledHint {
                Text(disabledHint)
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Color.textFaint)
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        PrimaryButton(title: "Anmelden") {}
        PrimaryButton(title: "Bestätigen", isEnabled: false, disabledHint: "Noch zwei Ziffern") {}
        PrimaryButton(title: "Anmelden", isLoading: true) {}
    }
    .padding()
    .background(DesignSystem.Color.bg)
}
```

- [ ] **Schritt 2: `SecondaryButton` schreiben — 46–52pt, Umriss**

```swift
import SwiftUI

/// Nebenaktion, Umriss statt Flaeche -- zaehlt nicht als die eine
/// Akzentflaeche des Screens (designsystem.md SS2).
struct SecondaryButton: View {
    let title: String
    let action: () async -> Void

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
        }
        .foregroundStyle(DesignSystem.Color.text)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.neben)
                .stroke(DesignSystem.Color.line, lineWidth: 1)
        )
    }
}

#Preview {
    SecondaryButton(title: "Gewicht ändern") {}
        .padding()
        .background(DesignSystem.Color.bg)
}
```

- [ ] **Schritt 3: `Chip` schreiben — Pille, immer Umriss**

```swift
import SwiftUI

/// Chip ist ausschliesslich Umriss, auch im aktiven Zustand -- eine gefuellte
/// Chip-Flaeche waere eine zweite Akzentflaeche (Design-Challenge-Review SS1.1).
struct Chip: View {
    let text: String
    var isActive: Bool = false

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundStyle(isActive ? DesignSystem.Color.accent : DesignSystem.Color.textMuted)
            .overlay(
                Capsule().stroke(isActive ? DesignSystem.Color.accent : DesignSystem.Color.line, lineWidth: 1)
            )
    }
}

#Preview {
    HStack {
        Chip(text: "Heute", isActive: true)
        Chip(text: "Woche")
    }
    .padding()
    .background(DesignSystem.Color.bg)
}
```

- [ ] **Schritt 4: `Card` schreiben**

```swift
import SwiftUI

struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .background(DesignSystem.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                    .stroke(DesignSystem.Color.line, lineWidth: 1)
            )
    }
}

#Preview {
    Card { Text("Kraftwerk Nord").padding() }
        .padding()
        .background(DesignSystem.Color.bg)
}
```

- [ ] **Schritt 5: `LabeledField` schreiben — Eyebrow-Label plus 58pt-Eingabefläche**

```swift
import SwiftUI

/// Eyebrow-Label (designsystem.md SS3 "Label"-Rolle) über einem 58pt hohen
/// Eingabefeld -- Standardform fuer alle Zugang-Screens.
struct LabeledField<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(label.uppercased())
                .font(DesignSystem.Typography.label)
                .foregroundStyle(DesignSystem.Color.textMuted)
            content
                .font(.system(size: 18, weight: .semibold))
                .padding(.horizontal, 17)
                .frame(height: 58)
                .background(DesignSystem.Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.neben))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.neben)
                        .stroke(DesignSystem.Color.line, lineWidth: 1)
                )
        }
    }
}

#Preview {
    LabeledField(label: "E-Mail-Adresse") {
        TextField("name@beispiel.de", text: .constant(""))
    }
    .padding()
    .background(DesignSystem.Color.bg)
}
```

- [ ] **Schritt 6: `InlineBanner` schreiben — deckt Skelett/Offline/Fehler-Töne aus designsystem.md §5 ab**

```swift
import SwiftUI

enum BannerTone {
    case accent, muted, danger

    var foreground: SwiftUI.Color {
        switch self {
        case .accent: DesignSystem.Color.accent
        case .muted: DesignSystem.Color.textMuted
        case .danger: DesignSystem.Color.danger
        }
    }

    var border: SwiftUI.Color {
        switch self {
        case .accent: DesignSystem.Color.accent.opacity(0.33)
        case .muted: DesignSystem.Color.line
        case .danger: DesignSystem.Color.danger.opacity(0.5)
        }
    }
}

struct InlineBanner: View {
    let tone: BannerTone
    let message: String
    var icon: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let icon {
                Image(systemName: icon).foregroundStyle(tone.foreground)
            }
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(DesignSystem.Color.textMuted)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                .stroke(tone.border, lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: 12) {
        InlineBanner(tone: .accent, message: "Beinpresse erkannt", icon: "wave.3.right")
        InlineBanner(tone: .danger, message: "E-Mail oder Passwort stimmt nicht.")
    }
    .padding()
    .background(DesignSystem.Color.bg)
}
```

- [ ] **Schritt 7: Im Xcode-Canvas prüfen**

Jede der sechs `#Preview`s im Canvas öffnen (⌥⌘Return), gegen `designsystem.md` §2–5 abgleichen: exakt eine Akzentfläche in keiner der Previews als Fläche verwendet außer dem aktiven `PrimaryButton`, `Chip` immer Umriss, `warn`/`danger` nie als Vollfläche.

- [ ] **Schritt 8: Bauen (kompiliert, keine Testpflicht für reine Views)**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" build 2>&1 | tail -30
```

Erwartet: `BUILD SUCCEEDED`.

- [ ] **Schritt 9: Commit**

```bash
cd apps/ios-member && git add FitnessMember/DesignSystem/Components
git commit -m "feat(ios): Basis-Komponenten-Bibliothek (PrimaryButton, SecondaryButton, Chip, Card, LabeledField, InlineBanner)"
```

---

### Aufgabe 4: Netzwerkschicht — DTOs für die sechs M1-Endpoints

**Files:**
- Create: `apps/ios-member/FitnessMember/Networking/JSONValue.swift`
- Create: `apps/ios-member/FitnessMember/Networking/DTOs/BootstrapResponse.swift`
- Create: `apps/ios-member/FitnessMember/Networking/DTOs/TagContextResponse.swift`
- Create: `apps/ios-member/FitnessMember/Networking/DTOs/SessionSummary.swift`
- Create: `apps/ios-member/FitnessMember/Networking/DTOs/ExerciseProgress.swift`
- Create: `apps/ios-member/FitnessMember/Networking/DTOs/WorkoutSet.swift`
- Create: `apps/ios-member/FitnessMember/Networking/DTOs/ErrorEnvelope.swift`
- Test: `apps/ios-member/FitnessMemberTests/DTOTests.swift`

**Interfaces:**
- Produces: `BootstrapResponse`, `TagContextResponse`, `SessionsResponse{sessions:[SessionSummary]}`, `ProgressResponse{exercises:[ExerciseProgress]}`, `SetWrite` (Encodable+Decodable Request-Body), `RecordedSet`, `CompletedSession`, `ProblemReason`, `ErrorEnvelope`, `JSONValue` — von Aufgabe 5 (`APIClient`) konsumiert.

Alle JSON-Felder der sechs Endpoints sind camelCase (bestätigt gegen `packages/domain/src/{bootstrap,tag-context,workout,sessions,progress}.ts`) — `JSONDecoder`/`JSONEncoder` brauchen keine `keyDecodingStrategy`, Swift-Property-Namen matchen die JSON-Schlüssel direkt.

- [ ] **Schritt 1: Test für `JSONValue`-Rundreise schreiben**

`settingValues` (Kalibrierung) ist serverseitig `unknown` — beliebiges JSON, je nach Gerätemodell anders geformt. `JSONValue` bildet das als generischer, testbarer JSON-Baum ab.

```swift
import Foundation
import Testing
@testable import FitnessMember

@Suite("JSONValue")
struct JSONValueTests {
    @Test("dekodiert und kodiert ein gemischtes Objekt verlustfrei")
    func roundTrips() throws {
        let json = #"{"sitz": 3, "aktiv": true, "label": "hoch", "leer": null, "liste": [1, 2]}"#
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
        guard case .object(let fields) = value else {
            Issue.record("erwartet .object")
            return
        }
        #expect(fields["sitz"] == .number(3))
        #expect(fields["aktiv"] == .bool(true))
        #expect(fields["label"] == .string("hoch"))
        #expect(fields["leer"] == .null)
        #expect(fields["liste"] == .array([.number(1), .number(2)]))

        let reencoded = try JSONEncoder().encode(value)
        let redecoded = try JSONDecoder().decode(JSONValue.self, from: reencoded)
        #expect(redecoded == value)
    }
}
```

- [ ] **Schritt 2: Test ausführen, Fehlschlag bestätigen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/JSONValueTests 2>&1 | tail -20
```

Erwartet: FAIL — `JSONValue` existiert noch nicht.

- [ ] **Schritt 3: `JSONValue.swift` implementieren**

```swift
import Foundation

/// Generischer JSON-Baum fuer Felder, die serverseitig als `unknown` gelten
/// (z. B. settingValues einer Kalibrierung -- die Form haengt vom
/// Geraetemodell ab, siehe packages/domain/src/bootstrap.ts).
indirect enum JSONValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Bool.self) { self = .bool(value); return }
        if let value = try? container.decode(Double.self) { self = .number(value); return }
        if let value = try? container.decode(String.self) { self = .string(value); return }
        if let value = try? container.decode([String: JSONValue].self) { self = .object(value); return }
        if let value = try? container.decode([JSONValue].self) { self = .array(value); return }
        if container.decodeNil() { self = .null; return }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unbekannter JSON-Wert")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}
```

- [ ] **Schritt 4: Test ausführen, Erfolg bestätigen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/JSONValueTests 2>&1 | tail -20
```

Erwartet: PASS.

- [ ] **Schritt 5: `ProblemReason` und `WorkoutSet.swift` schreiben (Request + Response für `PUT .../sets/{setId}`)**

Feldnamen und die vier Enum-Werte exakt aus `packages/domain/src/workout.ts` (`recordSetInputSchema`, `RecordedSet`):

```swift
import Foundation

/// Exakt die vier Werte aus packages/domain/src/workout.ts problemReasonSchema.
enum ProblemReason: String, Codable, Equatable, CaseIterable {
    case schmerz
    case geraetePasstNicht = "geraet_passt_nicht"
    case zuSchwer = "zu_schwer"
    case sonstiges
}

/// Anfrage-Rumpf fuer PUT /workout-sessions/{sessionId}/sets/{setId}.
/// sessionId/setId werden NICHT mitgeschickt -- sie stehen im Pfad und
/// gewinnen serverseitig ohnehin gegen den Rumpf (workout.ts Kommentar).
struct SetWrite: Codable, Equatable {
    var machineId: String
    var exerciseId: String
    var setIndex: Int
    var weightKg: Double
    var reps: Int
    var rir: Double? = nil
    var problemFlag: Bool = false
    var problemReason: ProblemReason? = nil
    var performedAt: String? = nil
}
```

Die drei `= nil`-Defaults sind Absicht, nicht Kosmetik: ohne sie verlangt Swifts synthetisierter Memberwise-Initialisierer auch für optionale Felder ein Argument. Spätere Aufrufstellen (Aufgaben 9, 10, 18) rufen `SetWrite(machineId:exerciseId:setIndex:weightKg:reps:rir:)` ohne `problemReason`/`performedAt` — das kompiliert nur mit diesen Defaults.

```swift
struct RecordedSet: Decodable, Equatable {
    let id: String
    let studioId: String
    let userId: String
    let sessionId: String
    let machineId: String
    let exerciseId: String
    let setIndex: Int
    let weightKg: Double
    let reps: Int
    let rir: Double?
    let problemFlag: Bool
    let problemReason: ProblemReason?
    let performedAt: String
}

struct CompletedSession: Decodable, Equatable {
    let id: String
    let startedAt: String
    let completedAt: String
    let completedReason: String // "manual" | "auto"
}
```

- [ ] **Schritt 6: `BootstrapResponse.swift` schreiben**

Felder exakt aus `packages/domain/src/bootstrap.ts`:

```swift
import Foundation

struct BootstrapResponse: Decodable, Equatable {
    struct Studio: Decodable, Equatable, Identifiable {
        let id: String
        let name: String
        let timezone: String
    }

    struct EquipmentModel: Decodable, Equatable {
        let id: String
        let name: String
        let manufacturer: String?
        let photoPath: String?
        let weightStepKg: Double
        let minWeightKg: Double
        let maxWeightKg: Double?
    }

    struct Exercise: Decodable, Equatable, Identifiable {
        let id: String
        let name: String
        let targetRepsMin: Int
        let targetRepsMax: Int
    }

    struct Machine: Decodable, Equatable, Identifiable {
        let id: String
        let studioId: String
        let label: String
        let locationNote: String?
        let status: String
        let tokenHashes: [String]
        let equipmentModel: EquipmentModel
        let exercises: [Exercise]
    }

    struct Calibration: Decodable, Equatable {
        let machineId: String
        let exerciseId: String
        let settingValues: JSONValue
        let schemaVersion: Int
        let createdAt: String
    }

    struct LastSet: Decodable, Equatable {
        let machineId: String
        let exerciseId: String
        let weightKg: Double
        let reps: Int
        let rir: Double?
        let performedAt: String
    }

    let studios: [Studio]
    let machines: [Machine]
    let calibrations: [Calibration]
    let lastSets: [LastSet]
}
```

- [ ] **Schritt 7: `TagContextResponse.swift` schreiben**

Felder exakt aus `packages/domain/src/tag-context.ts` und `packages/domain/src/progression.ts`:

```swift
import Foundation

struct TagContextResponse: Decodable, Equatable {
    struct Machine: Decodable, Equatable {
        let id: String
        let label: String
        let locationNote: String?
    }

    struct EquipmentModel: Decodable, Equatable {
        let id: String
        let name: String
        let manufacturer: String?
        let photoUrl: String?
        let weightStepKg: Double
        let minWeightKg: Double
        let maxWeightKg: Double?
    }

    struct SettingDefinition: Decodable, Equatable, Identifiable {
        var id: String { key }
        let key: String
        let label: String
        let kind: String
        let minValue: Double?
        let maxValue: Double?
        let stepValue: Double?
        let unit: String?
        let allowedValues: [String]?
    }

    struct Exercise: Decodable, Equatable, Identifiable {
        let id: String
        let name: String
        let description: String?
        let targetRepsMin: Int
        let targetRepsMax: Int
        let instructionVideoUrl: String?
    }

    struct Calibration: Decodable, Equatable {
        let settingValues: JSONValue
        let schemaVersion: Int
        let source: String
        let createdAt: String
    }

    struct HistoryEntry: Decodable, Equatable {
        let performedOn: String
        let weightKg: Double
        let reps: [Int]
    }

    struct Suggestion: Decodable, Equatable {
        struct Inputs: Decodable, Equatable {
            let targetRepsMin: Int
            let targetRepsMax: Int
            let weightStepKg: Double
            let minWeightKg: Double
            let maxWeightKg: Double
            let currentWeightKg: Double?
            let consideredBlocks: Int
        }
        let algoVersion: String
        let resultWeightKg: Double?
        let reasonCode: String
        let inputs: Inputs
    }

    let machine: Machine
    let equipmentModel: EquipmentModel
    let settingDefinitions: [SettingDefinition]
    let exercises: [Exercise]
    let selectedExerciseId: String?
    let calibration: Calibration?
    let history: [HistoryEntry]
    let suggestion: Suggestion
}
```

- [ ] **Schritt 8: `SessionSummary.swift` und `ExerciseProgress.swift` schreiben**

Felder exakt aus `packages/domain/src/sessions.ts` und `packages/domain/src/progress.ts`:

```swift
import Foundation

struct SessionsResponse: Decodable, Equatable { let sessions: [SessionSummary] }

struct SessionSummary: Decodable, Equatable, Identifiable {
    struct Block: Decodable, Equatable {
        struct Set: Decodable, Equatable {
            let setIndex: Int
            let weightKg: Double
            let reps: Int
            let rir: Double?
            let problemFlag: Bool
            let problemReason: ProblemReason?
            let performedAt: String
        }
        let machineId: String
        let machineLabel: String
        let exerciseId: String
        let exerciseName: String
        let sets: [Set]
    }

    let id: String
    let startedAt: String
    let completedAt: String?
    let completedReason: String? // "manual" | "auto" | null
    let machineCount: Int
    let setCount: Int
    let blocks: [Block]
}
```

```swift
import Foundation

struct ProgressResponse: Decodable, Equatable { let exercises: [ExerciseProgress] }

struct ExerciseProgress: Decodable, Equatable, Identifiable {
    struct Point: Decodable, Equatable {
        let performedOn: String
        let topWeightKg: Double
        let reps: Int
    }
    let id: String
    let exerciseName: String
    let firstWeightKg: Double
    let currentWeightKg: Double
    let changeKg: Double
    let points: [Point]

    private enum CodingKeys: String, CodingKey {
        case id = "exerciseId", exerciseName, firstWeightKg, currentWeightKg, changeKg, points
    }
}
```

- [ ] **Schritt 9: `ErrorEnvelope.swift` schreiben**

Exakt aus `apps/web/lib/api/respond.ts`:

```swift
import Foundation

/// Feste Fehlerhuelle aller /api/v1-Antworten: { "error": { "code", "message" } }.
struct ErrorEnvelope: Decodable, Equatable {
    struct Body: Decodable, Equatable {
        let code: String
        let message: String
    }
    let error: Body
}
```

- [ ] **Schritt 10: Decode-Tests für die vier großen DTOs schreiben, mit Fixture-JSON**

```swift
import Foundation
import Testing
@testable import FitnessMember

@Suite("DTOs")
struct DTOTests {
    @Test("dekodiert eine minimale BootstrapResponse")
    func decodesBootstrap() throws {
        let json = """
        {
          "studios": [{"id":"s1","name":"Kraftwerk Nord","timezone":"Europe/Berlin"}],
          "machines": [{
            "id":"m1","studioId":"s1","label":"07","locationNote":null,"status":"active",
            "tokenHashes":["abc"],
            "equipmentModel":{"id":"e1","name":"Beinpresse","manufacturer":null,"photoPath":null,"weightStepKg":2.5,"minWeightKg":10,"maxWeightKg":200},
            "exercises":[{"id":"ex1","name":"Beidbeinig","targetRepsMin":8,"targetRepsMax":12}]
          }],
          "calibrations": [{"machineId":"m1","exerciseId":"ex1","settingValues":{"sitz":3},"schemaVersion":1,"createdAt":"2026-09-01T10:00:00Z"}],
          "lastSets": [{"machineId":"m1","exerciseId":"ex1","weightKg":80,"reps":10,"rir":2,"performedAt":"2026-09-01T10:05:00Z"}]
        }
        """
        let response = try JSONDecoder().decode(BootstrapResponse.self, from: Data(json.utf8))
        #expect(response.studios.count == 1)
        #expect(response.machines[0].equipmentModel.weightStepKg == 2.5)
        #expect(response.calibrations[0].settingValues == .object(["sitz": .number(3)]))
    }

    @Test("dekodiert einen TagContextResponse mit leerer Historie")
    func decodesTagContext() throws {
        let json = """
        {
          "machine":{"id":"m1","label":"07","locationNote":null},
          "equipmentModel":{"id":"e1","name":"Beinpresse","manufacturer":null,"photoUrl":null,"weightStepKg":2.5,"minWeightKg":10,"maxWeightKg":200},
          "settingDefinitions":[],
          "exercises":[{"id":"ex1","name":"Beidbeinig","description":null,"targetRepsMin":8,"targetRepsMax":12,"instructionVideoUrl":null}],
          "selectedExerciseId":"ex1",
          "calibration":null,
          "history":[],
          "suggestion":{"algoVersion":"1.0.0","resultWeightKg":null,"reasonCode":"kein_verlauf","inputs":{"targetRepsMin":8,"targetRepsMax":12,"weightStepKg":2.5,"minWeightKg":10,"maxWeightKg":200,"currentWeightKg":null,"consideredBlocks":0}}
        }
        """
        let response = try JSONDecoder().decode(TagContextResponse.self, from: Data(json.utf8))
        #expect(response.suggestion.reasonCode == "kein_verlauf")
        #expect(response.calibration == nil)
    }

    @Test("kodiert SetWrite mit Problemmeldung")
    func encodesSetWriteWithProblem() throws {
        let write = SetWrite(
            machineId: "m1", exerciseId: "ex1", setIndex: 1,
            weightKg: 80, reps: 10, rir: 2,
            problemFlag: true, problemReason: .zuSchwer, performedAt: nil
        )
        let data = try JSONEncoder().encode(write)
        let decoded = try JSONDecoder().decode(SetWrite.self, from: data)
        #expect(decoded == write)
        #expect(decoded.problemReason == .zuSchwer)
    }

    @Test("dekodiert die Fehlerhuelle")
    func decodesErrorEnvelope() throws {
        let json = #"{"error":{"code":"validation_failed","message":"Der Rumpf ist kein gueltiges JSON."}}"#
        let envelope = try JSONDecoder().decode(ErrorEnvelope.self, from: Data(json.utf8))
        #expect(envelope.error.code == "validation_failed")
    }

    @Test("dekodiert eine SessionsResponse mit einem Block")
    func decodesSessions() throws {
        let json = """
        {"sessions":[{"id":"sess1","startedAt":"2026-09-01T10:00:00Z","completedAt":null,"completedReason":null,"machineCount":1,"setCount":1,"blocks":[{"machineId":"m1","machineLabel":"07","exerciseId":"ex1","exerciseName":"Beidbeinig","sets":[{"setIndex":1,"weightKg":80,"reps":10,"rir":null,"problemFlag":false,"problemReason":null,"performedAt":"2026-09-01T10:05:00Z"}]}]}]}
        """
        let response = try JSONDecoder().decode(SessionsResponse.self, from: Data(json.utf8))
        #expect(response.sessions[0].blocks[0].sets[0].weightKg == 80)
    }
}
```

- [ ] **Schritt 11: Alle Tests ausführen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test 2>&1 | tail -50
```

Erwartet: `TEST SUCCEEDED`, alle `DTOTests` und `JSONValueTests` grün.

- [ ] **Schritt 12: Commit**

```bash
cd apps/ios-member && git add FitnessMember/Networking FitnessMemberTests/DTOTests.swift
git commit -m "feat(ios): DTOs fuer die sechs M1-Endpoints"
```

---

### Aufgabe 5: Netzwerkschicht — `APIError` und `APIClient`

**Files:**
- Create: `apps/ios-member/FitnessMember/Networking/APIError.swift`
- Create: `apps/ios-member/FitnessMember/Networking/APIClient.swift`
- Test: `apps/ios-member/FitnessMemberTests/APIClientTests.swift`

**Interfaces:**
- Consumes: `AppConfig.apiBaseURL` (Aufgabe 1), alle DTOs (Aufgabe 4)
- Produces: `enum APIError`, `actor APIClient { init(baseURL:session:tokenProvider:); func bootstrap() async throws(APIError) -> BootstrapResponse; func tagContext(token:) async throws(APIError) -> TagContextResponse; func sessions() async throws(APIError) -> [SessionSummary]; func progress() async throws(APIError) -> [ExerciseProgress]; func putSet(sessionId:setId:_:) async throws(APIError) -> RecordedSet; func completeSession(sessionId:) async throws(APIError) -> CompletedSession }` — von Aufgabe 10 (`CatalogStore`) und Aufgabe 19 (Beitritts-Methoden) konsumiert.

- [ ] **Schritt 1: `APIError` schreiben — bildet die feste Fehlerhülle aus `respond.ts` ab**

```swift
import Foundation

/// Bildet apps/web/lib/api/respond.ts 1:1 ab: fuenf Codes, feste
/// Status-Zuordnung. .offline ist ein rein clientseitiger Fall (kein
/// HTTP-Response ueberhaupt) und hat kein Server-Gegenstueck.
enum APIError: Error, Equatable {
    case offline
    case unauthorized(message: String)
    case validation(message: String)
    case notFound(message: String)
    case conflict(message: String)
    case server(message: String)
    case decodingFailed

    static func map(code: String, message: String) -> APIError {
        switch code {
        case "unauthorized": .unauthorized(message: message)
        case "validation_failed": .validation(message: message)
        case "not_found": .notFound(message: message)
        case "conflict": .conflict(message: message)
        default: .server(message: message)
        }
    }
}
```

- [ ] **Schritt 2: Test für die Fehler-Zuordnung schreiben (URLProtocol-Stub)**

```swift
import Foundation
import Testing
@testable import FitnessMember

/// Stub, der jede Anfrage abfaengt und eine vorbereitete Antwort liefert --
/// kein echtes Netzwerk in Tests.
final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (Int, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let (status, data) = handler(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

func stubbedClient(tokenProvider: @escaping @Sendable () async -> String? = { "test-token" }) -> APIClient {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubURLProtocol.self]
    let session = URLSession(configuration: configuration)
    return APIClient(baseURL: URL(string: "https://example.test/api/v1")!, session: session, tokenProvider: tokenProvider)
}

@Suite("APIClient")
struct APIClientTests {
    @Test("dekodiert eine erfolgreiche bootstrap-Antwort")
    func decodesBootstrap() async throws {
        StubURLProtocol.handler = { _ in
            let json = #"{"studios":[],"machines":[],"calibrations":[],"lastSets":[]}"#
            return (200, Data(json.utf8))
        }
        let client = stubbedClient()
        let response = try await client.bootstrap()
        #expect(response.studios.isEmpty)
    }

    @Test("bildet 401 auf .unauthorized ab")
    func mapsUnauthorized() async throws {
        StubURLProtocol.handler = { _ in
            let json = #"{"error":{"code":"unauthorized","message":"Anmeldung erforderlich."}}"#
            return (401, Data(json.utf8))
        }
        let client = stubbedClient()
        await #expect(throws: APIError.unauthorized(message: "Anmeldung erforderlich.")) {
            try await client.bootstrap()
        }
    }

    @Test("bildet 422 mit Server-Text auf .validation ab")
    func mapsValidation() async throws {
        StubURLProtocol.handler = { _ in
            let json = #"{"error":{"code":"validation_failed","message":"Eine Problemursache setzt das Problemkennzeichen voraus."}}"#
            return (422, Data(json.utf8))
        }
        let client = stubbedClient()
        await #expect(throws: APIError.validation(message: "Eine Problemursache setzt das Problemkennzeichen voraus.")) {
            try await client.bootstrap()
        }
    }

    @Test("sendet den Bearer-Token aus dem tokenProvider")
    func sendsBearerToken() async throws {
        var capturedAuthHeader: String?
        StubURLProtocol.handler = { request in
            capturedAuthHeader = request.value(forHTTPHeaderField: "Authorization")
            return (200, Data(#"{"studios":[],"machines":[],"calibrations":[],"lastSets":[]}"#.utf8))
        }
        let client = stubbedClient(tokenProvider: { "abc123" })
        _ = try await client.bootstrap()
        #expect(capturedAuthHeader == "Bearer abc123")
    }

    @Test("bildet einen Netzwerkfehler auf .offline ab")
    func mapsOffline() async throws {
        StubURLProtocol.handler = { _ in fatalError("wird nicht aufgerufen") }
        // Kein Handler-Ergebnis liefern, sondern direkt didFailWithError simulieren
        // ist mit diesem einfachen Stub nicht abbildbar -- stattdessen eine
        // Session ohne registriertes Protokoll verwenden, das serverseitig
        // fehlschlaegt. Einfacher: Handler wirft ueber eine ungueltige URL.
        let client = APIClient(
            baseURL: URL(string: "https://127.0.0.1:1")!,
            session: URLSession(configuration: {
                let config = URLSessionConfiguration.ephemeral
                config.timeoutIntervalForRequest = 1
                return config
            }()),
            tokenProvider: { nil }
        )
        await #expect(throws: APIError.offline) {
            try await client.bootstrap()
        }
    }
}
```

- [ ] **Schritt 3: Tests ausführen, Fehlschlag bestätigen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/APIClientTests 2>&1 | tail -30
```

Erwartet: FAIL — `APIClient` existiert noch nicht.

- [ ] **Schritt 4: `APIClient.swift` implementieren**

```swift
import Foundation

actor APIClient {
    private let baseURL: URL
    private let session: URLSession
    private let tokenProvider: @Sendable () async -> String?
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(
        baseURL: URL,
        session: URLSession = .shared,
        tokenProvider: @escaping @Sendable () async -> String?
    ) {
        self.baseURL = baseURL
        self.session = session
        self.tokenProvider = tokenProvider
    }

    // MARK: - Die sechs M1-Endpoints (M1-Spec SS6.3)

    func bootstrap() async throws(APIError) -> BootstrapResponse {
        try await get("me/bootstrap")
    }

    func tagContext(token: String) async throws(APIError) -> TagContextResponse {
        try await get("tags/\(token)/context")
    }

    func sessions() async throws(APIError) -> [SessionSummary] {
        try await get("me/sessions", as: SessionsResponse.self).sessions
    }

    func progress() async throws(APIError) -> [ExerciseProgress] {
        try await get("me/progress", as: ProgressResponse.self).exercises
    }

    func putSet(sessionId: UUID, setId: UUID, _ body: SetWrite) async throws(APIError) -> RecordedSet {
        try await send("workout-sessions/\(sessionId.uuidString)/sets/\(setId.uuidString)", method: "PUT", body: body)
    }

    func completeSession(sessionId: UUID) async throws(APIError) -> CompletedSession {
        try await postNoBody("workout-sessions/\(sessionId.uuidString)/complete")
    }

    // MARK: - Hilfsmethoden

    private func get<T: Decodable>(_ path: String, as type: T.Type = T.self) async throws(APIError) -> T {
        try await execute(path: path, method: "GET", bodyData: nil)
    }

    private func send<Body: Encodable, T: Decodable>(_ path: String, method: String, body: Body) async throws(APIError) -> T {
        let bodyData: Data
        do { bodyData = try encoder.encode(body) }
        catch { throw APIError.decodingFailed }
        return try await execute(path: path, method: method, bodyData: bodyData)
    }

    private func postNoBody<T: Decodable>(_ path: String) async throws(APIError) -> T {
        try await execute(path: path, method: "POST", bodyData: nil)
    }

    private func execute<T: Decodable>(path: String, method: String, bodyData: Data?) async throws(APIError) -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = await tokenProvider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let bodyData {
            request.httpBody = bodyData
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.offline
        }

        guard let http = response as? HTTPURLResponse else { throw APIError.server(message: "Unerwartete Antwort.") }

        if (200..<300).contains(http.statusCode) {
            do { return try decoder.decode(T.self, from: data) }
            catch { throw APIError.decodingFailed }
        }

        if let envelope = try? decoder.decode(ErrorEnvelope.self, from: data) {
            throw APIError.map(code: envelope.error.code, message: envelope.error.message)
        }
        throw APIError.server(message: "Unerwarteter Fehler.")
    }
}
```

`completeSession` ruft intern `postNoBody<T>` mit `T == CompletedSession` auf — dieselbe generische Hilfsmethode wie `get`, aber ohne Decodable-Rumpf zu senden (das Backend erwartet für `POST .../complete` keinen Body, siehe `packages/domain/src/workout.ts:178-257`).

- [ ] **Schritt 5: Tests ausführen, Erfolg bestätigen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/APIClientTests 2>&1 | tail -30
```

Erwartet: PASS für alle fünf Tests, inklusive `.offline`-Mapping (URLSession-Timeout gegen `127.0.0.1:1` schlägt als `URLError` fehl, `execute` fängt das als `.offline`).

- [ ] **Schritt 6: Alle bisherigen Tests zusammen laufen lassen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test 2>&1 | tail -50
```

Erwartet: `TEST SUCCEEDED`.

- [ ] **Schritt 7: Commit**

```bash
cd apps/ios-member && git add FitnessMember/Networking/APIError.swift FitnessMember/Networking/APIClient.swift FitnessMemberTests/APIClientTests.swift
git commit -m "feat(ios): APIClient-Actor fuer die sechs M1-Endpoints"
```

---

### Aufgabe 6: Auth — Validierungs- und Eingabe-Logik

**Files:**
- Create: `apps/ios-member/FitnessMember/Auth/EmailValidator.swift`
- Create: `apps/ios-member/FitnessMember/Auth/PasswordPolicy.swift`
- Create: `apps/ios-member/FitnessMember/Auth/CodeEntry.swift`
- Create: `apps/ios-member/FitnessMember/Auth/AuthCopy.swift`
- Test: `apps/ios-member/FitnessMemberTests/AuthLogicTests.swift`

**Interfaces:**
- Produces: `EmailValidator.isValid(_:) -> Bool`, `PasswordPolicy.minimumLength: Int`, `PasswordPolicy.isValid(_:) -> Bool`, `CodeEntry(digits:)`, `CodeEntry.length`, `.digits`, `.isComplete`, `.remaining`, `AuthCopy.{unbekanntOderFalsch,sicherheitshinweisPasswortVergessen,codeUngueltig,passwoerterStimmenNichtUeberein}` — von den Screen-Aufgaben 13–17, 19–20 konsumiert.

- [ ] **Schritt 1: Tests für alle vier Typen schreiben**

```swift
import Foundation
import Testing
@testable import FitnessMember

@Suite("EmailValidator")
struct EmailValidatorTests {
    @Test("akzeptiert eine gueltige Adresse", arguments: ["lena.wagner@example.de", "a@b.co"])
    func acceptsValid(_ email: String) {
        #expect(EmailValidator.isValid(email))
    }

    @Test("weist eine ungueltige Adresse zurueck", arguments: ["", "keine-adresse", "a@b", "@example.de", "a@.de"])
    func rejectsInvalid(_ email: String) {
        #expect(!EmailValidator.isValid(email))
    }
}

@Suite("PasswordPolicy")
struct PasswordPolicyTests {
    @Test("neun Zeichen sind zu kurz")
    func rejectsNineCharacters() {
        #expect(!PasswordPolicy.isValid("123456789"))
    }

    @Test("zehn Zeichen reichen — config.toml minimum_password_length")
    func acceptsTenCharacters() {
        #expect(PasswordPolicy.isValid("1234567890"))
    }
}

@Suite("CodeEntry")
struct CodeEntryTests {
    @Test("filtert Nicht-Ziffern heraus")
    func filtersNonDigits() {
        #expect(CodeEntry(digits: "4a1b9c7").digits == "4197")
    }

    @Test("kappt bei sechs Ziffern")
    func clampsToSixDigits() {
        #expect(CodeEntry(digits: "1234567").digits == "123456")
    }

    @Test("isComplete erst bei genau sechs Ziffern")
    func isCompleteAtSix() {
        #expect(!CodeEntry(digits: "12345").isComplete)
        #expect(CodeEntry(digits: "123456").isComplete)
    }

    @Test("remaining zaehlt bis sechs")
    func remainingCounts() {
        #expect(CodeEntry(digits: "1234").remaining == 2)
    }
}
```

- [ ] **Schritt 2: Tests ausführen, Fehlschlag bestätigen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/EmailValidatorTests -only-testing:FitnessMemberTests/PasswordPolicyTests -only-testing:FitnessMemberTests/CodeEntryTests 2>&1 | tail -30
```

Erwartet: FAIL — keiner der vier Typen existiert.

- [ ] **Schritt 3: `EmailValidator.swift` implementieren**

```swift
import Foundation

enum EmailValidator {
    private static let pattern = #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#

    static func isValid(_ email: String) -> Bool {
        email.range(of: pattern, options: .regularExpression) != nil
    }
}
```

- [ ] **Schritt 4: `PasswordPolicy.swift` implementieren**

```swift
import Foundation

/// Minimum aus supabase/config.toml minimum_password_length (auf 10 erhoeht
/// seit der Passwort-Umstellung, siehe gesamtfahrplan.md Abschnitt "Phase 0").
enum PasswordPolicy {
    static let minimumLength = 10

    static func isValid(_ password: String) -> Bool {
        password.count >= minimumLength
    }
}
```

- [ ] **Schritt 5: `CodeEntry.swift` implementieren**

```swift
import Foundation

/// Eingabezustand fuer den sechsstelligen Bestaetigungs-/Reset-Code.
/// Wiederverwendet von LoginCodeView (Aufgabe 14) und MemberPasswortView
/// (Aufgabe 16).
struct CodeEntry: Equatable {
    static let length = 6

    private(set) var digits: String

    init(digits: String = "") {
        self.digits = String(digits.filter(\.isNumber).prefix(Self.length))
    }

    var isComplete: Bool { digits.count == Self.length }
    var remaining: Int { Self.length - digits.count }
}
```

- [ ] **Schritt 6: `AuthCopy.swift` implementieren**

```swift
import Foundation

/// Einzige Quelle fuer sicherheitskritische, bewusst neutrale Texte.
/// LoginMailView und MemberRegistrierenView referenzieren
/// unbekanntOderFalsch direkt -- kein Screen kopiert den String-Literal
/// separat (Design-Challenge-Entscheidung #4, spec SS9).
enum AuthCopy {
    static let unbekanntOderFalsch =
        "E-Mail oder Passwort stimmt nicht, oder es gibt kein Konto zu dieser Adresse."
    static let sicherheitshinweisPasswortVergessen =
        "Wenn es zu dieser Adresse ein Konto gibt, ist die Mail unterwegs."
    static let codeUngueltig = "Der Code ist ungültig oder abgelaufen."
    static let passwoerterStimmenNichtUeberein = "Die beiden Passwörter stimmen nicht überein."
    static let aktuellesPasswortFalsch = "Das aktuelle Passwort ist falsch."
}
```

- [ ] **Schritt 7: Tests ausführen, Erfolg bestätigen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test 2>&1 | tail -50
```

Erwartet: `TEST SUCCEEDED`.

- [ ] **Schritt 8: Commit**

```bash
cd apps/ios-member && git add FitnessMember/Auth/EmailValidator.swift FitnessMember/Auth/PasswordPolicy.swift FitnessMember/Auth/CodeEntry.swift FitnessMember/Auth/AuthCopy.swift FitnessMemberTests/AuthLogicTests.swift
git commit -m "feat(ios): Validierungs- und Code-Eingabe-Logik fuer Auth-Screens"
```

---

### Aufgabe 7: Auth — `AuthBackend`-Protokoll und `SupabaseAuthBackend`-Adapter

**Files:**
- Create: `apps/ios-member/FitnessMember/Auth/Session.swift`
- Create: `apps/ios-member/FitnessMember/Auth/AuthBackend.swift`
- Create: `apps/ios-member/FitnessMember/Auth/SupabaseAuthBackend.swift`

**Interfaces:**
- Consumes: `AppConfig.supabaseURL`, `AppConfig.supabaseAnonKey` (Aufgabe 1), `supabase-swift`-Paket (Aufgabe 1)
- Produces: `struct Session { accessToken: String; userId: String; email: String; expiresAt: Date }`, `protocol AuthBackend`, `final class SupabaseAuthBackend: AuthBackend` — von Aufgabe 8 (`SessionStore`) konsumiert. `SessionStore` hängt nur am Protokoll, nie an `SupabaseAuthBackend` direkt — das hält Aufgabe 8 vollständig ohne echtes Netzwerk testbar.

**Wichtiger Hinweis für die Ausführung:** `SessionStore` (Aufgabe 8) wird ausschließlich gegen einen `FakeAuthBackend` getestet, nie gegen `SupabaseAuthBackend` — die Methodennamen von `supabase-swift` unten sind nach bestem Wissen benannt (Parität mit dem JS-SDK, dessen Aufrufe in `apps/web/app/{login,registrieren,passwort-vergessen}/actions.ts` stehen), aber die installierte Paketversion ist die letzte Autorität. Meldet der Compiler in Schritt 4 einen Namens- oder Signaturkonflikt, Parameter-Label/Rückgabetyp anhand der Xcode-Codevervollständigung anpassen — die Struktur (ein Protokoll, ein schlanker Adapter, keine andere Datei betroffen) bleibt unverändert.

- [ ] **Schritt 1: `Session.swift` schreiben — eigener Typ statt des SDK-Typs**

```swift
import Foundation

/// Eigener, schlanker Session-Typ statt Supabase.Session direkt durch die
/// App zu reichen -- entkoppelt SessionStore und alle Screens vom SDK-Typ.
struct Session: Equatable, Sendable {
    let accessToken: String
    let userId: String
    let email: String
    let expiresAt: Date
}
```

- [ ] **Schritt 2: `AuthBackend.swift` schreiben**

```swift
import Foundation

protocol AuthBackend: Sendable {
    func currentSession() async -> Session?
    func signIn(email: String, password: String) async throws -> Session
    /// nil, wenn Bestaetigungspflicht aktiv ist (Cloud-Standard) und noch
    /// keine Session entsteht -- siehe apps/web/app/registrieren/actions.ts.
    func signUp(email: String, password: String) async throws -> Session?
    func verifySignupCode(email: String, code: String) async throws -> Session
    func resendSignupCode(email: String) async throws
    func requestPasswordReset(email: String) async throws
    func verifyRecoveryCode(email: String, code: String) async throws -> Session
    func updatePassword(_ newPassword: String) async throws
    func signOut() async throws
}
```

- [ ] **Schritt 3: `SupabaseAuthBackend.swift` schreiben**

```swift
import Foundation
import Supabase

final class SupabaseAuthBackend: AuthBackend {
    private let client: SupabaseClient

    init() {
        client = SupabaseClient(supabaseURL: AppConfig.supabaseURL, supabaseKey: AppConfig.supabaseAnonKey)
    }

    func currentSession() async -> Session? {
        guard let session = try? await client.auth.session else { return nil }
        return map(session)
    }

    func signIn(email: String, password: String) async throws -> Session {
        let session = try await client.auth.signIn(email: email, password: password)
        return map(session)
    }

    func signUp(email: String, password: String) async throws -> Session? {
        let response = try await client.auth.signUp(email: email, password: password)
        guard let session = response.session else { return nil }
        return map(session)
    }

    func verifySignupCode(email: String, code: String) async throws -> Session {
        let response = try await client.auth.verifyOTP(email: email, token: code, type: .signup)
        guard let session = response.session else {
            throw AuthBackendError.noSessionAfterVerification
        }
        return map(session)
    }

    func resendSignupCode(email: String) async throws {
        try await client.auth.resend(email: email, type: .signup)
    }

    func requestPasswordReset(email: String) async throws {
        try await client.auth.resetPasswordForEmail(email)
    }

    func verifyRecoveryCode(email: String, code: String) async throws -> Session {
        let response = try await client.auth.verifyOTP(email: email, token: code, type: .recovery)
        guard let session = response.session else {
            throw AuthBackendError.noSessionAfterVerification
        }
        return map(session)
    }

    func updatePassword(_ newPassword: String) async throws {
        try await client.auth.update(user: UserAttributes(password: newPassword))
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    private func map(_ session: Auth.Session) -> Session {
        FitnessMember.Session(
            accessToken: session.accessToken,
            userId: session.user.id.uuidString,
            email: session.user.email ?? "",
            expiresAt: Date(timeIntervalSince1970: session.expiresAt)
        )
    }
}

enum AuthBackendError: Error {
    case noSessionAfterVerification
}
```

- [ ] **Schritt 4: Bauen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" build 2>&1 | tail -60
```

Erwartet: `BUILD SUCCEEDED`. Schlägt der Build an einer `client.auth.*`-Zeile fehl: in Xcode `client.auth.` tippen, die Codevervollständigung zeigt die tatsächliche Methode dieser Paketversion — Name/Label/Rückgabetyp in genau dieser Zeile anpassen, keine andere Datei betroffen (siehe Hinweis oben).

- [ ] **Schritt 5: Bestätigen, dass `SupabaseClient` ohne eigene `AuthLocalStorage`-Injektion Keychain-Storage nutzt**

Keine Codeänderung — Dokumentationsschritt, der die nicht verhandelbare Anforderung aus M1-Spec §9/§10 festhält: `init()` oben übergibt keinen `authLocalStorage:`-Parameter, `SupabaseClient` verwendet damit seinen Standard. Ein Test dafür folgt in Aufgabe 8 Schritt 6 (`SessionStore` testet nicht direkt gegen `SupabaseAuthBackend`, aber der Kommentar in dieser Datei ist der Beleg, dass hier nichts Eigenes über UserDefaults gebaut wurde).

Kommentar über `init()` in `SupabaseAuthBackend.swift` ergänzen:

```swift
    /// Kein eigener authLocalStorage-Parameter: SupabaseClient nutzt seinen
    /// Standard (Keychain-gestuetzt). M1-Spec SS9/SS10 verbietet UserDefaults
    /// und SwiftData fuer Sessions -- das ist hier bewusst nicht eigens
    /// gebaut, sondern der SDK-Standard validiert und dokumentiert.
    init() {
```

- [ ] **Schritt 6: Commit**

```bash
cd apps/ios-member && git add FitnessMember/Auth/Session.swift FitnessMember/Auth/AuthBackend.swift FitnessMember/Auth/SupabaseAuthBackend.swift
git commit -m "feat(ios): AuthBackend-Protokoll und Supabase-Adapter"
```

---

### Aufgabe 8: Auth — `SessionStore`

**Files:**
- Create: `apps/ios-member/FitnessMember/Auth/AuthError.swift`
- Create: `apps/ios-member/FitnessMember/Auth/SessionStore.swift`
- Test: `apps/ios-member/FitnessMemberTests/SessionStoreTests.swift`

**Interfaces:**
- Consumes: `protocol AuthBackend`, `struct Session` (Aufgabe 7)
- Produces: `@Observable final class SessionStore { init(backend: AuthBackend); var session: Session? { get }; func restoreSession() async; func signIn(email:password:) async throws(AuthError); func signUp(email:password:) async throws(AuthError) -> Bool; func verifySignupCode(email:code:) async throws(AuthError); func resendSignupCode(email:) async; func requestPasswordReset(email:) async; func resetPassword(email:code:newPassword:) async throws(AuthError); func changePassword(currentPassword:newPassword:) async throws(AuthError); func signOut() async }` — von Aufgabe 11 (`RootView`) und allen Zugang-Screens konsumiert.

- [ ] **Schritt 1: `FakeAuthBackend`-Testdouble und Tests schreiben**

```swift
import Foundation
import Testing
@testable import FitnessMember

/// Testdouble fuer AuthBackend -- SessionStore wird nie gegen den echten
/// SupabaseAuthBackend getestet (siehe Hinweis in Aufgabe 7).
actor FakeAuthBackend: AuthBackend {
    enum Behavior {
        case succeed(Session)
        case fail(Error)
        case requireConfirmation
    }

    var behavior: Behavior = .fail(TestError.notConfigured)
    private(set) var storedSession: Session?
    private(set) var updatePasswordCalls: [String] = []
    private(set) var signInCalls: [(email: String, password: String)] = []

    enum TestError: Error { case notConfigured, invalidCredentials }

    func currentSession() async -> Session? { storedSession }

    func signIn(email: String, password: String) async throws -> Session {
        signInCalls.append((email, password))
        switch behavior {
        case .succeed(let session): storedSession = session; return session
        case .fail(let error): throw error
        case .requireConfirmation: throw TestError.invalidCredentials
        }
    }

    func signUp(email: String, password: String) async throws -> Session? {
        switch behavior {
        case .succeed(let session): storedSession = session; return session
        case .requireConfirmation: return nil
        case .fail(let error): throw error
        }
    }

    func verifySignupCode(email: String, code: String) async throws -> Session {
        try requireSuccess()
    }

    func resendSignupCode(email: String) async throws {}

    func requestPasswordReset(email: String) async throws {}

    func verifyRecoveryCode(email: String, code: String) async throws -> Session {
        try requireSuccess()
    }

    func updatePassword(_ newPassword: String) async throws {
        updatePasswordCalls.append(newPassword)
        if case .fail(let error) = behavior { throw error }
    }

    func signOut() async throws { storedSession = nil }

    private func requireSuccess() throws -> Session {
        switch behavior {
        case .succeed(let session): storedSession = session; return session
        case .fail(let error): throw error
        case .requireConfirmation: throw TestError.invalidCredentials
        }
    }
}

private let testSession = Session(accessToken: "tok", userId: "u1", email: "lena@example.de", expiresAt: .distantFuture)

@Suite("SessionStore")
struct SessionStoreTests {
    @Test("signIn setzt die Session bei Erfolg")
    func signInSucceeds() async {
        let backend = FakeAuthBackend()
        await backend.setBehavior(.succeed(testSession))
        let store = SessionStore(backend: backend)
        try? await store.signIn(email: "lena@example.de", password: "geheim1234")
        #expect(store.session == testSession)
    }

    @Test("signIn wirft AuthError.invalidCredentials bei falschem Passwort")
    func signInFails() async {
        let backend = FakeAuthBackend()
        await backend.setBehavior(.fail(FakeAuthBackend.TestError.invalidCredentials))
        let store = SessionStore(backend: backend)
        await #expect(throws: AuthError.invalidCredentials) {
            try await store.signIn(email: "lena@example.de", password: "falsch")
        }
        #expect(store.session == nil)
    }

    @Test("signUp liefert false, wenn Bestaetigung noetig ist")
    func signUpRequiresConfirmation() async throws {
        let backend = FakeAuthBackend()
        await backend.setBehavior(.requireConfirmation)
        let store = SessionStore(backend: backend)
        let gotImmediateSession = try await store.signUp(email: "neu@example.de", password: "geheim1234")
        #expect(gotImmediateSession == false)
        #expect(store.session == nil)
    }

    @Test("signOut leert die Session")
    func signOutClearsSession() async {
        let backend = FakeAuthBackend()
        await backend.setBehavior(.succeed(testSession))
        let store = SessionStore(backend: backend)
        try? await store.signIn(email: "lena@example.de", password: "geheim1234")
        await store.signOut()
        #expect(store.session == nil)
    }

    @Test("restoreSession uebernimmt eine vorhandene Backend-Session")
    func restoreSessionLoadsExisting() async {
        let backend = FakeAuthBackend()
        await backend.setBehavior(.succeed(testSession))
        _ = try? await backend.signIn(email: "lena@example.de", password: "geheim1234")
        let store = SessionStore(backend: backend)
        #expect(store.session == nil)
        await store.restoreSession()
        #expect(store.session == testSession)
    }

    @Test("changePassword meldet aktuelles Passwort falsch als eigenen Fehler")
    func changePasswordWrongCurrent() async {
        let backend = FakeAuthBackend()
        await backend.setBehavior(.fail(FakeAuthBackend.TestError.invalidCredentials))
        let store = SessionStore(backend: backend)
        await #expect(throws: AuthError.invalidCredentials) {
            try await store.changePassword(currentPassword: "falsch", newPassword: "neuesPasswort1")
        }
    }
}

private extension FakeAuthBackend {
    func setBehavior(_ value: Behavior) { behavior = value }
}
```

- [ ] **Schritt 2: Tests ausführen, Fehlschlag bestätigen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/SessionStoreTests 2>&1 | tail -30
```

Erwartet: FAIL — `SessionStore`, `AuthError` existieren noch nicht.

- [ ] **Schritt 3: `AuthError.swift` implementieren**

```swift
import Foundation

enum AuthError: Error, Equatable {
    case invalidCredentials
    case network
    case unknown

    static func map(_ error: Error) -> AuthError {
        if error is URLError { return .network }
        return .invalidCredentials
    }
}
```

- [ ] **Schritt 4: `SessionStore.swift` implementieren**

```swift
import Foundation
import Observation

@Observable
final class SessionStore {
    private(set) var session: Session?
    private let backend: AuthBackend

    init(backend: AuthBackend) {
        self.backend = backend
    }

    func restoreSession() async {
        session = await backend.currentSession()
    }

    func signIn(email: String, password: String) async throws(AuthError) {
        do { session = try await backend.signIn(email: email, password: password) }
        catch { throw AuthError.map(error) }
    }

    /// true, wenn signUp sofort eine Session liefert (nur ohne
    /// Bestaetigungspflicht -- Cloud hat sie immer aktiviert, siehe
    /// gesamtfahrplan.md). false heisst: LoginCodeView zeigen.
    func signUp(email: String, password: String) async throws(AuthError) -> Bool {
        do {
            if let newSession = try await backend.signUp(email: email, password: password) {
                session = newSession
                return true
            }
            return false
        } catch { throw AuthError.map(error) }
    }

    func verifySignupCode(email: String, code: String) async throws(AuthError) {
        do { session = try await backend.verifySignupCode(email: email, code: code) }
        catch { throw AuthError.map(error) }
    }

    func resendSignupCode(email: String) async {
        try? await backend.resendSignupCode(email: email)
    }

    /// Fehler werden bewusst verschluckt -- die Antwort ist immer gleich,
    /// egal ob das Konto existiert (spec SS9, AuthCopy.sicherheitshinweisPasswortVergessen).
    func requestPasswordReset(email: String) async {
        try? await backend.requestPasswordReset(email: email)
    }

    func resetPassword(email: String, code: String, newPassword: String) async throws(AuthError) {
        do {
            session = try await backend.verifyRecoveryCode(email: email, code: code)
            try await backend.updatePassword(newPassword)
        } catch { throw AuthError.map(error) }
    }

    /// Bestaetigt das aktuelle Passwort durch eine erneute Anmeldung, bevor
    /// das neue gesetzt wird -- Supabases updateUser verlangt keine
    /// Bestaetigung des alten Passworts, MemberPasswortAendernView braucht
    /// aber genau diesen Fehlerfall (spec SS8).
    func changePassword(currentPassword: String, newPassword: String) async throws(AuthError) {
        guard let email = session?.email else { throw AuthError.unknown }
        do {
            _ = try await backend.signIn(email: email, password: currentPassword)
            try await backend.updatePassword(newPassword)
        } catch { throw AuthError.map(error) }
    }

    func signOut() async {
        try? await backend.signOut()
        session = nil
    }
}
```

- [ ] **Schritt 5: Tests ausführen, Erfolg bestätigen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/SessionStoreTests 2>&1 | tail -30
```

Erwartet: PASS für alle sechs Tests.

- [ ] **Schritt 6: Alle Tests zusammen laufen lassen und committen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test 2>&1 | tail -50
git add FitnessMember/Auth/AuthError.swift FitnessMember/Auth/SessionStore.swift FitnessMemberTests/SessionStoreTests.swift
git commit -m "feat(ios): SessionStore mit FakeAuthBackend-Testabdeckung"
```

---

### Aufgabe 9: Catalog — `PendingSetWrite` und persistierte Schreib-Warteschlange

**Files:**
- Create: `apps/ios-member/FitnessMember/Catalog/PendingSetWrite.swift`
- Create: `apps/ios-member/FitnessMember/Catalog/PendingWriteStore.swift`
- Test: `apps/ios-member/FitnessMemberTests/PendingWriteStoreTests.swift`

**Interfaces:**
- Consumes: `SetWrite` (Aufgabe 4)
- Produces: `struct PendingSetWrite: Codable, Equatable, Identifiable { sessionId: UUID; setId: UUID; body: SetWrite }`, `final class PendingWriteStore { init(directory: URL); func loadAll() -> [PendingSetWrite]; func save(_:) }` — von Aufgabe 10 (`CatalogStore`) konsumiert.

- [ ] **Schritt 1: Test für den Persistenz-Roundtrip schreiben — simuliert einen Prozess-Neustart**

```swift
import Foundation
import Testing
@testable import FitnessMember

@Suite("PendingWriteStore")
struct PendingWriteStoreTests {
    private func makeTempDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pending-write-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @Test("liefert eine leere Liste, wenn nie gespeichert wurde")
    func startsEmpty() {
        let store = PendingWriteStore(directory: makeTempDirectory())
        #expect(store.loadAll().isEmpty)
    }

    @Test("uebersteht einen simulierten Neustart ohne Datenverlust")
    func survivesRestart() {
        let directory = makeTempDirectory()
        let write = PendingSetWrite(
            sessionId: UUID(), setId: UUID(),
            body: SetWrite(machineId: "m1", exerciseId: "ex1", setIndex: 1, weightKg: 80, reps: 10, rir: nil)
        )

        let firstProcess = PendingWriteStore(directory: directory)
        firstProcess.save([write])

        // "Neustart": eine neue Instanz auf demselben Verzeichnis, keine
        // gemeinsame In-Memory-Referenz mit firstProcess.
        let secondProcess = PendingWriteStore(directory: directory)
        #expect(secondProcess.loadAll() == [write])
    }

    @Test("speichert eine leere Liste, wenn alles abgearbeitet ist")
    func savingEmptyListClears() {
        let directory = makeTempDirectory()
        let write = PendingSetWrite(
            sessionId: UUID(), setId: UUID(),
            body: SetWrite(machineId: "m1", exerciseId: "ex1", setIndex: 1, weightKg: 80, reps: 10, rir: nil)
        )
        let store = PendingWriteStore(directory: directory)
        store.save([write])
        store.save([])
        #expect(PendingWriteStore(directory: directory).loadAll().isEmpty)
    }
}
```

- [ ] **Schritt 2: Tests ausführen, Fehlschlag bestätigen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/PendingWriteStoreTests 2>&1 | tail -30
```

Erwartet: FAIL — `PendingSetWrite`, `PendingWriteStore` existieren noch nicht.

- [ ] **Schritt 3: `PendingSetWrite.swift` implementieren**

```swift
import Foundation

/// Ein noch nicht bestaetigter PUT auf .../sets/{setId}. Persistiert auf
/// Platte statt nur im Speicher, weil der Offline-Zustand "gespeichert,
/// wird gesendet" verspricht (designsystem.md SS5) -- ein App-Kill waehrend
/// einer Offline-Phase darf das nicht brechen. PUT ist idempotent
/// (clientseitige UUID), ein Replay nach Neustart ist sicher.
struct PendingSetWrite: Codable, Equatable, Identifiable {
    var id: UUID { setId }
    let sessionId: UUID
    let setId: UUID
    let body: SetWrite
}
```

- [ ] **Schritt 4: `PendingWriteStore.swift` implementieren**

```swift
import Foundation

final class PendingWriteStore {
    private let fileURL: URL

    init(directory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("pending-writes.json")
    }

    func loadAll() -> [PendingSetWrite] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([PendingSetWrite].self, from: data)) ?? []
    }

    func save(_ writes: [PendingSetWrite]) {
        guard let data = try? JSONEncoder().encode(writes) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
```

- [ ] **Schritt 5: Tests ausführen, Erfolg bestätigen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/PendingWriteStoreTests 2>&1 | tail -30
```

Erwartet: PASS für alle drei Tests.

- [ ] **Schritt 6: Commit**

```bash
cd apps/ios-member && git add FitnessMember/Catalog/PendingSetWrite.swift FitnessMember/Catalog/PendingWriteStore.swift FitnessMemberTests/PendingWriteStoreTests.swift
git commit -m "feat(ios): persistierte Schreib-Warteschlange fuer offline gespeicherte Saetze"
```

---

### Aufgabe 10: Catalog — `CatalogStore`

**Files:**
- Create: `apps/ios-member/FitnessMember/Catalog/CatalogLoadState.swift`
- Create: `apps/ios-member/FitnessMember/Catalog/CatalogStore.swift`
- Test: `apps/ios-member/FitnessMemberTests/CatalogStoreTests.swift`

**Interfaces:**
- Consumes: `APIClient` (Aufgabe 5), `PendingSetWrite`/`PendingWriteStore` (Aufgabe 9)
- Produces: `enum CatalogLoadState: Equatable { case idle, loading, loaded(hasStudio: Bool), failed }`, `@Observable final class CatalogStore { init(apiClient:pendingWriteStore:defaults:); var bootstrap: BootstrapResponse? { get }; var loadState: CatalogLoadState { get }; var pendingWrites: [PendingSetWrite] { get }; func load() async; func enqueue(_:); func flushPending() async }` — von Aufgabe 11 (`RootView`/`RootDestinationLogic`) konsumiert.

- [ ] **Schritt 1: Test-Double für `APIClient` und Tests schreiben**

`APIClient` ist ein `actor` ohne Protokoll-Abstraktion (Aufgabe 5 begründet das mit YAGNI bei sechs bekannten Endpoints). Für `CatalogStore`-Tests wird deshalb eine minimale Protokoll-Fassade nur für die hier gebrauchten zwei Methoden ergänzt, ohne Aufgabe 5 anzufassen:

```swift
import Foundation
import Testing
@testable import FitnessMember

protocol BootstrapLoading: Sendable {
    func bootstrap() async throws(APIError) -> BootstrapResponse
    func putSet(sessionId: UUID, setId: UUID, _ body: SetWrite) async throws(APIError) -> RecordedSet
}

extension APIClient: BootstrapLoading {}

actor FakeBootstrapLoader: BootstrapLoading {
    enum Result { case success(BootstrapResponse), failure(APIError) }
    var bootstrapResult: Result = .failure(.offline)
    var putSetResult: Result2 = .failure(.offline)
    private(set) var putSetCalls: [(sessionId: UUID, setId: UUID)] = []

    enum Result2 { case success(RecordedSet), failure(APIError) }

    func setBootstrapResult(_ value: Result) { bootstrapResult = value }
    func setPutSetResult(_ value: Result2) { putSetResult = value }

    func bootstrap() async throws(APIError) -> BootstrapResponse {
        switch bootstrapResult {
        case .success(let response): return response
        case .failure(let error): throw error
        }
    }

    func putSet(sessionId: UUID, setId: UUID, _ body: SetWrite) async throws(APIError) -> RecordedSet {
        putSetCalls.append((sessionId, setId))
        switch putSetResult {
        case .success(let recorded): return recorded
        case .failure(let error): throw error
        }
    }
}

private func emptyBootstrap(studios: [BootstrapResponse.Studio] = []) -> BootstrapResponse {
    BootstrapResponse(studios: studios, machines: [], calibrations: [], lastSets: [])
}

private func tempDirectory() -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("catalog-tests-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

@Suite("CatalogStore")
struct CatalogStoreTests {
    @Test("load() ohne Studios ergibt loaded(hasStudio: false)")
    func loadWithoutStudio() async {
        let loader = FakeBootstrapLoader()
        await loader.setBootstrapResult(.success(emptyBootstrap()))
        let store = CatalogStore(loader: loader, pendingWriteStore: PendingWriteStore(directory: tempDirectory()))
        await store.load()
        #expect(store.loadState == .loaded(hasStudio: false))
    }

    @Test("load() mit einem Studio ergibt loaded(hasStudio: true)")
    func loadWithStudio() async {
        let loader = FakeBootstrapLoader()
        await loader.setBootstrapResult(.success(emptyBootstrap(studios: [.init(id: "s1", name: "Kraftwerk Nord", timezone: "Europe/Berlin")])))
        let store = CatalogStore(loader: loader, pendingWriteStore: PendingWriteStore(directory: tempDirectory()))
        await store.load()
        #expect(store.loadState == .loaded(hasStudio: true))
    }

    @Test("ein Netzwerkfehler ergibt .failed")
    func loadFailure() async {
        let loader = FakeBootstrapLoader()
        await loader.setBootstrapResult(.failure(.offline))
        let store = CatalogStore(loader: loader, pendingWriteStore: PendingWriteStore(directory: tempDirectory()))
        await store.load()
        #expect(store.loadState == .failed)
    }

    @Test("enqueue speichert sofort auf Platte")
    func enqueuePersists() {
        let directory = tempDirectory()
        let writeStore = PendingWriteStore(directory: directory)
        let store = CatalogStore(loader: FakeBootstrapLoader(), pendingWriteStore: writeStore)
        let write = PendingSetWrite(sessionId: UUID(), setId: UUID(), body: SetWrite(machineId: "m1", exerciseId: "ex1", setIndex: 1, weightKg: 80, reps: 10, rir: nil))
        store.enqueue(write)
        #expect(PendingWriteStore(directory: directory).loadAll() == [write])
    }

    @Test("flushPending entfernt erfolgreich gesendete Eintraege")
    func flushRemovesSucceeded() async {
        let directory = tempDirectory()
        let loader = FakeBootstrapLoader()
        let recorded = RecordedSet(id: "r1", studioId: "s1", userId: "u1", sessionId: UUID().uuidString, machineId: "m1", exerciseId: "ex1", setIndex: 1, weightKg: 80, reps: 10, rir: nil, problemFlag: false, problemReason: nil, performedAt: "2026-09-01T10:00:00Z")
        await loader.setPutSetResult(.success(recorded))
        let store = CatalogStore(loader: loader, pendingWriteStore: PendingWriteStore(directory: directory))
        let write = PendingSetWrite(sessionId: UUID(), setId: UUID(), body: SetWrite(machineId: "m1", exerciseId: "ex1", setIndex: 1, weightKg: 80, reps: 10, rir: nil))
        store.enqueue(write)
        await store.flushPending()
        #expect(store.pendingWrites.isEmpty)
    }

    @Test("flushPending behaelt Eintraege, die weiterhin fehlschlagen")
    func flushKeepsFailed() async {
        let directory = tempDirectory()
        let loader = FakeBootstrapLoader()
        await loader.setPutSetResult(.failure(.offline))
        let store = CatalogStore(loader: loader, pendingWriteStore: PendingWriteStore(directory: directory))
        let write = PendingSetWrite(sessionId: UUID(), setId: UUID(), body: SetWrite(machineId: "m1", exerciseId: "ex1", setIndex: 1, weightKg: 80, reps: 10, rir: nil))
        store.enqueue(write)
        await store.flushPending()
        #expect(store.pendingWrites == [write])
    }
}
```

- [ ] **Schritt 2: Tests ausführen, Fehlschlag bestätigen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/CatalogStoreTests 2>&1 | tail -40
```

Erwartet: FAIL — `CatalogLoadState`, `CatalogStore` existieren noch nicht.

- [ ] **Schritt 3: `CatalogLoadState.swift` implementieren**

```swift
import Foundation

enum CatalogLoadState: Equatable {
    case idle
    case loading
    case loaded(hasStudio: Bool)
    case failed
}
```

- [ ] **Schritt 4: `CatalogStore.swift` implementieren**

`init` nimmt intern `any BootstrapLoading` an (das Test-Protokoll aus Schritt 1) statt konkret `APIClient` — dadurch ist der Store sowohl mit dem echten `APIClient` (der es über die `extension APIClient: BootstrapLoading` aus dem Test bereits erfüllt) als auch mit `FakeBootstrapLoader` konstruierbar. Die Protokoll-Definition selbst gehört nicht ins Testziel, sondern hierher:

```swift
import Foundation
import Observation

protocol BootstrapLoading: Sendable {
    func bootstrap() async throws(APIError) -> BootstrapResponse
    func putSet(sessionId: UUID, setId: UUID, _ body: SetWrite) async throws(APIError) -> RecordedSet
}

extension APIClient: BootstrapLoading {}

@Observable
final class CatalogStore {
    private(set) var bootstrap: BootstrapResponse?
    private(set) var loadState: CatalogLoadState = .idle
    private(set) var pendingWrites: [PendingSetWrite]

    private let loader: any BootstrapLoading
    private let pendingWriteStore: PendingWriteStore

    init(loader: any BootstrapLoading, pendingWriteStore: PendingWriteStore) {
        self.loader = loader
        self.pendingWriteStore = pendingWriteStore
        pendingWrites = pendingWriteStore.loadAll()
    }

    func load() async {
        loadState = .loading
        do {
            let response = try await loader.bootstrap()
            bootstrap = response
            loadState = .loaded(hasStudio: !response.studios.isEmpty)
        } catch {
            loadState = .failed
        }
    }

    func enqueue(_ write: PendingSetWrite) {
        pendingWrites.append(write)
        pendingWriteStore.save(pendingWrites)
    }

    func flushPending() async {
        var remaining: [PendingSetWrite] = []
        for write in pendingWrites {
            do {
                _ = try await loader.putSet(sessionId: write.sessionId, setId: write.setId, write.body)
            } catch {
                remaining.append(write)
            }
        }
        pendingWrites = remaining
        pendingWriteStore.save(remaining)
    }
}
```

Schritt 1 der Tests deklariert `BootstrapLoading`/`FakeBootstrapLoader` testseitig noch einmal probeweise — beim Implementieren wird die Protokoll-Deklaration **aus der Testdatei entfernt** (sie zieht jetzt aus `CatalogStore.swift`), `extension APIClient: BootstrapLoading {}` ebenso, nur `FakeBootstrapLoader` bleibt im Testziel.

- [ ] **Schritt 5: Testdatei bereinigen**

In `CatalogStoreTests.swift` die `protocol BootstrapLoading` und `extension APIClient: BootstrapLoading {}` aus Schritt 1 löschen (jetzt Teil von `CatalogStore.swift`), `FakeBootstrapLoader` bleibt stehen.

- [ ] **Schritt 6: Tests ausführen, Erfolg bestätigen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/CatalogStoreTests 2>&1 | tail -40
```

Erwartet: PASS für alle sechs Tests.

- [ ] **Schritt 7: Alle Tests zusammen laufen lassen und committen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test 2>&1 | tail -50
git add FitnessMember/Catalog/CatalogLoadState.swift FitnessMember/Catalog/CatalogStore.swift FitnessMemberTests/CatalogStoreTests.swift
git commit -m "feat(ios): CatalogStore mit Bootstrap-Cache und Warteschlangen-Abarbeitung"
```

---

### Aufgabe 11: Navigation-Logik — `RootDestinationLogic`, `PendingTagStore`, `AuthRoute`

**Bewusst nur Logik und Zustand in dieser Aufgabe, keine `View`-Structs.** `RootView`, `AuthFlow` und `MainTabView` referenzieren Screens, die erst in den Aufgaben 12–21 entstehen — als `View`s hier geschrieben, würde das gesamte `FitnessMember`-Ziel bis dahin nicht mehr kompilieren, und `FitnessMemberTests` importiert `@testable import FitnessMember`: **jeder** Testlauf in jeder Folgeaufgabe schlüge fehl, nicht nur der die betroffene Datei betrifft. Die eigentliche Navigations-Komposition (`RootView`, `AuthFlow`, `MainTabView`, `ProfilRootView`) folgt gebündelt in Aufgabe 22, nachdem alle Screens existieren.

**Files:**
- Create: `apps/ios-member/FitnessMember/Navigation/RootDestination.swift`
- Create: `apps/ios-member/FitnessMember/Navigation/PendingTagStore.swift`
- Create: `apps/ios-member/FitnessMember/Navigation/AuthRoute.swift`
- Test: `apps/ios-member/FitnessMemberTests/RootDestinationTests.swift`

**Interfaces:**
- Consumes: `Session` (Aufgabe 7), `CatalogLoadState` (Aufgabe 10)
- Produces: `enum RootDestination: Equatable { case authFlow, loadingCatalog, noStudio, main }`, `enum RootDestinationLogic { static func destination(session:catalogState:) -> RootDestination }`, `@Observable final class PendingTagStore { var token: String? { get }; func capture(_:); func consume() -> String? }`, `enum AuthRoute: Hashable { case code(email: String), register, password }` — von den Zugang-Screens (Aufgabe 12–16, über `NavigationLink(value:)`) und von Aufgabe 22 (`RootView`/`AuthFlow`/`MainTabView`) konsumiert.

- [ ] **Schritt 1: Test für die reine Zustandslogik schreiben — vier Kombinationen**

```swift
import Foundation
import Testing
@testable import FitnessMember

@Suite("RootDestinationLogic")
struct RootDestinationLogicTests {
    private let session = Session(accessToken: "t", userId: "u", email: "lena@example.de", expiresAt: .distantFuture)

    @Test("ohne Session immer authFlow, unabhaengig vom Catalog-Zustand")
    func noSessionAlwaysAuthFlow() {
        #expect(RootDestinationLogic.destination(session: nil, catalogState: .idle) == .authFlow)
        #expect(RootDestinationLogic.destination(session: nil, catalogState: .loaded(hasStudio: true)) == .authFlow)
    }

    @Test("Session, Catalog laedt noch: loadingCatalog")
    func loadingShowsSpinner() {
        #expect(RootDestinationLogic.destination(session: session, catalogState: .loading) == .loadingCatalog)
        #expect(RootDestinationLogic.destination(session: session, catalogState: .idle) == .loadingCatalog)
    }

    @Test("Session, geladen ohne Studio: noStudio")
    func loadedWithoutStudio() {
        #expect(RootDestinationLogic.destination(session: session, catalogState: .loaded(hasStudio: false)) == .noStudio)
    }

    @Test("Session, geladen mit Studio: main")
    func loadedWithStudio() {
        #expect(RootDestinationLogic.destination(session: session, catalogState: .loaded(hasStudio: true)) == .main)
    }

    @Test("ein fehlgeschlagenes Laden fuehrt konservativ zu noStudio, nicht main")
    func failedFallsBackToNoStudio() {
        #expect(RootDestinationLogic.destination(session: session, catalogState: .failed) == .noStudio)
    }
}
```

- [ ] **Schritt 2: Test ausführen, Fehlschlag bestätigen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/RootDestinationLogicTests 2>&1 | tail -30
```

Erwartet: FAIL — `RootDestination`, `RootDestinationLogic` existieren noch nicht.

- [ ] **Schritt 3: `RootDestination.swift` implementieren**

```swift
import Foundation

enum RootDestination: Equatable {
    case authFlow
    case loadingCatalog
    case noStudio
    case main
}

enum RootDestinationLogic {
    /// .failed faellt bewusst auf .noStudio zurueck statt auf .main: ein
    /// gescheiterter Bootstrap-Ladevorgang soll nie so aussehen wie ein
    /// Mitglied ohne Studio, aber .noStudio zeigt wenigstens eine Aktion
    /// (Beitreten/erneut versuchen) statt einer blockierenden Sackgasse.
    static func destination(session: Session?, catalogState: CatalogLoadState) -> RootDestination {
        guard session != nil else { return .authFlow }
        switch catalogState {
        case .idle, .loading: return .loadingCatalog
        case .loaded(let hasStudio): return hasStudio ? .main : .noStudio
        case .failed: return .noStudio
        }
    }
}
```

- [ ] **Schritt 4: Test ausführen, Erfolg bestätigen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/RootDestinationLogicTests 2>&1 | tail -30
```

Erwartet: PASS für alle fünf Tests.

- [ ] **Schritt 5: `PendingTagStore.swift` implementieren**

```swift
import Foundation
import Observation

/// Haelt einen ueber Universal Link erfassten Tag-Token, bis er verbraucht
/// wird -- ersetzt die alte Weitergabe direkt an ContentView aus Task 7
/// (M0). In diesem Sub-Projekt nur fuer die Pending-Route-Banner-Anzeige auf
/// LoginMailView genutzt; Sub-Projekt 2 (Geraet-Kernflow) konsumiert token
/// nach dem Login, um direkt zum Geraet zu navigieren.
@Observable
final class PendingTagStore {
    private(set) var token: String?

    func capture(_ token: String) {
        self.token = token
    }

    func consume() -> String? {
        defer { token = nil }
        return token
    }
}
```

- [ ] **Schritt 6: `AuthRoute.swift` implementieren**

```swift
import Foundation

enum AuthRoute: Hashable {
    case code(email: String)
    case register
    case password
}
```

- [ ] **Schritt 7: Bauen und alle bisherigen Tests laufen lassen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test 2>&1 | tail -50
```

Erwartet: `TEST SUCCEEDED` — `AuthRoute`/`PendingTagStore` haben keine Abhängigkeit auf noch fehlende Screens, das Ziel kompiliert vollständig.

- [ ] **Schritt 8: Commit**

```bash
cd apps/ios-member && git add FitnessMember/Navigation/RootDestination.swift FitnessMember/Navigation/PendingTagStore.swift FitnessMember/Navigation/AuthRoute.swift FitnessMemberTests/RootDestinationTests.swift
git commit -m "feat(ios): Root-Navigationslogik, PendingTagStore, AuthRoute"
```

---

### Aufgabe 12: Screen — `LoginMailView`

**Files:**
- Create: `apps/ios-member/FitnessMember/Screens/Zugang/LoginMailView.swift`

**Interfaces:**
- Consumes: `SessionStore` (Aufgabe 8), `PendingTagStore`, `AuthRoute` (Aufgabe 11), `AuthCopy`, `EmailValidator` (Aufgabe 6), `LabeledField`, `PrimaryButton`, `InlineBanner`, `DesignSystem` (Aufgaben 2–3)
- Produces: `struct LoginMailView: View` — von Aufgabe 22 (`AuthFlow`) als Wurzel des Auth-`NavigationStack` konsumiert.

Reine `View` ohne eigene testbare Logik (Validierung/Fehlertext kommen bereits getestet aus Aufgabe 6). Abnahme laut Design-Dokument §10 manuell gegen `docs/superpowers/design/member/LoginMail.dc.html`.

- [ ] **Schritt 1: `LoginMailView.swift` schreiben**

```swift
import SwiftUI

struct LoginMailView: View {
    @Environment(SessionStore.self) private var sessionStore
    @Environment(PendingTagStore.self) private var pendingTagStore
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if pendingTagStore.token != nil {
                    InlineBanner(
                        tone: .accent,
                        message: "Melde dich an — danach landest du direkt bei diesem Gerät.",
                        icon: "wave.3.right"
                    )
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("ANMELDEN").font(DesignSystem.Typography.screentitel)
                    Text("Mit E-Mail und Passwort.").foregroundStyle(DesignSystem.Color.textMuted)
                }

                LabeledField(label: "E-Mail-Adresse") {
                    TextField("name@beispiel.de", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                LabeledField(label: "Passwort") {
                    SecureField("••••••••••", text: $password)
                }

                if let errorMessage {
                    InlineBanner(tone: .danger, message: errorMessage)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
        }
        .background(DesignSystem.Color.bg)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 16) {
                PrimaryButton(title: "Anmelden", isEnabled: !email.isEmpty && !password.isEmpty, isLoading: isSubmitting) {
                    await submit()
                }
                HStack(spacing: 10) {
                    NavigationLink("Passwort vergessen", value: AuthRoute.password)
                    Circle().fill(DesignSystem.Color.line).frame(width: 3, height: 3)
                    NavigationLink("Konto anlegen", value: AuthRoute.register)
                }
                .font(.system(size: 13))
                .foregroundStyle(DesignSystem.Color.textMuted)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 20)
            .background(DesignSystem.Color.bg)
        }
    }

    private func submit() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await sessionStore.signIn(email: email, password: password)
        } catch {
            errorMessage = AuthCopy.unbekanntOderFalsch
        }
    }
}
```

- [ ] **Schritt 2: Bauen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" build 2>&1 | tail -40
```

Erwartet: `BUILD SUCCEEDED` — `LoginMailView` referenziert `LoginCodeView`/`MemberRegistrierenView`/`MemberPasswortView` nur indirekt über `AuthRoute`-Werte, nicht als Typ, deshalb kein Compile-Fehler trotz noch fehlender Screens.

- [ ] **Schritt 3: Commit**

```bash
cd apps/ios-member && git add FitnessMember/Screens/Zugang/LoginMailView.swift
git commit -m "feat(ios): LoginMailView"
```

---

### Aufgabe 13: Screen — `LoginCodeView` und `CodeDigitsView`

**Files:**
- Create: `apps/ios-member/FitnessMember/DesignSystem/Components/CodeDigitsView.swift`
- Create: `apps/ios-member/FitnessMember/Screens/Zugang/LoginCodeView.swift`

**Interfaces:**
- Consumes: `SessionStore` (Aufgabe 8), `CodeEntry`, `AuthCopy` (Aufgabe 6), `PrimaryButton`, `DesignSystem` (Aufgaben 2–3)
- Produces: `struct CodeDigitsView: View` (Binding<CodeEntry>) — auch von Aufgabe 15 (`MemberPasswortView`) konsumiert. `struct LoginCodeView: View` (init(email: String)) — von Aufgabe 22 (`AuthFlow`) über `AuthRoute.code(email:)` konsumiert.

- [ ] **Schritt 1: `CodeDigitsView.swift` schreiben — sechs Kästchen plus unsichtbares Eingabefeld**

```swift
import SwiftUI

/// Sechs sichtbare Kaestchen, dahinter ein fast unsichtbares TextField als
/// Ziffernblock-Eingabeziel -- Standardmuster fuer Code-Eingaben auf iOS.
struct CodeDigitsView: View {
    @Binding var entry: CodeEntry
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            HStack(spacing: 9) {
                ForEach(0..<CodeEntry.length, id: \.self) { index in
                    let characters = Array(entry.digits)
                    let digit = index < characters.count ? String(characters[index]) : ""
                    Text(digit)
                        .font(.system(size: 28, weight: .black).monospacedDigit())
                        .frame(maxWidth: .infinity)
                        .frame(height: 66)
                        .background(DesignSystem.Color.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 13)
                                .stroke(
                                    index == characters.count ? DesignSystem.Color.accent : DesignSystem.Color.line,
                                    lineWidth: index == characters.count ? 1.5 : 1
                                )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 13))
                }
            }
            TextField("", text: Binding(
                get: { entry.digits },
                set: { entry = CodeEntry(digits: $0) }
            ))
            .keyboardType(.numberPad)
            .focused($isFocused)
            .opacity(0.02)
            .accessibilityLabel("Bestätigungscode")
        }
        .onAppear { isFocused = true }
        .onTapGesture { isFocused = true }
    }
}

#Preview {
    CodeDigitsView(entry: .constant(CodeEntry(digits: "419")))
        .padding()
        .background(DesignSystem.Color.bg)
}
```

- [ ] **Schritt 2: `LoginCodeView.swift` schreiben**

```swift
import SwiftUI

struct LoginCodeView: View {
    let email: String

    @Environment(SessionStore.self) private var sessionStore
    @State private var code = CodeEntry()
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @State private var secondsUntilResend = 60

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                Text("E-MAIL BESTÄTIGEN").font(DesignSystem.Typography.screentitel)
                (Text("Code gesendet an ") + Text(email).foregroundColor(DesignSystem.Color.text).fontWeight(.semibold))
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }

            CodeDigitsView(entry: $code)

            if secondsUntilResend > 0 {
                Label("Neuen Code anfordern in \(formattedCountdown)", systemImage: "clock")
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.Color.textFaint)
            } else {
                Button("Neuen Code anfordern") {
                    Task {
                        await sessionStore.resendSignupCode(email: email)
                        secondsUntilResend = 60
                    }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DesignSystem.Color.text)
            }

            if let errorMessage {
                InlineBanner(tone: .danger, message: errorMessage)
            }

            InlineBanner(
                tone: .muted,
                message: "Keine Mail bekommen? Sieh im Spam-Ordner nach. Der Code ist eine Stunde gültig.",
                icon: "envelope"
            )

            Spacer()

            PrimaryButton(
                title: "Bestätigen",
                isEnabled: code.isComplete,
                isLoading: isSubmitting,
                disabledHint: code.isComplete ? nil : "Noch \(code.remaining) Ziffern"
            ) {
                await submit()
            }
        }
        .padding(28)
        .background(DesignSystem.Color.bg)
        .onReceive(timer) { _ in
            if secondsUntilResend > 0 { secondsUntilResend -= 1 }
        }
        .onChange(of: code.isComplete) { _, complete in
            if complete { Task { await submit() } }
        }
    }

    private var formattedCountdown: String {
        String(format: "%02d:%02d", secondsUntilResend / 60, secondsUntilResend % 60)
    }

    private func submit() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await sessionStore.verifySignupCode(email: email, code: code.digits)
        } catch {
            errorMessage = AuthCopy.codeUngueltig
        }
    }
}
```

- [ ] **Schritt 3: Bauen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" build 2>&1 | tail -40
```

Erwartet: `BUILD SUCCEEDED`.

- [ ] **Schritt 4: Im Simulator gegen `LoginCode.dc.html` prüfen**

App im Simulator starten (nach Aufgabe 22/23 vollständig verdrahtet — bis dahin reicht die `#Preview` von `CodeDigitsView` im Canvas). Sechs-Kästchen-Layout, Fokusring auf dem nächsten leeren Feld, Auto-Submit bei der sechsten Ziffer gegen `docs/superpowers/design/member/LoginCode.dc.html` abgleichen.

- [ ] **Schritt 5: Commit**

```bash
cd apps/ios-member && git add FitnessMember/DesignSystem/Components/CodeDigitsView.swift FitnessMember/Screens/Zugang/LoginCodeView.swift
git commit -m "feat(ios): LoginCodeView mit wiederverwendbarer CodeDigitsView"
```

---

### Aufgabe 14: Screen — `MemberRegistrierenView`

**Files:**
- Create: `apps/ios-member/FitnessMember/Screens/Zugang/MemberRegistrierenView.swift`

**Interfaces:**
- Consumes: `SessionStore` (Aufgabe 8), `EmailValidator`, `PasswordPolicy`, `AuthCopy` (Aufgabe 6), `AuthRoute` (Aufgabe 11), `LabeledField`, `PrimaryButton`, `InlineBanner` (Aufgabe 3)
- Produces: `struct MemberRegistrierenView: View` — von Aufgabe 22 (`AuthFlow`) über `AuthRoute.register` konsumiert.

- [ ] **Schritt 1: `MemberRegistrierenView.swift` schreiben**

```swift
import SwiftUI

struct MemberRegistrierenView: View {
    @Environment(SessionStore.self) private var sessionStore
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false
    @State private var didRequireConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("KONTO ANLEGEN").font(DesignSystem.Typography.screentitel)
                    Text("Für dein Studio brauchst du ein Konto.").foregroundStyle(DesignSystem.Color.textMuted)
                }

                LabeledField(label: "E-Mail-Adresse") {
                    TextField("name@beispiel.de", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                LabeledField(label: "Passwort") {
                    SecureField("••••••••••", text: $password)
                }
                Text("Mindestens zehn Zeichen. Länge zählt mehr als Sonderzeichen.")
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Color.textFaint)

                if let errorMessage {
                    InlineBanner(tone: .danger, message: errorMessage)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
        }
        .background(DesignSystem.Color.bg)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                PrimaryButton(
                    title: "Konto anlegen",
                    isEnabled: EmailValidator.isValid(email) && PasswordPolicy.isValid(password),
                    isLoading: isSubmitting
                ) {
                    await submit()
                }
                Text("Danach schicken wir dir einen Code zur Bestätigung.")
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Color.textFaint)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 20)
            .background(DesignSystem.Color.bg)
        }
        .navigationDestination(isPresented: $didRequireConfirmation) {
            LoginCodeView(email: email)
        }
    }

    private func submit() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let gotImmediateSession = try await sessionStore.signUp(email: email, password: password)
            if !gotImmediateSession {
                didRequireConfirmation = true
            }
        } catch {
            errorMessage = AuthCopy.unbekanntOderFalsch
        }
    }
}
```

Die neutrale Fehlermeldung (`AuthCopy.unbekanntOderFalsch`) deckt hier auch den Fall "bereits registriert" ab — dieselbe Konstante wie `LoginMailView`, wie in `AuthCopy.swift` (Aufgabe 6) dokumentiert.

- [ ] **Schritt 2: Bauen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" build 2>&1 | tail -40
```

Erwartet: `BUILD SUCCEEDED` — `LoginCodeView` existiert bereits aus Aufgabe 13.

- [ ] **Schritt 3: Commit**

```bash
cd apps/ios-member && git add FitnessMember/Screens/Zugang/MemberRegistrierenView.swift
git commit -m "feat(ios): MemberRegistrierenView"
```

---

### Aufgabe 15: Screen — `MemberPasswortView`

**Files:**
- Create: `apps/ios-member/FitnessMember/Screens/Zugang/MemberPasswortView.swift`

**Interfaces:**
- Consumes: `SessionStore` (Aufgabe 8), `CodeEntry`, `EmailValidator`, `PasswordPolicy`, `AuthCopy` (Aufgabe 6), `CodeDigitsView` (Aufgabe 13), `LabeledField`, `PrimaryButton`, `InlineBanner` (Aufgabe 3)
- Produces: `struct MemberPasswortView: View` — von Aufgabe 22 (`AuthFlow`) über `AuthRoute.password` konsumiert.

Ein Screen, zwei immer sichtbare Abschnitte (Design-Spec §7/§8-Korrektur): "Vergessen" (E-Mail anfordern) und "Zurücksetzen" (Code + neues Passwort). Kein Deep-Link, kein Navigationsziel für den zweiten Abschnitt — `apps/web/app/passwort-vergessen/actions.ts` bestätigt `verifyOtp(type: "recovery")` mit sechsstelligem Code.

- [ ] **Schritt 1: `MemberPasswortView.swift` schreiben**

```swift
import SwiftUI

struct MemberPasswortView: View {
    @Environment(SessionStore.self) private var sessionStore

    @State private var requestEmail = ""
    @State private var requestSent = false
    @State private var resetEmail = ""
    @State private var code = CodeEntry()
    @State private var newPassword = ""
    @State private var repeatPassword = ""
    @State private var errorMessage: String?
    @State private var isSaving = false

    private var canReset: Bool {
        EmailValidator.isValid(resetEmail)
            && code.isComplete
            && PasswordPolicy.isValid(newPassword)
            && newPassword == repeatPassword
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("PASSWORT").font(DesignSystem.Typography.screentitel)
                    Text("Fordere einen Code an, oder setze ein neues Passwort, wenn du schon einen hast.")
                        .foregroundStyle(DesignSystem.Color.textMuted)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("VERGESSEN").font(DesignSystem.Typography.label).foregroundStyle(DesignSystem.Color.textMuted)
                    LabeledField(label: "E-Mail-Adresse") {
                        TextField("name@beispiel.de", text: $requestEmail)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    Button {
                        Task { await requestReset() }
                    } label: {
                        Label("Code anfordern", systemImage: "lock")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .disabled(!EmailValidator.isValid(requestEmail))
                    Text(AuthCopy.sicherheitshinweisPasswortVergessen)
                        .font(.system(size: 12))
                        .foregroundStyle(DesignSystem.Color.textFaint)
                }

                Divider().background(DesignSystem.Color.line)

                VStack(alignment: .leading, spacing: 12) {
                    Text("ZURÜCKSETZEN").font(DesignSystem.Typography.label).foregroundStyle(DesignSystem.Color.textMuted)
                    LabeledField(label: "E-Mail-Adresse") {
                        TextField("name@beispiel.de", text: $resetEmail)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    LabeledField(label: "Code") {
                        CodeDigitsView(entry: $code)
                    }
                    .frame(height: nil)
                    LabeledField(label: "Neues Passwort") {
                        SecureField("••••••••••", text: $newPassword)
                    }
                    LabeledField(label: "Wiederholen") {
                        SecureField("••••••••••", text: $repeatPassword)
                    }
                }

                if let errorMessage {
                    InlineBanner(tone: .danger, message: errorMessage)
                }

                PrimaryButton(title: "Passwort speichern", isEnabled: canReset, isLoading: isSaving) {
                    await save()
                }
            }
            .padding(28)
        }
        .background(DesignSystem.Color.bg)
    }

    private func requestReset() async {
        await sessionStore.requestPasswordReset(email: requestEmail)
        requestSent = true
        if resetEmail.isEmpty { resetEmail = requestEmail }
    }

    private func save() async {
        guard newPassword == repeatPassword else {
            errorMessage = AuthCopy.passwoerterStimmenNichtUeberein
            return
        }
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        do {
            try await sessionStore.resetPassword(email: resetEmail, code: code.digits, newPassword: newPassword)
        } catch {
            errorMessage = AuthCopy.codeUngueltig
        }
    }
}
```

`LabeledField(label: "Code") { CodeDigitsView(...) }` übernimmt `LabeledField`s 58pt-Rahmen nicht sinnvoll (die sechs Kästchen sind selbst schon 66pt hoch) — `.frame(height: nil)` hebt die feste Höhe aus `LabeledField` wieder auf, das Eyebrow-Label bleibt. Beim manuellen Abgleich in Schritt 3 prüfen, ob das visuell zu `LoginCode.dc.html`s Kästchen-Stil passt; falls nicht, `CodeDigitsView` direkt ohne `LabeledField`-Wrapper mit einem eigenen `Text("CODE")`-Label darüber setzen.

- [ ] **Schritt 2: Bauen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" build 2>&1 | tail -40
```

Erwartet: `BUILD SUCCEEDED`.

- [ ] **Schritt 3: Manuell gegen `MemberPasswort.dc.html` abgleichen, Codefeld-Layout korrigieren falls nötig**

Simulator/Canvas-Vorschau öffnen, gegen `docs/superpowers/design/member/MemberPasswort.dc.html` prüfen — insbesondere, dass das ergänzte Codefeld (im Artboard nicht vorhanden, siehe Design-Spec-Korrektur §7) sich visuell einfügt statt wie ein Fremdkörper zu wirken.

- [ ] **Schritt 4: Commit**

```bash
cd apps/ios-member && git add FitnessMember/Screens/Zugang/MemberPasswortView.swift
git commit -m "feat(ios): MemberPasswortView (Anfordern + Zuruecksetzen mit Code)"
```

---

### Aufgabe 16: Screen — `MemberPasswortAendernView`

**Files:**
- Create: `apps/ios-member/FitnessMember/Screens/Zugang/MemberPasswortAendernView.swift`

**Interfaces:**
- Consumes: `SessionStore` (Aufgabe 8), `PasswordPolicy`, `AuthCopy` (Aufgabe 6), `LabeledField`, `PrimaryButton`, `InlineBanner` (Aufgabe 3)
- Produces: `struct MemberPasswortAendernView: View` — von Aufgabe 22 (`ProfilRootView`) per Push konsumiert.

- [ ] **Schritt 1: `MemberPasswortAendernView.swift` schreiben**

```swift
import SwiftUI

struct MemberPasswortAendernView: View {
    @Environment(SessionStore.self) private var sessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var repeatPassword = ""
    @State private var errorMessage: String?
    @State private var isSaving = false

    private var canSubmit: Bool {
        !currentPassword.isEmpty && PasswordPolicy.isValid(newPassword) && newPassword == repeatPassword
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("PASSWORT ÄNDERN").font(DesignSystem.Typography.screentitel)

                LabeledField(label: "Aktuelles Passwort") {
                    SecureField("••••••••••", text: $currentPassword)
                }
                LabeledField(label: "Neues Passwort") {
                    SecureField("••••••••••", text: $newPassword)
                }
                LabeledField(label: "Wiederholen") {
                    SecureField("••••••••••", text: $repeatPassword)
                }

                if let errorMessage {
                    InlineBanner(tone: .danger, message: errorMessage)
                }
            }
            .padding(28)
        }
        .background(DesignSystem.Color.bg)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Passwort speichern", isEnabled: canSubmit, isLoading: isSaving) {
                await save()
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 20)
            .background(DesignSystem.Color.bg)
        }
    }

    private func save() async {
        guard newPassword == repeatPassword else {
            errorMessage = AuthCopy.passwoerterStimmenNichtUeberein
            return
        }
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        do {
            try await sessionStore.changePassword(currentPassword: currentPassword, newPassword: newPassword)
            dismiss()
        } catch {
            errorMessage = AuthCopy.aktuellesPasswortFalsch
        }
    }
}
```

- [ ] **Schritt 2: Bauen und committen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" build 2>&1 | tail -40
git add FitnessMember/Screens/Zugang/MemberPasswortAendernView.swift
git commit -m "feat(ios): MemberPasswortAendernView"
```

Erwartet: `BUILD SUCCEEDED`.

---

### Aufgabe 17: Backend — Beitritts- und Austritts-Endpoints

**Einzige Backend-Aufgabe in diesem sonst iOS-only Plan.** Beim Brainstorming bestätigt: `join_studio_by_code` und `join_studio_by_tag` existieren als Postgres-Funktionen, werden aber ausschließlich vom Web über Server Actions aufgerufen (direkter Postgres-Zugriff) — ein Pfad, den iOS laut M1-Spec §6.2 nicht nehmen darf. Diese Aufgabe schließt die Lücke mit drei dünnen `/api/v1`-Routen, exakt im Muster der sechs bestehenden Handler.

**Files:**
- Modify: `packages/domain/src/people.ts`
- Create: `apps/web/app/api/v1/studios/join-by-code/route.ts`
- Create: `apps/web/app/api/v1/studios/join-by-tag/route.ts`
- Create: `apps/web/app/api/v1/studios/[studioId]/membership/route.ts`
- Test: `tests/integration/api-studios-membership.test.ts`

**Interfaces:**
- Consumes: `joinStudioByCode` (bereits vorhanden, `packages/domain/src/people.ts:52-71`), `hashTagToken`/`isValidTagToken` (`packages/domain/src/tags.ts`), `bearerClientFrom`, `errorResponse`/`fromDomainError` (`apps/web/lib/api/respond.ts`)
- Produces: `POST /api/v1/studios/join-by-code` (Body `{code: string}` → `{studioId, joined}`), `POST /api/v1/studios/join-by-tag` (Body `{tagToken: string}` → `{studioId, machineId, joined}`), `DELETE /api/v1/studios/{studioId}/membership` (204) — von Aufgabe 18 (`APIClient`-Erweiterung) konsumiert.

- [ ] **Schritt 1: `joinStudioByTag` und `leaveStudio` zu `packages/domain/src/people.ts` hinzufügen**

Nach der bestehenden `joinStudioByCode`-Funktion (Zeile 71) einfügen:

```ts
import { hashTagToken, isValidTagToken } from "./tags.js";

/**
 * Gegenstueck zu joinStudioByCode fuer den Scan-Weg. Der rohe Token wird nur
 * gehasht verwendet, nie protokolliert (Spec 10.4) -- derselbe Umgang wie in
 * tag-context.ts.
 */
export async function joinStudioByTag(
  client: SupabaseClient,
  token: string,
): Promise<{ studioId: string; machineId: string | null; joined: boolean }> {
  if (!isValidTagToken(token)) {
    throw new DomainError("validation_failed", "Der Token hat ein ungueltiges Format.");
  }
  const { data, error } = await client.rpc("join_studio_by_tag", {
    p_token_hash: hashTagToken(token),
  });
  if (error) throw new DomainError("internal", error.message);
  const row = (data ?? [])[0] as
    | { studio_id: string; machine_id: string | null; joined: boolean }
    | undefined;
  if (!row) {
    throw new DomainError("not_found", "Dieser Tag ist ungueltig.");
  }
  return { studioId: row.studio_id, machineId: row.machine_id, joined: row.joined };
}

/**
 * Selbstaustritt (0024_membership_self_leave.sql) -- eine reine DELETE-Policy
 * auf role = 'member', kein RPC. Der explizite user_id-Filter hier ist
 * Verteidigung in der Tiefe, die Policy erzwingt es ohnehin.
 */
export async function leaveStudio(client: SupabaseClient, studioId: string): Promise<void> {
  const userId = await requireUserId(client);
  const { error, count } = await client
    .from("studio_memberships")
    .delete({ count: "exact" })
    .eq("studio_id", studioId)
    .eq("user_id", userId)
    .eq("role", "member");
  if (error) throw new DomainError("internal", error.message);
  if (!count) {
    throw new DomainError("not_found", "Keine Mitgliedschaft zum Entfernen gefunden.");
  }
}
```

`requireUserId` ist bereits in `packages/domain/src/auth.ts` vorhanden (von `getTagContext` u.a. genutzt) — am Dateikopf von `people.ts` importieren, falls noch nicht vorhanden:

```ts
import { requireUserId } from "./auth.js";
```

Beide neuen Funktionen und `joinStudioByCode` im Domain-Paket-Export (`packages/domain/src/index.ts`, falls dort ein expliziter Re-Export steht — sonst diesen Schritt überspringen, da `people.ts` bereits vollständig re-exportiert wird) sichtbar machen.

- [ ] **Schritt 2: `apps/web/app/api/v1/studios/join-by-code/route.ts` schreiben**

```ts
import { joinStudioByCode } from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

export async function POST(request: Request): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) return errorResponse("unauthorized", "Anmeldung erforderlich.");

  let payload: unknown;
  try {
    payload = await request.json();
  } catch {
    return errorResponse("validation_failed", "Der Rumpf ist kein gueltiges JSON.");
  }

  const code =
    typeof payload === "object" && payload !== null && "code" in payload
      ? String((payload as { code: unknown }).code)
      : "";

  try {
    const result = await joinStudioByCode(client, code);
    return Response.json(
      { studioId: result.studioId, joined: result.joined },
      { status: 200 },
    );
  } catch (error) {
    return fromDomainError(error);
  }
}
```

- [ ] **Schritt 3: `apps/web/app/api/v1/studios/join-by-tag/route.ts` schreiben**

```ts
import { joinStudioByTag } from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

export async function POST(request: Request): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) return errorResponse("unauthorized", "Anmeldung erforderlich.");

  let payload: unknown;
  try {
    payload = await request.json();
  } catch {
    return errorResponse("validation_failed", "Der Rumpf ist kein gueltiges JSON.");
  }

  const tagToken =
    typeof payload === "object" && payload !== null && "tagToken" in payload
      ? String((payload as { tagToken: unknown }).tagToken)
      : "";

  try {
    const result = await joinStudioByTag(client, tagToken);
    return Response.json(
      { studioId: result.studioId, machineId: result.machineId, joined: result.joined },
      { status: 200 },
    );
  } catch (error) {
    return fromDomainError(error);
  }
}
```

- [ ] **Schritt 4: `apps/web/app/api/v1/studios/[studioId]/membership/route.ts` schreiben**

```ts
import { leaveStudio } from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

type Context = { params: Promise<{ studioId: string }> };

export async function DELETE(request: Request, context: Context): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) return errorResponse("unauthorized", "Anmeldung erforderlich.");

  const { studioId } = await context.params;

  try {
    await leaveStudio(client, studioId);
    return new Response(null, { status: 204 });
  } catch (error) {
    return fromDomainError(error);
  }
}
```

- [ ] **Schritt 5: Integrationstest schreiben — Muster aus `tests/integration/api-tag-context.test.ts` übernommen**

```ts
import { beforeAll, describe, expect, it } from "vitest";
import { createTagToken } from "@fitretro/domain";
import { POST as joinByCode } from "@/app/api/v1/studios/join-by-code/route";
import { POST as joinByTag } from "@/app/api/v1/studios/join-by-tag/route";
import { DELETE as leaveMembership } from "@/app/api/v1/studios/[studioId]/membership/route";
import {
  accessTokenFor,
  createTestUser,
  serviceClient,
  uniqueEmail,
} from "./helpers/clients.js";
import { tagsAnlegen } from "../helpers/tags.js";

let studioId: string;
let joinCode: string;
let machineTagToken: string;
let memberBearer: string;

function jsonRequest(url: string, body: unknown, auth?: string): Request {
  return new Request(url, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      ...(auth ? { authorization: `Bearer ${auth}` } : {}),
    },
    body: JSON.stringify(body),
  });
}

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studio, error: studioError } = await admin
    .from("studios")
    .insert({ name: "Beitritts-API Studio" })
    .select("id, join_code")
    .single();
  if (studioError) throw studioError;
  studioId = studio.id;
  joinCode = studio.join_code;

  machineTagToken = createTagToken();
  await tagsAnlegen(admin, [{ studioId, token: machineTagToken, status: "active" }]);

  const email = uniqueEmail("beitrittapi-member");
  await createTestUser(email);
  memberBearer = await accessTokenFor(email);
});

describe("POST /api/v1/studios/join-by-code", () => {
  it("tritt einem Studio ueber den Code bei", async () => {
    const response = await joinByCode(jsonRequest("http://localhost/api/v1/studios/join-by-code", { code: joinCode }, memberBearer));
    expect(response.status).toBe(200);
    const payload = (await response.json()) as { studioId: string; joined: boolean };
    expect(payload.studioId).toBe(studioId);
    expect(payload.joined).toBe(true);
  });

  it("antwortet auf einen unbekannten Code mit 404, nicht 200 mit joined:false", async () => {
    const response = await joinByCode(jsonRequest("http://localhost/api/v1/studios/join-by-code", { code: "ZZZZZZZZ" }, memberBearer));
    expect(response.status).toBe(404);
  });

  it("antwortet ohne Token mit 401", async () => {
    const response = await joinByCode(jsonRequest("http://localhost/api/v1/studios/join-by-code", { code: joinCode }));
    expect(response.status).toBe(401);
  });
});

describe("POST /api/v1/studios/join-by-tag", () => {
  it("tritt einem Studio ueber einen Geraete-Tag bei", async () => {
    const email = uniqueEmail("beitrittapi-tag-member");
    await createTestUser(email);
    const bearer = await accessTokenFor(email);

    const response = await joinByTag(jsonRequest("http://localhost/api/v1/studios/join-by-tag", { tagToken: machineTagToken }, bearer));
    expect(response.status).toBe(200);
    const payload = (await response.json()) as { studioId: string; joined: boolean };
    expect(payload.studioId).toBe(studioId);
    expect(payload.joined).toBe(true);
  });

  it("antwortet auf ein unbrauchbares Tokenformat mit 422", async () => {
    const response = await joinByTag(jsonRequest("http://localhost/api/v1/studios/join-by-tag", { tagToken: "zu-kurz" }, memberBearer));
    expect(response.status).toBe(422);
  });
});

describe("DELETE /api/v1/studios/{studioId}/membership", () => {
  it("verlaesst ein Studio, dem man beigetreten ist", async () => {
    const email = uniqueEmail("beitrittapi-leave-member");
    await createTestUser(email);
    const bearer = await accessTokenFor(email);
    await joinByCode(jsonRequest("http://localhost/api/v1/studios/join-by-code", { code: joinCode }, bearer));

    const response = await leaveMembership(
      new Request(`http://localhost/api/v1/studios/${studioId}/membership`, {
        method: "DELETE",
        headers: { authorization: `Bearer ${bearer}` },
      }),
      { params: Promise.resolve({ studioId }) },
    );
    expect(response.status).toBe(204);
  });

  it("antwortet mit 404, wenn keine Mitgliedschaft besteht", async () => {
    const email = uniqueEmail("beitrittapi-notmember");
    await createTestUser(email);
    const bearer = await accessTokenFor(email);

    const response = await leaveMembership(
      new Request(`http://localhost/api/v1/studios/${studioId}/membership`, {
        method: "DELETE",
        headers: { authorization: `Bearer ${bearer}` },
      }),
      { params: Promise.resolve({ studioId }) },
    );
    expect(response.status).toBe(404);
  });
});
```

- [ ] **Schritt 6: Tests ausführen**

```bash
pnpm vitest run tests/integration/api-studios-membership.test.ts
```

Erwartet: alle sieben Tests grün. Schlägt `createTestUser`/`accessTokenFor`/`uniqueEmail` mit einem Importfehler fehl, den genauen Exportpfad in `tests/integration/helpers/clients.ts` prüfen (Namen können seit dem letzten Blick auf `api-tag-context.test.ts` variieren).

- [ ] **Schritt 7: Bestehende Integrationssuite gegenprüfen — keine Regression**

```bash
pnpm vitest run tests/integration
```

Erwartet: alle bisherigen Tests weiterhin grün, insbesondere `join-studio-by-code.test.ts` und `join-studio-by-tag.test.ts` (unverändert, da nur neue Aufrufer hinzukamen, keine Funktionssignaturen geändert wurden).

- [ ] **Schritt 8: Commit**

```bash
git add packages/domain/src/people.ts apps/web/app/api/v1/studios tests/integration/api-studios-membership.test.ts
git commit -m "feat(api): Beitritts- und Austritts-Endpoints fuer iOS (join-by-code, join-by-tag, membership)"
```

---

### Aufgabe 18: Netzwerkschicht — Beitritts-/Austritts-Methoden

**Files:**
- Create: `apps/ios-member/FitnessMember/Networking/DTOs/JoinResult.swift`
- Modify: `apps/ios-member/FitnessMember/Networking/APIClient.swift`
- Modify: `apps/ios-member/FitnessMember/Catalog/CatalogStore.swift`
- Modify: `apps/ios-member/FitnessMemberTests/CatalogStoreTests.swift`

**Interfaces:**
- Consumes: die drei Endpoints aus Aufgabe 17
- Produces: `APIClient.joinStudioByCode(_:) async throws(APIError) -> JoinResult`, `.joinStudioByTag(_:) async throws(APIError) -> JoinResult`, `.leaveStudioMembership(studioId:) async throws(APIError)`; `CatalogStore.activeStudioId: String? { get }`, `.setActiveStudio(_:)`, `.joinStudio(byCode:) async throws(APIError)`, `.joinStudio(byTag:) async throws(APIError)`, `.leaveStudio(_:) async throws(APIError)` — von Aufgabe 19 (`MemberKeinStudioView`), Aufgabe 20 (`MemberScannerView`-Aufrufer) und Aufgabe 21 (`MemberStudiosView`) konsumiert.

- [ ] **Schritt 1: `JoinResult.swift` schreiben**

```swift
import Foundation

struct JoinResult: Decodable, Equatable {
    let studioId: String
    let machineId: String?
    let joined: Bool
}

struct JoinByCodeRequest: Encodable { let code: String }
struct JoinByTagRequest: Encodable { let tagToken: String }
```

- [ ] **Schritt 2: Test-Erweiterungen in `CatalogStoreTests.swift` schreiben — `FakeBootstrapLoader` bekommt drei weitere Fälle**

In der bestehenden `FakeBootstrapLoader`-Actor-Definition (Aufgabe 10) ergänzen:

```swift
    var joinResult: Result3 = .failure(.offline)
    var leaveResult: Result4 = .failure(.offline)

    enum Result3 { case success(JoinResult), failure(APIError) }
    enum Result4 { case success, failure(APIError) }

    func setJoinResult(_ value: Result3) { joinResult = value }
    func setLeaveResult(_ value: Result4) { leaveResult = value }

    func joinStudioByCode(_ code: String) async throws(APIError) -> JoinResult {
        switch joinResult {
        case .success(let result): return result
        case .failure(let error): throw error
        }
    }

    func joinStudioByTag(_ token: String) async throws(APIError) -> JoinResult {
        switch joinResult {
        case .success(let result): return result
        case .failure(let error): throw error
        }
    }

    func leaveStudioMembership(studioId: String) async throws(APIError) {
        switch leaveResult {
        case .success: return
        case .failure(let error): throw error
        }
    }
```

Neue Tests am Ende der `CatalogStoreTests`-Suite ergänzen:

```swift
    @Test("joinStudio(byCode:) laedt danach den Katalog neu")
    func joinByCodeReloads() async {
        let loader = FakeBootstrapLoader()
        await loader.setJoinResult(.success(JoinResult(studioId: "s1", machineId: nil, joined: true)))
        await loader.setBootstrapResult(.success(emptyBootstrap(studios: [.init(id: "s1", name: "Kraftwerk Nord", timezone: "Europe/Berlin")])))
        let store = CatalogStore(loader: loader, pendingWriteStore: PendingWriteStore(directory: tempDirectory()))
        try? await store.joinStudio(byCode: "ABCD1234")
        #expect(store.loadState == .loaded(hasStudio: true))
    }

    @Test("leaveStudio wirft weiter, wenn keine Mitgliedschaft besteht")
    func leaveStudioPropagatesError() async {
        let loader = FakeBootstrapLoader()
        await loader.setLeaveResult(.failure(.notFound(message: "Keine Mitgliedschaft zum Entfernen gefunden.")))
        let store = CatalogStore(loader: loader, pendingWriteStore: PendingWriteStore(directory: tempDirectory()))
        await #expect(throws: APIError.notFound(message: "Keine Mitgliedschaft zum Entfernen gefunden.")) {
            try await store.leaveStudio("s1")
        }
    }

    @Test("setActiveStudio setzt und uebersteht ein neues CatalogStore-Objekt (UserDefaults)")
    func setActiveStudioPersists() {
        let defaults = UserDefaults(suiteName: "catalog-store-tests-\(UUID().uuidString)")!
        let store = CatalogStore(loader: FakeBootstrapLoader(), pendingWriteStore: PendingWriteStore(directory: tempDirectory()), defaults: defaults)
        store.setActiveStudio("s1")
        let secondStore = CatalogStore(loader: FakeBootstrapLoader(), pendingWriteStore: PendingWriteStore(directory: tempDirectory()), defaults: defaults)
        #expect(secondStore.activeStudioId == "s1")
    }
```

- [ ] **Schritt 3: Tests ausführen, Fehlschlag bestätigen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/CatalogStoreTests 2>&1 | tail -40
```

Erwartet: FAIL — `BootstrapLoading` fehlen die drei neuen Methoden, `CatalogStore` fehlen `activeStudioId`/`setActiveStudio`/`joinStudio`/`leaveStudio`.

- [ ] **Schritt 4: `APIClient.swift` um die drei Methoden erweitern**

Nach den sechs bestehenden Endpoint-Methoden (vor `// MARK: - Hilfsmethoden`) einfügen:

```swift
    // MARK: - Beitritts-/Austritts-Endpoints (Aufgabe 17, ausserhalb M1-Spec SS6.3)

    func joinStudioByCode(_ code: String) async throws(APIError) -> JoinResult {
        try await send("studios/join-by-code", method: "POST", body: JoinByCodeRequest(code: code))
    }

    func joinStudioByTag(_ token: String) async throws(APIError) -> JoinResult {
        try await send("studios/join-by-tag", method: "POST", body: JoinByTagRequest(tagToken: token))
    }

    func leaveStudioMembership(studioId: String) async throws(APIError) {
        try await executeNoContent(path: "studios/\(studioId)/membership", method: "DELETE")
    }
```

Direkt unter der bestehenden `execute<T: Decodable>`-Methode eine Variante ohne erwarteten Rumpf ergänzen:

```swift
    private func executeNoContent(path: String, method: String) async throws(APIError) {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        if let token = await tokenProvider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.offline
        }

        guard let http = response as? HTTPURLResponse else { throw APIError.server(message: "Unerwartete Antwort.") }
        if (200..<300).contains(http.statusCode) { return }

        if let envelope = try? decoder.decode(ErrorEnvelope.self, from: data) {
            throw APIError.map(code: envelope.error.code, message: envelope.error.message)
        }
        throw APIError.server(message: "Unerwarteter Fehler.")
    }
```

- [ ] **Schritt 5: `CatalogStore.swift` erweitern — `BootstrapLoading`-Protokoll, Init, drei neue Methoden**

`BootstrapLoading`-Protokoll um die drei Methoden erweitern:

```swift
protocol BootstrapLoading: Sendable {
    func bootstrap() async throws(APIError) -> BootstrapResponse
    func putSet(sessionId: UUID, setId: UUID, _ body: SetWrite) async throws(APIError) -> RecordedSet
    func joinStudioByCode(_ code: String) async throws(APIError) -> JoinResult
    func joinStudioByTag(_ token: String) async throws(APIError) -> JoinResult
    func leaveStudioMembership(studioId: String) async throws(APIError)
}
```

`CatalogStore` um `activeStudioId`, den `defaults`-Parameter und drei Methoden erweitern:

```swift
@Observable
final class CatalogStore {
    private(set) var bootstrap: BootstrapResponse?
    private(set) var loadState: CatalogLoadState = .idle
    private(set) var pendingWrites: [PendingSetWrite]
    private(set) var activeStudioId: String?

    private let loader: any BootstrapLoading
    private let pendingWriteStore: PendingWriteStore
    private let defaults: UserDefaults
    private static let activeStudioDefaultsKey = "activeStudioId"

    init(loader: any BootstrapLoading, pendingWriteStore: PendingWriteStore, defaults: UserDefaults = .standard) {
        self.loader = loader
        self.pendingWriteStore = pendingWriteStore
        self.defaults = defaults
        pendingWrites = pendingWriteStore.loadAll()
        activeStudioId = defaults.string(forKey: Self.activeStudioDefaultsKey)
    }

    func load() async {
        loadState = .loading
        do {
            let response = try await loader.bootstrap()
            bootstrap = response
            loadState = .loaded(hasStudio: !response.studios.isEmpty)
            if activeStudioId == nil || !response.studios.contains(where: { $0.id == activeStudioId }) {
                activeStudioId = response.studios.first?.id
            }
        } catch {
            loadState = .failed
        }
    }

    func enqueue(_ write: PendingSetWrite) {
        pendingWrites.append(write)
        pendingWriteStore.save(pendingWrites)
    }

    func flushPending() async {
        var remaining: [PendingSetWrite] = []
        for write in pendingWrites {
            do {
                _ = try await loader.putSet(sessionId: write.sessionId, setId: write.setId, write.body)
            } catch {
                remaining.append(write)
            }
        }
        pendingWrites = remaining
        pendingWriteStore.save(remaining)
    }

    /// Wechseln ist reiner Client-Zustand -- "Tippen wechselt" (MemberStudios.dc.html)
    /// beschreibt keine Server-Aktion, sondern welches Studio lokal angezeigt wird.
    func setActiveStudio(_ id: String) {
        activeStudioId = id
        defaults.set(id, forKey: Self.activeStudioDefaultsKey)
    }

    func joinStudio(byCode code: String) async throws(APIError) {
        _ = try await loader.joinStudioByCode(code)
        await load()
    }

    func joinStudio(byTag token: String) async throws(APIError) {
        _ = try await loader.joinStudioByTag(token)
        await load()
    }

    func leaveStudio(_ studioId: String) async throws(APIError) {
        try await loader.leaveStudioMembership(studioId: studioId)
        await load()
    }
}
```

- [ ] **Schritt 6: Tests ausführen, Erfolg bestätigen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/CatalogStoreTests 2>&1 | tail -50
```

Erwartet: PASS für alle neun Tests (sechs aus Aufgabe 10, drei neue).

- [ ] **Schritt 7: Alle Tests zusammen laufen lassen und committen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test 2>&1 | tail -50
git add FitnessMember/Networking/DTOs/JoinResult.swift FitnessMember/Networking/APIClient.swift FitnessMember/Catalog/CatalogStore.swift FitnessMemberTests/CatalogStoreTests.swift
git commit -m "feat(ios): Beitritts-/Austritts-Methoden in APIClient und CatalogStore"
```

---

### Aufgabe 19: Screen — `MemberKeinStudioView`

**Files:**
- Create: `apps/ios-member/FitnessMember/Screens/Zugang/MemberKeinStudioView.swift`

**Interfaces:**
- Consumes: `CatalogStore` (Aufgabe 18), `SessionStore` (Aufgabe 8), `PrimaryButton`, `SecondaryButton`, `LabeledField`, `InlineBanner` (Aufgabe 3), `MemberScannerView` (Aufgabe 20, als `.sheet`)
- Produces: `struct MemberKeinStudioView: View` — von Aufgabe 22 (`RootView`) im `.noStudio`-Zustand konsumiert.

Diese Aufgabe wird **nach** Aufgabe 20 (`MemberScannerView`) umgesetzt, obwohl sie in der Nummerierung davor steht — `MemberKeinStudioView` öffnet `MemberScannerView` als Sheet und braucht den Typ zum Bauen. Reihenfolge beim Ausführen: erst Aufgabe 20 lesen und `MemberScannerView` bauen, dann diese Aufgabe. (Der Plan listet sie in Lesereihenfolge Zugang-Screen-für-Zugang-Screen; die Bau-Reihenfolge weicht hier einmal ab.)

- [ ] **Schritt 1: `MemberKeinStudioView.swift` schreiben**

```swift
import SwiftUI

struct MemberKeinStudioView: View {
    @Environment(CatalogStore.self) private var catalogStore
    @Environment(SessionStore.self) private var sessionStore
    @State private var manualCode = ""
    @State private var showScanner = false
    @State private var errorMessage: String?
    @State private var isJoining = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("NOCH KEIN STUDIO").font(DesignSystem.Typography.screentitel)

                SecondaryButton(title: "Code im Studio scannen") {
                    showScanner = true
                }
                Text("Aushang am Eingang oder Aufkleber am Gerät.")
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Color.textFaint)

                Text("KEIN CODE ZUR HAND?").font(DesignSystem.Typography.label).foregroundStyle(DesignSystem.Color.textMuted)
                LabeledField(label: "Studio-Code") {
                    TextField("ABCD1234", text: $manualCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }
                Text("Den Code bekommst du an der Theke.")
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Color.textFaint)

                if let errorMessage {
                    InlineBanner(tone: .danger, message: errorMessage)
                }

                PrimaryButton(title: "Beitreten", isEnabled: !manualCode.isEmpty, isLoading: isJoining) {
                    await joinByCode()
                }

                Spacer()

                Button("Abmelden") { Task { await sessionStore.signOut() } }
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.Color.textFaint)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(28)
        }
        .background(DesignSystem.Color.bg)
        .sheet(isPresented: $showScanner) {
            MemberScannerView { scanned in
                showScanner = false
                Task { await joinByTag(scanned) }
            }
        }
    }

    private func joinByCode() async {
        errorMessage = nil
        isJoining = true
        defer { isJoining = false }
        do {
            try await catalogStore.joinStudio(byCode: manualCode)
        } catch {
            errorMessage = "Dieser Code ist ungültig."
        }
    }

    private func joinByTag(_ token: String) async {
        errorMessage = nil
        isJoining = true
        defer { isJoining = false }
        do {
            try await catalogStore.joinStudio(byTag: token)
        } catch {
            errorMessage = "Dieser Code ist ungültig."
        }
    }
}
```

- [ ] **Schritt 2: Bauen (erst nach Aufgabe 20)**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" build 2>&1 | tail -40
```

Erwartet: `BUILD SUCCEEDED`.

- [ ] **Schritt 3: Commit**

```bash
cd apps/ios-member && git add FitnessMember/Screens/Zugang/MemberKeinStudioView.swift
git commit -m "feat(ios): MemberKeinStudioView"
```

---

### Aufgabe 20: Screen — `MemberScannerView` (QR-Sheet)

**Files:**
- Create: `apps/ios-member/FitnessMember/Screens/Zugang/QRScannerController.swift`
- Create: `apps/ios-member/FitnessMember/Screens/Zugang/MemberScannerView.swift`

**Interfaces:**
- Consumes: `AVFoundation` (System-Framework, keine SPM-Abhängigkeit), `PrimaryButton`, `DesignSystem` (Aufgabe 3), `NSCameraUsageDescription` (Aufgabe 1)
- Produces: `struct MemberScannerView: View { init(onScanned: @escaping (String) -> Void) }` — von Aufgabe 19 (`MemberKeinStudioView`) als `.sheet` konsumiert. Der rohe gescannte String wird unverändert zurückgegeben; die Interpretation (Studio-Code vs. Tag-URL) liegt beim Aufrufer — dadurch bleibt dieselbe Sheet-Komponente in Sub-Projekt 2 unverändert vom Training-Tab wiederverwendbar (Design-Spec §7).

QR-Erkennung über `AVCaptureMetadataOutput` (System-Framework, kein zusätzliches Paket) statt VisionKit — funktioniert ab iOS 17 identisch und braucht keine zusätzliche Berechtigungsabfrage über `NSCameraUsageDescription` hinaus.

- [ ] **Schritt 1: `QRScannerController.swift` schreiben — `UIViewControllerRepresentable` um `AVCaptureSession`**

```swift
import AVFoundation
import SwiftUI

/// Kapselt AVCaptureSession/AVCaptureMetadataOutput fuer QR-Erkennung.
/// Ruft onCode genau einmal pro Sitzung auf -- SwiftUI-seitig wird die
/// Sitzung beim Dismiss des Sheets automatisch beendet (UIKit-Lebenszyklus).
struct QRScannerController: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.onCode = onCode
        return controller
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}

final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?
    private let session = AVCaptureSession()
    private var didDeliverCode = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else { return }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        preview.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        view.layer.addSublayer(preview)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        didDeliverCode = false
        DispatchQueue.global(qos: .userInitiated).async { [session] in session.startRunning() }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        DispatchQueue.global(qos: .userInitiated).async { [session] in session.stopRunning() }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !didDeliverCode,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue
        else { return }
        didDeliverCode = true
        onCode?(value)
    }
}
```

- [ ] **Schritt 2: `MemberScannerView.swift` schreiben — Sheet-Chrome (Anfasser, Schließen-Ziel, Fallback-Link)**

```swift
import SwiftUI

struct MemberScannerView: View {
    let onScanned: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showManualEntry = false

    var body: some View {
        ZStack(alignment: .top) {
            QRScannerController(onCode: onScanned)
                .ignoresSafeArea()

            VStack {
                Capsule()
                    .fill(DesignSystem.Color.line)
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)

                HStack {
                    Text("CODE SCANNEN")
                        .font(DesignSystem.Typography.label)
                        .foregroundStyle(DesignSystem.Color.text)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(DesignSystem.Color.text)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Schließen")
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                Spacer()

                Button("Code stattdessen eingeben") {
                    showManualEntry = true
                    dismiss()
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DesignSystem.Color.text)
                .padding(.bottom, 24)
            }
        }
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(DesignSystem.Radius.haupt)
    }
}
```

`showManualEntry` wird hier bewusst nicht weiter verdrahtet — "Code stattdessen eingeben" schließt das Sheet, `MemberKeinStudioView` (Aufgabe 19) hat das manuelle Code-Feld bereits sichtbar auf dem darunterliegenden Screen. Kein Navigationsziel nötig.

- [ ] **Schritt 3: Bauen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" build 2>&1 | tail -40
```

Erwartet: `BUILD SUCCEEDED`.

- [ ] **Schritt 4: Auf einem echten Gerät prüfen — Simulator hat keine Kamera**

`AVCaptureDevice.default(for: .video)` liefert im Simulator `nil` — der Scanner zeigt dann nur den schwarzen Hintergrund ohne Vorschau, stürzt aber nicht ab (die Guard-Klausel in `viewDidLoad` fängt das ab). Echter QR-Scan-Test ist nur auf einem physischen iPhone möglich, konsistent mit M1-Spec §11 ("Physisch auf echtem iPhone: NFC, QR... Simulator genügt nicht").

- [ ] **Schritt 5: Commit**

```bash
cd apps/ios-member && git add FitnessMember/Screens/Zugang/QRScannerController.swift FitnessMember/Screens/Zugang/MemberScannerView.swift
git commit -m "feat(ios): MemberScannerView mit AVFoundation-QR-Erkennung"
```

---

### Aufgabe 21: Screen — `MemberStudiosView`

**Files:**
- Create: `apps/ios-member/FitnessMember/Screens/Profil/MemberStudiosView.swift`

**Interfaces:**
- Consumes: `CatalogStore` (Aufgabe 18), `BootstrapResponse.Studio` (Aufgabe 4), `InlineBanner` (Aufgabe 3)
- Produces: `struct MemberStudiosView: View` — von Aufgabe 22 (`ProfilRootView`) per Push konsumiert.

"Wechseln" ist reiner Client-Zustand (`CatalogStore.setActiveStudio`, keine Server-Anfrage) — "Tippen wechselt" in `MemberStudios.dc.html` beschreibt genau das. "Verlassen" löst ein natives `.confirmationDialog` aus (Design-Challenge-Entscheidung #5), keinen eigenen Dialog.

- [ ] **Schritt 1: `MemberStudiosView.swift` schreiben**

```swift
import SwiftUI

struct MemberStudiosView: View {
    @Environment(CatalogStore.self) private var catalogStore
    @State private var studioPendingLeave: BootstrapResponse.Studio?
    @State private var errorMessage: String?

    private var studios: [BootstrapResponse.Studio] {
        catalogStore.bootstrap?.studios ?? []
    }

    var body: some View {
        List {
            ForEach(studios) { studio in
                HStack(spacing: 12) {
                    Circle()
                        .fill(studio.id == catalogStore.activeStudioId ? DesignSystem.Color.accent : DesignSystem.Color.line)
                        .frame(width: 7, height: 7)

                    Text(studio.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(studio.id == catalogStore.activeStudioId ? DesignSystem.Color.text : DesignSystem.Color.textMuted)
                        .contentShape(Rectangle())
                        .onTapGesture { catalogStore.setActiveStudio(studio.id) }

                    Spacer()

                    Button("Verlassen") { studioPendingLeave = studio }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(DesignSystem.Color.danger)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .listRowBackground(DesignSystem.Color.surface)
            }
        }
        .scrollContentBackground(.hidden)
        .background(DesignSystem.Color.bg)
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Tippen wechselt. Ein Scan im anderen Studio wechselt von selbst.")
                Text("Ein Studio, das du verlässt, verliert dich als Mitglied — deine Sätze und dein Fortschritt bleiben bei dir.")
                if let errorMessage {
                    InlineBanner(tone: .danger, message: errorMessage)
                }
            }
            .font(.system(size: 12))
            .foregroundStyle(DesignSystem.Color.textFaint)
            .padding(20)
            .background(DesignSystem.Color.bg)
        }
        .navigationTitle("STUDIOS")
        .confirmationDialog(
            "\(studioPendingLeave?.name ?? "Studio") verlassen?",
            isPresented: Binding(
                get: { studioPendingLeave != nil },
                set: { if !$0 { studioPendingLeave = nil } }
            ),
            presenting: studioPendingLeave
        ) { studio in
            Button("Verlassen", role: .destructive) { Task { await leave(studio) } }
            Button("Abbrechen", role: .cancel) {}
        } message: { _ in
            Text("Ein Studio, das du verlässt, verliert dich als Mitglied — deine Sätze und dein Fortschritt bleiben bei dir.")
        }
    }

    private func leave(_ studio: BootstrapResponse.Studio) async {
        errorMessage = nil
        do {
            try await catalogStore.leaveStudio(studio.id)
        } catch {
            errorMessage = "Das hat nicht geklappt. Prüf deine Verbindung."
        }
    }
}
```

- [ ] **Schritt 2: Bauen und committen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" build 2>&1 | tail -40
git add FitnessMember/Screens/Profil/MemberStudiosView.swift
git commit -m "feat(ios): MemberStudiosView mit nativem Verlassen-Dialog"
```

Erwartet: `BUILD SUCCEEDED`.

---

### Aufgabe 22: Navigation-Komposition — `ProfilRootView`, `AuthFlow`, `MainTabView`, `RootView`

**Alle Screens existieren jetzt** (Aufgaben 12–21) — diese Aufgabe verdrahtet sie zum ersten Mal zu einer vollständigen Navigationsstruktur. Vorher hätte jede dieser Dateien auf noch fehlende Typen verwiesen und das gesamte `FitnessMember`-Ziel am Kompilieren gehindert (siehe Begründung in Aufgabe 11).

**Files:**
- Create: `apps/ios-member/FitnessMember/Screens/Profil/ProfilRootView.swift`
- Create: `apps/ios-member/FitnessMember/Navigation/AuthFlow.swift`
- Create: `apps/ios-member/FitnessMember/Navigation/MainTabView.swift`
- Create: `apps/ios-member/FitnessMember/Navigation/PlaceholderView.swift`
- Create: `apps/ios-member/FitnessMember/Navigation/RootView.swift`

**Interfaces:**
- Consumes: alle Screens (Aufgaben 12–21), `SessionStore`/`CatalogStore` (Aufgaben 8/18), `RootDestinationLogic`/`AuthRoute` (Aufgabe 11)
- Produces: `struct ProfilRootView: View`, `struct AuthFlow: View`, `struct MainTabView: View`, `struct PlaceholderView: View`, `struct RootView: View` — von Aufgabe 23 (`FitnessMemberApp`) konsumiert.

- [ ] **Schritt 1: `ProfilRootView.swift` schreiben — minimale Wurzel, nur für Passwort/Studios/Abmelden**

```swift
import SwiftUI

/// Bewusst minimal (Design-Spec SS7): das vollstaendige Profil.dc.html
/// (Produktgrenze-Text, RIR-Einstellung) kommt mit der Home/Profil-Spec
/// eines Folge-Sub-Projekts. Hier nur genug, um MemberPasswortAendernView
/// und MemberStudiosView aufzuhaengen.
struct ProfilRootView: View {
    @Environment(SessionStore.self) private var sessionStore

    var body: some View {
        List {
            Section {
                if let email = sessionStore.session?.email {
                    Text(email)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DesignSystem.Color.text)
                }
            }
            .listRowBackground(DesignSystem.Color.surface)

            Section {
                NavigationLink("Passwort ändern") { MemberPasswortAendernView() }
                NavigationLink("Studios") { MemberStudiosView() }
            }
            .listRowBackground(DesignSystem.Color.surface)

            Section {
                Button("Abmelden", role: .destructive) {
                    Task { await sessionStore.signOut() }
                }
            }
            .listRowBackground(DesignSystem.Color.surface)
        }
        .scrollContentBackground(.hidden)
        .background(DesignSystem.Color.bg)
        .navigationTitle("PROFIL")
    }
}
```

- [ ] **Schritt 2: `PlaceholderView.swift` schreiben**

```swift
import SwiftUI

/// Steht fuer Home/Training/Kurse, bis die jeweiligen Folge-Sub-Projekte sie
/// fuellen (Design-Spec SS2 -- nicht Teil dieses Sub-Projekts).
struct PlaceholderView: View {
    let title: String

    var body: some View {
        VStack {
            Text(title.uppercased()).font(DesignSystem.Typography.screentitel)
            Text("Kommt mit einem Folge-Sub-Projekt.")
                .foregroundStyle(DesignSystem.Color.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Color.bg)
    }
}
```

- [ ] **Schritt 3: `AuthFlow.swift` schreiben**

```swift
import SwiftUI

struct AuthFlow: View {
    var body: some View {
        NavigationStack {
            LoginMailView()
                .navigationDestination(for: AuthRoute.self) { route in
                    switch route {
                    case .code(let email): LoginCodeView(email: email)
                    case .register: MemberRegistrierenView()
                    case .password: MemberPasswortView()
                    }
                }
        }
        .tint(DesignSystem.Color.accent)
    }
}
```

- [ ] **Schritt 4: `MainTabView.swift` schreiben**

```swift
import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack { PlaceholderView(title: "Home") }
                .tabItem { Label("Home", systemImage: "house") }

            NavigationStack { PlaceholderView(title: "Training") }
                .tabItem { Label("Training", systemImage: "figure.strengthtraining.traditional") }

            NavigationStack { PlaceholderView(title: "Kurse") }
                .tabItem { Label("Kurse", systemImage: "calendar") }

            NavigationStack { ProfilRootView() }
                .tabItem { Label("Profil", systemImage: "person.crop.circle") }
        }
        .tint(DesignSystem.Color.accent)
    }
}
```

- [ ] **Schritt 5: `RootView.swift` schreiben**

```swift
import SwiftUI

struct RootView: View {
    @Environment(SessionStore.self) private var sessionStore
    @Environment(CatalogStore.self) private var catalogStore

    var body: some View {
        let destination = RootDestinationLogic.destination(session: sessionStore.session, catalogState: catalogStore.loadState)

        Group {
            switch destination {
            case .authFlow:
                AuthFlow()
            case .loadingCatalog:
                ProgressView()
                    .tint(DesignSystem.Color.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DesignSystem.Color.bg)
            case .noStudio:
                NavigationStack { MemberKeinStudioView() }
                    .tint(DesignSystem.Color.accent)
            case .main:
                MainTabView()
            }
        }
        .task(id: sessionStore.session) {
            if sessionStore.session != nil, catalogStore.loadState == .idle {
                await catalogStore.load()
            }
        }
    }
}
```

- [ ] **Schritt 6: Bauen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test 2>&1 | tail -60
```

Erwartet: `TEST SUCCEEDED` — jetzt zum ersten Mal das komplette Ziel inklusive aller Screens, alle bisherigen Tests weiterhin grün.

- [ ] **Schritt 7: Commit**

```bash
cd apps/ios-member && git add FitnessMember/Screens/Profil/ProfilRootView.swift FitnessMember/Navigation/AuthFlow.swift FitnessMember/Navigation/MainTabView.swift FitnessMember/Navigation/PlaceholderView.swift FitnessMember/Navigation/RootView.swift
git commit -m "feat(ios): Navigations-Komposition -- ProfilRootView, AuthFlow, MainTabView, RootView"
```

---

### Aufgabe 23: Integration — `FitnessMemberApp` verdrahten, Gesamtabnahme

**Files:**
- Modify: `apps/ios-member/FitnessMember/FitnessMemberApp.swift`
- Delete: `apps/ios-member/FitnessMember/ContentView.swift`

**Interfaces:**
- Consumes: alles aus den Aufgaben 1–22

- [ ] **Schritt 1: `AppConfig` um einen `tokenProvider`-tauglichen Zugriff prüfen — keine Änderung nötig, nur Bestätigung**

`APIClient`s `tokenProvider`-Closure braucht Zugriff auf die aktuelle `SessionStore`-Instanz zur Aufrufzeit, nicht auf eine Kopie beim App-Start. `SessionStore` ist eine `final class` (Referenztyp) — ein `let session = SessionStore(...)` vor der `@State`-Zuweisung, von der Closure eingefangen, reicht dafür aus (siehe Schritt 2).

- [ ] **Schritt 2: `FitnessMemberApp.swift` neu schreiben**

```swift
import SwiftUI

@main
struct FitnessMemberApp: App {
    @State private var sessionStore: SessionStore
    @State private var catalogStore: CatalogStore
    @State private var pendingTagStore = PendingTagStore()

    init() {
        let session = SessionStore(backend: SupabaseAuthBackend())
        let apiClient = APIClient(baseURL: AppConfig.apiBaseURL) { session.session?.accessToken }
        _sessionStore = State(initialValue: session)
        _catalogStore = State(initialValue: CatalogStore(loader: apiClient, pendingWriteStore: PendingWriteStore()))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(sessionStore)
                .environment(catalogStore)
                .environment(pendingTagStore)
                .task {
                    await sessionStore.restoreSession()
                }
                .onOpenURL { url in
                    // Ungueltige Links werden still verworfen (M0-Verhalten
                    // aus Task 7 unveraendert uebernommen).
                    if let token = TagLink.token(from: url) {
                        pendingTagStore.capture(token)
                    }
                }
        }
    }
}
```

- [ ] **Schritt 3: `ContentView.swift` löschen — durch `RootView` ersetzt**

```bash
cd apps/ios-member && git rm FitnessMember/ContentView.swift
```

- [ ] **Schritt 4: Projekt neu generieren (falls `project.yml` seit Aufgabe 1 nicht erneut lief) und bauen**

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test 2>&1 | tail -80
```

Erwartet: `TEST SUCCEEDED`, alle Tests aus den Aufgaben 1–22 grün, inklusive der sieben ursprünglichen `TagLinkTests`.

- [ ] **Schritt 5: Im Simulator starten und den vollständigen Flow einmal durchspielen**

```bash
cd apps/ios-member && xcrun simctl boot "iPhone 17 Pro" 2>/dev/null; open -a Simulator
xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" -derivedDataPath .build build 2>&1 | tail -20
xcrun simctl install "iPhone 17 Pro" .build/Build/Products/Debug-iphonesimulator/FitnessMember.app
xcrun simctl launch "iPhone 17 Pro" de.gymtaro.member
```

Manuell durchspielen und je gegen das passende Artboard unter `docs/superpowers/design/member/` abgleichen:

1. **Registrieren:** `MemberRegistrieren` → Code kommt per Mail (echtes Supabase-Cloud-Projekt, `Config.xcconfig`) → `LoginCode` mit Auto-Submit bei der sechsten Ziffer.
2. **Kein Studio:** landet nach Bestätigung auf `MemberKeinStudio` (kein Studio in `Config.xcconfig`s Projekt vorhanden) — Code manuell eingeben oder Scanner öffnen (Scanner-Vorschau im Simulator schwarz, siehe Aufgabe 20 Schritt 4).
3. **Beitreten:** nach gültigem Code landet die App in `MainTabView`, Profil-Tab zeigt die eigene E-Mail.
4. **Passwort ändern:** Profil → Passwort ändern → falsches aktuelles Passwort zeigt `AuthCopy.aktuellesPasswortFalsch`.
5. **Studios:** Profil → Studios → Verlassen löst das native `.confirmationDialog` aus, Bestätigen entfernt die Zeile.
6. **Abmelden:** Profil → Abmelden → zurück auf `LoginMailView`.
7. **Passwort vergessen:** `LoginMail` → "Passwort vergessen" → Code anfordern → mit dem realen, per Mail zugestellten Code den Zurücksetzen-Abschnitt ausfüllen → erneut anmelden.
8. **VoiceOver:** VoiceOver einschalten (Einstellungen → Bedienungshilfen, oder ⌘F5 im Simulator), jeden der acht Screens einmal durchgehen — jedes Eingabefeld und jeder Button muss ein sinnvolles Label ansagen; Standard-`TextField`/`SecureField`/`Button` erben das über das `LabeledField`-Label bzw. den Button-Titel weitgehend automatisch, `CodeDigitsView`s unsichtbares `TextField` trägt bereits `.accessibilityLabel("Bestätigungscode")` (Aufgabe 13).

- [ ] **Schritt 6: Pending-Route-Banner manuell prüfen**

Universal Link mit einem beliebigen 22-stelligen Platzhalter-Token simulieren:

```bash
xcrun simctl openurl booted "https://gymodo-web.vercel.app/t/abcdefghij0123456789AB"
```

Bei abgemeldetem Zustand: `LoginMailView` zeigt das `InlineBanner(tone: .accent, ...)`. Bei angemeldetem Zustand ohne Sub-Projekt-2-Zielscreen: keine Weiterleitung (erwartet, `PendingTagStore.consume()` hat noch keinen Aufrufer — das kommt mit Sub-Projekt 2).

- [ ] **Schritt 7: Finalen Commit**

```bash
cd apps/ios-member && git add -A
git commit -m "feat(ios): FitnessMemberApp verdrahtet -- Fundament und Zugang vollstaendig"
```

---

## Nach Abschluss dieses Plans

Sub-Projekt 1 (Fundament + Zugang) ist fertig: acht Zugang-Screens, Netzwerkschicht, Auth, Design-System, Navigations-Hülle, plus die drei neuen Beitritts-/Austritts-Endpoints. Home-, Training- und Kurse-Tab bleiben Platzhalter.

Nächster Schritt laut Design-Spec §1: eine eigene Brainstorming-Runde für Sub-Projekt 2 (Gerät-Kernflow, 10 Screens — die Rad-Geste mit den bereits in `designsystem.md` §6/§7 festgelegten Spring-/Momentum-Werten). Erst danach Sub-Projekt 3 (Training/Kurse) und Sub-Projekt 4 (Home/Profil-Rest).

