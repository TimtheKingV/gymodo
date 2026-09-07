# iOS Member-App — Fundament + Zugang (Sub-Projekt 1 von 4)

**Stand:** 7. September 2026
**Status:** Entschieden, bereit für Umsetzungsplan.
**Vorbedingung:** M0 abgeschlossen (`docs/m0-ergebnis.md` — NFC-first entschieden), Universal-Link-Validierung und App-Shell stehen (`apps/ios-member`). Design entschieden und in den Artboards umgesetzt (`2026-09-07-member-app-design-challenge.md`).
**Verhältnis zu anderen Dokumenten:** untergeordnet gegenüber `2026-08-28-fitness-retrofit-m1-design.md` (Produktverhalten) und `2026-08-30-designsystem.md` (Aussehen/Gefühl). Dieses Dokument bestimmt nur, *wie* Sub-Projekt 1 in Swift gebaut wird.

---

## 1. Warum ein Sub-Projekt statt einer Spec für alle 34 Artboards

Die Member-App-Canvas umfasst 34 Artboards. Drei davon (`FallbackGeraet`, `FallbackInaktiv`, `FallbackAushang`) sind bereits als Web-Route `/t/[token]` gebaut und fließen **nicht** in die SwiftUI-Umsetzung ein. Es bleiben 30 Screens plus das Fundament (App-Shell, Netzwerk, Auth, Design-System, Navigation) — zu groß für eine einzelne Spec und einen einzelnen Umsetzungsplan.

Die 30 Screens zerfallen in dieselben vier Gruppen, die die Design-Challenge-Review schon zum Prüfen genutzt hat:

| Gruppe | Screens | Sub-Projekt |
| --- | --- | --- |
| Zugang & Einstieg | 8 (`LoginMail`, `LoginCode`, `MemberRegistrieren`, `MemberPasswort`, `MemberPasswortAendern`, `MemberKeinStudio`, `MemberScanner`, `MemberStudios`) | **1 — dieses Dokument**, zusammen mit dem Fundament |
| Gerät-Kernflow | 10 | 2 — eigene Spec, nach diesem Sub-Projekt |
| Training & Kurse | 7 | 3 — eigene Spec |
| Home, Profil (Rest), | 5 | 4 — eigene Spec |

Reihenfolge: Fundament+Zugang zuerst, weil ohne Auth/Netzwerk/Navigation kein anderer Screen erreichbar ist. Gerät-Kernflow ist das technisch riskanteste Stück (Rad-Geste mit Spring-Physik), kommt aber erst danach — er braucht den Boden, den dieses Sub-Projekt legt.

---

## 2. Scope

**Enthalten:**
- Xcode-Projekt um `supabase-swift` (nur `Auth`) erweitern, Privacy Manifest anlegen
- Design-System als Swift-Namespace (Farben, Typo, Abstände, Radien aus `designsystem.md` §2–4) plus Basis-Komponenten (`PrimaryButton`, `SecondaryButton`, `Chip`, `Card`)
- `APIClient`-Actor mit den sechs Endpoints aus M1-Spec §6.3
- `SessionStore` (Auth-Zustand, Keychain-Sessions über supabase-swift)
- `CatalogStore` (Bootstrap-Cache, persistierte Schreib-Warteschlange)
- Navigations-Hülle: `RootView`, `AuthFlow`, `MainTabView` mit vier Tabs (Platzhalter außer Profil)
- Die acht Zugang-Screens, vollständig inklusive Fehlerzustände
- Minimale Profil-Wurzelansicht, nur um `MemberPasswortAendern` und `MemberStudios` aufzuhängen

**Nicht enthalten** (eigene Spec später):
- Inhalt der Tabs Home, Training, Kurse
- Der Geräte-Screen und alles, was daran hängt (Gerät-Kernflow, 10 Screens)
- Vollständiges `Profil.dc.html` (Produktgrenze-Text, RIR-Einstellung, Abmelden-Bestätigung darüber hinaus)
- Push-Benachrichtigungen, Offline-Sync über die reine Schreib-Warteschlange hinaus

