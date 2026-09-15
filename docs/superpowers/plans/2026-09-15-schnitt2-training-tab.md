# Schnitt 2: Training-Tab — Umsetzungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Der Training-Tab zeigt, was gerade ist, und legt den Start in die Daumenzone. Die Startwege (QR, NFC, Suchen) stehen in beiden Zuständen unten an derselben Stelle. Läuft ein Training, steht es mit „Training läuft“ und der gelaufenen Zeit darüber in der Mitte. Läuft keins, bleibt die Mitte leer. In „Gerät wählen“ trägt jede Zeile mit Gerätefoto ein kleines Vorschaubild.

**Architecture:** Punkt 3 und 8 sind reiner Client. Aus zwei sich ausschließenden Inhalten (`leerInhalt`, `laufendInhalt`) wird **ein Gerüst** aus Titel, Mitte und Fuß. Nur die Mitte hängt am Zustand, und diese Entscheidung trifft eine prüfbare Ableitung (`TrainingTab.mitte`), nicht der View. Punkt 16 braucht **einen neuen Endpunkt**: Das Bucket `equipment-photos` ist privat, und der Bootstrap trägt absichtlich nur Pfade (Medien-Plan 08-31: eine 15-Minuten-URL gehört nicht in einen stundenlangen Prefetch). `GET /api/v1/me/machine-photos` signiert alle Modellfotos in einem Aufruf. Die App ruft ihn beim Öffnen von „Gerät wählen“ ab und verkleinert die Bilder vor dem Anzeigen. Entschieden am 15. September.

**Tech Stack:** Swift 6 / SwiftUI / Swift Testing / XcodeGen (`apps/ios-member`); TypeScript / Next.js Route Handler / Vitest gegen lokales Supabase (`packages/domain`, `apps/web`, `tests/integration`).

**Quelle:** `docs/superpowers/plans/2026-09-12-ios-verbesserungen-aus-dem-betrieb.md`, Punkte 3, 8, 16 und „Schnitt 2 — Training-Tab“.

## Global Constraints

- **Kommentare in Swift ohne Umlaute** (ASCII). Nutzertexte tragen Umlaute. In TypeScript gilt dieselbe Regel, wie im Bestand (`machine-context.ts`).
- **Kommentare begründen, sie beschreiben nicht.** Wird durch den Umbau ein Kommentar falsch, wird er im selben Task umgeschrieben, nicht stehen gelassen.
- **Design-Tokens aus `DesignSystem.swift`**, nie als Literal: `bg`, `surface`, `surfaceRaised`, `line`, `text`, `textMuted`, `textFaint`, `accent`, `warn`. Radien `card` 12, `neben` 14, `haupt` 16. Abstände 4/8/12/16/24/32/48. Ausnahme wie im Bestand: die horizontale Seitenkante 20.
- **Eine Akzentfläche pro Screen** (designsystem.md §2). Im laufenden Zustand bleibt „Training beenden“ (`PrimaryButton`) die eine Fläche. Im leeren Zustand gibt es keine. Die Scanwege tragen den Akzent nur als Kontur. Das Vorschaubild ist Inhalt, keine Akzentfläche.
- **Hit-Targets nie unter 44 pt.**
- **Die App misst nichts** (§10). Ohne laufendes Training steht keine Uhr und keine Null da. Eine Einheit ohne Satz zeigt keine Geräte- und Satzzahl.
- **Swift-Tests mit Swift Testing** (`import Testing`, `@Test`, `#expect`), als `struct`-Suite.
- **Neue Swift-Dateien:** `project.yml` zieht Verzeichnisse, nach dem Anlegen `xcodegen generate` in `apps/ios-member`.
- **Reihenfolge:** Jede Ableitung kommt mit ihrem Test vor dem View, der sie benutzt.
- **iOS-Tests:** in `apps/ios-member`
  `xcodebuild test -scheme FitnessMember -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
  (ein iPhone 16 gibt es auf dem Rechner nicht). Einzelne Suite: `-only-testing:FitnessMemberTests/<Suite>`. Vor jedem vollen Build `df -h /` prüfen, die Platte war zeitweise fast voll.
- **Server-Tests:** im Repo-Wurzelverzeichnis `pnpm typecheck`, `pnpm test`, `pnpm test:integration` (lokales Supabase läuft, `.env` liegt im Wurzelverzeichnis). Einzeldatei: `pnpm test:integration tests/integration/<datei>`.
- **Ein Commit je Task**, deutsche Message im Stil der Historie mit ae/oe/ue (`feat(training): …`). Trailer genau so, wörtlich:
  ```
  Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_016yVGhWppeaRYjvM5Wveivi
  ```
- **Nicht pushen.**

---

## Task 1: Die Mitte ist eine Ableitung

Ob in der Mitte etwas steht und welche Zahlen, entscheidet heute der View: `laufendKopf` zählt Geräte und Sätze selbst, `zuletztZuerst` sortiert im View. Beides zieht in ein reines `enum`, damit die Regel „keine Null“ einen Test hat.

**Files:**
- Create: `apps/ios-member/FitnessMember/Workout/TrainingTab.swift`
- Create: `apps/ios-member/FitnessMemberTests/TrainingTabTests.swift`

**Interfaces:**
- Produces:
  - `enum TrainingTab`
  - `struct TrainingTab.Mitte: Equatable { let startedAt: Date; let zahlen: Zahlen? }`
  - `struct TrainingTab.Zahlen: Equatable { let geraete: Int; let saetze: Int }`
  - `static func TrainingTab.mitte(_ session: LokaleSession?) -> Mitte?`: `nil` ohne Session. `zahlen == nil`, solange kein Satz in der Session steht.
  - `static func TrainingTab.zuletztZuerst(_ bloecke: [LokalerBlock]) -> [LokalerBlock]`: zieht unverändert aus `TrainingRootView` um.

- [x] **Step 1: Tests schreiben** (`TrainingTabTests.swift`)

```swift
import Foundation
import Testing
@testable import FitnessMember

/// Was in der Mitte des Training-Tabs steht -- und wann dort nichts steht.
struct TrainingTabTests {

    private let start = Date(timeIntervalSince1970: 1_757_930_400)

    private func satz(_ index: Int, minuten: Double) -> LokalerSatz {
        LokalerSatz(id: UUID(), setIndex: index, weightKg: 50, reps: 10, rir: nil,
                    problemFlag: false, problemReason: nil,
                    performedAt: start.addingTimeInterval(minuten * 60))
    }

    @Test func ohneSessionBleibtDieMitteLeer() {
        // Keine Uhr auf 00:00, keine "0 Geraete": ohne Training steht nichts da.
        #expect(TrainingTab.mitte(nil) == nil)
    }