---

## 3. Abhängigkeiten

**Eine neue SPM-Abhängigkeit: `supabase-swift`, nur die `Auth`-Komponente.** Kein `PostgREST`, kein `Realtime`, kein `Storage` — die App spricht Fachdaten ausschließlich über `/api/v1` (M1-Spec §6.1/§6.2: Direktzugriff aus Swift ist bewusst verworfen, RLS bleibt zweite statt einzige Verteidigungslinie, Fachlogik bleibt serverseitig).

Diese Abhängigkeit ist die **erste externe** in der App. M1-Spec §9 verlangt: Privacy Manifest wird angelegt, sobald die erste externe Abhängigkeit dazukommt — das passiert also in diesem Sub-Projekt, nicht erst kurz vor TestFlight.

`project.yml` bekommt einen SPM-Package-Eintrag für `supabase-swift`; die bestehenden Ziele (`FitnessMember`, `FitnessMemberTests`) bleiben unverändert in Struktur, nur die Abhängigkeit kommt dazu.

---

## 4. Design-System als Swift-Namespace

Ein `DesignSystem`-Enum als reiner Werte-Namespace (keine Instanzen, keine Umgebung nötig — die App hat keinen Hell-Modus, `designsystem.md` §14 hält das bewusst offen):

```swift
enum DesignSystem {
    enum Color { static let bg = ...; static let accent = ...; /* §2 */ }
    enum Typography { static let wertHeld = Font...; /* §3 */ }
    enum Spacing { static let s4 = 4.0; ... static let s48 = 48.0 } // §4
    enum Radius { static let card = 12.0; static let haupt = 16.0; static let pille = ... }
}
```

Dazu eine kleine Komponenten-Bibliothek, die `build.py`s Baustein-Idee nach SwiftUI überträgt:

- `PrimaryButton` — 64pt Höhe, Radius 16, `accent`/`on-accent`, `accent-pressed` beim Drücken, deaktivierter Zustand `surface-raised`/`text-faint` mit Pflichthinweis daneben (§5: "nie stumm")
- `SecondaryButton` — 46–52pt, Umriss
- `Chip` — Pille, Umriss (nie gefüllt außer für den einen erlaubten Akzent je Screen)
- `Card` — `surface`, Radius 12

**Warum das keine Nebensache ist:** Die Design-Challenge-Review (§1.6) fand mehrfach Abweichungen von genau diesen Konstanten in der HTML-Canvas (60pt statt 64pt Hauptaktion, uneinheitliche Nebenaktion-Höhen). Eine gemeinsame SwiftUI-Komponente statt wiederholter Inline-Werte macht diese Abweichung strukturell unmöglich statt nur Konvention — dieselbe Lehre, nur in Swift statt Python/HTML angewendet.

---

## 5. Netzwerkschicht

`APIClient` als `actor`, sechs Methoden — eine je Endpoint aus M1-Spec §6.3:

```swift
actor APIClient {
    func bootstrap() async throws(APIError) -> BootstrapResponse
    func tagContext(token: String) async throws(APIError) -> TagContextResponse
    func sessions() async throws(APIError) -> [SessionSummary]
    func progress() async throws(APIError) -> [ExerciseProgress]
    func putSet(sessionId: UUID, setId: UUID, _ body: SetWrite) async throws(APIError)
    func completeSession(sessionId: UUID) async throws(APIError)
}
```

Keine generische Endpoint-Abstraktion (Enum + Router o. ä.) — bei sechs bekannten, screenorientierten Endpoints wäre das Overhead ohne Gegenwert (YAGNI). Jede Methode holt den Bearer-Token frisch vom `SessionStore` (der ihn wiederum von supabase-swift bezieht, inkl. automatischem Refresh vor Ablauf).

`APIError` ist ein geschlossenes Enum, das sich direkt auf die fünf UI-Zustände aus `designsystem.md` §5 abbildet:

```swift
enum APIError: Error {
    case offline               // → Zustand "Offline"
    case unauthorized          // → zurück zu RootView/AuthFlow
    case validation(message: String) // → Zustand "Fehler", Text aus dem Server
    case server                // → Zustand "Fehler", generischer Text
}
```

Für dieses Sub-Projekt werden nur die Auth-Aufrufe von supabase-swift benötigt (`signIn`, `signUp`, `signOut`, Passwort-Reset); die sechs `APIClient`-Methoden werden hier bereits vollständig implementiert (sie sind unabhängig von der Screen-Gruppe), aber erst ab Sub-Projekt 2 tatsächlich aufgerufen.

---

## 6. Zustands-Stores

Zwei fokussierte `@Observable`-Stores statt eines großen `AppModel` oder eines ViewModels je Screen — kleinere Einheiten mit einem klaren Zweck, austauschbar und einzeln testbar:

### `SessionStore`

Kapselt supabase-swift vollständig; sonst spricht nichts in der App direkt mit dem Auth-Client.

```swift
@Observable
final class SessionStore {
    private(set) var session: Session?          // nil = ausgeloggt
    private(set) var hasStudio: Bool?            // nil = noch nicht geprüft

    func signIn(email: String, password: String) async throws(AuthError)
    func signUp(email: String, password: String) async throws(AuthError)
    func requestPasswordReset(email: String) async throws(AuthError)
    func completePasswordReset(newPassword: String) async throws(AuthError)
    func signOut() async
}
```

`AuthError` ist absichtlich neutral formuliert (siehe §9) — sie unterscheidet nach außen **nicht** zwischen falschem Passwort, unbekanntem und gesperrtem Konto.

**Sessions liegen ausschließlich im Keychain.** Das ist in M1-Spec §9/§10 als strukturell nicht nachrüstbar markiert — nie `UserDefaults`, nie SwiftData. Das ist zugleich das Standardverhalten von supabase-swift ohne eigens injizierten `AuthLocalStorage`: hier wird nichts Eigenes gebaut, sondern der Default validiert und als bewusste Entscheidung festgehalten (ein Swift-Test bestätigt das, siehe §10).

### `CatalogStore`

```swift
@Observable
final class CatalogStore {
    private(set) var bootstrap: BootstrapResponse?
    private(set) var pendingWrites: [PendingSetWrite]

    func load() async throws(APIError)
    func enqueue(_ write: PendingSetWrite)   // schreibt sofort auf Platte
    func flushPending() async               // versucht die Warteschlange abzuarbeiten
}
```

Die Schreib-Warteschlange wird bei jeder Änderung als JSON in das App-Support-Verzeichnis geschrieben (nicht Keychain — das sind Trainingsdaten, keine Zugangsdaten) und beim Start wieder eingelesen. Ein `NWPathMonitor` löst `flushPending()` bei Netzwerkänderung aus.

**Warum Persistenz auf Platte und nicht nur im Speicher:** Der Offline-Zustand aus `designsystem.md` §5 verspricht wörtlich *„gespeichert, wird gesendet"* — nie *„fehlgeschlagen"*. Das ist ein Versprechen an den Nutzer, kein Werbetext. Bliebe die Warteschlange nur im Speicher, würde ein App-Kill während einer Offline-Phase das Versprechen brechen. Da `PUT .../sets/{setId}` mit clientseitig erzeugter UUID strukturell idempotent ist (M1-Spec §6.3), ist ein Replay nach Neustart sicher — kein Duplikat-Risiko.

In diesem Sub-Projekt wird `CatalogStore` gebaut und getestet, aber noch nicht produktiv befüllt — `load()` wird erst ab Sub-Projekt 2 (Gerät-Kernflow) beim App-Start aufgerufen.

---

## 7. Navigations-Hülle

`RootView` schaltet zwischen drei Zuständen um, abhängig von `SessionStore`:

```
kein Session          → AuthFlow (NavigationStack, Wurzel: LoginMail)
Session, kein Studio  → MemberKeinStudio
Session + Studio      → MainTabView (TabView, 4 Tabs, je eigener NavigationStack)
```