    @Test func laufendeSessionTraegtStartUndZahlen() throws {
        let session = LokaleSession(id: UUID(), startedAt: start, bloecke: [
            LokalerBlock(machineId: "m1", exerciseId: "e1", saetze: [satz(1, minuten: 0), satz(2, minuten: 3)]),
            LokalerBlock(machineId: "m2", exerciseId: "e2", saetze: [satz(1, minuten: 9)]),
        ])
        let mitte = try #require(TrainingTab.mitte(session))
        #expect(mitte.startedAt == start)
        #expect(mitte.zahlen == TrainingTab.Zahlen(geraete: 2, saetze: 3))
    }

    @Test func zweiUebungenAmSelbenGeraetSindEinGeraet() throws {
        let session = LokaleSession(id: UUID(), startedAt: start, bloecke: [
            LokalerBlock(machineId: "m1", exerciseId: "e1", saetze: [satz(1, minuten: 0)]),
            LokalerBlock(machineId: "m1", exerciseId: "e2", saetze: [satz(1, minuten: 4)]),
        ])
        #expect(try #require(TrainingTab.mitte(session)).zahlen?.geraete == 1)
    }

    @Test func sessionOhneSatzZeigtUhrAberKeineZahlen() throws {
        // Heute entsteht die Einheit mit dem ersten Satz, der Fall kommt also
        // nicht vor. Mit Schnitt 4 (Start beim Verlassen des Einstiegs) kommt
        // er, und dann darf dort keine "0 Saetze" stehen.
        let session = LokaleSession(id: UUID(), startedAt: start, bloecke: [])
        let mitte = try #require(TrainingTab.mitte(session))
        #expect(mitte.zahlen == nil)
    }

    @Test func zuletztBespieltesGeraetStehtOben() {
        // Zirkel: zurueck an m1 nach m2 -- dann ist m1 das juengste, obwohl
        // es zuerst angelegt wurde.
        let m1 = LokalerBlock(machineId: "m1", exerciseId: "e1", saetze: [satz(1, minuten: 0), satz(2, minuten: 20)])
        let m2 = LokalerBlock(machineId: "m2", exerciseId: "e2", saetze: [satz(1, minuten: 10)])
        #expect(TrainingTab.zuletztZuerst([m1, m2]).map(\.machineId) == ["m1", "m2"])
        #expect(TrainingTab.zuletztZuerst([m2, m1]).map(\.machineId) == ["m1", "m2"])
    }
}
```

- [x] **Step 2: Rot sehen.** `xcodegen generate`, dann `xcodebuild test … -only-testing:FitnessMemberTests/TrainingTabTests`. Erwartet: Build-Fehler „cannot find 'TrainingTab' in scope“.

- [x] **Step 3: Implementieren** (`TrainingTab.swift`)

```swift
import Foundation

/// Was der Training-Tab zwischen Titel und Startwegen zeigt.
///
/// Ein reines enum wie GeraeteAuswahl: Die Wurzel hat genug Lebenszyklus
/// (Umschalttick, Scan, NFC), die Regel "ohne Training keine Null" soll
/// ohne ihn pruefbar sein.
enum TrainingTab {

    struct Zahlen: Equatable {
        let geraete: Int
        let saetze: Int
    }

    struct Mitte: Equatable {
        /// Die Uhr rechnet gegen diesen Zeitpunkt, nicht gegen einen
        /// mitgezaehlten Wert: ein gespeicherter Zeitpunkt ueberlebt
        /// Hintergrund und Sperrbildschirm.
        let startedAt: Date
        /// nil ohne Satz -- "0 Geraete · 0 Saetze" waere eine Zahl, die
        /// nichts Bestaetigtes zeigt (designsystem.md SS10).
        let zahlen: Zahlen?
    }

    static func mitte(_ session: LokaleSession?) -> Mitte? {
        guard let session else { return nil }
        let saetze = session.bloecke.flatMap(\.saetze).count
        let zahlen = saetze == 0 ? nil : Zahlen(
            geraete: Set(session.bloecke.map(\.machineId)).count,
            saetze: saetze
        )
        return Mitte(startedAt: session.startedAt, zahlen: zahlen)
    }