`AuthFlow` pusht `LoginCode`, `MemberRegistrieren` und `MemberPasswort` (Anfordern-Schritt) von `LoginMail` aus. Der Zurücksetzen-Schritt von `MemberPasswort` wird **nicht** über Navigation erreicht: Der Recovery-Link liefert supabase-swift eine eigene Session-Art, `RootView` erkennt das beim Start und zeigt `MemberPasswort` direkt im Zurücksetzen-Zustand — ein von außen ausgelöster Screen-Modus, kein Navigationsziel.

`MainTabView` bekommt bereits alle vier Tabs aus `designsystem.md` §11 (Home · Training · Kurse · Profil — die M1-Spec nennt noch drei, weil ihre Fassung vor dem Bau von Kurse lag). Home, Training und Kurse sind in diesem Sub-Projekt reine Platzhalter-Views (`Text("Kommt mit Sub-Projekt N")`), bis die jeweiligen Folge-Specs sie füllen.

Der Profil-Tab bekommt eine **minimale** Wurzelansicht — Name, „Passwort ändern", „Studios", „Abmelden" — nicht das vollständige `Profil.dc.html`. Grund: `MemberPasswortAendern` und `MemberStudios` werden von dort gepusht und gehören inhaltlich zur Zugang-Gruppe; der Rest von `Profil.dc.html` (Produktgrenze-Text, RIR-Einstellung) gehört zu Sub-Projekt 4 und würde dieses Sub-Projekt sonst künstlich aufblähen.

`MemberScanner` ist ein `.sheet`, das ein `(String) -> Void`-Closure für den erkannten Code entgegennimmt — dadurch lässt es sich unverändert später auch vom Training-Tab aus wiederverwenden (M1-Spec §5.1: Scan-Zugang ist ein Button im Training-Tab), ohne dass Sub-Projekt 3 den Sheet-Code anfassen muss.

---

## 8. Die acht Zugang-Screens

| Screen | Aufgabe | Besonderheiten |
| --- | --- | --- |
| `LoginMail` | E-Mail + Passwort, „Anmelden" | Fehlerfall (falsches Passwort **oder** unbekanntes/gesperrtes Konto) zeigt denselben neutralen Text — eine gemeinsame Konstante (§9), von `MemberRegistrieren` mitbenutzt |
| `LoginCode` | 6-stelliger Bestätigungscode nach Registrierung, Resend-Timer | Auto-Submit bei der sechsten Ziffer |
| `MemberRegistrieren` | E-Mail + Passwort, Live-Validierung der Mindestlänge (10 Zeichen, `config.toml`) | „bereits registriert" nutzt dieselbe neutrale Konstante wie `LoginMail` |
| `MemberPasswort` | Zwei Zustände eines Screens: Anfordern (E-Mail) / Zurücksetzen (neues Passwort) | Pflichtsatz „Wenn es zu dieser Adresse ein Konto gibt, ist die Mail unterwegs" |
| `MemberPasswortAendern` | Aktuelles + neues Passwort, vom Profil-Tab gepusht | Eigener Fehlerzustand „aktuelles Passwort falsch" |
| `MemberKeinStudio` | Beitritt per Scan (öffnet `MemberScanner`) oder manuelle Code-Eingabe | Wurzelzustand direkt nach Login ohne Studio |
| `MemberScanner` | Kamera-Sheet für QR | `.sheet`, nicht Push (entschieden in der Design-Challenge-Review); eigener Anfasser, obere Ecken gerundet, zusätzlich zur Wisch-Geste ein explizites 44pt-Schließen-Ziel |
| `MemberStudios` | Liste der Studios, „Wechseln" per Tap, „Verlassen" separat | „Verlassen" löst natives `.confirmationDialog` aus (Titel „Studio verlassen?", der im Screen selbst stehende Erklärsatz als Nachricht, destruktiv „Verlassen", „Abbrechen") — kein eigener Dialog |

Jeder Screen wird gegen sein `.dc.html`-Artboard unter `docs/superpowers/design/member/` abgenommen (Farben, Abstände, Typo-Rollen exakt wie in `designsystem.md` §2–4, keine Inline-Abweichungen — durchgesetzt durch die Komponenten aus §4).

---

## 9. Fehlerzustände & Sicherheit

Alle Formulare nutzen die fünf Zustände aus `designsystem.md` §5 (Skelett/Leer/Offline/Fehler/Deaktiviert).

**Neutrale Antwort bei Login/Registrierung ist eine einzige geteilte Konstante**, nicht pro Screen wiederholter Text:

```swift
enum AuthCopy {
    static let unbekanntOderFalsch = "E-Mail oder Passwort stimmt nicht, oder es gibt kein Konto zu dieser Adresse."
}
```

Grund: Die Design-Challenge-Review (§1.5) fand, dass genau diese Konsistenz in der ursprünglichen Canvas fehlte — indem beide Screens auf dieselbe Swift-Konstante zeigen, ist ein Auseinanderlaufen strukturell ausgeschlossen statt nur Konvention.

Zwei Punkte sind aus M1-Spec §9/§10 nicht verhandelbar und werden hier bestätigt, nicht neu entschieden:
- **Sessions ausschließlich im Keychain** (§6, `SessionStore`).
- **Kein Freitext zu Gesundheit** — betrifft diese Gruppe nicht direkt, ist aber dasselbe Prinzip (kein Informationsleck) wie die neutrale Fehlerantwort.

---

## 10. Tests

**Swift Testing:**
- `APIError`-Mapping auf die fünf UI-Zustände (Tabelle → Zustand)
- Persistenz-Roundtrip der Schreib-Warteschlange: schreiben → Prozess-Neustart simulieren → lesen, keine Duplikate
- `SessionStore`-Zustandsübergänge gegen einen gemockten Auth-Client (signIn/signUp/reset/signOut, inkl. Fehlerfall)
- Bestätigung: `SessionStore` ohne eigene `AuthLocalStorage`-Injektion landet im Keychain (Default von supabase-swift) — ein expliziter Test, kein impliziertes Verhalten
- `LoginMail` und `MemberRegistrieren` referenzieren dieselbe `AuthCopy`-Konstante (Kompilierzeit-Garantie durch gemeinsamen Typ, zusätzlich ein Test, der beide Aufrufstellen auf Identität prüft)

**Manuell:** jeder der acht Screens im Simulator gegen sein Artboard abgenommen, plus ein VoiceOver-Durchgang je Screen (Standard-Controls wie `TextField`/`Button` erben Labels weitgehend automatisch; geprüft wird, dass nichts durch eigene Zustands-Overlays verdeckt wird).

---

## 11. Selbstprüfung

- Keine Platzhalter/TBD im Dokument.
- Kein Widerspruch zu `designsystem.md` (4 Tabs, Sheet für Scanner, neutrale Fehlerantwort, Keychain-only) oder zur M1-Spec (§6.3-Endpoints, Idempotenz, kein Direktzugriff aus Swift).
- Scope ist eng genug für einen einzelnen Umsetzungsplan: ein Xcode-Ziel, zwei Stores, eine Netzwerkschicht, acht Screens plus eine Platzhalter-Hülle für den Rest.
- Offene Punkte aus der Design-Challenge-Review, die diese Gruppe betreffen (E-Mail-Enumeration, Scanner-Sheet vs. Push, Bestätigungsdialog fürs Verlassen), sind alle als bereits entschieden übernommen — keine neue offene Entscheidung in diesem Dokument.

---

## 12. Nächste Schritte

Nach Freigabe dieses Dokuments: `writing-plans`-Skill für den Umsetzungsplan zu Sub-Projekt 1. Sub-Projekte 2–4 (Gerät-Kernflow, Training/Kurse, Home/Profil-Rest) bekommen je eine eigene Brainstorming-Runde, sobald Sub-Projekt 1 steht — nicht vorher, weil ihre Screens auf dem hier gebauten `APIClient`, den Stores und der Navigations-Hülle aufsetzen.