    /// Zuletzt bespieltes Geraet nach oben. Nicht einfach umgedreht: im
    /// Zirkel kehrt man zu einem frueheren Block zurueck, und dann ist DER
    /// das zuletzt benutzte Geraet, nicht der zuletzt angelegte Block.
    /// .distantPast ist nur der sichere Boden fuer einen Block ohne Satz.
    static func zuletztZuerst(_ bloecke: [LokalerBlock]) -> [LokalerBlock] {
        bloecke.sorted {
            ($0.saetze.map(\.performedAt).max() ?? .distantPast)
                > ($1.saetze.map(\.performedAt).max() ?? .distantPast)
        }
    }
}
```

- [x] **Step 4: Grün sehen.** Dieselbe Suite, dann der volle `xcodebuild test`.

- [x] **Step 5: Commit** — `feat(training): Mitte des Training-Tabs als pruefbare Ableitung`

---

## Task 2: Ein Gerüst für beide Zustände

Heute rendert die Wurzel entweder `leerInhalt` (Titel, „Training starten“, Scanwege, alles oben im Scrollinhalt) oder `laufendInhalt` (Kopf mit Uhr, Liste, Fuß mit Scanwegen). Die Startwege stehen damit je nach Zustand oben oder unten. Danach gibt es **ein** Gerüst:

```
TRAINING                      <- Titel, NUR leerer Zustand
┌ Mitte ───────────────────┐
│ ● TRAINING LÄUFT   2   5 │  <- nur laufend: Kopf (ersetzt den Titel) mit Uhr und Zahlen
│ 23:41        GERÄTE SÄTZE│
│ seit 18:04               │
│ [Block] [Block] …        │  <- nur laufend: scrollende Liste + Zirkelhinweis
│ [Training beenden]       │  <- nur laufend: die eine Akzentflaeche
│ Ohne neuen Satz …        │
└──────────────────────────┘  <- leer: Spacer, sonst nichts
(Banner: ausgelaufen / Scanfehler)
Training starten | NÄCHSTES GERÄT
[QR-Code] [NFC]
[Suchen]                      <- Fuss, in beiden Zustaenden an derselben Stelle
```

**Entscheidung (bestätigt 15. September):** „Training beenden“ steht nicht mehr ganz unten, sondern über den Startwegen. So springen die Startwege beim Wechsel zwischen den Zuständen nicht, und die häufigere Aktion mitten im Training (nächstes Gerät) liegt in der Daumenzone. Beenden kommt einmal je Training vor. Am Satz „Ohne neuen Satz endet das Training nach vier Stunden von selbst.“ ändert sich nichts, er steht unter dem Knopf.

Ebenfalls bestätigt: Der Kopf mit der Uhr steht oben in der Mitte, nicht senkrecht mittig. **Nachgezogen nach dem Review (Fix-Runde 1):** Der Titel „TRAINING“ steht nur im leeren Zustand — im laufenden Zustand entfällt er, und der Kopf übernimmt an derselben Stelle seine Rolle, weil auf kleinen iPhones (SE, 667 pt) sonst nicht genug Höhe für Titel, Kopf, Liste und Beenden-Gruppe zugleich bleibt. Im leeren Zustand bleibt „Training starten“ als 22-pt-Überschrift, im laufenden steht „NÄCHSTES GERÄT“ als Label.

**Files:**
- Modify: `apps/ios-member/FitnessMember/Screens/Training/TrainingRootView.swift` (`body` Z. 72–90, `leerInhalt` Z. 203–241, `laufendInhalt`/`laufendFuss`/`zuletztZuerst`/`laufendKopf` Z. 278–409)
- Modify: `docs/superpowers/plans/2026-09-12-ios-verbesserungen-aus-dem-betrieb.md` (Abschnitt „Stand“, Punkt **Training**)

**Interfaces:**
- Consumes: `TrainingTab.mitte(_:)`, `TrainingTab.zuletztZuerst(_:)` aus Task 1.
- Produces: keine neuen Typen. `leerInhalt`, `laufendInhalt`, `laufendFuss` und die private `zuletztZuerst` entfallen, dafür kommen `titel`, `mitte(_:)` und `fuss(laeuft:)`.

- [x] **Step 1: `body` auf das Gerüst umstellen.** Die Umschalt-`TimelineView` (60 s) und ihr `.task(id: UmschaltTick…)` bleiben **unverändert** samt Kommentaren. Nur der `Group`-Inhalt wird ersetzt:

```swift
TimelineView(.periodic(from: .now, by: 60)) { context in
    // Ein Geruest fuer beide Zustaende: nur die Mitte haengt daran, ob
    // ein Training laeuft. Die Startwege stehen so immer an derselben
    // Stelle in der Daumenzone, statt beim ersten Satz von oben nach unten
    // zu springen (Sammelstelle Punkt 3 und 8).
    let session = sessions.aktiveSession()
    let mitte = TrainingTab.mitte(session)
    VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
        titel
            .padding(.horizontal, 20)
            .padding(.top, DesignSystem.Spacing.s24)
        if let mitte, let session {
            laufendeMitte(mitte, session: session)
        } else {
            // Leer heisst leer: keine Uhr auf null, kein Platzhaltersatz.
            Spacer(minLength: 0)
        }
        fuss(laeuft: mitte != nil)
            .padding(.horizontal, 20)
            .padding(.bottom, DesignSystem.Spacing.s24)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .task(id: UmschaltTick(datum: context.date, wach: neuAuswerten)) { … unveraendert … }
}
```

Der Kommentar „Nur der leere Zustand scrollt als Ganzes …“ (Z. 73–76) ist danach falsch und entfällt. Die Begründung, warum nur die Liste scrollt, wandert an `laufendeMitte`.

- [x] **Step 2: `titel` und `laufendeMitte` bauen.**
  - `titel`: `Text("TRAINING")` mit `Typography.screentitel`, `tracking(-1)`, `Color.text`, wie bisher in `leerInhalt`.
  - `laufendeMitte(_ mitte: TrainingTab.Mitte, session: LokaleSession)`: ein `VStack(alignment: .leading, spacing: s24)` aus `laufendKopf(mitte)` (Seitenkante 20), dann die `ScrollView` mit `ForEach(TrainingTab.zuletztZuerst(session.bloecke))` und `zirkelHinweis` (wie heute, `.scrollBounceBehavior(.basedOnSize)`), dann `PrimaryButton(title: "Training beenden") { beenden() }` und der Vier-Stunden-Satz (Seitenkante 20). Der Kommentar „Die eine Akzentflaeche dieses Screens“ zieht mit an den Knopf.
  - `laufendKopf` bekommt `TrainingTab.Mitte` statt `LokaleSession`. Statt selbst zu zählen, liest es `mitte.zahlen`. Ist `zahlen == nil`, entfällt der rechte `HStack` mit den zwei `statistik`-Spalten ganz. Die innere 1-s-`TimelineView` rechnet gegen `mitte.startedAt`.
  - Im Kopf steht noch der falsche Kommentar „Die eine Akzentflaeche dieses Screens ist 'Naechstes Geraet'“ (Z. 366–368). Seit `9591345` ist es „Training beenden“. Umschreiben: Der Punkt und das Label bleiben `textMuted`, weil die Akzentfläche dem Beenden gehört.

- [x] **Step 3: `fuss(laeuft:)` bauen.** Er ersetzt `laufendFuss` und den unteren Teil von `leerInhalt`:

```swift
/// Banner, Ueberschrift, die drei Wege -- in beiden Zustaenden an derselben
/// Stelle. Die Banner stehen direkt ueber der Aktionsgruppe, nicht dahinter
/// (M3): ein Fehler muss im Sichtfeld stehen, nicht unter der Falz.
@ViewBuilder
private func fuss(laeuft: Bool) -> some View {
    VStack(spacing: DesignSystem.Spacing.s12) {
        if zeigeAusgelaufenHinweis {
            InlineBanner(tone: .muted, message: "Dein letztes Training wurde automatisch beendet.")
        }
        if let scanFehler {
            InlineBanner(tone: .danger, message: scanFehler)
        }
        if laeuft {
            // Zwei gleich aussehende Scan-Knoepfe sagen fuer sich genommen
            // nicht, WOZU man mitten im Training scannt.
            Text("NÄCHSTES GERÄT")
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text("Training starten")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(DesignSystem.Color.text)
                .frame(maxWidth: .infinity)
        }
        scanWege
    }
}
```

`zeigeAusgelaufenHinweis` ist im laufenden Zustand ohnehin `false` (der `onChange` auf `aktiveSession() != nil` setzt ihn zurück). Er braucht deshalb keine eigene `laeuft`-Bedingung. Der Kommentarblock „Abweichung vom Artboard TrainingLeer.dc.html …“ (Z. 210–219) zieht mit an die Überschrift „Training starten“. Der `.padding(.vertical, s24)` an ihr entfällt, der Abstand kommt aus dem Gerüst.

- [x] **Step 4: Dateikommentar am Typ umschreiben.** „Leer und laufend sind kein zweiter Screen, sondern zwei Zustaende derselben Wurzel“ stimmt weiterhin, aber der Satz muss sagen, dass sie sich seit Schnitt 2 **ein Gerüst teilen** und nur die Mitte wechselt. Den Kommentar an `scanWege` („in beiden Zustaenden dieselben“) prüfen: Er bleibt richtig.

- [x] **Step 5: Überdeckung und Kontrast selbst prüfen**, nicht nur bauen. Im Simulator (iPhone 17 Pro) beide Zustände ansehen. Den laufenden Zustand bekommst du über einen gesicherten Satz, am schnellsten über „Suchen“ → Gerät → Satz sichern → zurück zum Tab. Außerdem: Dynamic Type auf `accessibilityExtraExtraExtraLarge` (Xcode-Umgebungsüberschreibung). Fällt dabei der Fuß über die Tab-Leiste oder schiebt er den Titel aus dem Bild, bekommt der leere Zustand eine `ScrollView` mit `frame(minHeight:)` aus einem `GeometryReader`, damit der Fuß unten bleibt und trotzdem scrollt. Das Ergebnis kommt in den Bericht.

- [x] **Step 6: Sammelstelle nachziehen.** Unter „Stand“, Punkt **Training**: Die Startwege stehen in beiden Zuständen unten, das laufende Training mit Uhr in der Mitte (Schnitt 2). Bei Punkt 3 und 8 nichts löschen, die Sammelstelle hält fest, was gemeint war.

- [x] **Step 7: `xcodebuild test`**, grün.

- [x] **Step 8: Commit** — `feat(training): Startwege stehen unten, laufendes Training in der Mitte`

---

## Task 3: Der Server signiert die Gerätefotos

Die Liste braucht je Gerätemodell eine ladbare URL. `getBootstrap` bleibt, wie er ist, er liefert weiter nur Pfade. Neu ist ein eigener, kleiner Endpunkt, den die App **beim Öffnen der Liste** ruft. Das ist dieselbe Linie wie beim Gerätekontext: signiert wird, wenn der Screen aufgeht, nicht im Vorrat.

Welche Modelle: dieselben, die der Bootstrap über `machines` liest, also alle Geräte aller eigenen Studios, gesperrte eingeschlossen. Die Liste zeigt gesperrte Geräte gedimmt an, und „Auch in … suchen“ wechselt das Studio ohne neuen Abruf. RLS begrenzt die Abfrage auf die eigenen Studios. Signiert wird mit dem Bearer-Client, `media_select` (0020) verlangt dabei die Mitgliedschaft ein zweites Mal.

**Files:**
- Create: `packages/domain/src/machine-photos.ts`
- Modify: `packages/domain/src/index.ts` (Export neben `getMachineContext`, Z. 85–86)
- Create: `apps/web/app/api/v1/me/machine-photos/route.ts`
- Create: `tests/integration/api-machine-photos.test.ts`

**Interfaces:**
- Produces:
  - `export type MachinePhotos = { photos: Array<{ equipmentModelId: string; url: string }> }`
  - `export async function getMachinePhotos(client: SupabaseClient): Promise<MachinePhotos>`
  - `GET /api/v1/me/machine-photos` → `200 { "photos": [{ "equipmentModelId": "…", "url": "https://…" }] }`, `401 unauthorized` ohne Bearer, `cache-control: private, no-store`
- Ein Modell ohne Foto oder mit einem Pfad, der sich nicht signieren lässt (Objekt fehlt), **fehlt** in `photos`. Es kommt nicht als `null`: Die App zeigt dann keine Vorschau, und ein fehlendes Foto macht die Liste nicht kaputt.

- [x] **Step 1: Integrationstest schreiben** (`tests/integration/api-machine-photos.test.ts`). Aufbau wie `api-me.test.ts` (Studios und Mitgliedschaften über `serviceClient()`, Bearer über `accessTokenFor`), JPEG-Bytes wie `storage-media.test.ts` (`jpegBytes()`), Upload mit `admin.storage.from("equipment-photos").upload(\`${studioId}/${crypto.randomUUID()}.jpg\`, jpegBytes())`. Daten:
  - Studio A: Modell „Rudermaschine“ **mit** Foto, zwei Geräte davon. Modell „Beinpresse“ **ohne** Foto, ein Gerät. Modell „Latzug“ mit `photo_path` auf ein **nicht hochgeladenes** Objekt, ein Gerät. Mitglied A.
  - Studio B: Modell „Crosstrainer“ mit Foto, ein Gerät. Mitglied B.

  Fälle:
  - `it("ohne Anmeldung 401")`: `GET(new Request(url))` → `status 401`.
  - `it("liefert je Modell mit Foto genau eine ladbare URL")`: Mitglied A bekommt genau einen Eintrag mit `equipmentModelId` der Rudermaschine, obwohl zwei Geräte daran hängen. `await fetch(url)` → `status 200`, damit ist die URL wirklich ladbar und nicht nur wohlgeformt.
  - `it("ein Modell ohne Foto fehlt, statt mit null zu kommen")`: Die Beinpresse steht nicht in `photos`.
  - `it("ein verwaister Pfad fehlt, statt die Antwort zu kippen")`: Der Latzug steht nicht in `photos`, `status` bleibt 200.
  - `it("cross-tenant: das Foto aus Studio B erscheint bei A nicht")`: Die `equipmentModelId` des Crosstrainers kommt bei Mitglied A nicht vor, bei Mitglied B schon.
  - `it("antwortet private, no-store")`: Header prüfen.

- [x] **Step 2: Rot sehen.** `pnpm test:integration tests/integration/api-machine-photos.test.ts`. Erwartet: Importfehler, die Route gibt es nicht.

- [x] **Step 3: Domain-Funktion** (`packages/domain/src/machine-photos.ts`)

```ts
import type { SupabaseClient } from "@supabase/supabase-js";
import { requireUserId } from "./auth.js";
import { MEDIA_URL_TTL_SECONDS, PHOTO_BUCKET } from "./media.js";
import { signMediaUrls } from "./media-store.js";

export type MachinePhotos = {
  photos: Array<{ equipmentModelId: string; url: string }>;
};

/**
 * Signierte Geraetefotos fuer die Geraeteliste der App.
 *
 * Eigene Anfrage statt eines Felds im Bootstrap: der Bootstrap ist ein
 * Vorrat, der Stunden haelt, eine signierte URL lebt 15 Minuten
 * (MEDIA_URL_TTL_SECONDS). Die App fragt deshalb erst, wenn die Liste
 * aufgeht -- dieselbe Linie wie beim Geraetekontext.
 *
 * Je Modell, nicht je Geraet: zwei Rudermaschinen desselben Modells tragen
 * dasselbe Foto, und es wird nur einmal signiert.
 */
export async function getMachinePhotos(
  client: SupabaseClient,
): Promise<MachinePhotos> {
  await requireUserId(client);

  // Dieselbe Geraetemenge wie getBootstrap: RLS beschraenkt auf die
  // eigenen Studios, gesperrte Geraete stehen in der Liste mit.
  const { data: rows } = await client
    .from("machines")
    .select("equipment_models (id, photo_path)");

  type Row = { equipment_models: { id: string; photo_path: string | null } };
  const pfadJeModell = new Map<string, string>();
  for (const row of (rows ?? []) as unknown as Row[]) {
    const pfad = row.equipment_models.photo_path;
    if (pfad) pfadJeModell.set(row.equipment_models.id, pfad);
  }

  const signiert = await signMediaUrls(
    client,
    PHOTO_BUCKET,
    [...new Set(pfadJeModell.values())],
    MEDIA_URL_TTL_SECONDS,
  );

  // Was sich nicht signieren laesst, fehlt -- ein verwaister Pfad macht die
  // Liste nicht kaputt, die Zeile bleibt nur ohne Bild.
  const photos = [...pfadJeModell].flatMap(([equipmentModelId, pfad]) => {
    const url = signiert.get(pfad);
    return url ? [{ equipmentModelId, url }] : [];
  });
  return { photos };
}
```

In `index.ts`: `export { getMachinePhotos } from "./machine-photos.js";` und `export type { MachinePhotos } from "./machine-photos.js";`.

- [x] **Step 4: Route** (`apps/web/app/api/v1/me/machine-photos/route.ts`), gebaut wie `me/bootstrap/route.ts`:

```ts
import { getMachinePhotos } from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

/**
 * Signierte Geraetefotos fuer "Geraet waehlen" (Sammelstelle Punkt 16).
 *
 * no-store: die URLs laufen nach 15 Minuten ab, und ein Zwischenspeicher
 * wuerde abgelaufene ausliefern.
 */
export async function GET(request: Request): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) {
    return errorResponse("unauthorized", "Anmeldung erforderlich.");
  }

  try {
    const fotos = await getMachinePhotos(client);
    return Response.json(fotos, {
      status: 200,
      headers: { "cache-control": "private, no-store" },
    });
  } catch (error) {
    return fromDomainError(error);
  }
}
```

- [x] **Step 5: Grün sehen.** Die Einzeldatei, dann `pnpm typecheck`, `pnpm test`, `pnpm test:integration`. Vor dem vollen Integrationslauf `df -h /`.

- [x] **Step 6: Commit** — `feat(api): signierte Geraetefotos fuer die Geraeteliste`

---

## Task 4: Die App lädt die Fotos

Die Liste kennt heute weder das Modell einer Zeile noch einen Weg zum Server. Beides kommt dazu, als Ableitung mit Test und noch ohne View.

**Files:**
- Create: `apps/ios-member/FitnessMember/Networking/DTOs/MachinePhotosResponse.swift`
- Modify: `apps/ios-member/FitnessMember/Networking/APIClient.swift` (neben `machineContext`)
- Create: `apps/ios-member/FitnessMember/Workout/GeraeteFotos.swift`
- Modify: `apps/ios-member/FitnessMember/Workout/GeraeteAuswahl.swift` (`Eintrag`, `eintrag(_:zuletzt:trefferUebung:)`)
- Modify: `apps/ios-member/FitnessMemberTests/DTOTests.swift`, `apps/ios-member/FitnessMemberTests/GeraeteAuswahlTests.swift`
- Create: `apps/ios-member/FitnessMemberTests/GeraeteFotosTests.swift`

**Interfaces:**
- Consumes: `GET /api/v1/me/machine-photos` aus Task 3.
- Produces:
  - `struct MachinePhotosResponse: Decodable, Equatable, Sendable { struct Photo: Decodable, Equatable, Sendable { let equipmentModelId: String; let url: String }; let photos: [Photo] }`
  - `APIClient.machinePhotos() async throws(APIError) -> MachinePhotosResponse`: `get("me/machine-photos")`
  - `protocol GeraetefotosLoading: Sendable { func machinePhotos() async throws(APIError) -> MachinePhotosResponse }`, `extension APIClient: GeraetefotosLoading {}`, in `GeraeteFotos.swift`
  - `enum GeraeteFotos { static func zuordnung(_ antwort: MachinePhotosResponse) -> [String: URL]; static func laden(von loader: any GeraetefotosLoading) async -> [String: URL] }`: Schlüssel ist die `equipmentModelId`. Jeder Fehler (offline, 401, 5xx) liefert `[:]`.
  - `GeraeteAuswahl.Eintrag.modellId: String`, aus `maschine.equipmentModel.id`

- [x] **Step 1: Tests schreiben.**
  - `DTOTests`: `@Test func dekodiertGeraetefotos()` mit `{"photos":[{"equipmentModelId":"em1","url":"https://example.test/a.jpg"}]}` → ein Eintrag mit beiden Feldern. Dazu `{"photos":[]}` → leer.
  - `GeraeteAuswahlTests`: `@Test func eintragTraegtDasModell()`. Der Helfer `maschineJSON` baut die Modell-ID schon als `"em-\(id)"`, also `#expect(g.alle.first?.modellId == "em-m1")`.
  - `GeraeteFotosTests`:

```swift
import Foundation
import Testing
@testable import FitnessMember

/// Geraetefotos fuer die Liste: was ankommt, wird zur Zuordnung Modell -> URL,
/// und jeder Fehler endet in einer Liste ohne Bilder, nie in einer
/// Fehlermeldung.
struct GeraeteFotosTests {

    private struct Fake: GeraetefotosLoading {
        let ergebnis: Result<MachinePhotosResponse, APIError>
        func machinePhotos() async throws(APIError) -> MachinePhotosResponse {
            try ergebnis.get()
        }
    }

    private func antwort(_ fotos: [(String, String)]) -> MachinePhotosResponse {
        MachinePhotosResponse(photos: fotos.map { .init(equipmentModelId: $0.0, url: $0.1) })
    }

    @Test func ordnetUrlDemModellZu() async {
        let fotos = await GeraeteFotos.laden(von: Fake(ergebnis: .success(antwort([("em1", "https://example.test/a.jpg")]))))
        #expect(fotos == ["em1": URL(string: "https://example.test/a.jpg")!])
    }

    @Test func offlineGibtKeineBilderStattEinesFehlers() async {
        // Die Liste funktioniert ohne Netz aus dem Prefetch -- die Fotos
        // sind Zugabe und duerfen daran nichts aendern.
        let fotos = await GeraeteFotos.laden(von: Fake(ergebnis: .failure(.offline)))
        #expect(fotos.isEmpty)
    }

    @Test func eineUnlesbareUrlFaelltWegOhneDieAnderen() {
        // Leerer String: URL(string:) kodiert seit iOS 17 Leerzeichen und
        // Umlaute selbst, "" bleibt der verlaessliche Fall fuer nil.
        let fotos = GeraeteFotos.zuordnung(antwort([("em1", ""), ("em2", "https://example.test/b.jpg")]))
        #expect(fotos.keys.sorted() == ["em2"])
    }
}
```

  Falls `MachinePhotosResponse`/`Photo` als reines `Decodable` keinen Memberwise-Init anbieten: Er entsteht automatisch, solange kein eigener `init` im Typ steht. Den Typ deshalb ohne eigenen `init` bauen. `.offline` ist der Fall, den `APIClientTests` für Netzwerkfehler prüft. Meldet Swift 6, dass `UIImage` die Actor-Grenze nicht überqueren darf, nicht mit `nonisolated(unsafe)` zudecken, sondern im Bericht melden.

- [x] **Step 2: Rot sehen.** `xcodegen generate`, `xcodebuild test … -only-testing:FitnessMemberTests/GeraeteFotosTests`. Erwartet: Build-Fehler.

- [x] **Step 3: Implementieren.**
  - DTO wie unter Interfaces.
  - `APIClient`: nach `machineContext`:
    ```swift
    /// Signierte Geraetefotos fuer die Liste. Eigener Abruf statt eines
    /// Bootstrap-Felds: die URLs leben 15 Minuten, der Prefetch Stunden.
    func machinePhotos() async throws(APIError) -> MachinePhotosResponse {
        try await get("me/machine-photos")
    }
    ```
  - `GeraeteFotos.swift`:
    ```swift
    import Foundation

    /// Was "Geraet waehlen" vom Netz braucht -- eine schmale Fassade wie
    /// GeraetLoading, damit die Zuordnung ohne APIClient pruefbar bleibt.
    protocol GeraetefotosLoading: Sendable {
        func machinePhotos() async throws(APIError) -> MachinePhotosResponse
    }

    extension APIClient: GeraetefotosLoading {}

    enum GeraeteFotos {
        /// Modell -> URL. Je Modell, weil der Server je Modell signiert:
        /// zwei Geraete desselben Modells tragen dasselbe Foto.
        static func zuordnung(_ antwort: MachinePhotosResponse) -> [String: URL] {
            var fotos: [String: URL] = [:]
            for foto in antwort.photos {
                guard let url = URL(string: foto.url) else { continue }
                fotos[foto.equipmentModelId] = url
            }
            return fotos
        }

        /// Jeder Fehler endet leer: die Liste rechnet auf dem Prefetch und
        /// funktioniert im Keller ohne Empfang -- ein fehlendes Foto ist dort
        /// kein Zustand, den das Mitglied erklaert bekommen muss.
        static func laden(von loader: any GeraetefotosLoading) async -> [String: URL] {
            guard let antwort = try? await loader.machinePhotos() else { return [:] }
            return zuordnung(antwort)
        }
    }
    ```
  - `GeraeteAuswahl.Eintrag`: `let modellId: String` mit Kommentar „`equipmentModel.id` -- der Schluessel, unter dem der Server das Foto signiert“, gesetzt in `eintrag(_:zuletzt:trefferUebung:)`.

- [x] **Step 4: `xcodebuild test`**, grün.

- [x] **Step 5: Commit** — `feat(geraet): Geraetefotos fuer die Liste laden`

---

## Task 5: Die Zeile zeigt das Vorschaubild

Die Fotos kommen, wie das Studio sie hochgeladen hat, bis 10 MiB. Beim Upload entsteht keine Vorschaugröße (`stripImageMetadata` kodiert nicht neu). `AsyncImage` würde jedes Bild in voller Auflösung dekodieren: bei einem 12-MP-Foto sind das rund 48 MB Speicher je Zeile. Deshalb gibt es einen eigenen kleinen Lader, der mit ImageIO direkt auf Vorschaugröße dekodiert. Die Liste wird außerdem lazy, damit nur sichtbare Zeilen laden.

**Files:**
- Create: `apps/ios-member/FitnessMember/DesignSystem/Components/Vorschaubild.swift`
- Create: `apps/ios-member/FitnessMemberTests/VorschaubildTests.swift`
- Modify: `apps/ios-member/FitnessMember/Screens/Geraet/GeraeteAuswahlView.swift` (`inhalt`, `gruppe`, `zeile`)
- Modify: `apps/ios-member/FitnessMember/Screens/Training/TrainingRootView.swift` (`ziel(_:)`, Fall `.auswahl`)
- Modify: `docs/superpowers/plans/2026-09-12-ios-verbesserungen-aus-dem-betrieb.md` (Punkt 16 und Kopf von „Schnitt 2“)

**Interfaces:**
- Consumes: `GeraeteFotos.laden(von:)`, `GeraetefotosLoading`, `Eintrag.modellId` aus Task 4.
- Produces:
  - `enum Vorschau { static func verkleinert(_ daten: Data, kantePixel: Int) -> CGImage? }`
  - `actor VorschauLader { init(session: URLSession = .shared); func bild(modellId: String, url: URL, kantePixel: Int) async -> UIImage? }`: merkt sich fertige Bilder je `modellId`, liefert bei jedem Fehler `nil`
  - `GeraeteAuswahlView(fotoLader: any GeraetefotosLoading, beiAuswahl: (String) -> Void)`

- [x] **Step 1: Tests für `Vorschau.verkleinert`** (`VorschaubildTests.swift`)

```swift
import Foundation
import Testing
import UIKit
@testable import FitnessMember

/// Die Liste dekodiert Geraetefotos direkt auf Vorschaugroesse -- ein
/// 12-MP-Foto in voller Aufloesung waeren rund 48 MB je Zeile.
struct VorschaubildTests {

    private func jpeg(breite: CGFloat, hoehe: CGFloat) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let bild = UIGraphicsImageRenderer(size: CGSize(width: breite, height: hoehe), format: format)
            .image { kontext in
                UIColor.gray.setFill()
                kontext.fill(CGRect(x: 0, y: 0, width: breite, height: hoehe))
            }
        return bild.jpegData(compressionQuality: 0.8)!
    }

    @Test func verkleinertAufDieLaengsteKante() throws {
        let bild = try #require(Vorschau.verkleinert(jpeg(breite: 2000, hoehe: 1000), kantePixel: 168))
        #expect(max(bild.width, bild.height) == 168)
        #expect(bild.width == 168 && bild.height == 84)
    }

    @Test func vergroessertKleineBilderNicht() throws {
        let bild = try #require(Vorschau.verkleinert(jpeg(breite: 100, hoehe: 80), kantePixel: 168))
        #expect(bild.width <= 100)
    }

    @Test func keinBildGibtNil() {
        #expect(Vorschau.verkleinert(Data("kein bild".utf8), kantePixel: 168) == nil)
    }
}
```

  Falls ImageIO ein kleines Bild bei `CreateThumbnailFromImageAlways` doch auf `kantePixel` hochzieht, ist der zweite Test rot. Dann liefert `verkleinert` die Kante als `min(kantePixel, längste Originalkante)` (aus `CGImageSourceCopyPropertiesAtIndex`, `kCGImagePropertyPixelWidth/Height`). Den Test nicht aufweichen.

- [x] **Step 2: Rot sehen.** `xcodegen generate`, `-only-testing:FitnessMemberTests/VorschaubildTests`.

- [x] **Step 3: `Vorschaubild.swift` implementieren.**

```swift
import ImageIO
import SwiftUI
import UIKit

/// Geraetefotos auf Vorschaugroesse dekodieren.
///
/// Bewusst nicht AsyncImage: das dekodiert in voller Aufloesung, und die
/// Fotos kommen unverkleinert aus dem Upload (bis 10 MiB, keine
/// Vorschaugroesse am Server).
enum Vorschau {
    static func verkleinert(_ daten: Data, kantePixel: Int) -> CGImage? {
        // ShouldCache false: sonst haelt die Quelle die volle Bitmap trotzdem.
        guard let quelle = CGImageSourceCreateWithData(
            daten as CFData, [kCGImageSourceShouldCache: false] as CFDictionary
        ) else { return nil }
        let optionen: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: kantePixel,
        ]
        return CGImageSourceCreateThumbnailAtIndex(quelle, 0, optionen as CFDictionary)
    }
}

/// Laedt und merkt sich Vorschaubilder je Modell.
///
/// Schluessel ist das Modell, nicht die URL: die signierte URL traegt einen
/// Token und ist bei jedem Oeffnen der Liste eine andere.
actor VorschauLader {
    private let session: URLSession
    private var fertig: [String: UIImage] = [:]

    init(session: URLSession = .shared) {
        self.session = session
    }

    func bild(modellId: String, url: URL, kantePixel: Int) async -> UIImage? {
        if let vorhanden = fertig[modellId] { return vorhanden }
        guard let geladen = try? await session.data(from: url),
              (geladen.1 as? HTTPURLResponse)?.statusCode == 200,
              let verkleinert = Vorschau.verkleinert(geladen.0, kantePixel: kantePixel)
        else { return nil }
        let bild = UIImage(cgImage: verkleinert)
        fertig[modellId] = bild
        return bild
    }
}
```

- [x] **Step 4: `GeraeteAuswahlView` umbauen.**
  - Neuer Parameter `let fotoLader: any GeraetefotosLoading` vor `beiAuswahl`. Neue Zustände: `@State private var fotos: [String: URL] = [:]`, `@State private var bilder: [String: UIImage] = [:]`, `@State private var vorschauLader = VorschauLader()`.
  - Am `body`: `.task { fotos = await GeraeteFotos.laden(von: fotoLader) }`. Das ist ein Abruf je Öffnen, passend zur Lebensdauer der URLs.
  - `inhalt`: Den äußeren `VStack` in der `ScrollView` durch `LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.s12)` ersetzen. `gruppe` liefert dafür keine eigene `VStack` mehr, sondern `Section { ForEach … } header: { Überschrift }`, sonst lädt die innere `VStack` doch wieder alle Zeilen auf einmal. Die Abstände bleiben sichtbar wie heute: Überschrift zu erster Zeile 8, Zeile zu Zeile 12 (die Überschrift bekommt dafür `.padding(.bottom, -4)` oder eine eigene Zeilenhöhe, nachmessen, nicht raten).
  - `zeile`: vorne im `HStack` `vorschau(eintrag)`, danach der Textblock wie heute.

```swift
/// Ohne Foto steht hier nichts -- kein grauer Kasten, die Zeile bleibt
/// wie vorher (Sammelstelle Punkt 16). Das Bild erscheint, sobald es da
/// ist; bis dahin haelt die Zeile keinen Platz frei, sonst stuende im
/// Keller ohne Empfang dauerhaft eine Luecke da.
@ViewBuilder
private func vorschau(_ eintrag: GeraeteAuswahl.Eintrag) -> some View {
    if let bild = bilder[eintrag.modellId] {
        Image(uiImage: bild)
            .resizable()
            .scaledToFill()
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
            // clipShape VOR overlay (Vorlage: InlineBanner). Die Kontur
            // haelt die Kante eines dunklen Fotos auf surface sichtbar.
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                    .stroke(DesignSystem.Color.line, lineWidth: 1)
            )
            .accessibilityHidden(true)
    }
}
```

  - Laden je Zeile: an der Zeile `.task(id: fotos[eintrag.modellId]) { … }`. Ist eine URL da und `bilder[modellId]` noch leer: `bilder[modellId] = await vorschauLader.bild(modellId:url:kantePixel: 168)`. 168 px sind 56 pt × 3, die Auflösung des iPhone 17 Pro.
  - `accessibilityElement(children: .combine)` an der Zeile bleibt. Das Bild ist versteckt, VoiceOver liest die Zeile wie heute.
  - Dateikommentar am Typ: „Rechnet vollstaendig auf dem Prefetch: kein Netz, kein Ladezustand, keine Fehlerzustaende“ stimmt danach nicht mehr. Umschreiben: Die Liste rechnet auf dem Prefetch, **nur die Vorschaubilder** kommen aus dem Netz und fehlen still, wenn es keins gibt.

- [x] **Step 5: `TrainingRootView.ziel(_:)`**, Fall `.auswahl`: `GeraeteAuswahlView(fotoLader: apiClient) { machineId in … }`.

- [x] **Step 6: Kontrast und Überdeckung selbst prüfen.** Die lokale Datenbank hat Geräte ohne Fotos. Deshalb im Simulator gegen das lokale Supabase ein Foto über das Trainerportal hochladen (Modell → Foto) oder per `serviceClient` in `equipment-photos` legen und `photo_path` setzen, einmal hell, einmal fast schwarz. Nachsehen: Die dunkle Vorschau hat eine sichtbare Kante, eine gesperrte Zeile dimmt das Bild mit, und der Text neben dem Bild bricht bei langen Namen („Beinpresse sitzend 45°“) um statt abzuschneiden. Außerdem die Zeilen ohne Bild: Die linke Textkante liegt dort, wo sie heute liegt. Ergebnis in den Bericht. — erledigt im Verifikationslauf gegen lokales Backend (15. September)

- [x] **Step 7: Sammelstelle nachziehen.**
  - Punkt 16: Der Satz „also ohne neue Datenhaltung — nur als Vorschaugröße“ bleibt richtig. Dazu kommt ein Satz, dass die Liste die URLs über `GET /api/v1/me/machine-photos` holt (Bucket privat, Bootstrap trägt nur Pfade) und die Bilder in der App auf Vorschaugröße dekodiert.
  - Kopf von „Schnitt 2 — Training-Tab“: „(Client, ohne Server)“ wird „(Client, ein Endpunkt)“, der zweite Spiegelstrich nennt den Endpunkt.
  - Unter „Stand“ einen Punkt **Geräteliste** ergänzen: Vorschaubild je Zeile seit Schnitt 2, Vorschaugrößen am Server gibt es nicht (siehe Schnitt 5).

- [x] **Step 8: `xcodebuild test`**, grün.

- [x] **Step 9: Commit** — `feat(geraet): Vorschaubild je Zeile in der Geraeteliste`

**Nachgezogen nach dem Review (15. September):** `kantePixel` zielt auf die KURZE Kante, nicht die lange — ein 2000×1000-Foto wird zu 336×168 verkleinert (Step 1 und Step 3 oben rechnen noch mit der langen Kante, das stimmte nicht mehr, sobald `Vorschau.verkleinert` auf die kurze Kante umgestellt wurde). `VorschauLader` bündelt gleichzeitige Anfragen für dasselbe Modell zusätzlich über ein `laufend`-Dictionary je Modell: ohne das sähe eine zweite Zeile desselben Modells den `fertig`-Cache noch leer (Actor-Reentrancy legt den ersten Download bei seinem `await` frei) und stieße einen zweiten Download desselben Originalfotos an. Der Zeilenabstand bleibt **8 innerhalb einer Gruppe und 12 zwischen zwei Gruppen** — nicht „Zeile zu Zeile 12“, wie Step 4 oben noch sagt; die 12 entstehen aus dem `s8`-Spacing der `LazyVStack` plus `s4`-Top-Padding auf jedem Gruppenkopf außer dem ersten. Der Lader selbst zieht aus `GeraeteAuswahlView` in `TrainingRootView` um (`@State private var vorschauLader`) und wird durchgereicht: wiederholtes Öffnen von „Gerät wählen“ beim Wandern durchs Studio würde sonst jedes Mal von vorn laden, weil die signierte URL bei jedem Öffnen eine andere ist. Vor jedem Download wartet die Zeile 200 ms und bricht danach ab, wenn sie inzwischen weggescrollt ist (`Task.isCancelled`), damit schnelles Scrollen keine Downloads für Zeilen anstößt, die nur kurz im Bild waren. Die Session ist `.ephemeral` statt `.shared`, damit die einmalig gültigen, token-tragenden URLs nicht im `URLCache` landen.

---

## Selbstprüfung

`xcodebuild test` und `pnpm test:integration` beweisen die Ableitungen und den Endpunkt, nicht den Bildschirm. Von Hand, am Gerät, im Studio:

- [ ] Training ohne laufendes Training: Oben steht „TRAINING“, die Mitte ist leer (keine 00:00, keine Null). „Training starten“ mit QR, NFC und Suchen steht unten und ist mit dem Daumen der haltenden Hand erreichbar.
- [ ] Einen Satz sichern und zurück zum Tab: Die Startwege stehen **an derselben Stelle** wie vorher, darüber jetzt „NÄCHSTES GERÄT“. In der Mitte stehen „TRAINING LÄUFT“, die Uhr tickt sekundengenau, darunter „seit …“, rechts Geräte und Sätze.
- [ ] Mehrere Geräte trainieren: Die Liste scrollt, Uhr und Startwege bleiben stehen. „Training beenden“ steht über den Startwegen und ist die einzige grüne Fläche.
- [ ] App vier Stunden liegen lassen (oder `sessionPause` im Debug verkürzen): Der Tab springt in den leeren Zustand, und der Satz „Dein letztes Training wurde automatisch beendet.“ steht direkt über den Startwegen.
- [ ] Einen unbekannten QR-Code scannen, einmal ohne und einmal mit laufendem Training: Die Fehlermeldung steht in beiden Zuständen direkt über den Startwegen.
- [ ] VoiceOver: Die Uhr sagt „23 Minuten trainiert“, nicht „23:41“. Die Kopfzeile liest sich als ein Satz.
- [ ] Dynamic Type auf der größten Stufe, auf dem kleinsten verfügbaren iPhone: Der Fuß schiebt weder den Titel aus dem Bild noch liegt er unter der Tab-Leiste.
- [ ] Gerät wählen: Zeilen mit Gerätefoto zeigen links ein kleines Bild, Zeilen ohne Foto sehen aus wie vorher, ohne grauen Kasten und ohne Lücke.
- [ ] Ein dunkles Gerätefoto: Die Kante des Vorschaubilds ist auf der Zeilenfläche erkennbar. Eine gesperrte Zeile dimmt ihr Bild mit.
- [ ] Lange Liste schnell scrollen: Bilder erscheinen, wenn die Zeile ins Bild kommt. Die Liste ruckelt nicht, und der Speicher im Xcode-Debug-Navigator bleibt flach.
- [ ] Flugmodus, dann „Gerät wählen“: Die Liste und die Suche funktionieren wie vorher, ohne Bilder und ohne Fehlermeldung.

## Was dieser Schnitt NICHT tut

- **Startzeitpunkt der Einheit** (Punkt 10, Schnitt 4). Entschieden ist ein eigener Screen „Training starten“ nach Geräte- und Übungswahl, mit dem die Uhr beginnt. Gebaut wird er in Schnitt 4. Bis dahin zählt die Uhr ab dem ersten gesicherten Satz. Die drei Texte, die Punkt 10 falsch macht, bleiben stehen. `TrainingTab.Mitte.zahlen == nil` ist der einzige Vorgriff, er kostet eine Zeile und verhindert die Null, sobald Schnitt 4 Einheiten ohne Satz möglich macht.
- **Laufendes Training auf Home oben rechts** (Punkt 21, neu). Dort steht der Umschalter aus Schnitt 1. Der Platz ist offen, notiert in der Sammelstelle.
- **Satzpfad am Gerät** (Punkte 11–13, Schnitt 3). `GeraetView` und `radOffen` bleiben unberührt.
- **Übungsbilder** (Punkte 14 und 18, Schnitt 5). Die Liste zeigt das Foto **des Gerätemodells**. `GeraetErkanntView` bekommt kein neues Bild, und der leere Kasten dort bleibt.
- **Vorschaugrößen am Server.** Die App verkleinert selbst, übertragen wird trotzdem das Original. Eine Vorschau beim Upload gehört zum Portal- und Medienumbau in Schnitt 5 und wird dort notiert.
- **Offline-Fotos.** Es gibt keinen Platten- oder Offline-Cache. Dekodierte Vorschaubilder bleiben nur im Speicher, und nur so lange, wie die Wurzel des Training-Tabs lebt (`VorschauLader` sitzt seit dem Review in `TrainingRootView`, nicht mehr im Screen selbst) — nicht darüber hinaus, und nicht auf der Platte. Ohne Netz bleibt die Liste ohne Bilder, wie der Gerätescreen offline ohne Foto bleibt (Kernflow-Spec §8.4).
- **Erneutes Signieren nach 15 Minuten.** Wer die Liste länger offen hat und dann zu neuen Zeilen scrollt, sieht dort keine Bilder mehr. Schon geladene bleiben. Das ist ein Grenzfall, keine Nachlade-Logik.
