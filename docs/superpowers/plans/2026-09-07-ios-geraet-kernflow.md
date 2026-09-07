# iOS Member-App — Gerät-Kernflow: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Den Gerät-Kernflow der iOS-Member-App bauen — vom Tag-Tap über die Wertrad-Geste bis zum gesicherten Satz, offline lauffähig, inklusive der zwei Server-Ergänzungen, ohne die er nicht baubar ist.

**Architecture:** Die zehn Gerät-Artboards bilden Zustände ab, keine Navigationsziele; sie werden zu sechs Views. Das Wertrad ist ein System-`ScrollView` mit `.scrollTargetBehavior(.viewAligned)` — Momentum, Deceleration, Rubber-Banding und Unterbrechbarkeit kommen von UIKit, nicht aus eigener Physik. Ein neuer `WorkoutSessionStore` hält die laufende Einheit auf Platte; jeder Satz läuft durch die bestehende Schreib-Warteschlange, damit der Offline-Pfad derselbe ist, der jeden Tag läuft. Zwei kleine Ergänzungen in `packages/domain` und `apps/web` schließen Lücken, die beim Brainstorming gefunden wurden: der Kalibrierung fehlt jeder Schreibweg, und der Einstiegsentscheidung fehlt eine Größe, die kein Endpoint liefert.

**Tech Stack:** Swift 6.0, SwiftUI (iOS 17), Swift Testing, CryptoKit, Network (`NWPathMonitor`), XcodeGen. Backend: TypeScript, Next.js App Router, Zod, Vitest.

**Spec:** `docs/superpowers/specs/2026-09-07-ios-geraet-kernflow-design.md` — dieser Plan setzt sie um; Ausführende lesen beide Dokumente. Referenziert außerdem `docs/superpowers/specs/2026-08-28-fitness-retrofit-m1-design.md` (Produktverhalten), `docs/superpowers/specs/2026-08-30-designsystem.md` (Aussehen, Bewegung, Wertwahl §7–9) und `docs/superpowers/specs/2026-09-07-ios-fundament-zugang-design.md` (die Bausteine aus Sub-Projekt 1).

**Artboards:** `docs/superpowers/design/member/{GeraetErkannt,Main,GeraetWertRad,GeraetResttimer,GeraetEinweisung,GeraetKalibrierung,GeraetErsteWerte,GeraetUebungWechseln,GeraetProblem,GeraetOffline}.dc.html`. **Sie werden gegen die Abweichungstabelle in Abschnitt 9 der Spec gelesen, nicht wörtlich** — sechs von ihnen tragen bekannte, dokumentierte Regelbrüche.

## Global Constraints

- iOS-Deployment-Ziel 17.0, Swift-Version 6.0 (`apps/ios-member/project.yml`) — nicht ändern. Keine neue SPM-Abhängigkeit in diesem Sub-Projekt.
- **Kein Direktzugriff aus Swift auf Postgres/PostgREST** — jede Fachfunktion läuft über `/api/v1` (M1-Spec §6.1/§6.2).
- **Schreibvorgänge sind idempotent**: `sessionId`/`setId` werden clientseitig als UUID erzeugt, `PUT` statt `POST` (M1-Spec §6.3).
- **Alle Ziffern tabellarisch** (`.monospacedDigit()`). **Gewichte immer mit genau einer Nachkommastelle und Dezimalkomma** (`80,0 kg`, nie `80 kg`), Einheit immer sichtbar, immer Kilogramm (`designsystem.md` §3).
- **Trefferflächen ≥ 44 pt, Hauptaktion exakt 64 pt hoch, Radzeile 44 pt**, Radius 16 Hauptaktion / 14 Nebenaktion + Stepper / 12 Karten. Abstandsskala ausschließlich 4 · 8 · 12 · 16 · 24 · 32 · 48. Seitenrand 20 pt im Content (`designsystem.md` §4).
- **Genau eine Akzentfläche je Screen.** `accent` (`#D4FF3F`) markiert nur die eine Hauptaktion und den aktiven Wert (`designsystem.md` §2, nicht verhandelbar).
- **`warn` (`#FFB020`) nur als Umriss, nie als Fläche** (`designsystem.md` §2, nicht verhandelbar).
- **Kein reines Schwarz** (`#000000`) — Grundfläche ist `bg` = `#0A0B0D`.
- **Deaktivierte Zustände sind nie stumm** — daneben steht, was fehlt (`designsystem.md` §5).
- **Offline heißt „gespeichert, wird gesendet", nie „fehlgeschlagen"** (`designsystem.md` §5).
- **Fehler sagen, was falsch ist UND was gilt**, nie nur „ungültig" (`designsystem.md` §5).
- **Haptik nie als einzige Rückmeldung** — jede Bestätigung ist zusätzlich sichtbar (`designsystem.md` §6, M1-Spec §5.9).
- **Reduce Motion ersetzt jede Animation durch einen Zustandswechsel**, nie durch Weglassen von Information (`designsystem.md` §6).
- **Kein Keyboard im Satzpfad, nirgends.** Gewicht und Wiederholungen sind Räder, keine Textfelder (`designsystem.md` §9).
- **Kein Freitext zu Schmerzen, Verletzungen oder Gesundheit** — die Problemmeldung ist ein Boolean plus feste Liste (`designsystem.md` §10, M1-Spec §5.8).
- **Vorschläge sind eine Rechnung, keine Empfehlung**: „Vorschlag · +2,5", nie „Du solltest" (`designsystem.md` §10).
- **Durchgehend Deutsch, Du-Form, keine Ausrufezeichen, kein Motivationston** (`designsystem.md` §10).
- **Der Tag-Token darf nie gespeichert und nie protokolliert werden** (M1-Spec §10.4/§10.6). Gespeichert wird ausschließlich sein SHA-256-Hash-Vergleich zur Laufzeit.
- **Bewegungswerte** (Spec Abschnitt 6, hier verbindlich): Öffnen/Schließen `.spring(response: 0.34, dampingFraction: 0.86)` · Satz→Pause `.spring(response: 0.4, dampingFraction: 0.9)` · Press-Feedback `.spring(response: 0.22, dampingFraction: 0.9)` mit `scaleEffect(0.97)`.
- **Backend-Fehlerhülle:** `{ "error": { "code": "...", "message": "..." } }`, Status fest zugeordnet: `validation_failed`→422, `unauthorized`→401, `not_found`→404, `conflict`→409, `internal`→500 (`apps/web/lib/api/respond.ts`).
- Neue Web-Routen folgen exakt dem Muster der bestehenden `/api/v1`-Handler: `bearerClientFrom(request)` für Auth, `fromDomainError`/`errorResponse` für Antworten, `export const dynamic = "force-dynamic"`.
- Deutsche Bezeichner in neuem Fachcode (bestehende Konvention: `zaehleBesuche`, `pruefeEinstellwerte`, `LokaleSession`); englische Bezeichner nur dort, wo sie einen API-Vertrag abbilden (`visitCount`, `settingValues`).
- **Kommentare erklären, warum — nicht was.** Bestehende Dateien in `packages/domain` und `apps/ios-member` sind das Vorbild.

## Dateistruktur

**Neu, Server:**

| Datei | Verantwortung |
| --- | --- |
| `packages/domain/src/calibration.ts` | Kalibrierung schreiben: Zod-Schema, reine Wertprüfung, Insert |
| `packages/domain/src/calibration.test.ts` | Tests der reinen Wertprüfung |
| `packages/domain/src/bootstrap.test.ts` | Tests des reinen Besuchszählers |
| `apps/web/app/api/v1/me/calibrations/route.ts` | HTTP-Hülle für `recordCalibration` |

**Neu, iOS:**

| Datei | Verantwortung |
| --- | --- |
| `FitnessMember/DesignSystem/Zahlformat.swift` | Gewicht/Wiederholungen als Text und als VoiceOver-Ansage |
| `FitnessMember/DesignSystem/Components/PressButtonStyle.swift` | Press-Feedback, einmal für alle Buttons |
| `FitnessMember/DesignSystem/Components/RastRad.swift` | Die Rad-Komponente |
| `FitnessMember/DesignSystem/Components/Stepper44.swift` | ± Stepper der Kalibrierung |
| `FitnessMember/Networking/NetzwerkMonitor.swift` | Verbindungszustand, Auslöser für die Warteschlange |
| `FitnessMember/Networking/DTOs/CalibrationWrite.swift` | DTOs des neuen Endpoints |
| `FitnessMember/Workout/Rastwerte.swift` | Wertelisten aus dem Gerätemodell |
| `FitnessMember/Workout/MachineResolver.swift` | Token → Gerät aus dem Prefetch |
| `FitnessMember/Workout/GeraetEinstieg.swift` | Einstiegsentscheidung als reine Funktion |
| `FitnessMember/Workout/LokaleSession.swift` | Datentypen der laufenden Einheit |
| `FitnessMember/Workout/SessionFileStore.swift` | Persistenz der laufenden Einheit |
| `FitnessMember/Workout/WorkoutSessionStore.swift` | Laufende Einheit, Vier-Stunden-Regel, `setIndex` |
| `FitnessMember/Workout/Resttimer.swift` | Restdauer aus `endetAm` |
| `FitnessMember/Screens/Geraet/GeraetModel.swift` | Zustand eines geöffneten Geräte-Screens |
| `FitnessMember/Screens/Geraet/GeraetErkanntView.swift` | `GeraetErkannt` |
| `FitnessMember/Screens/Geraet/GeraetView.swift` | `Main` / `GeraetWertRad` / `GeraetResttimer` / `GeraetOffline` |
| `FitnessMember/Screens/Geraet/WertZeile.swift` | Die zwei Räder plus Kontextzeilen |
| `FitnessMember/Screens/Geraet/ResttimerBalken.swift` | Balken, Live-Region, Reduce-Motion |
| `FitnessMember/Screens/Geraet/OfflineLeiste.swift` | Offline-Leiste und Warteschlangen-Karte |
| `FitnessMember/Screens/Geraet/ErstkontaktFlow.swift` | Der modale Dreischritt, Hülle |
| `FitnessMember/Screens/Geraet/EinweisungSchritt.swift` | Schritt 1 |
| `FitnessMember/Screens/Geraet/KalibrierungSchritt.swift` | Schritt 2 |
| `FitnessMember/Screens/Geraet/ErsteWerteSchritt.swift` | Schritt 3 |
| `FitnessMember/Screens/Geraet/UebungWechselnSheet.swift` | `GeraetUebungWechseln` |
| `FitnessMember/Screens/Geraet/ProblemSheet.swift` | `GeraetProblem` |
| `FitnessMember/Screens/Training/TrainingRootView.swift` | Minimale Training-Wurzel |
| `FitnessMember/Navigation/GeraetRoute.swift` | Typisierter Navigationspfad des Training-Tabs |

**Geändert:**

| Datei | Änderung |
| --- | --- |
| `packages/domain/src/bootstrap.ts` | `visitCount` je Gerät, reiner Zähler ausgelagert |
| `packages/domain/src/index.ts` | `recordCalibration` und Schema exportieren |
| `FitnessMember/Networking/DTOs/BootstrapResponse.swift` | `visitCount` |
| `FitnessMember/Networking/APIClient.swift` | `recordCalibration` |
| `FitnessMember/Networking/APIError.swift` | `istDauerhaft` |
| `FitnessMember/Catalog/CatalogStore.swift` | `flushPending` unterscheidet dauerhaft/vorübergehend; `tagContext` durchreichen |
| `FitnessMember/DesignSystem/DesignSystem.swift` | fehlende Typo-Rollen, `Motion`-Konstanten |
| `FitnessMember/DesignSystem/Components/PrimaryButton.swift` | Press-Feedback |
| `FitnessMember/DesignSystem/Components/SecondaryButton.swift` | Press-Feedback |
| `FitnessMember/Navigation/MainTabView.swift` | Training-Tab statt Platzhalter |
| `FitnessMember/FitnessMemberApp.swift` | `APIClient`, `WorkoutSessionStore`, `NetzwerkMonitor` in die Umgebung |

---

### Aufgabe 1: `bootstrap` liefert `visitCount` und die Einstellparameter

Die Einstiegsentscheidung aus `designsystem.md` §8 braucht die Anzahl Besuche an einem Gerät. Kein Endpoint liefert sie. Sie muss aus `bootstrap` kommen, nicht aus `tagContext`, weil der Geräte-Screen laut M1-Spec §8.1 Schritt 3 sofort aus dem Prefetch rendert — eine Entscheidung, die auf `tagContext` wartet, verletzt das.

`getBootstrap` liest bereits bis zu 2000 Zeilen aus `workout_sets`. Es genügt, `session_id` in das bestehende `select` aufzunehmen und im selben Durchlauf mitzuzählen. Keine zusätzliche Abfrage.

**Zweiter Vertragspunkt, beim Ausschreiben der Screens gefunden — nicht in der Spec, aber ohne ihn ist `GeraetOffline` nicht baubar:** Der Offline-Zustand zeigt die eigenen Einstellwerte **mit Beschriftung** („Sitz 4 · Lehne 2 · Startwinkel 30°"). Die Werte stehen als `settingValues` im Prefetch, die Beschriftungen aber nur in `equipment_setting_definitions` — und die liest `getBootstrap` gar nicht. Offline stünde dort sonst der rohe Schlüssel („sitz 4"). `machines[].equipmentModel` bekommt deshalb `settingDefinitions`. Das kostet **eine** zusätzliche Abfrage; die Definitionen sind Studioinhalt, klein und je Modell geteilt.

**Files:**
- Modify: `packages/domain/src/bootstrap.ts`
- Create: `packages/domain/src/bootstrap.test.ts`
- Modify: `apps/ios-member/FitnessMember/Networking/DTOs/BootstrapResponse.swift`
- Modify: `apps/ios-member/FitnessMemberTests/DTOTests.swift`

**Interfaces:**
- Produces: `zaehleBesucheJeGeraet(rows: Array<{ machine_id: string; session_id: string }>): Map<string, number>` — exportiert aus `bootstrap.ts`, nur für den Test.
- Produces: `Bootstrap["machines"][number].visitCount: number` — von Aufgabe 6 (`GeraetEinstieg`) konsumiert.
- Produces: `Bootstrap["machines"][number]["equipmentModel"].settingDefinitions: Array<{ key: string; label: string; kind: string; minValue: number | null; maxValue: number | null; stepValue: number | null; unit: string | null; allowedValues: string[] | null }>` — von Aufgabe 10 und 15 konsumiert.
- Produces: `BootstrapResponse.Machine.visitCount: Int` und `BootstrapResponse.EquipmentModel.settingDefinitions: [TagContextResponse.SettingDefinition]` — von Aufgabe 6, 10, 12 und 15 konsumiert. **Bewusst derselbe Swift-Typ wie in `TagContextResponse`**, damit `GeraetModel` online und offline dieselbe Liste verarbeitet statt zwei Formen zu kennen.

- [ ] **Step 1: Den Test für den reinen Zähler schreiben**

Create `packages/domain/src/bootstrap.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { zaehleBesucheJeGeraet } from "./bootstrap.js";

describe("zaehleBesucheJeGeraet", () => {
  it("zaehlt zwei Saetze derselben Session als einen Besuch", () => {
    const besuche = zaehleBesucheJeGeraet([
      { machine_id: "m1", session_id: "s1" },
      { machine_id: "m1", session_id: "s1" },
    ]);

    expect(besuche.get("m1")).toBe(1);
  });

  it("zaehlt zwei Sessions als zwei Besuche", () => {
    const besuche = zaehleBesucheJeGeraet([
      { machine_id: "m1", session_id: "s1" },
      { machine_id: "m1", session_id: "s2" },
    ]);

    expect(besuche.get("m1")).toBe(2);
  });

  it("haelt Geraete auseinander", () => {
    const besuche = zaehleBesucheJeGeraet([
      { machine_id: "m1", session_id: "s1" },
      { machine_id: "m2", session_id: "s1" },
      { machine_id: "m2", session_id: "s2" },
    ]);

    expect(besuche.get("m1")).toBe(1);
    expect(besuche.get("m2")).toBe(2);
  });

  it("liefert fuer ein nie benutztes Geraet keinen Eintrag", () => {
    const besuche = zaehleBesucheJeGeraet([]);

    expect(besuche.get("m1")).toBeUndefined();
  });
});
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag bestätigen**

```bash
cd packages/domain && pnpm vitest run src/bootstrap.test.ts
```

Erwartet: FAIL — `zaehleBesucheJeGeraet` ist kein Export von `./bootstrap.js`.

- [ ] **Step 3: Den Zähler implementieren und einhängen**

In `packages/domain/src/bootstrap.ts`, direkt unter `function key(...)`:

```ts
/**
 * Besuche je Geraet: unterschiedliche Sessions mit mindestens einem Satz.
 *
 * Ausgelagert, weil `designsystem.md` SS8 daraus den Einstieg ableitet
 * (Erstkontakt / erkannt / direkt zum Satz) und diese Regel testbar sein
 * muss, ohne eine Datenbank zu stellen.
 */
export function zaehleBesucheJeGeraet(
  rows: Array<{ machine_id: string; session_id: string }>,
): Map<string, number> {
  const sessionsJeGeraet = new Map<string, Set<string>>();
  for (const row of rows) {
    const menge = sessionsJeGeraet.get(row.machine_id) ?? new Set<string>();
    menge.add(row.session_id);
    sessionsJeGeraet.set(row.machine_id, menge);
  }
  return new Map(
    [...sessionsJeGeraet].map(([machineId, menge]) => [machineId, menge.size]),
  );
}
```

Im `Bootstrap`-Typ, in `machines`, direkt nach `tokenHashes: string[];`:

```ts
    /**
     * Unterschiedliche Sessions mit mindestens einem Satz an diesem Geraet.
     * Der Einstieg (designsystem.md SS8) wertet davon nur 0 / 1 / >= 2 aus,
     * deshalb ist die Deckelung durch SET_SCAN_LIMIT unkritisch.
     */
    visitCount: number;
```

Im `select` auf `workout_sets` (in `getBootstrap`) `session_id` ergänzen:

```ts
  const { data: setRows } = await client
    .from("workout_sets")
    .select("machine_id, exercise_id, session_id, weight_kg, reps, rir, performed_at")
    .eq("user_id", userId)
    .order("performed_at", { ascending: false })
    .limit(SET_SCAN_LIMIT);
```

Den Zeilentyp derselben Schleife um `session_id: string;` erweitern (die `for`-Schleife, die `lastSets` füllt) und direkt **vor** dem `machines`-Mapping den Zähler bilden:

```ts
  const besucheJeGeraet = zaehleBesucheJeGeraet(
    (setRows ?? []) as Array<{ machine_id: string; session_id: string }>,
  );
```

Im `machines`-Mapping nach `tokenHashes:`:

```ts
    visitCount: besucheJeGeraet.get(row.id) ?? 0,
```

**Achtung:** Das `machines`-Mapping steht in der Datei **vor** dem Lesen von `setRows`. Verschiebe die Konstante `machines` unter die `setRows`-Abfrage, damit `besucheJeGeraet` bereits existiert — die Abfragen selbst bleiben in ihrer Reihenfolge stehen.

Im `Bootstrap`-Typ, in `machines[].equipmentModel`, nach `maxWeightKg`:

```ts
      /**
       * Beschriftungen der Einstellparameter. Ohne sie zeigt der
       * Offline-Zustand den rohen Schluessel ("sitz 4") statt "Sitz 4" --
       * GeraetOffline.dc.html verlangt die Beschriftung.
       */
      settingDefinitions: Array<{
        key: string;
        label: string;
        kind: string;
        minValue: number | null;
        maxValue: number | null;
        stepValue: number | null;
        unit: string | null;
        allowedValues: string[] | null;
      }>;
```

Eine Abfrage dazu, neben den übrigen in `getBootstrap` (Definitionen sind Studioinhalt und je Modell geteilt — RLS beschränkt sie ohnehin auf die Studios des Mitglieds):

```ts
  const { data: settingRows } = await client
    .from("equipment_setting_definitions")
    .select(
      "equipment_model_id, key, label, kind, min_value, max_value, step_value, unit, allowed_values",
    )
    .order("sort_order", { ascending: true });
```

Und die Zuordnung, direkt vor dem `machines`-Mapping:

```ts
  const einstellungenJeModell = new Map<
    string,
    Bootstrap["machines"][number]["equipmentModel"]["settingDefinitions"]
  >();
  for (const row of (settingRows ?? []) as Array<{
    equipment_model_id: string;
    key: string;
    label: string;
    kind: string;
    min_value: number | string | null;
    max_value: number | string | null;
    step_value: number | string | null;
    unit: string | null;
    allowed_values: string[] | null;
  }>) {
    const liste = einstellungenJeModell.get(row.equipment_model_id) ?? [];
    liste.push({
      key: row.key,
      label: row.label,
      kind: row.kind,
      minValue: row.min_value === null ? null : Number(row.min_value),
      maxValue: row.max_value === null ? null : Number(row.max_value),
      stepValue: row.step_value === null ? null : Number(row.step_value),
      unit: row.unit,
      allowedValues: row.allowed_values,
    });
    einstellungenJeModell.set(row.equipment_model_id, liste);
  }
```

Im `equipmentModel`-Teil des `machines`-Mappings, nach `maxWeightKg`:

```ts
      settingDefinitions: einstellungenJeModell.get(row.equipment_models.id) ?? [],
```

- [ ] **Step 4: Test laufen lassen, Erfolg bestätigen**

```bash
cd packages/domain && pnpm vitest run src/bootstrap.test.ts
```

Erwartet: PASS, 4 Tests.

- [ ] **Step 5: Typprüfung über das Monorepo**

```bash
pnpm typecheck 2>&1 | tail -20
```

Erwartet: keine Fehler.

- [ ] **Step 6: Das Swift-DTO nachziehen**

In `apps/ios-member/FitnessMember/Networking/DTOs/BootstrapResponse.swift`, in `struct Machine`, nach `let tokenHashes: [String]`:

```swift
        /// Unterschiedliche Sessions mit mindestens einem Satz an diesem
        /// Geraet. Traegt die Einstiegsentscheidung aus designsystem.md SS8
        /// und muss deshalb auch offline aus dem Prefetch verfuegbar sein.
        let visitCount: Int
```

Und in `struct EquipmentModel`, nach `let maxWeightKg: Double?`:

```swift
        /// Derselbe Typ wie in TagContextResponse -- GeraetModel verarbeitet
        /// online und offline dieselbe Liste, statt zwei Formen zu kennen.
        ///
        /// Ohne diese Beschriftungen zeigt der Offline-Zustand den rohen
        /// Schluessel ("sitz 4") statt "Sitz 4".
        let settingDefinitions: [TagContextResponse.SettingDefinition]
```

- [ ] **Step 7: Den DTO-Test erweitern**

In `apps/ios-member/FitnessMemberTests/DTOTests.swift` einen Test ergänzen. Falls dort bereits ein Bootstrap-JSON-Literal existiert, dieses um `"visitCount": 3` in der Maschine erweitern und die Zusicherung anhängen; andernfalls neu anlegen:

```swift
@Test func bootstrapDecodiertVisitCount() throws {
    let json = """
    {
      "studios": [],
      "machines": [{
        "id": "m1", "studioId": "s1", "label": "Gerät 7",
        "locationNote": null, "status": "active",
        "tokenHashes": ["abc"], "visitCount": 3,
        "equipmentModel": {
          "id": "em1", "name": "Beinpresse", "manufacturer": null,
          "photoPath": null, "weightStepKg": 2.5,
          "minWeightKg": 5.0, "maxWeightKg": 150.0,
          "settingDefinitions": [{
            "key": "sitz", "label": "Sitzposition", "kind": "number",
            "minValue": 1, "maxValue": 8, "stepValue": 1,
            "unit": null, "allowedValues": null
          }]
        },
        "exercises": []
      }],
      "calibrations": [],
      "lastSets": []
    }
    """.data(using: .utf8)!

    let bootstrap = try JSONDecoder().decode(BootstrapResponse.self, from: json)

    #expect(bootstrap.machines[0].visitCount == 3)
    // Ohne die Beschriftung zeigt der Offline-Zustand "sitz 4" statt "Sitz 4".
    #expect(bootstrap.machines[0].equipmentModel.settingDefinitions.first?.label == "Sitzposition")
}
```

- [ ] **Step 8: Swift-Tests laufen lassen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/DTOTests 2>&1 | tail -20
```

Erwartet: alle Tests grün. Schlagen andere Tests fehl, weil sie ein Bootstrap-JSON ohne `visitCount` enthalten, ergänze dort `"visitCount": 0`.

- [ ] **Step 9: Commit**

```bash
git add packages/domain/src/bootstrap.ts packages/domain/src/bootstrap.test.ts \
        apps/ios-member/FitnessMember/Networking/DTOs/BootstrapResponse.swift \
        apps/ios-member/FitnessMemberTests/DTOTests.swift
git commit -m "feat(api): bootstrap liefert visitCount und die Einstellparameter

Der Einstieg am Geraet (designsystem.md SS8) unterscheidet 0 / 1 / ab 2
Besuche. Die Groesse lieferte bisher kein Endpoint. Sie kommt aus dem
Prefetch statt aus tagContext, weil der Screen laut M1-Spec SS8.1 sofort
rendern muss -- ohne auf das Netz zu warten. Das kostet keine zusaetzliche
Abfrage: getBootstrap liest die Satzzeilen ohnehin und verwarf session_id
bisher nur.

Dazu die Beschriftungen der Einstellparameter. Der Offline-Zustand zeigt
'Sitz 4 . Lehne 2 . Startwinkel 30 Grad'; die Werte lagen im Prefetch, die
Beschriftungen nicht -- dort haette der rohe Schluessel gestanden."
```

---

### Aufgabe 2: Endpoint `POST /api/v1/me/calibrations`

Die Tabelle `member_machine_calibrations` steht seit Migration `0014` inklusive Insert-Policy, beide Lesepfade nutzen sie — aber es gibt weder Domain-Funktion noch Route. `GeraetKalibrierung` („Speichern und weiter") und M1-Spec §8.3 Schritt 4 brauchen sie zwingend.

`designsystem.md` §7.4 verlangt serverseitige Validierung der Werte gegen die Einstellparameter. Ein JSONB ohne Prüfung wäre ein Freitextfeld mit anderem Namen.

**Files:**
- Create: `packages/domain/src/calibration.ts`
- Create: `packages/domain/src/calibration.test.ts`
- Modify: `packages/domain/src/index.ts`
- Create: `apps/web/app/api/v1/me/calibrations/route.ts`

**Interfaces:**
- Consumes: nichts aus früheren Aufgaben.
- Produces: `recordCalibration(client: SupabaseClient, rawInput: unknown): Promise<RecordedCalibration>`
- Produces: `pruefeEinstellwerte(definitionen: EinstellDefinition[], werte: Record<string, unknown>): string | null` — Fehlermeldung oder `null`.
- Produces: `type EinstellDefinition = { key: string; label: string; kind: string; min_value: number | null; max_value: number | null; step_value: number | null; allowed_values: string[] | null }`
- Produces: `type RecordedCalibration = { id: string; machineId: string; exerciseId: string; settingValues: unknown; schemaVersion: number; source: string; createdAt: string }`

- [ ] **Step 1: Den Test der reinen Wertprüfung schreiben**

Create `packages/domain/src/calibration.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { pruefeEinstellwerte, type EinstellDefinition } from "./calibration.js";

/** Beinpresse aus dem Testkatalog: Sitz 1-8 in Schritten von 1. */
const sitz: EinstellDefinition = {
  key: "sitz",
  label: "Sitzposition",
  kind: "number",
  min_value: 1,
  max_value: 8,
  step_value: 1,
  allowed_values: null,
};

const griff: EinstellDefinition = {
  key: "griff",
  label: "Griff",
  kind: "enum",
  min_value: null,
  max_value: null,
  step_value: null,
  allowed_values: ["eng", "breit"],
};

describe("pruefeEinstellwerte", () => {
  it("nimmt einen Wert innerhalb der Grenzen an", () => {
    expect(pruefeEinstellwerte([sitz], { sitz: 4 })).toBeNull();
  });

  it("weist einen Wert oberhalb des Maximums ab und nennt die Grenze", () => {
    const fehler = pruefeEinstellwerte([sitz], { sitz: 9 });

    expect(fehler).toContain("Sitzposition");
    expect(fehler).toContain("8");
  });

  it("weist einen Wert unterhalb des Minimums ab", () => {
    expect(pruefeEinstellwerte([sitz], { sitz: 0 })).not.toBeNull();
  });

  it("weist einen Wert neben der Schrittweite ab", () => {
    expect(pruefeEinstellwerte([sitz], { sitz: 4.5 })).not.toBeNull();
  });

  it("weist einen unbekannten Schluessel ab", () => {
    expect(pruefeEinstellwerte([sitz], { lehne: 2 })).not.toBeNull();
  });

  it("nimmt einen erlaubten Auswahlwert an", () => {
    expect(pruefeEinstellwerte([griff], { griff: "eng" })).toBeNull();
  });

  it("weist einen nicht erlaubten Auswahlwert ab", () => {
    expect(pruefeEinstellwerte([griff], { griff: "mittel" })).not.toBeNull();
  });

  it("weist eine Zahl fuer ein Auswahlfeld ab", () => {
    expect(pruefeEinstellwerte([griff], { griff: 3 })).not.toBeNull();
  });

  it("nimmt eine Teilmenge an -- nicht jeder Parameter muss gesetzt sein", () => {
    expect(pruefeEinstellwerte([sitz, griff], { sitz: 4 })).toBeNull();
  });

  it("weist einen leeren Satz ab -- eine Kalibrierung ohne Werte ist keine", () => {
    expect(pruefeEinstellwerte([sitz], {})).not.toBeNull();
  });
});
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag bestätigen**

```bash
cd packages/domain && pnpm vitest run src/calibration.test.ts
```

Erwartet: FAIL — Modul `./calibration.js` existiert nicht.

- [ ] **Step 3: Die Fachschicht schreiben**

Create `packages/domain/src/calibration.ts`:

```ts
import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";
import { requireUserId } from "./auth.js";
import { DomainError } from "./errors.js";

/**
 * Eigene Einstellwerte schreiben.
 *
 * Fehlte bis Sub-Projekt 2 vollstaendig: Tabelle und Insert-Policy stehen
 * seit Migration 0014, beide Lesepfade nutzen sie, aber es gab keinen
 * Schreibweg. M1-Spec SS8.3 Schritt 4 und der Kalibrierungs-Screen brauchen
 * ihn zwingend.
 *
 * Anfuegend, nie ueberschreibend -- die Tabelle hat bewusst weder Update-
 * noch Delete-Policy: eine Aenderung ist eine neue Zeile.
 */
export const recordCalibrationInputSchema = z.object({
  machineId: z.string().uuid(),
  exerciseId: z.string().uuid(),
  settingValues: z.record(z.union([z.number(), z.string()])),
  schemaVersion: z.number().int().min(1),
  source: z.enum(["self", "trainer_assisted"]).default("self"),
});

export type RecordCalibrationInput = z.infer<typeof recordCalibrationInputSchema>;

export type EinstellDefinition = {
  key: string;
  label: string;
  kind: string;
  min_value: number | null;
  max_value: number | null;
  step_value: number | null;
  allowed_values: string[] | null;
};

export type RecordedCalibration = {
  id: string;
  machineId: string;
  exerciseId: string;
  settingValues: unknown;
  schemaVersion: number;
  source: string;
  createdAt: string;
};

/** Toleranz beim Schrittvergleich -- numeric kommt als Gleitkomma zurueck. */
const SCHRITT_TOLERANZ = 1e-6;

/**
 * Prueft die Werte gegen die Einstellparameter des Geraetemodells
 * (designsystem.md SS7.4). Gibt eine Meldung zurueck oder null.
 *
 * Die Meldung nennt immer, was gilt -- nicht nur, dass etwas ungueltig ist
 * (designsystem.md SS5).
 */
export function pruefeEinstellwerte(
  definitionen: EinstellDefinition[],
  werte: Record<string, unknown>,
): string | null {
  const eintraege = Object.entries(werte);
  if (eintraege.length === 0) {
    return "Es wurde kein Einstellwert uebergeben.";
  }

  const nachKey = new Map(definitionen.map((d) => [d.key, d]));

  for (const [key, wert] of eintraege) {
    const definition = nachKey.get(key);
    if (!definition) {
      return `Unbekannter Einstellparameter: ${key}.`;
    }

    if (definition.kind === "enum") {
      if (typeof wert !== "string") {
        return `${definition.label} erwartet eine Auswahl, keinen Zahlenwert.`;
      }
      const erlaubt = definition.allowed_values ?? [];
      if (!erlaubt.includes(wert)) {
        return `${definition.label} erlaubt nur: ${erlaubt.join(", ")}.`;
      }
      continue;
    }

    if (typeof wert !== "number" || !Number.isFinite(wert)) {
      return `${definition.label} erwartet einen Zahlenwert.`;
    }
    if (definition.min_value !== null && wert < definition.min_value) {
      return `${definition.label} liegt unter dem Minimum ${definition.min_value}.`;
    }
    if (definition.max_value !== null && wert > definition.max_value) {
      return `${definition.label} liegt ueber dem Maximum ${definition.max_value}.`;
    }
    if (definition.step_value !== null && definition.step_value > 0) {
      const basis = definition.min_value ?? 0;
      const schritte = (wert - basis) / definition.step_value;
      if (Math.abs(schritte - Math.round(schritte)) > SCHRITT_TOLERANZ) {
        return `${definition.label} geht in Schritten von ${definition.step_value}.`;
      }
    }
  }

  return null;
}

export async function recordCalibration(
  client: SupabaseClient,
  rawInput: unknown,
): Promise<RecordedCalibration> {
  const parsed = recordCalibrationInputSchema.safeParse(rawInput);
  if (!parsed.success) {
    throw new DomainError("validation_failed", parsed.error.issues[0]!.message);
  }
  const input = parsed.data;

  const userId = await requireUserId(client);

  // Das Studio kommt aus dem Geraet. RLS macht ein fremdes Geraet unsichtbar,
  // der Aufruf endet dann hier statt an einer Policy weiter unten.
  const { data: machine } = await client
    .from("machines")
    .select("studio_id, equipment_model_id")
    .eq("id", input.machineId)
    .maybeSingle<{ studio_id: string; equipment_model_id: string }>();
  if (!machine) {
    throw new DomainError("not_found", "Geraet nicht gefunden.");
  }

  const { data: exercise } = await client
    .from("exercises")
    .select("id")
    .eq("id", input.exerciseId)
    .eq("studio_id", machine.studio_id)
    .maybeSingle<{ id: string }>();
  if (!exercise) {
    throw new DomainError("not_found", "Uebung nicht gefunden.");
  }

  const { data: definitionen } = await client
    .from("equipment_setting_definitions")
    .select("key, label, kind, min_value, max_value, step_value, allowed_values")
    .eq("equipment_model_id", machine.equipment_model_id);

  const fehler = pruefeEinstellwerte(
    (definitionen ?? []) as EinstellDefinition[],
    input.settingValues,
  );
  if (fehler) {
    throw new DomainError("validation_failed", fehler);
  }

  const { data: row, error } = await client
    .from("member_machine_calibrations")
    .insert({
      studio_id: machine.studio_id,
      user_id: userId,
      machine_id: input.machineId,
      exercise_id: input.exerciseId,
      setting_values: input.settingValues,
      schema_version: input.schemaVersion,
      source: input.source,
      // recorded_by bleibt null: die Insert-Policy erzwingt
      // user_id = auth.uid(), ein Trainer weist sich in der Member-App
      // nicht aus. Der Schalter setzt nur die Quelle.
    })
    .select("id, machine_id, exercise_id, setting_values, schema_version, source, created_at")
    .single<{
      id: string;
      machine_id: string;
      exercise_id: string;
      setting_values: unknown;
      schema_version: number;
      source: string;
      created_at: string;
    }>();

  if (error || !row) {
    throw new DomainError(
      "internal",
      error?.message ?? "Einstellung konnte nicht gespeichert werden.",
    );
  }

  return {
    id: row.id,
    machineId: row.machine_id,
    exerciseId: row.exercise_id,
    settingValues: row.setting_values,
    schemaVersion: row.schema_version,
    source: row.source,
    createdAt: row.created_at,
  };
}
```

**Vor dem Schreiben prüfen:** `DomainError` und `requireUserId` müssen aus denselben Modulen kommen wie in `packages/domain/src/workout.ts`. Sieh dort in die `import`-Zeilen und übernimm sie wörtlich.

- [ ] **Step 4: Test laufen lassen, Erfolg bestätigen**

```bash
cd packages/domain && pnpm vitest run src/calibration.test.ts
```

Erwartet: PASS, 10 Tests.

- [ ] **Step 5: Exportieren**

In `packages/domain/src/index.ts`, bei den übrigen Exporten:

```ts
export {
  recordCalibration,
  recordCalibrationInputSchema,
  pruefeEinstellwerte,
} from "./calibration.js";
export type {
  RecordCalibrationInput,
  RecordedCalibration,
  EinstellDefinition,
} from "./calibration.js";
```

- [ ] **Step 6: Die Route anlegen**

Create `apps/web/app/api/v1/me/calibrations/route.ts`:

```ts
import { recordCalibration } from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

/**
 * Eigene Einstellwerte schreiben (Kalibrierung).
 *
 * Ausserhalb der sechs Endpoints aus M1-Spec SS6.3 -- wie schon
 * studios/join-by-code, join-by-tag und DELETE membership aus
 * Sub-Projekt 1. Die Architekturaussage dahinter (screenorientiert, keine
 * Fachlogik im Client) bleibt unberuehrt.
 */
export async function POST(request: Request): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) return errorResponse("unauthorized", "Anmeldung erforderlich.");

  let payload: unknown;
  try {
    payload = await request.json();
  } catch {
    return errorResponse("validation_failed", "Der Rumpf ist kein gueltiges JSON.");
  }

  try {
    const calibration = await recordCalibration(client, payload);
    return Response.json(calibration, { status: 201 });
  } catch (error) {
    return fromDomainError(error);
  }
}
```

- [ ] **Step 7: Typprüfung und vollständiger Domain-Testlauf**

```bash
pnpm typecheck 2>&1 | tail -20 && cd packages/domain && pnpm vitest run 2>&1 | tail -20
```

Erwartet: keine Typfehler, alle Domain-Tests grün.

- [ ] **Step 8: Commit**

```bash
git add packages/domain/src/calibration.ts packages/domain/src/calibration.test.ts \
        packages/domain/src/index.ts \
        apps/web/app/api/v1/me/calibrations/route.ts
git commit -m "feat(api): POST /api/v1/me/calibrations

Die Kalibrierung hatte keinen Schreibweg: Tabelle und Insert-Policy stehen
seit Migration 0014, beide Lesepfade nutzen sie, aber weder Domain-Funktion
noch Route existierten -- obwohl M1-Spec SS8.3 Schritt 4 und der
Kalibrierungs-Screen sie zwingend brauchen.

Die Werte werden serverseitig gegen equipment_setting_definitions geprueft
(designsystem.md SS7.4); ein JSONB ohne Pruefung waere ein Freitextfeld mit
anderem Namen. Die Meldung nennt immer, was gilt, nicht nur dass etwas
ungueltig ist.

recorded_by bleibt null -- die Insert-Policy erzwingt user_id = auth.uid();
der Schalter 'Ein Trainer war dabei' setzt nur die Quelle."
```

---

### Aufgabe 3: Design-System — Zahlformat, fehlende Typo-Rollen, Bewegung, Press-Feedback

Der Design-Challenge-Befund „kein `:active`-Press-Feedback für einen einzigen Button in der gesamten Canvas" ist unverändert nach Swift durchgeschlagen: `DesignSystem.Color.accentPressed` ist definiert und wird nirgends verwendet. Das wird hier einmal zentral gelöst, damit es überall gilt — dieselbe Lehre wie bei den Maßkonstanten in Sub-Projekt 1.

Dazu die Typo-Rollen aus `designsystem.md` §3, die Sub-Projekt 1 nicht brauchte, und das Zahlformat: Gewichte immer mit einer Nachkommastelle und Dezimalkomma.

**Files:**
- Modify: `apps/ios-member/FitnessMember/DesignSystem/DesignSystem.swift`
- Create: `apps/ios-member/FitnessMember/DesignSystem/Zahlformat.swift`
- Create: `apps/ios-member/FitnessMember/DesignSystem/Components/PressButtonStyle.swift`
- Modify: `apps/ios-member/FitnessMember/DesignSystem/Components/PrimaryButton.swift`
- Modify: `apps/ios-member/FitnessMember/DesignSystem/Components/SecondaryButton.swift`
- Create: `apps/ios-member/FitnessMemberTests/ZahlformatTests.swift`

**Interfaces:**
- Produces: `enum Zahlformat { static func gewicht(_ kg: Double) -> String; static func gewichtMitEinheit(_ kg: Double) -> String; static func gewichtGesprochen(_ kg: Double) -> String; static func wiederholungenGesprochen(_ reps: Int) -> String }` — von Aufgabe 7, 9, 10, 11, 12, 13, 14 konsumiert.
- Produces: `DesignSystem.Motion.oeffnen`, `.pause`, `.press` (`Animation`) — von Aufgabe 7, 10, 13 konsumiert.
- Produces: `DesignSystem.Typography.geraetename`, `.detailScreentitel`, `.uebungsname`, `.wertSekundaer`, `.fliesstext`, `.radNah`, `.radFern` — von den Screen-Aufgaben konsumiert.
- Produces: `struct PressButtonStyle: ButtonStyle` — von `PrimaryButton`, `SecondaryButton` und allen Screen-Aufgaben konsumiert.

- [ ] **Step 1: Den Zahlformat-Test schreiben**

Create `apps/ios-member/FitnessMemberTests/ZahlformatTests.swift`:

```swift
import Testing
@testable import FitnessMember

struct ZahlformatTests {
    @Test func gewichtHatImmerGenauEineNachkommastelle() {
        #expect(Zahlformat.gewicht(80) == "80,0")
        #expect(Zahlformat.gewicht(82.5) == "82,5")
        #expect(Zahlformat.gewicht(5) == "5,0")
    }

    @Test func gewichtNutztDezimalkommaUnabhaengigVonDerSystemsprache() {
        // Ein Punkt hier waere ein Formatfehler, kein Gebietsschema-Detail:
        // designsystem.md SS3 legt Dezimalkomma fest.
        #expect(!Zahlformat.gewicht(82.5).contains("."))
    }

    @Test func gewichtMitEinheitHaengtKilogrammAn() {
        #expect(Zahlformat.gewichtMitEinheit(80) == "80,0 kg")
    }

    @Test func gesprocheneAnsageIstEineZeichenkette() {
        // designsystem.md SS12: sonst liest VoiceOver "achtzig, Komma, null,
        // k, g" als vier Elemente.
        #expect(Zahlformat.gewichtGesprochen(80) == "80,0 Kilogramm")
        #expect(Zahlformat.wiederholungenGesprochen(1) == "1 Wiederholung")
        #expect(Zahlformat.wiederholungenGesprochen(10) == "10 Wiederholungen")
    }
}
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag bestätigen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/ZahlformatTests 2>&1 | tail -20
```

Erwartet: FAIL — `Zahlformat` ist nicht bekannt.

- [ ] **Step 3: `Zahlformat` implementieren**

Create `apps/ios-member/FitnessMember/DesignSystem/Zahlformat.swift`:

```swift
import Foundation

/// Zahlen so, wie designsystem.md SS3 sie festlegt.
///
/// Gewichte tragen **immer** eine Nachkommastelle: ein Wechsel von 80 auf
/// 82,5 wirkte sonst wie ein Formatfehler statt wie eine Steigerung.
///
/// Das Gebietsschema ist fest auf Deutsch gesetzt, nicht `.current` -- das
/// Dezimalkomma ist hier eine Designentscheidung, kein Systemdetail.
enum Zahlformat {
    private static let gebietsschema = Locale(identifier: "de_DE")

    private static let gewichtFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = gebietsschema
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        formatter.usesGroupingSeparator = false
        return formatter
    }()

    static func gewicht(_ kg: Double) -> String {
        gewichtFormatter.string(from: NSNumber(value: kg)) ?? "0,0"
    }

    static func gewichtMitEinheit(_ kg: Double) -> String {
        "\(gewicht(kg)) kg"
    }

    /// Eine einzige Zeichenkette -- sonst liest VoiceOver "achtzig, Komma,
    /// null, k, g" als vier Elemente (designsystem.md SS12).
    static func gewichtGesprochen(_ kg: Double) -> String {
        "\(gewicht(kg)) Kilogramm"
    }

    static func wiederholungenGesprochen(_ reps: Int) -> String {
        reps == 1 ? "1 Wiederholung" : "\(reps) Wiederholungen"
    }
}
```

- [ ] **Step 4: Test laufen lassen, Erfolg bestätigen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/ZahlformatTests 2>&1 | tail -20
```

Erwartet: PASS, 4 Tests.

- [ ] **Step 5: Typo-Rollen und Bewegungskonstanten ergänzen**

In `apps/ios-member/FitnessMember/DesignSystem/DesignSystem.swift`, im `Typography`-Enum die bestehenden Zeilen ergänzen um:

```swift
        /// designsystem.md SS3: 30-34pt Black, Versalien, Tracking -2,5 %.
        static let geraetename = Font.system(size: 32, weight: .black)
        /// Zweite Titelrolle, in SessionDetail/Uebungsfortschritt belegt
        /// (Design-Challenge SS3.4 -- dort als nachzutragen vermerkt).
        static let detailScreentitel = Font.system(size: 28, weight: .black)
        static let uebungsname = Font.system(size: 17, weight: .semibold)
        static let wertSekundaer = Font.system(size: 19, weight: .black).monospacedDigit()
        static let fliesstext = Font.system(size: 15, weight: .regular)
        /// Nachbarn im Rad, designsystem.md SS7: 30pt und 26pt.
        static let radNah = Font.system(size: 30, weight: .black).monospacedDigit()
        static let radFern = Font.system(size: 26, weight: .black).monospacedDigit()
```

Und ein neues Enum am Ende von `DesignSystem`:

```swift
    /// Die vier Momente, die wir selbst fahren. Momentum, Deceleration,
    /// Rubber-Banding und Unterbrechbarkeit kommen vom System-Scroller und
    /// stehen deshalb bewusst nicht hier (Spec Abschnitt 6).
    enum Motion {
        static let oeffnen = Animation.spring(response: 0.34, dampingFraction: 0.86)
        static let pause = Animation.spring(response: 0.4, dampingFraction: 0.9)
        static let press = Animation.spring(response: 0.22, dampingFraction: 0.9)
        static let pressSkalierung: CGFloat = 0.97
    }
```

Für die Versalien-Rollen gilt: Der Text wird im Screen mit `.textCase(.uppercase)` und `.tracking(-0.8)` bzw. `.tracking(1.5)` versehen — `Font` allein trägt kein Tracking.

- [ ] **Step 6: `PressButtonStyle` anlegen**

Create `apps/ios-member/FitnessMember/DesignSystem/Components/PressButtonStyle.swift`:

```swift
import SwiftUI

/// Press-Feedback fuer jeden Button der App.
///
/// Die Design-Challenge fand, dass in der gesamten Canvas kein einziger
/// Button ein :active-Feedback hat -- und accentPressed war in Swift
/// definiert, aber unbenutzt. Einmal als ButtonStyle statt je Button, damit
/// die Abweichung strukturell unmoeglich wird statt nur unerwuenscht.
struct PressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion
                         ? DesignSystem.Motion.pressSkalierung : 1)
            .animation(reduceMotion ? nil : DesignSystem.Motion.press,
                       value: configuration.isPressed)
    }
}
```

- [ ] **Step 7: `PrimaryButton` und `SecondaryButton` verdrahten**

In `PrimaryButton.swift` den `Button` um `.buttonStyle(PressButtonStyle())` ergänzen und die Hintergrundfarbe an den Druckzustand koppeln. Ersetze den `Button { … } label: { … }`-Block samt Modifikatoren durch:

```swift
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
                .background(isEnabled ? DesignSystem.Color.accent : DesignSystem.Color.surfaceRaised)
                .foregroundStyle(isEnabled ? DesignSystem.Color.onAccent : DesignSystem.Color.textFaint)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.haupt))
            }
            .buttonStyle(PressButtonStyle())
            .disabled(!isEnabled || isLoading)
```

Der Farbwechsel auf `accentPressed` kommt über eine Ergänzung in `PressButtonStyle` — füge dort einen zweiten Style hinzu, der ihn trägt:

```swift
/// Wie PressButtonStyle, zusaetzlich mit dem Farbwechsel der Hauptaktion.
struct HauptaktionButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(hintergrund(gedrueckt: configuration.isPressed))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.haupt))
            .scaleEffect(configuration.isPressed && !reduceMotion
                         ? DesignSystem.Motion.pressSkalierung : 1)
            .animation(reduceMotion ? nil : DesignSystem.Motion.press,
                       value: configuration.isPressed)
    }

    private func hintergrund(gedrueckt: Bool) -> Color {
        guard isEnabled else { return DesignSystem.Color.surfaceRaised }
        return gedrueckt ? DesignSystem.Color.accentPressed : DesignSystem.Color.accent
    }
}
```

und nutze in `PrimaryButton` `.buttonStyle(HauptaktionButtonStyle(isEnabled: isEnabled))` statt `PressButtonStyle()`, ohne eigenes `.background`/`.clipShape` am Label. In `SecondaryButton` genügt `.buttonStyle(PressButtonStyle())`.

- [ ] **Step 8: Vollständiger Testlauf und Sichtprüfung**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test 2>&1 | tail -30
```

Erwartet: alle Tests grün.

Dann die Previews in `PrimaryButton.swift` und `SecondaryButton.swift` in der Xcode-Canvas öffnen und gedrückt halten: Die Fläche muss auf `#A8CC2A` wechseln und leicht schrumpfen. Mit „Reduce Motion" in den Simulator-Einstellungen darf nichts schrumpfen, der Farbwechsel bleibt.

- [ ] **Step 9: Commit**

```bash
git add apps/ios-member/FitnessMember/DesignSystem apps/ios-member/FitnessMemberTests/ZahlformatTests.swift
git commit -m "feat(ios): Zahlformat, Typo-Rollen, Bewegungskonstanten, Press-Feedback

Die Design-Challenge fand, dass in der gesamten Canvas kein einziger Button
ein :active-Feedback hat. In Swift war accentPressed definiert und unbenutzt
-- der Befund war unveraendert durchgeschlagen. Jetzt einmal als ButtonStyle
statt je Button.

Zahlformat setzt das Dezimalkomma und die Nachkommastelle fest (SS3): ein
Wechsel von 80 auf 82,5 wirkt sonst wie ein Formatfehler statt wie eine
Steigerung. Das Gebietsschema ist fest deutsch, nicht .current -- das ist
eine Designentscheidung, kein Systemdetail."
```

---

### Aufgabe 4: `NetzwerkMonitor` und die zwei Reparaturen an der Warteschlange

Die SP1-Spec sagt zu: „Ein `NWPathMonitor` löst `flushPending()` bei Netzwerkänderung aus." Gebaut wurde er nie — `flushPending()` hat heute überhaupt keinen Auslöser. Und es behält bei **jedem** Fehler: ein dauerhaft abweisbarer Schreibvorgang bliebe für immer in der Schlange und würde bei jedem Netzwechsel neu versucht.

**Files:**
- Create: `apps/ios-member/FitnessMember/Networking/NetzwerkMonitor.swift`
- Modify: `apps/ios-member/FitnessMember/Networking/APIError.swift`
- Modify: `apps/ios-member/FitnessMember/Catalog/CatalogStore.swift`
- Modify: `apps/ios-member/FitnessMemberTests/CatalogStoreTests.swift`

**Interfaces:**
- Consumes: `APIError` (Sub-Projekt 1), `CatalogStore.flushPending()` (Sub-Projekt 1).
- Produces: `APIError.istDauerhaft: Bool`
- Produces: `@MainActor @Observable final class NetzwerkMonitor { private(set) var istOnline: Bool; func start(beiVerbindung: @escaping @MainActor () -> Void); func stop() }` — von Aufgabe 14 und 13 konsumiert.
- Produces: `CatalogStore.verworfeneWrites: [PendingSetWrite]` — von Aufgabe 13 konsumiert.

- [ ] **Step 1: Die Tests schreiben**

An `apps/ios-member/FitnessMemberTests/CatalogStoreTests.swift` anhängen:

```swift
struct APIErrorDauerhaftTests {
    @Test func offlineUndServerfehlerSindVoruebergehend() {
        #expect(APIError.offline.istDauerhaft == false)
        #expect(APIError.server(message: "x").istDauerhaft == false)
    }

    @Test func validierungUndNichtGefundenSindDauerhaft() {
        // Ein Geraet, das stillgelegt wurde, kommt nie zurueck -- der
        // Schreibvorgang darf nicht ewig wiederholt werden.
        #expect(APIError.validation(message: "x").istDauerhaft)
        #expect(APIError.notFound(message: "x").istDauerhaft)
        #expect(APIError.unauthorized(message: "x").istDauerhaft)
        #expect(APIError.conflict(message: "x").istDauerhaft)
        #expect(APIError.decodingFailed.istDauerhaft)
    }
}
```

Und ein Test für die Warteschlange (im bestehenden `CatalogStore`-Testtyp, oder als eigener Typ, falls die Datei mehrere hat):

```swift
struct FlushPendingTests {
    private func store(loader: FakeBootstrapLoader) -> CatalogStore {
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        return CatalogStore(
            loader: loader,
            pendingWriteStore: PendingWriteStore(directory: verzeichnis),
            defaults: UserDefaults(suiteName: UUID().uuidString)!
        )
    }

    private var beispielWrite: PendingSetWrite {
        PendingSetWrite(
            sessionId: UUID(),
            setId: UUID(),
            body: SetWrite(machineId: "m1", exerciseId: "e1", setIndex: 1,
                           weightKg: 80, reps: 10)
        )
    }

    @MainActor
    @Test func behaeltDenEintragBeiVoruebergehendemFehler() async {
        let loader = FakeBootstrapLoader()
        await loader.setPutSetResult(.failure(.offline))
        let catalog = store(loader: loader)
        catalog.enqueue(beispielWrite)

        await catalog.flushPending()

        #expect(catalog.pendingWrites.count == 1)
        #expect(catalog.verworfeneWrites.isEmpty)
    }

    @MainActor
    @Test func verwirftDenEintragBeiDauerhaftemFehler() async {
        let loader = FakeBootstrapLoader()
        await loader.setPutSetResult(.failure(.notFound(message: "Geraet nicht gefunden.")))
        let catalog = store(loader: loader)
        catalog.enqueue(beispielWrite)

        await catalog.flushPending()

        #expect(catalog.pendingWrites.isEmpty)
        #expect(catalog.verworfeneWrites.count == 1)
    }
}
```

- [ ] **Step 2: Tests laufen lassen, Fehlschlag bestätigen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests 2>&1 | tail -30
```

Erwartet: FAIL — `istDauerhaft` und `verworfeneWrites` sind unbekannt.

- [ ] **Step 3: `istDauerhaft` ergänzen**

In `apps/ios-member/FitnessMember/Networking/APIError.swift`, innerhalb des Enums:

```swift
    /// Ob ein Wiederholen aussichtslos ist.
    ///
    /// Die Schreib-Warteschlange behielt bisher bei jedem Fehler. Ein
    /// stillgelegtes Geraet oder eine entfernte Uebung kommt nie zurueck --
    /// der Eintrag wuerde sonst bei jedem Netzwechsel neu versucht, fuer
    /// immer.
    var istDauerhaft: Bool {
        switch self {
        case .offline, .server: false
        case .unauthorized, .validation, .notFound, .conflict, .decodingFailed: true
        }
    }
```

- [ ] **Step 4: `flushPending` reparieren**

In `apps/ios-member/FitnessMember/Catalog/CatalogStore.swift` neben `pendingWrites` ergänzen:

```swift
    /// Schreibvorgaenge, die der Server dauerhaft abgelehnt hat. Sie werden
    /// nicht wiederholt, verschwinden aber auch nicht stillschweigend --
    /// der Geraete-Screen zeigt sie an (designsystem.md SS5: Fehler sagen,
    /// was falsch ist und was gilt).
    private(set) var verworfeneWrites: [PendingSetWrite] = []
```

und `flushPending()` ersetzen durch:

```swift
    func flushPending() async {
        var verbleibend: [PendingSetWrite] = []
        for write in pendingWrites {
            do {
                _ = try await loader.putSet(sessionId: write.sessionId, setId: write.setId, write.body)
            } catch {
                if error.istDauerhaft {
                    verworfeneWrites.append(write)
                } else {
                    verbleibend.append(write)
                }
            }
        }
        pendingWrites = verbleibend
        pendingWriteStore.save(verbleibend)
    }

    /// Nach dem Anzeigen quittiert der Screen die abgelehnten Vorgaenge.
    func verworfeneQuittieren() {
        verworfeneWrites = []
    }
```

In `reset()` zusätzlich `verworfeneWrites = []` ergänzen.

- [ ] **Step 5: Tests laufen lassen, Erfolg bestätigen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests 2>&1 | tail -30
```

Erwartet: alle Tests grün. Schlägt der Aufruf von `PendingWriteStore(directory:)` fehl, prüfe die Signatur in `PendingWriteStore.swift` — sie nimmt bereits ein `directory`.

- [ ] **Step 6: `NetzwerkMonitor` anlegen**

Create `apps/ios-member/FitnessMember/Networking/NetzwerkMonitor.swift`:

```swift
import Foundation
import Network
import Observation

/// Verbindungszustand -- speist die Offline-Leiste und loest die
/// Schreib-Warteschlange aus.
///
/// Die SP1-Spec sagt diesen Monitor zu; gebaut wurde er nie, weshalb
/// flushPending() bisher ueberhaupt keinen Ausloeser hatte.
@MainActor
@Observable
final class NetzwerkMonitor {
    private(set) var istOnline = true

    @ObservationIgnored private let monitor = NWPathMonitor()
    @ObservationIgnored private let warteschlange = DispatchQueue(label: "de.gymtaro.netzwerk")
    @ObservationIgnored private var laeuft = false

    /// `beiVerbindung` feuert nur beim Wechsel von offline nach online --
    /// nicht bei jedem Pfad-Update, sonst liefe die Warteschlange bei jedem
    /// WLAN-Kanalwechsel erneut an.
    func start(beiVerbindung: @escaping @MainActor () -> Void) {
        guard !laeuft else { return }
        laeuft = true
        monitor.pathUpdateHandler = { [weak self] pfad in
            let erreichbar = pfad.status == .satisfied
            Task { @MainActor in
                guard let self else { return }
                let warOffline = !self.istOnline
                self.istOnline = erreichbar
                if erreichbar && warOffline { beiVerbindung() }
            }
        }
        monitor.start(queue: warteschlange)
    }

    func stop() {
        monitor.cancel()
        laeuft = false
    }
}
```

- [ ] **Step 7: Bauen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" build 2>&1 | tail -20
```

Erwartet: BUILD SUCCEEDED. `NetzwerkMonitor` bekommt in Aufgabe 14 seinen Aufrufer.

- [ ] **Step 8: Commit**

```bash
git add apps/ios-member/FitnessMember/Networking apps/ios-member/FitnessMember/Catalog \
        apps/ios-member/FitnessMemberTests/CatalogStoreTests.swift
git commit -m "fix(ios): Warteschlange verwirft dauerhafte Fehler, NWPathMonitor kommt nach

Zwei Zusagen aus Sub-Projekt 1, die nicht gebaut waren:

flushPending() behielt bei jedem Fehler. Ein stillgelegtes Geraet oder eine
entfernte Uebung kommt nie zurueck -- der Eintrag waere bei jedem
Netzwechsel fuer immer neu versucht worden. Dauerhafte Fehler landen jetzt
in verworfeneWrites statt still zu verschwinden.

Und es gab keinen NWPathMonitor: flushPending() hatte ueberhaupt keinen
Ausloeser. Der Monitor feuert nur beim Wechsel offline -> online, nicht bei
jedem Pfad-Update."
```

---

### Aufgabe 5: `WorkoutSessionStore` — laufende Einheit, Vier-Stunden-Regel, `setIndex`

Die Session entsteht implizit beim ersten gesicherten Satz (M1-Spec §5.6), es gibt keinen Startknopf. Sie muss auf Platte liegen: nach einem App-Kill muss „Satz 3" noch Satz 3 heißen und der Training-Tab seine Blöcke zeigen.

**Die Vier-Stunden-Regel gilt auf beiden Seiten.** M1-Spec §5.2 wertet sie serverseitig träge aus. Aber `recordSet` upsertet die Session mit `ignoreDuplicates` und prüft **nicht**, ob sie bereits als beendet gilt — ein Client, der eine fünf Stunden alte `sessionId` weiterbenutzt, hängt Sätze an eine Einheit, die der Server längst als abgeschlossen liest.

**Files:**
- Create: `apps/ios-member/FitnessMember/Workout/LokaleSession.swift`
- Create: `apps/ios-member/FitnessMember/Workout/SessionFileStore.swift`
- Create: `apps/ios-member/FitnessMember/Workout/WorkoutSessionStore.swift`
- Create: `apps/ios-member/FitnessMemberTests/WorkoutSessionStoreTests.swift`

**Interfaces:**
- Consumes: `SetWrite`, `ProblemReason` (Sub-Projekt 1, `DTOs/WorkoutSet.swift`).
- Produces: `struct LokalerSatz`, `struct LokalerBlock`, `struct LokaleSession` — von Aufgabe 10, 11, 14, 15 konsumiert.
- Produces: `@MainActor @Observable final class WorkoutSessionStore` mit
  `func aktiveSession(jetzt: Date = Date()) -> LokaleSession?`,
  `func naechsterSetIndex(machineId: String, exerciseId: String, jetzt: Date) -> Int`,
  `func satzSichern(machineId: String, exerciseId: String, weightKg: Double, reps: Int, rir: Double?, problemFlag: Bool, problemReason: ProblemReason?, jetzt: Date) -> (sessionId: UUID, setId: UUID, body: SetWrite)`,
  `func beenden() -> UUID?` — von Aufgabe 11, 13, 15 konsumiert.
- Produces: `final class SessionFileStore { init(directory: URL); func load() -> LokaleSession?; func save(_ session: LokaleSession?) }`

- [ ] **Step 1: Die Tests schreiben**

Create `apps/ios-member/FitnessMemberTests/WorkoutSessionStoreTests.swift`:

```swift
import Foundation
import Testing
@testable import FitnessMember

@MainActor
struct WorkoutSessionStoreTests {
    private func store() -> (WorkoutSessionStore, URL) {
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        return (WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis)), verzeichnis)
    }

    private let start = Date(timeIntervalSince1970: 1_757_000_000)

    @Test func derErsteSatzLegtDieSessionAn() {
        let (sut, _) = store()
        #expect(sut.aktiveSession() == nil)

        let geschrieben = sut.satzSichern(machineId: "m1", exerciseId: "e1",
                                          weightKg: 80, reps: 10, rir: nil,
                                          problemFlag: false, problemReason: nil,
                                          jetzt: start)

        #expect(sut.aktiveSession()?.id == geschrieben.sessionId)
        #expect(geschrieben.body.setIndex == 1)
    }

    @Test func setIndexLaeuftInnerhalbDesBlocks() {
        let (sut, _) = store()
        _ = sut.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 80, reps: 10,
                            rir: nil, problemFlag: false, problemReason: nil, jetzt: start)
        // Anderes Geraet dazwischen -- Zirkeltraining.
        _ = sut.satzSichern(machineId: "m2", exerciseId: "e2", weightKg: 45, reps: 12,
                            rir: nil, problemFlag: false, problemReason: nil,
                            jetzt: start.addingTimeInterval(120))
        let dritter = sut.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 80, reps: 9,
                                      rir: nil, problemFlag: false, problemReason: nil,
                                      jetzt: start.addingTimeInterval(240))

        // Zweiter Satz IM BLOCK, nicht dritter Satz der Session.
        #expect(dritter.body.setIndex == 2)
        #expect(sut.aktiveSession()?.bloecke.count == 2)
    }

    @Test func dieselbeSessionInnerhalbVonVierStunden() {
        let (sut, _) = store()
        let erster = sut.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 80, reps: 10,
                                     rir: nil, problemFlag: false, problemReason: nil, jetzt: start)
        let zweiter = sut.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 80, reps: 10,
                                      rir: nil, problemFlag: false, problemReason: nil,
                                      jetzt: start.addingTimeInterval(3 * 3600))

        #expect(erster.sessionId == zweiter.sessionId)
    }

    @Test func neueSessionNachVierStundenOhneSatz() {
        let (sut, _) = store()
        let erster = sut.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 80, reps: 10,
                                     rir: nil, problemFlag: false, problemReason: nil, jetzt: start)
        let zweiter = sut.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 80, reps: 10,
                                      rir: nil, problemFlag: false, problemReason: nil,
                                      jetzt: start.addingTimeInterval(4 * 3600 + 1))

        // recordSet prueft serverseitig nicht, ob die Session schon
        // auto-beendet ist -- der Client muss die Grenze selbst ziehen.
        #expect(erster.sessionId != zweiter.sessionId)
        #expect(zweiter.body.setIndex == 1)
    }

    @Test func abgelaufeneSessionGiltNichtMehrAlsAktiv() {
        let (sut, _) = store()
        _ = sut.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 80, reps: 10,
                            rir: nil, problemFlag: false, problemReason: nil, jetzt: start)

        #expect(sut.aktiveSession(jetzt: start.addingTimeInterval(3 * 3600)) != nil)
        #expect(sut.aktiveSession(jetzt: start.addingTimeInterval(4 * 3600 + 1)) == nil)
    }

    @Test func ueberlebtEinenProzessNeustart() {
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let ersterLauf = WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))
        let geschrieben = ersterLauf.satzSichern(machineId: "m1", exerciseId: "e1",
                                                 weightKg: 80, reps: 10, rir: nil,
                                                 problemFlag: false, problemReason: nil, jetzt: start)

        let zweiterLauf = WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))

        #expect(zweiterLauf.aktiveSession()?.id == geschrieben.sessionId)
        #expect(zweiterLauf.naechsterSetIndex(machineId: "m1", exerciseId: "e1",
                                              jetzt: start.addingTimeInterval(60)) == 2)
    }

    @Test func beendenLoeschtDieSessionUndGibtIhreKennungZurueck() {
        let (sut, _) = store()
        let geschrieben = sut.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 80, reps: 10,
                                          rir: nil, problemFlag: false, problemReason: nil, jetzt: start)

        #expect(sut.beenden() == geschrieben.sessionId)
        #expect(sut.aktiveSession() == nil)
        #expect(sut.beenden() == nil)
    }

    @Test func dieProblemmeldungLandetImSatzRumpf() {
        let (sut, _) = store()
        let geschrieben = sut.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 80, reps: 10,
                                          rir: 2, problemFlag: true, problemReason: .zuSchwer,
                                          jetzt: start)

        // Die Meldung braucht keinen eigenen Endpoint (M1-Spec SS6.3).
        #expect(geschrieben.body.problemFlag)
        #expect(geschrieben.body.problemReason == .zuSchwer)
        #expect(geschrieben.body.rir == 2)
    }
}
```

- [ ] **Step 2: Tests laufen lassen, Fehlschlag bestätigen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/WorkoutSessionStoreTests 2>&1 | tail -20
```

Erwartet: FAIL — `WorkoutSessionStore` ist unbekannt.

- [ ] **Step 3: Die Datentypen anlegen**

Create `apps/ios-member/FitnessMember/Workout/LokaleSession.swift`:

```swift
import Foundation

/// Ein bestaetigter Satz, wie ihn der Client kennt -- vor oder nach dem
/// erfolgreichen PUT. Die id ist die setId aus M1-Spec SS6.3: clientseitig
/// erzeugt, damit derselbe PUT zweimal gesendet denselben Satz ergibt.
struct LokalerSatz: Codable, Equatable, Identifiable {
    let id: UUID
    var setIndex: Int
    var weightKg: Double
    var reps: Int
    var rir: Double?
    var problemFlag: Bool
    var problemReason: ProblemReason?
    var performedAt: Date
}

/// Ein Geraet plus eine Uebung, mit seinen Saetzen (M1-Spec SS5.3).
struct LokalerBlock: Codable, Equatable, Identifiable {
    var id: String { "\(machineId):\(exerciseId)" }
    let machineId: String
    let exerciseId: String
    var saetze: [LokalerSatz]
}

/// Die laufende Einheit. Entsteht implizit beim ersten Satz -- es gibt
/// keinen Startknopf (M1-Spec SS5.6).
struct LokaleSession: Codable, Equatable {
    let id: UUID
    let startedAt: Date
    var bloecke: [LokalerBlock]

    var letzterSatzAm: Date? {
        bloecke.flatMap(\.saetze).map(\.performedAt).max()
    }
}
```

- [ ] **Step 4: Die Persistenz anlegen**

Create `apps/ios-member/FitnessMember/Workout/SessionFileStore.swift`:

```swift
import Foundation

/// Die laufende Einheit auf Platte -- wie PendingWriteStore, aus demselben
/// Grund: nach einem App-Kill muss "Satz 3" noch Satz 3 heissen und der
/// Training-Tab seine Bloecke zeigen.
///
/// App-Support statt Keychain: das sind Trainingsdaten, keine Zugangsdaten.
final class SessionFileStore {
    private let fileURL: URL

    init(directory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("laufende-session.json")
    }

    func load() -> LokaleSession? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(LokaleSession.self, from: data)
    }

    func save(_ session: LokaleSession?) {
        guard let session else {
            try? FileManager.default.removeItem(at: fileURL)
            return
        }
        guard let data = try? JSONEncoder().encode(session) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
```

- [ ] **Step 5: Den Store anlegen**

Create `apps/ios-member/FitnessMember/Workout/WorkoutSessionStore.swift`:

```swift
import Foundation
import Observation

@MainActor
@Observable
final class WorkoutSessionStore {
    /// Eine Session ohne neuen Satz seit vier Stunden gilt als beendet
    /// (M1-Spec SS5.2).
    ///
    /// Die Regel gilt bewusst auf BEIDEN Seiten: recordSet upsertet die
    /// Session mit ignoreDuplicates und prueft nicht, ob sie serverseitig
    /// schon auto-beendet ist. Ein Client, der eine fuenf Stunden alte
    /// sessionId weiterbenutzt, haengt Saetze an eine Einheit, die der
    /// Server laengst als abgeschlossen liest.
    static let sessionPause: TimeInterval = 4 * 60 * 60

    private(set) var gespeicherteSession: LokaleSession?
    private let fileStore: SessionFileStore

    init(fileStore: SessionFileStore = SessionFileStore()) {
        self.fileStore = fileStore
        gespeicherteSession = fileStore.load()
    }

    /// Die Session, sofern sie noch laeuft. Ohne Argument gegen die aktuelle
    /// Uhr -- fuer Views; mit Argument fuer Tests.
    ///
    /// Bewusst EINE Methode mit Vorgabewert statt Eigenschaft plus Methode:
    /// derselbe Name in beiden Formen waere in Swift eine ungueltige
    /// Neudeklaration.
    func aktiveSession(jetzt: Date = Date()) -> LokaleSession? {
        guard let session = gespeicherteSession else { return nil }
        let letzte = session.letzterSatzAm ?? session.startedAt
        return jetzt.timeIntervalSince(letzte) > Self.sessionPause ? nil : session
    }

    func naechsterSetIndex(machineId: String, exerciseId: String, jetzt: Date = Date()) -> Int {
        let block = aktiveSession(jetzt: jetzt)?.bloecke
            .first { $0.machineId == machineId && $0.exerciseId == exerciseId }
        return (block?.saetze.count ?? 0) + 1
    }

    func satzSichern(
        machineId: String,
        exerciseId: String,
        weightKg: Double,
        reps: Int,
        rir: Double?,
        problemFlag: Bool,
        problemReason: ProblemReason?,
        jetzt: Date = Date()
    ) -> (sessionId: UUID, setId: UUID, body: SetWrite) {
        var session = aktiveSession(jetzt: jetzt)
            ?? LokaleSession(id: UUID(), startedAt: jetzt, bloecke: [])

        let index = session.bloecke.firstIndex {
            $0.machineId == machineId && $0.exerciseId == exerciseId
        }
        let setIndex = (index.map { session.bloecke[$0].saetze.count } ?? 0) + 1

        let satz = LokalerSatz(
            id: UUID(), setIndex: setIndex, weightKg: weightKg, reps: reps,
            rir: rir, problemFlag: problemFlag, problemReason: problemReason,
            performedAt: jetzt
        )

        if let index {
            session.bloecke[index].saetze.append(satz)
        } else {
            session.bloecke.append(
                LokalerBlock(machineId: machineId, exerciseId: exerciseId, saetze: [satz])
            )
        }

        gespeicherteSession = session
        fileStore.save(session)

        let body = SetWrite(
            machineId: machineId, exerciseId: exerciseId, setIndex: setIndex,
            weightKg: weightKg, reps: reps, rir: rir,
            problemFlag: problemFlag, problemReason: problemReason,
            performedAt: ISO8601DateFormatter().string(from: jetzt)
        )
        return (session.id, satz.id, body)
    }

    /// Gibt die Kennung zurueck, damit der Aufrufer
    /// POST .../complete schicken kann.
    @discardableResult
    func beenden() -> UUID? {
        let id = gespeicherteSession?.id
        gespeicherteSession = nil
        fileStore.save(nil)
        return id
    }

    /// Nach dem Abmelden faellt die laufende Einheit -- ihre Kennungen
    /// gehoeren zum abgemeldeten Konto.
    func reset() { beenden() }
}
```

- [ ] **Step 6: Tests laufen lassen, Erfolg bestätigen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/WorkoutSessionStoreTests 2>&1 | tail -30
```

Erwartet: PASS, 8 Tests.

- [ ] **Step 7: Commit**

```bash
git add apps/ios-member/FitnessMember/Workout apps/ios-member/FitnessMemberTests/WorkoutSessionStoreTests.swift
git commit -m "feat(ios): WorkoutSessionStore -- laufende Einheit auf Platte

Die Session entsteht implizit beim ersten Satz (M1-Spec SS5.6). Sie liegt
auf Platte, weil nach einem App-Kill 'Satz 3' noch Satz 3 heissen muss.

setIndex laeuft innerhalb des Blocks, nicht innerhalb der Session -- so
verlangt es workout_sets_unique_index_per_block aus Migration 0013, und so
traegt Zirkeltraining ohne Sonderlogik.

Die Vier-Stunden-Regel gilt auf beiden Seiten: recordSet upsertet die
Session mit ignoreDuplicates und prueft nicht, ob sie serverseitig schon
auto-beendet ist."
```

---

### Aufgabe 6: Geräteauflösung aus dem Prefetch und die Einstiegsentscheidung

M1-Spec §8.1 Schritt 3 löst das Empfangsproblem: Die App hasht den Token selbst und findet das Gerät lokal, bevor das Netz antwortet. Und `designsystem.md` §8 entscheidet aus der eigenen Historie, wo das Mitglied landet.

**Files:**
- Create: `apps/ios-member/FitnessMember/Workout/MachineResolver.swift`
- Create: `apps/ios-member/FitnessMember/Workout/GeraetEinstieg.swift`
- Create: `apps/ios-member/FitnessMemberTests/GeraetEinstiegTests.swift`

**Interfaces:**
- Consumes: `BootstrapResponse` inkl. `Machine.visitCount` (Aufgabe 1).
- Produces: `enum MachineResolver { static func hash(token: String) -> String; static func maschine(fuerToken: String, in: BootstrapResponse) -> BootstrapResponse.Machine? }` — von Aufgabe 15 konsumiert.
- Produces: `enum GeraetEinstieg: Equatable { case erkannt, direktZumSatz }`
- Produces: `enum GeraetEinstiegRechner { static func einstieg(visitCount: Int, genutzteUebungen: Int) -> GeraetEinstieg; static func istErstkontakt(hatKalibrierung: Bool, hatLetztenSatz: Bool) -> Bool; static func genutzteUebungen(machineId: String, in: BootstrapResponse) -> Int }` — von Aufgabe 9 und 15 konsumiert.

- [ ] **Step 1: Die Tests schreiben**

Create `apps/ios-member/FitnessMemberTests/GeraetEinstiegTests.swift`:

```swift
import Foundation
import Testing
@testable import FitnessMember

struct MachineResolverTests {
    @Test func hashtWieDerServer() {
        // packages/domain/src/tags.ts: sha256 des UTF-8-Tokens, Hex,
        // Kleinbuchstaben. Referenzwert: echo -n "abc" | shasum -a 256
        #expect(MachineResolver.hash(token: "abc")
                == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @Test func findetDasGeraetImPrefetch() {
        let treffer = MachineResolver.maschine(
            fuerToken: "abc",
            in: bootstrapMitTokenHash("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        )
        #expect(treffer?.id == "m1")
    }

    @Test func findetNichtsBeiUnbekanntemToken() {
        #expect(MachineResolver.maschine(fuerToken: "xyz",
                                         in: bootstrapMitTokenHash("deadbeef")) == nil)
    }
}

struct GeraetEinstiegTests {
    // designsystem.md SS8, Zeile fuer Zeile.

    @Test func ohneBesuchKommtDerErkennungsScreen() {
        // "0 -- Erstkontakt: Geraet erkannt -> Einweisung -> ..."
        #expect(GeraetEinstiegRechner.einstieg(visitCount: 0, genutzteUebungen: 0) == .erkannt)
    }

    @Test func nachGenauEinemBesuchBleibenDieOptionenSichtbar() {
        #expect(GeraetEinstiegRechner.einstieg(visitCount: 1, genutzteUebungen: 1) == .erkannt)
    }

    @Test func abZweiBesuchenMitMehrerenUebungenBleibtDieListe() {
        #expect(GeraetEinstiegRechner.einstieg(visitCount: 2, genutzteUebungen: 2) == .erkannt)
    }

    @Test func abZweiBesuchenMitImmerDerselbenUebungGehtEsDirektZumSatz() {
        #expect(GeraetEinstiegRechner.einstieg(visitCount: 2, genutzteUebungen: 1) == .direktZumSatz)
        #expect(GeraetEinstiegRechner.einstieg(visitCount: 9, genutzteUebungen: 1) == .direktZumSatz)
    }

    @Test func erstkontaktBrauchtWederKalibrierungNochSatz() {
        #expect(GeraetEinstiegRechner.istErstkontakt(hatKalibrierung: false, hatLetztenSatz: false))
        #expect(!GeraetEinstiegRechner.istErstkontakt(hatKalibrierung: true, hatLetztenSatz: false))
        #expect(!GeraetEinstiegRechner.istErstkontakt(hatKalibrierung: false, hatLetztenSatz: true))
    }

    @Test func alteSaetzeAusserhalbDesScanFenstersLoesenKeinenDreischrittAus() {
        // visitCount kann 0 lesen, wenn die Saetze aus dem 2000er-Fenster
        // von getBootstrap gefallen sind. Die Kalibrierung faengt das ab --
        // sie wird ungedeckelt gelesen.
        #expect(!GeraetEinstiegRechner.istErstkontakt(hatKalibrierung: true, hatLetztenSatz: false))
    }

    @Test func zaehltGenutzteUebungenAusDenLetztenSaetzen() {
        let bootstrap = bootstrapMitLetztenSaetzen([("m1", "e1"), ("m1", "e2"), ("m2", "e1")])
        #expect(GeraetEinstiegRechner.genutzteUebungen(machineId: "m1", in: bootstrap) == 2)
        #expect(GeraetEinstiegRechner.genutzteUebungen(machineId: "m3", in: bootstrap) == 0)
    }
}

// MARK: - Testdaten

private func bootstrapMitTokenHash(_ hash: String) -> BootstrapResponse {
    BootstrapResponse(
        studios: [],
        machines: [maschine(id: "m1", tokenHashes: [hash])],
        calibrations: [],
        lastSets: []
    )
}

private func bootstrapMitLetztenSaetzen(_ paare: [(String, String)]) -> BootstrapResponse {
    BootstrapResponse(
        studios: [],
        machines: [maschine(id: "m1", tokenHashes: [])],
        calibrations: [],
        lastSets: paare.map { paar in
            BootstrapResponse.LastSet(machineId: paar.0, exerciseId: paar.1,
                                      weightKg: 80, reps: 10, rir: nil,
                                      performedAt: "2026-09-01T10:00:00Z")
        }
    )
}

private func maschine(id: String, tokenHashes: [String]) -> BootstrapResponse.Machine {
    BootstrapResponse.Machine(
        id: id, studioId: "s1", label: "Gerät 7", locationNote: nil,
        status: "active", tokenHashes: tokenHashes, visitCount: 0,
        equipmentModel: BootstrapResponse.EquipmentModel(
            id: "em1", name: "Beinpresse", manufacturer: nil, photoPath: nil,
            weightStepKg: 2.5, minWeightKg: 5, maxWeightKg: 150,
            settingDefinitions: []
        ),
        exercises: []
    )
}
```

**Hinweis:** Die DTO-Strukturen aus Sub-Projekt 1 haben keine expliziten Initialisierer, weil sie nur `Decodable` sind. Prüfe `BootstrapResponse.swift`: Wenn der memberweise Initialisierer wegen `Decodable`-Synthese nicht sichtbar ist, ergänze in derselben Datei `extension BootstrapResponse { init(studios:machines:calibrations:lastSets:) }` — oder einfacher: baue die Testdaten über `JSONDecoder` aus einem JSON-Literal, wie es `DTOTests.swift` bereits tut. Wähle den Weg, der zur Datei passt, und halte ihn in allen Testdateien gleich.

- [ ] **Step 2: Tests laufen lassen, Fehlschlag bestätigen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/GeraetEinstiegTests 2>&1 | tail -20
```

Erwartet: FAIL — `MachineResolver` und `GeraetEinstiegRechner` sind unbekannt.

- [ ] **Step 3: `MachineResolver` implementieren**

Create `apps/ios-member/FitnessMember/Workout/MachineResolver.swift`:

```swift
import CryptoKit
import Foundation

/// Token -> Geraet, lokal aus dem Prefetch.
///
/// M1-Spec SS8.1 Schritt 3: Der Prefetch enthaelt je Geraet den token_hash,
/// die App hat den Token aus der URL und hasht ihn selbst. Dadurch rendert
/// der Screen sofort, auch ohne Empfang.
///
/// Unbedenklich, weil Tag-Tokens oeffentliche Locator sind und Hashes keine
/// Tokens verraten. Der Token selbst wird nie gespeichert und nie
/// protokolliert (M1-Spec SS10.4/SS10.6).
enum MachineResolver {
    /// Muss byteweise zu packages/domain/src/tags.ts hashTagToken passen:
    /// sha256 ueber die UTF-8-Bytes, Hex in Kleinbuchstaben.
    static func hash(token: String) -> String {
        SHA256.hash(data: Data(token.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    static func maschine(
        fuerToken token: String,
        in bootstrap: BootstrapResponse
    ) -> BootstrapResponse.Machine? {
        let gesucht = hash(token: token)
        return bootstrap.machines.first { $0.tokenHashes.contains(gesucht) }
    }
}
```

- [ ] **Step 4: `GeraetEinstieg` implementieren**

Create `apps/ios-member/FitnessMember/Workout/GeraetEinstieg.swift`:

```swift
import Foundation

/// Wo das Mitglied nach dem Tap landet.
enum GeraetEinstieg: Equatable {
    /// GeraetErkannt -- die Uebungsliste bleibt sichtbar.
    case erkannt
    /// Direkt auf den Geraete-Screen, ohne Zwischenschritt.
    case direktZumSatz
}

/// Die Tabelle aus designsystem.md SS8, als reine Funktionen.
///
/// Sie faellt bewusst aus dem Prefetch und nicht aus tagContext: M1-Spec
/// SS8.1 Schritt 3 verlangt, dass der Screen sofort rendert, bevor das Netz
/// antwortet.
enum GeraetEinstiegRechner {
    static func einstieg(visitCount: Int, genutzteUebungen: Int) -> GeraetEinstieg {
        // Ab dem dritten Besuch an einem Geraet, an dem immer dieselbe
        // Uebung lief, wird der Zwischenschritt uebersprungen. Wer erst
        // einmal hier war, sieht weiterhin, was es sonst noch gaebe.
        visitCount >= 2 && genutzteUebungen <= 1 ? .direktZumSatz : .erkannt
    }

    /// Erstkontakt gilt je (Geraet, Uebung) -- der Dreischritt laeuft genau
    /// einmal je Paar (designsystem.md SS8).
    static func istErstkontakt(hatKalibrierung: Bool, hatLetztenSatz: Bool) -> Bool {
        !hatKalibrierung && !hatLetztenSatz
    }

    static func genutzteUebungen(machineId: String, in bootstrap: BootstrapResponse) -> Int {
        Set(bootstrap.lastSets.filter { $0.machineId == machineId }.map(\.exerciseId)).count
    }

    static func hatKalibrierung(machineId: String, exerciseId: String, in bootstrap: BootstrapResponse) -> Bool {
        bootstrap.calibrations.contains { $0.machineId == machineId && $0.exerciseId == exerciseId }
    }

    static func hatLetztenSatz(machineId: String, exerciseId: String, in bootstrap: BootstrapResponse) -> Bool {
        bootstrap.lastSets.contains { $0.machineId == machineId && $0.exerciseId == exerciseId }
    }
}
```

- [ ] **Step 5: Tests laufen lassen, Erfolg bestätigen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/GeraetEinstiegTests 2>&1 | tail -30
```

Erwartet: PASS.

- [ ] **Step 6: Commit**

```bash
git add apps/ios-member/FitnessMember/Workout apps/ios-member/FitnessMemberTests/GeraetEinstiegTests.swift
git commit -m "feat(ios): Geraeteaufloesung aus dem Prefetch und Einstiegsentscheidung

MachineResolver hasht den Token lokal und findet das Geraet im Prefetch --
der Screen rendert damit sofort, auch ohne Empfang (M1-Spec SS8.1
Schritt 3). Der Hash passt byteweise zu hashTagToken aus packages/domain.

GeraetEinstiegRechner bildet die Tabelle aus designsystem.md SS8 als reine
Funktionen ab. Sie weicht bewusst von M1-Spec SS5.7 ab: dort entscheidet der
Katalog des Studios, hier die Gewohnheit des Mitglieds."
```

---

### Aufgabe 7: `Rastwerte` und die Rad-Komponente

Das Herzstück. `designsystem.md` §7: ein Tap auf eine der beiden Zahlen öffnet **beide** Räder, danach wird nur noch gescrollt.

**Der tragende Kniff:** Die Akzentlinie gehört **nicht** zur scrollenden Zeile. Sie liegt statisch im `ZStack` hinter dem Scroller auf Höhe der Mittelzeile — „die Linie bleibt liegen, die Zahlen ziehen daran vorbei". Damit sind Ruhe und Offen dieselbe View.

**Files:**
- Create: `apps/ios-member/FitnessMember/Workout/Rastwerte.swift`
- Create: `apps/ios-member/FitnessMember/DesignSystem/Components/RastRad.swift`
- Create: `apps/ios-member/FitnessMemberTests/RastwerteTests.swift`

**Interfaces:**
- Consumes: `Zahlformat`, `DesignSystem.Motion`, `DesignSystem.Typography.radNah/.radFern` (Aufgabe 3).
- Produces: `enum Rastwerte { static let maxRastenOhneObergrenze: Int; static func gewichte(min: Double, max: Double?, schritt: Double) -> [Double]; static let wiederholungen: [Int] }` — von Aufgabe 10, 12 konsumiert.
- Produces: `enum UnterstrichStil { case akzent, linie }`
- Produces: `struct RastRad: View` mit den Parametern `werte: [Double]`, `auswahl: Binding<Double>`, `offen: Bool`, `unterstrich: UnterstrichStil`, `voLabel: String`, `voWert: (Double) -> String`, `anschlagText: String?` — von Aufgabe 10 und 12 konsumiert.

- [ ] **Step 1: Den Test für die Wertelisten schreiben**

Create `apps/ios-member/FitnessMemberTests/RastwerteTests.swift`:

```swift
import Testing
@testable import FitnessMember

struct RastwerteTests {
    @Test func rastetAufDieSchrittweiteDesGeraets() {
        // designsystem.md SS7: die Rastung kommt aus dem Geraet, nicht aus
        // dem Entwurf. Ein Wert, den das Geraet nicht kann, wird damit
        // strukturell unmoeglich.
        let werte = Rastwerte.gewichte(min: 5, max: 15, schritt: 2.5)
        #expect(werte == [5.0, 7.5, 10.0, 12.5, 15.0])
    }

    @Test func andereSchrittweiteAnderesRad() {
        let werte = Rastwerte.gewichte(min: 10, max: 30, schritt: 5)
        #expect(werte == [10.0, 15.0, 20.0, 25.0, 30.0])
    }

    @Test func schliesstDasMaximumEinAuchWennEsNichtAufDerRasterFaellt() {
        let werte = Rastwerte.gewichte(min: 5, max: 11, schritt: 2.5)
        #expect(werte.last == 10.0)
        #expect(werte.allSatisfy { $0 <= 11 })
    }

    @Test func ohneObergrenzeEndetDasRadNachZweihundertRasten() {
        // maxWeightKg ist nullable. Der Server rechnet dort mit 9999 --
        // als Radlaenge waere das absurd.
        let werte = Rastwerte.gewichte(min: 5, max: nil, schritt: 2.5)
        #expect(werte.count == Rastwerte.maxRastenOhneObergrenze + 1)
        #expect(werte.first == 5.0)
    }

    @Test func schuetztVorEinerUnbrauchbarenSchrittweite() {
        #expect(Rastwerte.gewichte(min: 5, max: 100, schritt: 0) == [5.0])
        #expect(Rastwerte.gewichte(min: 5, max: 100, schritt: -1) == [5.0])
    }

    @Test func wiederholungenRastenAufEins() {
        #expect(Rastwerte.wiederholungen.first == 1)
        #expect(Rastwerte.wiederholungen.last == 40)
        #expect(Rastwerte.wiederholungen.count == 40)
    }

    @Test func naechsterWertRastetAufDieListe() {
        let werte = Rastwerte.gewichte(min: 5, max: 100, schritt: 2.5)
        #expect(Rastwerte.naechster(zu: 81.2, in: werte) == 80.0)
        #expect(Rastwerte.naechster(zu: 1.0, in: werte) == 5.0)
        #expect(Rastwerte.naechster(zu: 999, in: werte) == 100.0)
    }
}
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag bestätigen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/RastwerteTests 2>&1 | tail -20
```

Erwartet: FAIL — `Rastwerte` ist unbekannt.

- [ ] **Step 3: `Rastwerte` implementieren**

Create `apps/ios-member/FitnessMember/Workout/Rastwerte.swift`:

```swift
import Foundation

/// Die Wertelisten der beiden Raeder.
///
/// designsystem.md SS7: "Die Rastung kommt aus dem Geraet, nicht aus dem
/// Entwurf." Dieselbe Daumenstrecke deckt an einer Beinpresse mit
/// 2,5-kg-Platten eine andere Spanne ab als an einem Beinbeuger mit
/// 5-kg-Platten. Weil die Liste aus dem Modell entsteht, ist ein Wert, den
/// das Geraet gar nicht kann, strukturell unmoeglich.
enum Rastwerte {
    /// Obergrenze fuer Geraete ohne max_weight_kg. Der Server rechnet dort
    /// mit 9999 -- als Radlaenge waere das absurd, und ein Anschlag, den
    /// niemand dokumentiert hat, braucht auch kein Anschlagsfeedback.
    static let maxRastenOhneObergrenze = 200

    /// Wiederholungen rasten immer auf 1. Die Datenbank liesse 1000 zu; ein
    /// Rad ist kein Formularfeld, und 1-40 deckt jedes reale Kraft- und
    /// Ausdauerschema ab.
    static let wiederholungen: [Int] = Array(1...40)

    static func gewichte(min: Double, max: Double?, schritt: Double) -> [Double] {
        guard schritt > 0 else { return [min] }
        let obergrenze = max ?? (min + Double(maxRastenOhneObergrenze) * schritt)
        guard obergrenze > min else { return [min] }

        let rasten = Int(((obergrenze - min) / schritt).rounded(.down))
        return (0...rasten).map { min + Double($0) * schritt }
    }

    /// Rastet einen beliebigen Wert -- etwa einen Serververschlag -- auf die
    /// Liste. Ohne das koennte ein Vorschlag neben der Rasterung liegen und
    /// das Rad haette keinen Startpunkt.
    static func naechster(zu wert: Double, in werte: [Double]) -> Double {
        guard let erster = werte.first else { return wert }
        return werte.min { abs($0 - wert) < abs($1 - wert) } ?? erster
    }
}
```

- [ ] **Step 4: Test laufen lassen, Erfolg bestätigen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/RastwerteTests 2>&1 | tail -20
```

Erwartet: PASS, 7 Tests.

- [ ] **Step 5: `RastRad` implementieren**

Create `apps/ios-member/FitnessMember/DesignSystem/Components/RastRad.swift`:

```swift
import SwiftUI

enum UnterstrichStil {
    case akzent   // Gewicht: 4pt accent
    case linie    // Wiederholungen: 3pt line
}

/// Ein Wertrad. Ruhe und Offen sind derselbe Aufbau.
///
/// Der Kniff aus designsystem.md SS7: "die Linie bleibt liegen, die Zahlen
/// ziehen daran vorbei." Die Unterstreichung gehoert deshalb NICHT zur
/// scrollenden Zeile -- sie liegt statisch hinter dem Scroller auf Hoehe der
/// Mittelzeile. Dadurch hat der Screen in beiden Zustaenden dieselbe
/// Silhouette und der Uebergang ist eine Bewegung statt eines Aufbaus.
///
/// Momentum, Deceleration, Rubber-Banding und Unterbrechbarkeit kommen vom
/// System-Scroller. Das sind genau die vier Dinge, die eine handgeschriebene
/// DragGesture als erstes falsch macht -- bei der laut SS9 am haeufigsten
/// ausgeloesten Geste der App das groesste vermeidbare Risiko.
struct RastRad: View {
    let werte: [Double]
    @Binding var auswahl: Double
    let offen: Bool
    let unterstrich: UnterstrichStil
    /// VoiceOver: "Gewicht" bzw. "Wiederholungen".
    let voLabel: String
    /// VoiceOver: der Wert als EINE Zeichenkette, inklusive Einheit.
    let voWert: (Double) -> String
    /// Wird an den VoiceOver-Wert angehaengt, wenn die Auswahl am Ende
    /// klebt. `nil` bei Geraeten ohne dokumentierte Obergrenze.
    let anschlagText: String?
    /// Formatiert die Zahl auf der Zeile.
    let text: (Double) -> String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var zeilenhoehe: CGFloat = 44
    @State private var scrollPosition: Double?
    @State private var anschlagStoss = 0

    private var amAnschlag: Bool {
        guard anschlagText != nil else { return false }
        return auswahl == werte.first || auswahl == werte.last
    }

    /// Fuenf Zeilen: der gewaehlte Wert plus zwei Nachbarn je Richtung.
    private var radhoehe: CGFloat { zeilenhoehe * 5 }

    var body: some View {
        ZStack {
            unterstreichung
            scroller
        }
        .frame(height: offen ? radhoehe : zeilenhoehe * 1.6)
        .animation(reduceMotion ? nil : DesignSystem.Motion.oeffnen, value: offen)
        .sensoryFeedback(.selection, trigger: auswahl)
        .sensoryFeedback(.impact(weight: .light), trigger: anschlagStoss)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(voLabel)
        .accessibilityValue(voWertMitAnschlag)
        .accessibilityAdjustableAction { richtung in
            switch richtung {
            case .increment: schiebe(um: 1)
            case .decrement: schiebe(um: -1)
            @unknown default: break
            }
        }
    }

    // MARK: - Bestandteile

    /// Liegt fest. Bewegt sich nie -- das ist der ganze Punkt.
    private var unterstreichung: some View {
        VStack(spacing: 0) {
            Spacer()
            Rectangle()
                .fill(unterstrich == .akzent ? DesignSystem.Color.accent : DesignSystem.Color.line)
                .frame(height: unterstrich == .akzent ? 4 : 3)
            Spacer()
        }
        .frame(height: zeilenhoehe * 1.6)
    }

    private var scroller: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(werte, id: \.self) { wert in
                    Text(text(wert))
                        .frame(height: zeilenhoehe)
                        .frame(maxWidth: .infinity)
                        .scrollTransition(.interactive, axis: .vertical) { inhalt, phase in
                            inhalt
                                .font(schrift(fuer: phase.value))
                                .foregroundStyle(farbe(fuer: phase.value))
                                .opacity(deckkraft(fuer: phase.value))
                        }
                }
            }
            .scrollTargetLayout()
        }
        .scrollDisabled(!offen)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $scrollPosition, anchor: .center)
        // Damit Minimum und Maximum mittig einrasten koennen.
        .safeAreaPadding(.vertical, (radhoehe - zeilenhoehe) / 2)
        // Ausblendung nach bg, wie SS7 sie verlangt.
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.32),
                    .init(color: .black, location: 0.68),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .top, endPoint: .bottom
            )
        )
        .onAppear { scrollPosition = auswahl }
        .onChange(of: scrollPosition) { _, neu in
            guard let neu, neu != auswahl else { return }
            auswahl = neu
        }
        .onChange(of: auswahl) { _, neu in
            if scrollPosition != neu { scrollPosition = neu }
        }
    }

    // MARK: - Nachbar-Optik (designsystem.md SS7)

    /// phase.value ist 0 in der Mitte und waechst betragsmaessig nach aussen.
    private func schrift(fuer phase: Double) -> Font {
        switch abs(phase) {
        case ..<0.5: DesignSystem.Typography.wertHeld
        case ..<1.5: DesignSystem.Typography.radNah
        default: DesignSystem.Typography.radFern
        }
    }

    private func farbe(fuer phase: Double) -> Color {
        switch abs(phase) {
        case ..<0.5: DesignSystem.Color.text
        case ..<1.5: DesignSystem.Color.textFaint
        default: DesignSystem.Color.line
        }
    }

    private func deckkraft(fuer phase: Double) -> Double {
        switch abs(phase) {
        case ..<0.5: 1.0
        case ..<1.5: offen ? 0.55 : 0
        default: offen ? 0.25 : 0
        }
    }

    // MARK: - VoiceOver

    private var voWertMitAnschlag: String {
        guard amAnschlag, let anschlagText else { return voWert(auswahl) }
        return "\(voWert(auswahl)), \(anschlagText)"
    }

    /// Auf und Ab gehen genau einen Geraeteschritt (designsystem.md SS12).
    private func schiebe(um schritte: Int) {
        guard let index = werte.firstIndex(of: auswahl) else { return }
        let ziel = index + schritte
        guard werte.indices.contains(ziel) else {
            anschlagStoss += 1
            return
        }
        auswahl = werte[ziel]
    }
}
```

- [ ] **Step 6: Eine Preview anhängen und in der Canvas prüfen**

Ans Ende von `RastRad.swift`:

```swift
#Preview {
    struct Vorschau: View {
        @State private var gewicht = 80.0
        @State private var offen = true

        var body: some View {
            VStack(spacing: DesignSystem.Spacing.32) {
                RastRad(
                    werte: Rastwerte.gewichte(min: 5, max: 150, schritt: 2.5),
                    auswahl: $gewicht,
                    offen: offen,
                    unterstrich: .akzent,
                    voLabel: "Gewicht",
                    voWert: Zahlformat.gewichtGesprochen,
                    anschlagText: "Maximum des Geräts erreicht",
                    text: Zahlformat.gewicht
                )
                Button(offen ? "Schließen" : "Öffnen") { offen.toggle() }
                    .foregroundStyle(DesignSystem.Color.accent)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesignSystem.Color.bg)
        }
    }
    return Vorschau()
}
```

**Achtung:** `DesignSystem.Spacing` heißt `s32`, nicht `32` — passe den Aufruf an die tatsächlichen Namen in `DesignSystem.swift` an (`s4`, `s8`, `s12`, `s16`, `s24`, `s32`, `s48`).

- [ ] **Step 7: Bauen und in der Canvas prüfen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" build 2>&1 | tail -20
```

Erwartet: BUILD SUCCEEDED.

Dann die Preview öffnen und prüfen:
1. Der gewählte Wert steht 64 pt in `text`, die Akzentlinie liegt darunter und **bewegt sich beim Scrollen nicht**.
2. Zwei Nachbarn je Richtung, 30 pt in `text-faint` und 26 pt in `line`, nach oben und unten ausgeblendet.
3. „Schließen" lässt die Nachbarn verschwinden — die Silhouette des gewählten Werts bleibt identisch.
4. Am Minimum (5,0) und Maximum (150,0) federt das Rad zurück statt hart zu stoppen.
5. VoiceOver-Rotor auf „Anpassen": Auf/Ab geht genau 2,5 kg, angesagt wird „82,5 Kilogramm"; am Maximum wird „Maximum des Geräts erreicht" angehängt.

- [ ] **Step 8: Commit**

```bash
git add apps/ios-member/FitnessMember/Workout/Rastwerte.swift \
        apps/ios-member/FitnessMember/DesignSystem/Components/RastRad.swift \
        apps/ios-member/FitnessMemberTests/RastwerteTests.swift
git commit -m "feat(ios): RastRad -- das Wertrad

Der Kniff aus designsystem.md SS7: die Linie bleibt liegen, die Zahlen
ziehen daran vorbei. Die Unterstreichung gehoert deshalb nicht zur
scrollenden Zeile, sondern liegt statisch dahinter -- dadurch sind Ruhe und
Offen derselbe Aufbau, und GeraetWertRad ist kein zweiter Screen.

Momentum, Deceleration, Rubber-Banding und Unterbrechbarkeit kommen vom
System-Scroller statt aus eigener Physik. Die Werteliste entsteht aus
weight_step_kg des Geraetemodells: ein Wert, den das Geraet nicht kann, ist
damit strukturell unmoeglich."
```

---

### Aufgabe 8: Netzwerkfassade fürs Gerät — `tagContext`, `recordCalibration`, `completeSession`

`APIClient` hat `tagContext` und `completeSession` seit Sub-Projekt 1, sie wurden nur nie aufgerufen. `recordCalibration` kommt jetzt dazu. Damit die Screens testbar bleiben, bekommt das Gerät seine eigene schmale Protokoll-Fassade — dieselbe Begründung wie bei `BootstrapLoading`: `APIClient` ist bewusst ein `actor` ohne generische Abstraktion.

**Files:**
- Create: `apps/ios-member/FitnessMember/Networking/DTOs/CalibrationWrite.swift`
- Modify: `apps/ios-member/FitnessMember/Networking/APIClient.swift`
- Create: `apps/ios-member/FitnessMember/Workout/GeraetLoading.swift`
- Modify: `apps/ios-member/FitnessMemberTests/APIClientTests.swift`

**Interfaces:**
- Consumes: `APIError`, `APIClient`, `JSONValue`, `TagContextResponse`, `CompletedSession` (Sub-Projekt 1).
- Produces: `struct CalibrationWrite: Encodable { machineId, exerciseId, settingValues: [String: JSONValue], schemaVersion: Int, source: String }`
- Produces: `struct RecordedCalibration: Decodable { id, machineId, exerciseId, settingValues: JSONValue, schemaVersion: Int, source: String, createdAt: String }`
- Produces: `APIClient.recordCalibration(_ body: CalibrationWrite) async throws(APIError) -> RecordedCalibration`
- Produces: `protocol GeraetLoading: Sendable { func tagContext(token: String) async throws(APIError) -> TagContextResponse; func recordCalibration(_ body: CalibrationWrite) async throws(APIError) -> RecordedCalibration; func completeSession(sessionId: UUID) async throws(APIError) -> CompletedSession }` mit `extension APIClient: GeraetLoading {}` — von Aufgabe 10 und 16 konsumiert.

- [ ] **Step 1: Den Test schreiben**

An `apps/ios-member/FitnessMemberTests/APIClientTests.swift` innerhalb des bestehenden `@Suite("APIClient", .serialized)`-Typs anhängen:

```swift
    @Test("schickt die Kalibrierung als POST auf me/calibrations")
    func postsCalibration() async throws {
        // Kein `nonisolated(unsafe) var` -- das gilt nur fuer globale und
        // statische Eigenschaften, nicht fuer lokale Variablen.
        final class Aufzeichnung: @unchecked Sendable { var request: URLRequest? }
        let gesehen = Aufzeichnung()
        StubURLProtocol.handler = { request in
            gesehen.request = request
            let json = #"""
            {"id":"c1","machineId":"m1","exerciseId":"e1",
             "settingValues":{"sitz":4},"schemaVersion":1,
             "source":"self","createdAt":"2026-09-07T10:00:00Z"}
            """#
            return (201, Data(json.utf8))
        }
        let client = stubbedClient()

        let angelegt = try await client.recordCalibration(
            CalibrationWrite(machineId: "m1", exerciseId: "e1",
                             settingValues: ["sitz": .number(4)],
                             schemaVersion: 1, source: "self")
        )

        #expect(angelegt.id == "c1")
        #expect(gesehen.request?.httpMethod == "POST")
        #expect(gesehen.request?.url?.path.hasSuffix("/me/calibrations") == true)
    }

    @Test("reicht die Serverbegruendung einer abgelehnten Kalibrierung durch")
    func mapsCalibrationValidation() async throws {
        StubURLProtocol.handler = { _ in
            let json = #"{"error":{"code":"validation_failed","message":"Sitzposition liegt ueber dem Maximum 8."}}"#
            return (422, Data(json.utf8))
        }
        let client = stubbedClient()

        // designsystem.md SS5: der Fehler sagt, was gilt -- nicht nur, dass
        // etwas ungueltig ist. Der Text kommt deshalb vom Server.
        await #expect(throws: APIError.validation(message: "Sitzposition liegt ueber dem Maximum 8.")) {
            try await client.recordCalibration(
                CalibrationWrite(machineId: "m1", exerciseId: "e1",
                                 settingValues: ["sitz": .number(9)],
                                 schemaVersion: 1, source: "self")
            )
        }
    }
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag bestätigen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/APIClientTests 2>&1 | tail -20
```

Erwartet: FAIL — `CalibrationWrite` ist unbekannt.

- [ ] **Step 3: Die DTOs anlegen**

Create `apps/ios-member/FitnessMember/Networking/DTOs/CalibrationWrite.swift`:

```swift
import Foundation

/// Anfrage-Rumpf fuer POST /api/v1/me/calibrations.
///
/// Die Form von settingValues haengt vom Geraetemodell ab -- deshalb
/// JSONValue statt eines festen Typs, wie schon beim Lesen in
/// BootstrapResponse.Calibration.
struct CalibrationWrite: Encodable, Equatable {
    var machineId: String
    var exerciseId: String
    var settingValues: [String: JSONValue]
    var schemaVersion: Int
    /// "self" oder "trainer_assisted". Der Schalter "Ein Trainer war dabei"
    /// setzt nur die Quelle -- recorded_by bleibt serverseitig null, weil
    /// die Insert-Policy user_id = auth.uid() erzwingt.
    var source: String
}

struct RecordedCalibration: Decodable, Equatable {
    let id: String
    let machineId: String
    let exerciseId: String
    let settingValues: JSONValue
    let schemaVersion: Int
    let source: String
    let createdAt: String
}
```

- [ ] **Step 4: `APIClient` erweitern**

In `apps/ios-member/FitnessMember/Networking/APIClient.swift`, direkt unter dem `MARK: - Beitritts-/Austritts-Endpoints`-Block:

```swift
    // MARK: - Kalibrierung (Sub-Projekt 2, ausserhalb M1-Spec SS6.3)

    func recordCalibration(_ body: CalibrationWrite) async throws(APIError) -> RecordedCalibration {
        try await send("me/calibrations", method: "POST", body: body)
    }
```

- [ ] **Step 5: Die Fassade anlegen**

Create `apps/ios-member/FitnessMember/Workout/GeraetLoading.swift`:

```swift
import Foundation

/// Was der Geraete-Screen vom Netz braucht.
///
/// Eigene schmale Fassade statt einer generischen Abstraktion -- dieselbe
/// Begruendung wie bei BootstrapLoading: APIClient ist bewusst ein actor
/// ohne Router, und ein Protokoll je Aufrufkontext bleibt testbar, ohne
/// den Client aufzublaehen.
protocol GeraetLoading: Sendable {
    func tagContext(token: String) async throws(APIError) -> TagContextResponse
    func recordCalibration(_ body: CalibrationWrite) async throws(APIError) -> RecordedCalibration
    func completeSession(sessionId: UUID) async throws(APIError) -> CompletedSession
}

extension APIClient: GeraetLoading {}
```

- [ ] **Step 6: Tests laufen lassen, Erfolg bestätigen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/APIClientTests 2>&1 | tail -30
```

Erwartet: alle Tests grün.

- [ ] **Step 7: Commit**

```bash
git add apps/ios-member/FitnessMember/Networking apps/ios-member/FitnessMember/Workout/GeraetLoading.swift \
        apps/ios-member/FitnessMemberTests/APIClientTests.swift
git commit -m "feat(ios): APIClient.recordCalibration und die Geraete-Fassade

tagContext und completeSession lagen seit Sub-Projekt 1 fertig, aber
unaufgerufen im Client. recordCalibration kommt dazu -- Gegenstueck zum
neuen Endpoint.

GeraetLoading ist eine eigene schmale Fassade statt einer generischen
Abstraktion, dieselbe Begruendung wie bei BootstrapLoading."
```

---

### Aufgabe 9: Resttimer

`designsystem.md` §6: linearer Balken, kein Spinner — er zeigt Restdauer, nicht Beschäftigung. Er läuft über einen gespeicherten `endetAm`, nicht über einen Zähler: nur so hält er „Läuft weiter, auch wenn du wegsiehst" über Hintergrund und Sperrbildschirm.

Die VoiceOver-Live-Region wird auf 15 s gedrosselt (§12). Ohne diese Trennung entstünde die naive 1:1-Kopplung an die sekündliche Anzeige, vor der die Design-Challenge warnt.

**Files:**
- Create: `apps/ios-member/FitnessMember/Workout/Resttimer.swift`
- Create: `apps/ios-member/FitnessMember/Screens/Geraet/ResttimerBalken.swift`
- Create: `apps/ios-member/FitnessMemberTests/ResttimerTests.swift`

**Interfaces:**
- Consumes: `DesignSystem` (Aufgabe 3).
- Produces: `struct Resttimer: Codable, Equatable { static let dauer: TimeInterval; static let verlaengerung: TimeInterval; let endetAm: Date; init(start: Date); func restsekunden(jetzt: Date) -> Int; func anteil(jetzt: Date) -> Double; func laeuft(jetzt: Date) -> Bool; func verlaengert() -> Resttimer; func gesprochen(_ jetzt: Date = Date()) -> String }` — von Aufgabe 10 und 12 konsumiert.
- Produces: `struct ResttimerBalken: View` mit `timer: Resttimer` und `beiVerlaengern: () -> Void` — von Aufgabe 12 konsumiert.

- [ ] **Step 1: Den Test schreiben**

Create `apps/ios-member/FitnessMemberTests/ResttimerTests.swift`:

```swift
import Foundation
import Testing
@testable import FitnessMember

struct ResttimerTests {
    private let start = Date(timeIntervalSince1970: 1_757_000_000)

    @Test func neunzigSekundenAbStart() {
        let timer = Resttimer(start: start)
        #expect(timer.restsekunden(jetzt: start) == 90)
    }

    @Test func rechnetAusDerUhrzeitUndNichtAusEinemZaehler() {
        // "Laeuft weiter, auch wenn du wegsiehst" -- ueber Hintergrund und
        // Sperrbildschirm haelt nur ein gespeicherter Endzeitpunkt.
        let timer = Resttimer(start: start)
        #expect(timer.restsekunden(jetzt: start.addingTimeInterval(18)) == 72)
    }

    @Test func laeuftNichtInsNegative() {
        let timer = Resttimer(start: start)
        #expect(timer.restsekunden(jetzt: start.addingTimeInterval(120)) == 0)
        #expect(timer.laeuft(jetzt: start.addingTimeInterval(120)) == false)
        #expect(timer.laeuft(jetzt: start.addingTimeInterval(10)))
    }

    @Test func anteilLaeuftVonEinsNachNull() {
        let timer = Resttimer(start: start)
        #expect(timer.anteil(jetzt: start) == 1.0)
        #expect(abs(timer.anteil(jetzt: start.addingTimeInterval(45)) - 0.5) < 0.001)
        #expect(timer.anteil(jetzt: start.addingTimeInterval(200)) == 0.0)
    }

    @Test func verlaengernSchiebtDenEndzeitpunkt() {
        let timer = Resttimer(start: start).verlaengert()
        #expect(timer.restsekunden(jetzt: start) == 120)
    }

    @Test func dieAnsageNenntMinutenUndSekunden() {
        // designsystem.md SS12: "Pause, noch 1 Minute 12 Sekunden"
        let timer = Resttimer(start: start)
        #expect(timer.gesprochen(start.addingTimeInterval(18)) == "Pause, noch 1 Minute 12 Sekunden")
        #expect(timer.gesprochen(start.addingTimeInterval(45)) == "Pause, noch 45 Sekunden")
        #expect(timer.gesprochen(start.addingTimeInterval(30)) == "Pause, noch 1 Minute")
        #expect(timer.gesprochen(start.addingTimeInterval(90)) == "Pause beendet")
    }
}
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag bestätigen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/ResttimerTests 2>&1 | tail -20
```

Erwartet: FAIL — `Resttimer` ist unbekannt.

- [ ] **Step 3: `Resttimer` implementieren**

Create `apps/ios-member/FitnessMember/Workout/Resttimer.swift`:

```swift
import Foundation

/// Die Pause zwischen zwei Saetzen.
///
/// Der Timer haelt einen Endzeitpunkt, keinen Zaehler -- "Laeuft weiter,
/// auch wenn du wegsiehst" (GeraetResttimer.dc.html) haelt ueber
/// Hintergrund und Sperrbildschirm nur so.
struct Resttimer: Codable, Equatable {
    /// Feste Groesse: die Pausendauer ist kein Feld im Datenmodell und in
    /// M1 keine Einstellung.
    static let dauer: TimeInterval = 90
    static let verlaengerung: TimeInterval = 30

    let endetAm: Date

    init(start: Date = Date()) {
        endetAm = start.addingTimeInterval(Self.dauer)
    }

    private init(endetAm: Date) {
        self.endetAm = endetAm
    }

    func restsekunden(jetzt: Date = Date()) -> Int {
        max(0, Int(endetAm.timeIntervalSince(jetzt).rounded(.up)))
    }

    func laeuft(jetzt: Date = Date()) -> Bool {
        restsekunden(jetzt: jetzt) > 0
    }

    /// 1,0 zu Beginn, 0,0 am Ende -- der Balken zeigt Restdauer.
    func anteil(jetzt: Date = Date()) -> Double {
        min(1, max(0, Double(restsekunden(jetzt: jetzt)) / Self.dauer))
    }

    func verlaengert() -> Resttimer {
        Resttimer(endetAm: endetAm.addingTimeInterval(Self.verlaengerung))
    }

    /// Die Live-Region-Ansage aus designsystem.md SS12.
    func gesprochen(_ jetzt: Date = Date()) -> String {
        let rest = restsekunden(jetzt: jetzt)
        guard rest > 0 else { return "Pause beendet" }

        let minuten = rest / 60
        let sekunden = rest % 60
        switch (minuten, sekunden) {
        case (0, let s): return "Pause, noch \(s) Sekunden"
        case (let m, 0): return "Pause, noch \(m) Minute\(m == 1 ? "" : "n")"
        case (let m, let s): return "Pause, noch \(m) Minute\(m == 1 ? "" : "n") \(s) Sekunden"
        }
    }
}
```

- [ ] **Step 4: Test laufen lassen, Erfolg bestätigen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/ResttimerTests 2>&1 | tail -20
```

Erwartet: PASS, 6 Tests.

- [ ] **Step 5: Den Balken bauen**

Create `apps/ios-member/FitnessMember/Screens/Geraet/ResttimerBalken.swift`:

```swift
import SwiftUI

/// Linearer Balken, kein Spinner -- er zeigt Restdauer, nicht
/// Beschaeftigung (designsystem.md SS6).
///
/// Reduce Motion faellt hier von selbst richtig: die Sekundenschritte
/// kommen ohnehin diskret aus TimelineView, nur die Interpolation dazwischen
/// entfaellt. Genau das meint "der Balken springt dann sekundenweise".
struct ResttimerBalken: View {
    let timer: Resttimer
    let beiVerlaengern: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            HStack(alignment: .firstTextBaseline) {
                Text("PAUSE · \(Int(Resttimer.dauer)) S")
                    .font(DesignSystem.Typography.label)
                    .tracking(1.5)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                Spacer()
                TimelineView(.periodic(from: .now, by: 1)) { zeit in
                    Text(uhrzeit(timer.restsekunden(jetzt: zeit.date)))
                        .font(DesignSystem.Typography.wertSekundaer)
                        .foregroundStyle(DesignSystem.Color.text)
                }
            }

            TimelineView(.periodic(from: .now, by: 1)) { zeit in
                GeometryReader { rahmen in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(DesignSystem.Color.line)
                        Rectangle()
                            .fill(DesignSystem.Color.accent)
                            .frame(width: rahmen.size.width * timer.anteil(jetzt: zeit.date))
                            .animation(reduceMotion ? nil : .linear(duration: 1),
                                       value: timer.anteil(jetzt: zeit.date))
                    }
                }
                .frame(height: 4)
                .clipShape(Capsule())
            }
            .frame(height: 4)

            HStack {
                Text("Läuft weiter, auch wenn du wegsiehst.")
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.Color.textMuted)
                Spacer()
                Button("+30 s", action: beiVerlaengern)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.text)
                    .padding(.horizontal, DesignSystem.Spacing.s16)
                    .frame(height: 44)
                    .background(DesignSystem.Color.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.neben))
                    .buttonStyle(PressButtonStyle())
                    .accessibilityLabel("Pause um 30 Sekunden verlängern")
            }
        }
        .padding(DesignSystem.Spacing.s16)
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        .accessibilityElement(children: .contain)
        // Auf 15 s gedrosselt (designsystem.md SS12) -- eine 1:1-Kopplung an
        // die sekuendliche Anzeige waere fuer VoiceOver unbenutzbar.
        .overlay(alignment: .topLeading) {
            TimelineView(.periodic(from: .now, by: 15)) { zeit in
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityLabel(timer.gesprochen(zeit.date))
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
    }

    private func uhrzeit(_ sekunden: Int) -> String {
        String(format: "%02d:%02d", sekunden / 60, sekunden % 60)
    }
}

#Preview {
    ResttimerBalken(timer: Resttimer(), beiVerlaengern: {})
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Color.bg)
}
```

- [ ] **Step 6: Bauen und in der Canvas prüfen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" build 2>&1 | tail -20
```

Erwartet: BUILD SUCCEEDED.

In der Preview prüfen: Der Balken läuft sichtbar linear ab, die Ziffern springen nicht (tabellarisch), „+30 s" ist 44 pt hoch und verlängert. Mit „Reduce Motion" springt der Balken sekundenweise statt zu laufen — die Information bleibt vollständig.

- [ ] **Step 7: Commit**

```bash
git add apps/ios-member/FitnessMember/Workout/Resttimer.swift \
        apps/ios-member/FitnessMember/Screens/Geraet/ResttimerBalken.swift \
        apps/ios-member/FitnessMemberTests/ResttimerTests.swift
git commit -m "feat(ios): Resttimer als Endzeitpunkt, nicht als Zaehler

'Laeuft weiter, auch wenn du wegsiehst' haelt ueber Hintergrund und
Sperrbildschirm nur ein gespeicherter Endzeitpunkt.

Linearer Balken statt Spinner: er zeigt Restdauer, nicht Beschaeftigung.
Reduce Motion faellt von selbst richtig -- die Sekundenschritte kommen
ohnehin diskret aus TimelineView, nur die Interpolation entfaellt.

Die VoiceOver-Live-Region laeuft auf einem eigenen 15-Sekunden-Takt
(designsystem.md SS12); eine 1:1-Kopplung an die Anzeige waere unbenutzbar."
```

---

### Aufgabe 10: `GeraetModel` — der Zustand eines geöffneten Geräte-Screens

Ein `@Observable`-Modell je geöffnetem Gerät, nicht ein weiterer globaler Store: Der Screen wird gepusht, lebt so lange wie der Push und verschwindet mit ihm.

**Das tragende Prinzip:** Das Modell wird mit dem **Prefetch-Gerät** erzeugt und rendert sofort. `tagContext` kommt später und ergänzt nur, was der Server allein hat — signiertes Foto, signierte Videos, Vorschlag. Der Screen wartet nie darauf.

**Files:**
- Create: `apps/ios-member/FitnessMember/Screens/Geraet/GeraetModel.swift`
- Create: `apps/ios-member/FitnessMemberTests/GeraetModelTests.swift`

**Interfaces:**
- Consumes: `BootstrapResponse` (Aufgabe 1), `GeraetLoading` (Aufgabe 8), `Rastwerte` (Aufgabe 7), `Resttimer` (Aufgabe 9), `WorkoutSessionStore` (Aufgabe 5), `CatalogStore`, `GeraetEinstiegRechner` (Aufgabe 6), `Zahlformat` (Aufgabe 3).
- Produces: `struct GeraetUebung: Identifiable, Equatable { let id: String; let name: String; let targetRepsMin: Int; let targetRepsMax: Int; let videoURL: URL? }`
- Produces: `struct Einstellwert: Identifiable, Equatable { var id: String { key }; let key: String; let label: String; let anzeige: String }`
- Produces: `@MainActor @Observable final class GeraetModel` — von Aufgabe 11 bis 16 konsumiert. Öffentliche Fläche:
  `let maschine`, `var uebungId: String`, `var gewicht: Double`, `var wiederholungen: Int`, `var reserve: Double?`, `var radOffen: Bool`, `private(set) var pause: Resttimer?`, `private(set) var kontext: TagContextResponse?`,
  `var uebungen: [GeraetUebung]`, `var aktiveUebung: GeraetUebung?`, `var gewichtsWerte: [Double]`, `var einstellwerte: [Einstellwert]`, `var satzNummer: Int`, `var vorschlagText: String?`, `var zuletztText: String?`, `var anschlagText: String?`, `var istErstkontakt: Bool`, `var produktgrenze: String`,
  `func kontextLaden() async`, `func uebungWechseln(zu: String)`, `func satzSichern(problemFlag: Bool, problemReason: ProblemReason?) async`, `func pauseVerlaengern()`, `func pauseBeenden()`.

- [ ] **Step 1: Den Test schreiben**

Create `apps/ios-member/FitnessMemberTests/GeraetModelTests.swift`:

```swift
import Foundation
import Testing
@testable import FitnessMember

/// Nur die Ableitungen werden geprueft -- reine SwiftUI-Views werden laut
/// Spec Abschnitt 10 manuell gegen die Artboards abgenommen.
@MainActor
struct GeraetModelTests {
    private func modell(
        maschine: BootstrapResponse.Machine,
        bootstrap: BootstrapResponse
    ) -> GeraetModel {
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        return GeraetModel(
            maschine: maschine,
            uebungId: maschine.exercises.first?.id ?? "e1",
            token: nil,
            bootstrap: bootstrap,
            loader: FakeGeraetLoader(),
            sessions: WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis)),
            enqueue: { _ in }
        )
    }

    @Test func startetOhneHistorieAmGeraeteminimum() {
        // designsystem.md SS8: "Beim ersten Mal schlaegt gymodo kein Gewicht
        // vor. Das Rad startet am Geraetminimum."
        let bootstrap = GeraetTestdaten.bootstrap(lastSets: [])
        let sut = modell(maschine: GeraetTestdaten.maschine, bootstrap: bootstrap)

        #expect(sut.gewicht == 5.0)
        #expect(sut.vorschlagText == nil)
    }

    @Test func uebernimmtDenLetztenEigenenWertOhneNetz() {
        let bootstrap = GeraetTestdaten.bootstrap(lastSets: [("m1", "e1", 77.5, 11)])
        let sut = modell(maschine: GeraetTestdaten.maschine, bootstrap: bootstrap)

        #expect(sut.gewicht == 77.5)
        #expect(sut.wiederholungen == 11)
        #expect(sut.zuletztText?.contains("77,5 kg") == true)
    }

    @Test func rastetEinenVorschlagAufDieSchrittweite() {
        let bootstrap = GeraetTestdaten.bootstrap(lastSets: [("m1", "e1", 77.5, 11)])
        let sut = modell(maschine: GeraetTestdaten.maschine, bootstrap: bootstrap)

        sut.kontextUebernehmen(GeraetTestdaten.kontext(vorschlag: 80.0))

        #expect(sut.gewicht == 80.0)
        #expect(sut.vorschlagText == "Vorschlag · +2,5")
    }

    @Test func meldetDenAnschlagNurWennEsEinenGibt() {
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []))
        #expect(sut.anschlagText == "Maximum des Geräts erreicht")

        let ohneGrenze = modell(maschine: GeraetTestdaten.maschineOhneMaximum,
                                bootstrap: GeraetTestdaten.bootstrap(lastSets: []))
        #expect(ohneGrenze.anschlagText == nil)
    }

    @Test func einstellwerteTragenDieBeschriftungAuchOhneNetz() {
        let bootstrap = GeraetTestdaten.bootstrap(lastSets: [], mitKalibrierung: true)
        let sut = modell(maschine: GeraetTestdaten.maschine, bootstrap: bootstrap)

        #expect(sut.einstellwerte.first?.label == "Sitzposition")
        #expect(sut.einstellwerte.first?.anzeige == "4")
    }

    @Test func satzNummerZaehltImBlock() async {
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []))
        #expect(sut.satzNummer == 1)

        await sut.satzSichern(problemFlag: false, problemReason: nil)

        #expect(sut.satzNummer == 2)
        #expect(sut.pause != nil)
        #expect(sut.radOffen == false)
    }
}
```

Und die Testdaten plus den Fake in derselben Datei:

```swift
// MARK: - Testdaten

actor FakeGeraetLoader: GeraetLoading {
    var kontextResult: Result<TagContextResponse, APIError> = .failure(.offline)

    func setKontext(_ value: Result<TagContextResponse, APIError>) { kontextResult = value }

    func tagContext(token: String) async throws(APIError) -> TagContextResponse {
        switch kontextResult {
        case .success(let value): return value
        case .failure(let error): throw error
        }
    }

    func recordCalibration(_ body: CalibrationWrite) async throws(APIError) -> RecordedCalibration {
        throw APIError.offline
    }

    func completeSession(sessionId: UUID) async throws(APIError) -> CompletedSession {
        throw APIError.offline
    }
}

enum GeraetTestdaten {
    static func dekodiere<T: Decodable>(_ json: String, as: T.Type = T.self) -> T {
        try! JSONDecoder().decode(T.self, from: Data(json.utf8))
    }

    static var maschine: BootstrapResponse.Machine { maschine(maxWeightKg: "150.0") }
    static var maschineOhneMaximum: BootstrapResponse.Machine { maschine(maxWeightKg: "null") }

    static func maschine(maxWeightKg: String) -> BootstrapResponse.Machine {
        dekodiere("""
        {"id":"m1","studioId":"s1","label":"Gerät 7","locationNote":"Fensterseite",
         "status":"active","tokenHashes":[],"visitCount":2,
         "equipmentModel":{"id":"em1","name":"Beinpresse","manufacturer":"Technogym",
           "photoPath":null,"weightStepKg":2.5,"minWeightKg":5.0,"maxWeightKg":\(maxWeightKg),
           "settingDefinitions":[{"key":"sitz","label":"Sitzposition","kind":"number",
             "minValue":1,"maxValue":8,"stepValue":1,"unit":null,"allowedValues":null}]},
         "exercises":[{"id":"e1","name":"Beidbeinig","targetRepsMin":8,"targetRepsMax":12}]}
        """)
    }

    static func bootstrap(
        lastSets: [(String, String, Double, Int)],
        mitKalibrierung: Bool = false
    ) -> BootstrapResponse {
        let saetze = lastSets.map { eintrag in
            """
            {"machineId":"\(eintrag.0)","exerciseId":"\(eintrag.1)",
             "weightKg":\(eintrag.2),"reps":\(eintrag.3),"rir":null,
             "performedAt":"2026-09-01T10:00:00Z"}
            """
        }.joined(separator: ",")
        let kalibrierungen = mitKalibrierung
            ? #"{"machineId":"m1","exerciseId":"e1","settingValues":{"sitz":4},"schemaVersion":1,"createdAt":"2026-09-01T10:00:00Z"}"#
            : ""
        return dekodiere("""
        {"studios":[],"machines":[],"calibrations":[\(kalibrierungen)],"lastSets":[\(saetze)]}
        """)
    }

    static func kontext(vorschlag: Double) -> TagContextResponse {
        dekodiere("""
        {"machine":{"id":"m1","label":"Gerät 7","locationNote":"Fensterseite"},
         "equipmentModel":{"id":"em1","name":"Beinpresse","manufacturer":"Technogym",
           "photoUrl":null,"weightStepKg":2.5,"minWeightKg":5.0,"maxWeightKg":150.0},
         "settingDefinitions":[{"key":"sitz","label":"Sitzposition","kind":"number",
           "minValue":1,"maxValue":8,"stepValue":1,"unit":null,"allowedValues":null}],
         "exercises":[{"id":"e1","name":"Beidbeinig","description":null,
           "targetRepsMin":8,"targetRepsMax":12,"instructionVideoUrl":null}],
         "selectedExerciseId":"e1","calibration":null,
         "history":[{"performedOn":"2026-09-01","weightKg":77.5,"reps":[11,11,10]}],
         "suggestion":{"algoVersion":"v1","resultWeightKg":\(vorschlag),
           "reasonCode":"steigerung","inputs":{"targetRepsMin":8,"targetRepsMax":12,
             "weightStepKg":2.5,"minWeightKg":5.0,"maxWeightKg":150.0,
             "currentWeightKg":77.5,"consideredBlocks":1}}}
        """)
    }
}
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag bestätigen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/GeraetModelTests 2>&1 | tail -20
```

Erwartet: FAIL — `GeraetModel` ist unbekannt.

- [ ] **Step 3: `GeraetModel` implementieren**

Create `apps/ios-member/FitnessMember/Screens/Geraet/GeraetModel.swift`:

```swift
import Foundation
import Observation

/// Eine Uebung, egal ob aus dem Prefetch oder aus tagContext.
///
/// Vereinheitlicht die beiden DTO-Formen, damit der Screen nicht zwei
/// Quellen kennen muss. Das Video kommt nur online (signierte URL).
struct GeraetUebung: Identifiable, Equatable {
    let id: String
    let name: String
    let targetRepsMin: Int
    let targetRepsMax: Int
    let videoURL: URL?
}

/// Ein eigener Einstellwert, fertig zum Anzeigen.
struct Einstellwert: Identifiable, Equatable {
    var id: String { key }
    let key: String
    let label: String
    let anzeige: String
}

/// Der Zustand eines geoeffneten Geraete-Screens.
///
/// Kein weiterer globaler Store: Der Screen wird gepusht, lebt so lange wie
/// der Push und verschwindet mit ihm.
///
/// Erzeugt wird das Modell mit dem PREFETCH-Geraet -- es rendert sofort.
/// tagContext kommt spaeter und ergaenzt nur, was der Server allein hat:
/// signiertes Foto, signierte Videos, Vorschlag (M1-Spec SS8.1 Schritt 3).
@MainActor
@Observable
final class GeraetModel {
    let maschine: BootstrapResponse.Machine
    private(set) var uebungId: String
    private(set) var kontext: TagContextResponse?
    private(set) var pause: Resttimer?

    var gewicht: Double
    var wiederholungen: Int
    var reserve: Double?
    var radOffen = false

    private let token: String?
    private let bootstrap: BootstrapResponse
    private let loader: any GeraetLoading
    private let sessions: WorkoutSessionStore
    private let enqueue: (PendingSetWrite) -> Void

    init(
        maschine: BootstrapResponse.Machine,
        uebungId: String,
        token: String?,
        bootstrap: BootstrapResponse,
        loader: any GeraetLoading,
        sessions: WorkoutSessionStore,
        enqueue: @escaping (PendingSetWrite) -> Void
    ) {
        self.maschine = maschine
        self.uebungId = uebungId
        self.token = token
        self.bootstrap = bootstrap
        self.loader = loader
        self.sessions = sessions
        self.enqueue = enqueue

        let letzter = bootstrap.lastSets.first {
            $0.machineId == maschine.id && $0.exerciseId == uebungId
        }
        // Ohne Historie startet das Rad am Geraetminimum -- ein Vorschlag
        // ohne Daten waere eine Trainingsempfehlung (designsystem.md SS8).
        gewicht = letzter?.weightKg ?? maschine.equipmentModel.minWeightKg
        wiederholungen = letzter?.reps ?? maschine.exercises.first { $0.id == uebungId }?.targetRepsMin ?? 10
        reserve = letzter?.rir
    }

    // MARK: - Abgeleitetes

    var uebungen: [GeraetUebung] {
        if let kontext {
            return kontext.exercises.map {
                GeraetUebung(id: $0.id, name: $0.name,
                             targetRepsMin: $0.targetRepsMin, targetRepsMax: $0.targetRepsMax,
                             videoURL: $0.instructionVideoUrl.flatMap(URL.init(string:)))
            }
        }
        return maschine.exercises.map {
            GeraetUebung(id: $0.id, name: $0.name,
                         targetRepsMin: $0.targetRepsMin, targetRepsMax: $0.targetRepsMax,
                         videoURL: nil)
        }
    }

    var aktiveUebung: GeraetUebung? { uebungen.first { $0.id == uebungId } }

    private var modell: (schritt: Double, min: Double, max: Double?) {
        if let kontext {
            return (kontext.equipmentModel.weightStepKg,
                    kontext.equipmentModel.minWeightKg,
                    kontext.equipmentModel.maxWeightKg)
        }
        return (maschine.equipmentModel.weightStepKg,
                maschine.equipmentModel.minWeightKg,
                maschine.equipmentModel.maxWeightKg)
    }

    var gewichtsWerte: [Double] {
        Rastwerte.gewichte(min: modell.min, max: modell.max, schritt: modell.schritt)
    }

    /// Nur wo es einen dokumentierten Anschlag gibt.
    var anschlagText: String? {
        modell.max == nil ? nil : "Maximum des Geräts erreicht"
    }

    var kontextzeileGewicht: String {
        let bereich = modell.max.map {
            "\(Zahlformat.gewicht(modell.min)) – \(Zahlformat.gewicht($0))"
        } ?? "ab \(Zahlformat.gewicht(modell.min))"
        return "Schritt \(Zahlformat.gewicht(modell.schritt)) kg · \(bereich)"
    }

    var kontextzeileWiederholungen: String {
        guard let uebung = aktiveUebung else { return "" }
        return "Ziel \(uebung.targetRepsMin) – \(uebung.targetRepsMax)"
    }

    private var definitionen: [TagContextResponse.SettingDefinition] {
        kontext?.settingDefinitions ?? maschine.equipmentModel.settingDefinitions
    }

    private var kalibrierungswerte: JSONValue? {
        if let kontext, let kalibrierung = kontext.calibration { return kalibrierung.settingValues }
        return bootstrap.calibrations.first {
            $0.machineId == maschine.id && $0.exerciseId == uebungId
        }?.settingValues
    }

    /// Beschriftete Einstellwerte -- auch offline, weil bootstrap die
    /// Definitionen mitliefert.
    var einstellwerte: [Einstellwert] {
        guard case .object(let werte)? = kalibrierungswerte else { return [] }
        return definitionen.compactMap { definition in
            guard let wert = werte[definition.key] else { return nil }
            return Einstellwert(key: definition.key, label: definition.label,
                                anzeige: anzeige(fuer: wert, einheit: definition.unit))
        }
    }

    private func anzeige(fuer wert: JSONValue, einheit: String?) -> String {
        let roh: String = switch wert {
        case .number(let zahl): zahl == zahl.rounded() ? String(Int(zahl)) : Zahlformat.gewicht(zahl)
        case .string(let text): text
        default: "–"
        }
        return einheit.map { "\(roh)\($0)" } ?? roh
    }

    var satzNummer: Int {
        sessions.naechsterSetIndex(machineId: maschine.id, exerciseId: uebungId)
    }

    /// "Vorschlag · +2,5" -- eine Rechnung, keine Empfehlung
    /// (designsystem.md SS10). Fehlt offline und beim Erstkontakt.
    var vorschlagText: String? {
        guard let vorschlag = kontext?.suggestion.resultWeightKg,
              let vorher = kontext?.suggestion.inputs.currentWeightKg
        else { return nil }
        let delta = vorschlag - vorher
        guard delta != 0 else { return "Vorschlag · halten" }
        let vorzeichen = delta > 0 ? "+" : "−"
        return "Vorschlag · \(vorzeichen)\(Zahlformat.gewicht(abs(delta)))"
    }

    var zuletztText: String? {
        guard let letzter = bootstrap.lastSets.first(where: {
            $0.machineId == maschine.id && $0.exerciseId == uebungId
        }) else { return nil }
        return "Zuletzt \(Zahlformat.gewichtMitEinheit(letzter.weightKg)) × \(letzter.reps)"
    }

    var istErstkontakt: Bool {
        GeraetEinstiegRechner.istErstkontakt(
            hatKalibrierung: GeraetEinstiegRechner.hatKalibrierung(
                machineId: maschine.id, exerciseId: uebungId, in: bootstrap),
            hatLetztenSatz: GeraetEinstiegRechner.hatLetztenSatz(
                machineId: maschine.id, exerciseId: uebungId, in: bootstrap)
        )
    }

    /// Pflichtort laut designsystem.md SS10.
    let produktgrenze = """
        gymodo misst nichts. Angezeigt wird ausschließlich, was du selbst \
        bestätigt hast. Einweisungsvideos und Einstellhinweise sind Inhalte \
        deines Studios, keine Trainings- oder Gesundheitsempfehlung von gymodo.
        """

    // MARK: - Aktionen

    func kontextLaden() async {
        guard let token else { return }
        // Ein Fehlschlag ist kein Fehlerzustand: der Screen steht bereits
        // aus dem Prefetch. Es fehlen nur Video, Foto und Vorschlag.
        guard let geladen = try? await loader.tagContext(token: token) else { return }
        kontextUebernehmen(geladen)
    }

    func kontextUebernehmen(_ geladen: TagContextResponse) {
        kontext = geladen
        if let vorschlag = geladen.suggestion.resultWeightKg {
            gewicht = Rastwerte.naechster(zu: vorschlag, in: gewichtsWerte)
        }
    }

    func uebungWechseln(zu neue: String) {
        uebungId = neue
        let letzter = bootstrap.lastSets.first {
            $0.machineId == maschine.id && $0.exerciseId == neue
        }
        gewicht = Rastwerte.naechster(
            zu: letzter?.weightKg ?? modell.min, in: gewichtsWerte)
        wiederholungen = letzter?.reps ?? aktiveUebung?.targetRepsMin ?? 10
        reserve = letzter?.rir
        radOffen = false
    }

    func satzSichern(problemFlag: Bool, problemReason: ProblemReason?) async {
        let geschrieben = sessions.satzSichern(
            machineId: maschine.id, exerciseId: uebungId,
            weightKg: gewicht, reps: wiederholungen, rir: reserve,
            problemFlag: problemFlag, problemReason: problemReason
        )
        // Immer ueber die Warteschlange, nie direkt: so ist "gespeichert,
        // wird gesendet" nie gelogen, und der Offline-Pfad ist derselbe, der
        // jeden Tag laeuft (Spec Abschnitt 8.2).
        enqueue(PendingSetWrite(sessionId: geschrieben.sessionId,
                                setId: geschrieben.setId,
                                body: geschrieben.body))
        radOffen = false
        pause = Resttimer()
    }

    func pauseVerlaengern() { pause = pause?.verlaengert() }
    func pauseBeenden() { pause = nil }
}
```

- [ ] **Step 4: Test laufen lassen, Erfolg bestätigen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/GeraetModelTests 2>&1 | tail -30
```

Erwartet: PASS, 6 Tests. Der Test `satzNummerZaehltImBlock` verlangt, dass `satzSichern` `radOffen` schließt und die Pause startet.

- [ ] **Step 5: Commit**

```bash
git add apps/ios-member/FitnessMember/Screens/Geraet/GeraetModel.swift \
        apps/ios-member/FitnessMemberTests/GeraetModelTests.swift
git commit -m "feat(ios): GeraetModel -- Zustand eines geoeffneten Geraete-Screens

Erzeugt aus dem Prefetch-Geraet, rendert sofort. tagContext kommt spaeter
und ergaenzt nur, was der Server allein hat: signiertes Foto, signierte
Videos, Vorschlag. Der Screen wartet nie darauf (M1-Spec SS8.1 Schritt 3);
ein Fehlschlag ist deshalb kein Fehlerzustand.

Ohne Historie startet das Rad am Geraetminimum -- ein Vorschlag ohne Daten
waere eine Trainingsempfehlung, genau das schliesst die Produktgrenze aus.

Jeder Satz geht ueber die Warteschlange, nie direkt: so ist 'gespeichert,
wird gesendet' nie gelogen."
```

---

### Aufgabe 11: `GeraetErkannt`

Der Erkennungs-Screen. Er zeigt das Gerätefoto — es bestätigt in einer Sekunde, dass man am richtigen Gerät steht; bei zwei baugleichen Stationen nebeneinander ist das der eigentliche Nutzen, nicht Dekoration.

**Ein Tap auf eine Übung führt direkt zum Satz; es gibt keinen Bestätigungsknopf.**

**Artboard:** `GeraetErkannt.dc.html`. **Abweichung (Spec Abschnitt 9):** Das „ERKANNT"-Badge trägt dort `accent` — in Swift `text-muted`, weil die aktive Übungszeile die eine Akzentfläche des Screens ist.

**Files:**
- Create: `apps/ios-member/FitnessMember/Screens/Geraet/GeraetErkanntView.swift`

**Interfaces:**
- Consumes: `GeraetModel` (Aufgabe 10), `Zahlformat`, `DesignSystem` (Aufgabe 3).
- Produces: `struct GeraetErkanntView: View { let modell: GeraetModel; let beiAuswahl: (String) -> Void }` — von Aufgabe 16 konsumiert.

- [ ] **Step 1: Die View schreiben**

Create `apps/ios-member/FitnessMember/Screens/Geraet/GeraetErkanntView.swift`:

```swift
import SwiftUI

/// "Was machst du heute?" -- die Uebungsliste eines erkannten Geraets.
///
/// Ein Tap auf eine Uebung fuehrt direkt zum Satz; es gibt keinen
/// Bestaetigungsknopf (designsystem.md SS8).
struct GeraetErkanntView: View {
    let modell: GeraetModel
    let beiAuswahl: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
                kopfzeile
                geraetefoto
                geraetename
                Text("Was machst du heute?")
                    .font(DesignSystem.Typography.uebungsname)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                uebungsliste
                hinweis
            }
            .padding(.horizontal, 20)
            .padding(.bottom, DesignSystem.Spacing.s32)
        }
        .background(DesignSystem.Color.bg)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var kopfzeile: some View {
        HStack {
            Text(ortsangabe)
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textFaint)
            Spacer()
            // Abweichung vom Artboard: dort accent. Die eine Akzentflaeche
            // des Screens ist die aktive Uebungszeile (designsystem.md SS2).
            Label("ERKANNT", systemImage: "wave.3.right")
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)
        }
    }

    private var ortsangabe: String {
        [modell.maschine.label, modell.maschine.locationNote]
            .compactMap { $0 }
            .joined(separator: " · ")
            .uppercased()
    }

    /// Bestaetigt in einer Sekunde, dass man am richtigen Geraet steht --
    /// bei zwei baugleichen Stationen der eigentliche Nutzen. Offline gibt
    /// es keine signierte URL, dann steht hier der Platzhalter.
    private var geraetefoto: some View {
        AsyncImage(url: modell.kontext?.equipmentModel.photoUrl.flatMap(URL.init(string:))) { bild in
            bild.resizable().aspectRatio(contentMode: .fill)
        } placeholder: {
            ZStack {
                DesignSystem.Color.surfaceRaised
                Image(systemName: "photo")
                    .font(.system(size: 28))
                    .foregroundStyle(DesignSystem.Color.textFaint)
            }
        }
        .frame(height: 180)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        .accessibilityHidden(true)
    }

    private var geraetename: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
            Text(modell.maschine.equipmentModel.name.uppercased())
                .font(DesignSystem.Typography.geraetename)
                .tracking(-0.8)
                .foregroundStyle(DesignSystem.Color.text)
            Text(hersteller)
                .font(.system(size: 13))
                .foregroundStyle(DesignSystem.Color.textMuted)
        }
    }

    private var hersteller: String {
        [modell.maschine.equipmentModel.manufacturer, modell.maschine.locationNote]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private var uebungsliste: some View {
        VStack(spacing: DesignSystem.Spacing.s8) {
            ForEach(sortierteUebungen) { uebung in
                Button { beiAuswahl(uebung.id) } label: {
                    zeile(uebung)
                }
                .buttonStyle(PressButtonStyle())
                .accessibilityLabel("\(uebung.name), \(untertitel(uebung))")
                .accessibilityHint("Öffnet das Gerät")
            }
        }
    }

    /// Ab zwei Besuchen steht die zuletzt genutzte Uebung oben
    /// (designsystem.md SS8).
    private var sortierteUebungen: [GeraetUebung] {
        modell.uebungen.sorted { links, _ in links.id == modell.uebungId }
    }

    private func zeile(_ uebung: GeraetUebung) -> some View {
        let aktiv = uebung.id == modell.uebungId
        return HStack(spacing: DesignSystem.Spacing.s12) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                Text(uebung.name)
                    .font(DesignSystem.Typography.uebungsname)
                    .foregroundStyle(DesignSystem.Color.text)
                Text(untertitel(uebung))
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DesignSystem.Color.textFaint)
        }
        .padding(DesignSystem.Spacing.s16)
        .frame(minHeight: 44)
        .background(aktiv ? DesignSystem.Color.surfaceRaised : DesignSystem.Color.surface)
        .overlay(alignment: .leading) {
            // Die eine Akzentflaeche des Screens.
            if aktiv {
                Rectangle().fill(DesignSystem.Color.accent).frame(width: 3)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
    }

    private func untertitel(_ uebung: GeraetUebung) -> String {
        if let letzter = letzterSatz(uebung.id) {
            return "zuletzt · \(Zahlformat.gewichtMitEinheit(letzter))"
        }
        return "Noch nie · Ziel \(uebung.targetRepsMin) – \(uebung.targetRepsMax) Wdh."
    }

    private func letzterSatz(_ uebungId: String) -> Double? {
        modell.letztesGewicht(fuer: uebungId)
    }

    private var hinweis: some View {
        Text("Ein Tap genügt — du landest direkt beim Satz. Trainierst du hier immer dasselbe, überspringt gymodo diesen Schritt künftig.")
            .font(.system(size: 12))
            .foregroundStyle(DesignSystem.Color.textFaint)
            .lineSpacing(3)
    }
}
```

- [ ] **Step 2: Die fehlende Ableitung in `GeraetModel` ergänzen**

`GeraetErkanntView` braucht das letzte Gewicht je Übung, nicht nur für die aktive. In `GeraetModel.swift`, bei den Ableitungen:

```swift
    func letztesGewicht(fuer uebungId: String) -> Double? {
        bootstrap.lastSets.first {
            $0.machineId == maschine.id && $0.exerciseId == uebungId
        }?.weightKg
    }
```

- [ ] **Step 3: Bauen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" build 2>&1 | tail -20
```

Erwartet: BUILD SUCCEEDED.

- [ ] **Step 4: Gegen das Artboard abnehmen**

`GeraetErkannt.dc.html` im Browser neben dem Simulator öffnen und prüfen:
1. Genau **eine** Akzentfläche: der 3-pt-Streifen an der aktiven Übungszeile. Das „ERKANNT"-Badge ist `text-muted` — das ist die dokumentierte Abweichung.
2. Jede Übungszeile ist ≥ 44 pt hoch und antippbar; es gibt keinen Bestätigungsknopf.
3. Zuletzt genutzte Übung steht oben.
4. Ohne Netz steht statt des Fotos der Platzhalter, alles andere ist da.
5. VoiceOver liest je Zeile „Beidbeinig, zuletzt · 45,0 kg" mit dem Hinweis „Öffnet das Gerät".

- [ ] **Step 5: Commit**

```bash
git add apps/ios-member/FitnessMember/Screens/Geraet
git commit -m "feat(ios): GeraetErkannt

Ein Tap auf eine Uebung fuehrt direkt zum Satz, kein Bestaetigungsknopf.
Das Geraetefoto bestaetigt in einer Sekunde, dass man am richtigen Geraet
steht -- bei zwei baugleichen Stationen der eigentliche Nutzen.

Abweichung vom Artboard (Spec Abschnitt 9): das ERKANNT-Badge traegt dort
accent. Die eine Akzentflaeche des Screens ist die aktive Uebungszeile."
```

---

### Aufgabe 12: `GeraetView` — Ruhe, Rad offen, Pause

Der Kern. **Ein Screen, drei Zustände** — `Main`, `GeraetWertRad` und `GeraetResttimer` sind keine Navigationsziele. `designsystem.md` §7 verlangt ausdrücklich dieselbe Silhouette in Ruhe und Offen; zwei Views wären hier der Fehler.

**Interaktionsbudget** (§9, Abnahmebedingung): Normalfall ein Tap auf „Satz N sichern". Abweichungsfall ein Tap öffnet **beide** Räder, danach ist Scrollen kostenlos, und „Satz N sichern" bleibt im offenen Zustand sichtbar — kein Schließen-Tap dazwischen.

**Artboards:** `Main.dc.html`, `GeraetWertRad.dc.html`, `GeraetResttimer.dc.html`. **Abweichungen (Spec Abschnitt 9):** „andere Übung" ist `text-muted` statt `accent`; der Wiederholungswert ist 44 pt (das Artboard zeigt 50 px); der Reserve-Chip ist Umriss, nie Fläche.

**Files:**
- Create: `apps/ios-member/FitnessMember/Screens/Geraet/WertZeile.swift`
- Create: `apps/ios-member/FitnessMember/Screens/Geraet/GeraetView.swift`

**Interfaces:**
- Consumes: `GeraetModel` (Aufgabe 10), `RastRad`/`Rastwerte` (Aufgabe 7), `ResttimerBalken` (Aufgabe 9), `Zahlformat`/`DesignSystem.Motion`/`PressButtonStyle` (Aufgabe 3).
- Produces: `struct WertZeile: View { let modell: GeraetModel }`
- Produces: `struct GeraetView: View { let modell: GeraetModel; let beiUebungWechseln: () -> Void; let beiProblem: () -> Void; let beiZurueckZumTraining: () -> Void }` — von Aufgabe 16 konsumiert.

- [ ] **Step 1: `WertZeile` schreiben**

Create `apps/ios-member/FitnessMember/Screens/Geraet/WertZeile.swift`:

```swift
import SwiftUI

/// Die beiden Werte, nackt auf der Flaeche -- kein Kasten, kein Rahmen,
/// kein Eingabefeld (designsystem.md SS7).
///
/// Ein Tap auf EINE der beiden Zahlen oeffnet BEIDE Raeder. Danach wird nur
/// noch gescrollt: ohne weiteren Tap und ohne Tastatur, mit dem Daumen der
/// Hand, die das Handy haelt.
struct WertZeile: View {
    @Bindable var modell: GeraetModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            kopf
            HStack(alignment: .top, spacing: DesignSystem.Spacing.s24) {
                gewichtsrad
                wiederholungsrad
            }
            if !modell.radOffen, let zuletzt = modell.zuletztText {
                Text(zuletzt)
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.Color.textFaint)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard !modell.radOffen else { return }
            withAnimation(reduceMotion ? nil : DesignSystem.Motion.oeffnen) {
                modell.radOffen = true
            }
        }
    }

    private var kopf: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.s8) {
            Text("SATZ \(modell.satzNummer)")
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)
            Text(modell.radOffen ? "scrollen, dann sichern" : "antippen und scrollen")
                .font(.system(size: 12))
                .foregroundStyle(DesignSystem.Color.textFaint)
        }
        .accessibilityHidden(true)
    }

    private var gewichtsrad: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
            HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.s4) {
                RastRad(
                    werte: modell.gewichtsWerte,
                    auswahl: $modell.gewicht,
                    offen: modell.radOffen,
                    unterstrich: .akzent,
                    voLabel: "Gewicht",
                    voWert: Zahlformat.gewichtGesprochen,
                    anschlagText: modell.anschlagText,
                    text: Zahlformat.gewicht
                )
                Text("kg")
                    .font(DesignSystem.Typography.uebungsname)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .accessibilityHidden(true)
            }
            kontextzeileGewicht
        }
    }

    /// Am Anschlag tritt die Grenze an die Stelle des Kontexts -- sichtbares
    /// Anschlagsfeedback, nicht nur eine VoiceOver-Ansage (SS6: Haptik nie
    /// als einzige Rueckmeldung).
    private var kontextzeileGewicht: some View {
        let amAnschlag = modell.anschlagText != nil
            && (modell.gewicht == modell.gewichtsWerte.first
                || modell.gewicht == modell.gewichtsWerte.last)
        let text = amAnschlag
            ? (modell.anschlagText ?? "")
            : (modell.radOffen ? modell.kontextzeileGewicht : (modell.vorschlagText ?? modell.kontextzeileGewicht))
        return Text(text)
            .font(.system(size: 12))
            .foregroundStyle(amAnschlag ? DesignSystem.Color.textMuted : DesignSystem.Color.textFaint)
            .accessibilityHidden(true)
    }

    private var wiederholungsrad: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
            HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.s4) {
                RastRad(
                    werte: Rastwerte.wiederholungen.map(Double.init),
                    auswahl: Binding(
                        get: { Double(modell.wiederholungen) },
                        set: { modell.wiederholungen = Int($0) }
                    ),
                    offen: modell.radOffen,
                    unterstrich: .linie,
                    voLabel: "Wiederholungen",
                    voWert: { Zahlformat.wiederholungenGesprochen(Int($0)) },
                    anschlagText: nil,
                    text: { String(Int($0)) }
                )
                Text("Wdh.")
                    .font(DesignSystem.Typography.uebungsname)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .accessibilityHidden(true)
            }
            Text(modell.kontextzeileWiederholungen)
                .font(.system(size: 12))
                .foregroundStyle(DesignSystem.Color.textFaint)
                .accessibilityHidden(true)
        }
    }
}
```

**Hinweis zur Größe:** Der Wiederholungswert erbt über `RastRad` dieselbe `wertHeld`-Rolle wie das Gewicht. Das ist Absicht und die dokumentierte Abweichung vom Artboard — `designsystem.md` §3 kennt für die Satz-Wertzeile nur eine Held-Rolle, und §7 verlangt dieselbe Silhouette. Skaliert das Layout auf kleinen Geräten nicht, verkleinere **beide** Räder gemeinsam, nie nur eines.

- [ ] **Step 2: `GeraetView` schreiben**

Create `apps/ios-member/FitnessMember/Screens/Geraet/GeraetView.swift`:

```swift
import SwiftUI

/// Main, GeraetWertRad und GeraetResttimer sind derselbe Screen in drei
/// Zustaenden -- keine Navigationsziele. designsystem.md SS7 verlangt
/// dieselbe Silhouette in Ruhe und Offen; zwei Views waeren hier der Fehler.
struct GeraetView: View {
    @Bindable var modell: GeraetModel
    let beiUebungWechseln: () -> Void
    let beiProblem: () -> Void
    let beiZurueckZumTraining: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
                kopfzeile
                geraetUndUebung
                if let pause = modell.pause, pause.laeuft() {
                    ResttimerBalken(timer: pause, beiVerlaengern: modell.pauseVerlaengern)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                einstellung
                WertZeile(modell: modell)
                aktionen
                produktgrenze
            }
            .padding(.horizontal, 20)
            .padding(.bottom, DesignSystem.Spacing.s32)
            .animation(reduceMotion ? nil : DesignSystem.Motion.pause, value: modell.pause)
            .animation(reduceMotion ? nil : DesignSystem.Motion.oeffnen, value: modell.radOffen)
        }
        .background(DesignSystem.Color.bg)
        .navigationBarTitleDisplayMode(.inline)
        .task { await modell.kontextLaden() }
    }

    private var kopfzeile: some View {
        Text([modell.maschine.label, modell.maschine.locationNote]
            .compactMap { $0 }.joined(separator: " · ").uppercased())
            .font(DesignSystem.Typography.label)
            .tracking(1.5)
            .foregroundStyle(DesignSystem.Color.textFaint)
    }

    private var geraetUndUebung: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                Text(modell.maschine.equipmentModel.name.uppercased())
                    .font(DesignSystem.Typography.geraetename)
                    .tracking(-0.8)
                    .foregroundStyle(DesignSystem.Color.text)
                Text(modell.aktiveUebung?.name ?? "")
                    .font(DesignSystem.Typography.uebungsname)
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }
            Spacer()
            // Abweichung vom Artboard (Spec Abschnitt 9): dort accent. Die
            // eine Akzentflaeche des Screens ist die Hauptaktion.
            Button("andere Übung", action: beiUebungWechseln)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DesignSystem.Color.textMuted)
                .frame(minHeight: 44)
                .buttonStyle(PressButtonStyle())
        }
    }

    /// Schrumpft auf eine Zeile, sobald die Raeder offen sind -- damit das
    /// Rad Platz hat (Artboard-Kommentar in GeraetWertRad.dc.html).
    @ViewBuilder
    private var einstellung: some View {
        if !modell.einstellwerte.isEmpty {
            if modell.radOffen {
                HStack {
                    Text(modell.einstellwerte.map { "\($0.label) \($0.anzeige)" }
                        .joined(separator: " · "))
                        .font(.system(size: 13))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                        .lineLimit(1)
                    Spacer()
                    aendernKnopf
                }
            } else {
                HStack(alignment: .top) {
                    ForEach(modell.einstellwerte) { wert in
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                            Text(wert.label.uppercased())
                                .font(DesignSystem.Typography.label)
                                .tracking(1.5)
                                .foregroundStyle(DesignSystem.Color.textFaint)
                            Text(wert.anzeige)
                                .font(DesignSystem.Typography.wertSekundaer)
                                .foregroundStyle(DesignSystem.Color.text)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .combine)
                    }
                    aendernKnopf
                }
                .padding(DesignSystem.Spacing.s16)
                .background(DesignSystem.Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
            }
        }
    }

    private var aendernKnopf: some View {
        Button("ändern") { modell.kalibrierungOeffnen() }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(DesignSystem.Color.textMuted)
            .frame(minHeight: 44)
            .buttonStyle(PressButtonStyle())
    }

    private var aktionen: some View {
        VStack(spacing: DesignSystem.Spacing.s12) {
            reserveZeile
            // Bleibt im offenen Zustand sichtbar und sichert direkt -- kein
            // Schliessen-Tap dazwischen (Interaktionsbudget SS9).
            PrimaryButton(title: hauptaktion) {
                await modell.satzSichern(problemFlag: false, problemReason: nil)
            }
            .accessibilityLabel("\(hauptaktion), \(Zahlformat.gewichtGesprochen(modell.gewicht))")

            if modell.pause != nil {
                SecondaryButton(title: "Übung wechseln", action: beiUebungWechseln)
            }
            Button("Problem melden", action: beiProblem)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DesignSystem.Color.textMuted)
                .frame(maxWidth: .infinity, minHeight: 44)
                .buttonStyle(PressButtonStyle())
                .accessibilityHint("Verhindert einen Steigerungsvorschlag")
            Button("← Zurück zum Training", action: beiZurueckZumTraining)
                .font(.system(size: 15))
                .foregroundStyle(DesignSystem.Color.textFaint)
                .frame(maxWidth: .infinity, minHeight: 44)
                .buttonStyle(PressButtonStyle())
        }
    }

    private var hauptaktion: String {
        "Satz \(modell.satzNummer) sichern"
    }

    /// RIR, laut SS9 optional und ueber das Profil abschaltbar. Der Schalter
    /// selbst gehoert zu Sub-Projekt 4; hier steht schon die Ablage, damit
    /// SP4 nur noch den Schalter anhaengen muss.
    @AppStorage("rirSichtbar") private var rirSichtbar = true

    @ViewBuilder
    private var reserveZeile: some View {
        if rirSichtbar {
            HStack(spacing: DesignSystem.Spacing.s8) {
                Text("RESERVE")
                    .font(DesignSystem.Typography.label)
                    .tracking(1.5)
                    .foregroundStyle(DesignSystem.Color.textFaint)
                Text("optional")
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Color.textFaint)
                Spacer()
                ForEach([0.0, 1.0, 2.0, 3.0, 4.0], id: \.self) { wert in
                    // Umriss, nie Flaeche -- die dokumentierte Abweichung vom
                    // Artboard (Spec Abschnitt 9).
                    Button(wert == 4 ? "4+" : String(Int(wert))) {
                        modell.reserve = modell.reserve == wert ? nil : wert
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(modell.reserve == wert
                                     ? DesignSystem.Color.text : DesignSystem.Color.textMuted)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Capsule().stroke(
                            modell.reserve == wert
                                ? DesignSystem.Color.text : DesignSystem.Color.line,
                            lineWidth: modell.reserve == wert ? 2 : 1)
                    )
                    .buttonStyle(PressButtonStyle())
                    .accessibilityLabel("Reserve \(Int(wert))\(wert == 4 ? " oder mehr" : "")")
                }
            }
        }
    }

    private var produktgrenze: some View {
        Text(modell.produktgrenze)
            .font(.system(size: 12))
            .foregroundStyle(DesignSystem.Color.textFaint)
            .lineSpacing(3)
    }
}
```

- [ ] **Step 3: Den fehlenden Haken in `GeraetModel` ergänzen**

`aendernKnopf` ruft `modell.kalibrierungOeffnen()`. In `GeraetModel.swift` ergänzen:

```swift
    /// Die Kalibrierung ist auch ausserhalb des Dreischritts erreichbar
    /// ("aendern" auf Main) -- genau der Fall, der den eigenen Endpoint
    /// noetig macht.
    var kalibrierungOffen = false

    func kalibrierungOeffnen() { kalibrierungOffen = true }
```

- [ ] **Step 4: Bauen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" build 2>&1 | tail -20
```

Erwartet: BUILD SUCCEEDED.

- [ ] **Step 5: Gegen drei Artboards abnehmen**

`Main.dc.html`, `GeraetWertRad.dc.html` und `GeraetResttimer.dc.html` nebeneinander öffnen und prüfen:

1. **Silhouette:** Ein Tap auf das Gewicht öffnet **beide** Räder. Der gewählte Wert behält Größe und Position; nur die Nachbarn kommen dazu und der Einstellungsblock schrumpft auf eine Zeile.
2. **Interaktionsbudget:** Vom offenen Zustand aus ist „Satz 1 sichern" ohne Zwischentap erreichbar. Zwei Interaktionen im Abweichungsfall, eine im Normalfall.
3. **Akzentregel:** Genau eine Akzentfläche — die Hauptaktion. Der Gewichts-Unterstrich ist eine Linie, keine Fläche; „andere Übung" ist `text-muted`; der Reserve-Chip ist Umriss.
4. **Anschlag:** Bis 150,0 scrollen — die Kontextzeile wechselt sichtbar auf „Maximum des Geräts erreicht" und es klopft haptisch.
5. **Pause:** Nach „Satz 1 sichern" fährt der Balken von oben ein, die Hauptaktion heißt „Satz 2 sichern", das Rad ist zu.
6. **VoiceOver:** Die Hauptaktion liest „Satz 2 sichern, 80,0 Kilogramm" als **eine** Zeichenkette.
7. **Dynamic Type XXL:** Die Wertzeile bricht um statt zu skalieren; nichts wird abgeschnitten.
8. **Reduce Motion:** Öffnen und Pause sind Zustandswechsel ohne Interpolation; alle Informationen bleiben.

- [ ] **Step 6: Commit**

```bash
git add apps/ios-member/FitnessMember/Screens/Geraet
git commit -m "feat(ios): GeraetView -- ein Screen, drei Zustaende

Main, GeraetWertRad und GeraetResttimer sind keine Navigationsziele.
designsystem.md SS7 verlangt dieselbe Silhouette in Ruhe und Offen -- zwei
Views waeren hier der Fehler.

Ein Tap auf eine der beiden Zahlen oeffnet beide Raeder; 'Satz N sichern'
bleibt im offenen Zustand sichtbar und sichert direkt. Damit bleibt auch
der Abweichungsfall bei zwei Interaktionen (SS9, Abnahmebedingung).

Am Anschlag wechselt die Kontextzeile sichtbar auf 'Maximum des Geraets
erreicht' -- die Design-Challenge fand, dass es dafuer bisher nur eine
VoiceOver-Ansage gab."
```

---

### Aufgabe 13: Der Erstkontakt-Dreischritt

Einweisung → Kalibrierung → erste Werte. Ein `.fullScreenCover` — er ist der einzige Ort ohne Tab-Leiste, und `fullScreenCover` verdeckt sie. Er läuft genau einmal je Gerät **und** Übung.

**Artboards:** `GeraetEinweisung.dc.html`, `GeraetKalibrierung.dc.html`, `GeraetErsteWerte.dc.html`. **Abweichungen (Spec Abschnitt 9):** „Kenne ich schon — direkt zum Satz" wird zu **„Kenne ich schon"** und überspringt nur die Einweisung; der Gewichtswert ist 64 pt (das Artboard zeigt 58 px); der deaktivierte Stepper nutzt `surface-raised`; die „ohne Video"-Variante kommt dazu.

**Files:**
- Create: `apps/ios-member/FitnessMember/DesignSystem/Components/Stepper44.swift`
- Create: `apps/ios-member/FitnessMember/Screens/Geraet/ErstkontaktFlow.swift`
- Create: `apps/ios-member/FitnessMember/Screens/Geraet/EinweisungSchritt.swift`
- Create: `apps/ios-member/FitnessMember/Screens/Geraet/KalibrierungSchritt.swift`
- Create: `apps/ios-member/FitnessMember/Screens/Geraet/ErsteWerteSchritt.swift`

**Interfaces:**
- Consumes: `GeraetModel` (Aufgabe 10), `RastRad`/`Rastwerte` (Aufgabe 7), `CalibrationWrite`/`GeraetLoading` (Aufgabe 8), `Zahlformat`/`PressButtonStyle` (Aufgabe 3).
- Produces: `struct Stepper44: View { let definition: TagContextResponse.SettingDefinition; @Binding var wert: Double }`
- Produces: `struct ErstkontaktFlow: View { let modell: GeraetModel; let beiAbschluss: () -> Void }` — von Aufgabe 16 konsumiert.
- Produces in `GeraetModel`: `var entwurfEinstellung: [String: Double]`, `var trainerDabei: Bool`, `var kalibrierungFehler: String?`, `func kalibrierungSichern() async -> Bool`.

- [ ] **Step 1: `Stepper44` schreiben**

Create `apps/ios-member/FitnessMember/DesignSystem/Components/Stepper44.swift`:

```swift
import SwiftUI

/// ± Stepper fuer die Kalibrierung.
///
/// Kein Rad: die Wertebereiche sind einstellig, dort waere ein Rad mehr
/// Mechanik als Nutzen (designsystem.md SS8).
struct Stepper44: View {
    let definition: TagContextResponse.SettingDefinition
    @Binding var wert: Double

    private var schritt: Double { definition.stepValue ?? 1 }
    private var untergrenze: Double { definition.minValue ?? 0 }
    private var obergrenze: Double { definition.maxValue ?? 99 }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.s16) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                Text(definition.label)
                    .font(DesignSystem.Typography.uebungsname)
                    .foregroundStyle(DesignSystem.Color.text)
                Text(bereichstext)
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Color.textFaint)
            }
            Spacer()
            taste("minus", aktiv: wert > untergrenze) { wert = max(untergrenze, wert - schritt) }
            Text(anzeige)
                .font(DesignSystem.Typography.wertSekundaer)
                .foregroundStyle(DesignSystem.Color.text)
                .frame(minWidth: 48)
            taste("plus", aktiv: wert < obergrenze) { wert = min(obergrenze, wert + schritt) }
        }
        .padding(DesignSystem.Spacing.s16)
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(definition.label)
        .accessibilityValue(anzeige)
        .accessibilityAdjustableAction { richtung in
            switch richtung {
            case .increment: wert = min(obergrenze, wert + schritt)
            case .decrement: wert = max(untergrenze, wert - schritt)
            @unknown default: break
            }
        }
    }

    private var anzeige: String {
        let zahl = wert == wert.rounded() ? String(Int(wert)) : Zahlformat.gewicht(wert)
        return definition.unit.map { "\(zahl)\($0)" } ?? zahl
    }

    private var bereichstext: String {
        let von = untergrenze == untergrenze.rounded() ? String(Int(untergrenze)) : Zahlformat.gewicht(untergrenze)
        let bis = obergrenze == obergrenze.rounded() ? String(Int(obergrenze)) : Zahlformat.gewicht(obergrenze)
        let einheit = definition.unit ?? ""
        let s = schritt == schritt.rounded() ? String(Int(schritt)) : Zahlformat.gewicht(schritt)
        return "\(von) – \(bis)\(einheit) · Schritt \(s)"
    }

    /// Deaktiviert traegt surface-raised auf text-faint (designsystem.md SS5)
    /// -- das Artboard nutzt hier faelschlich surface.
    private func taste(_ symbol: String, aktiv: Bool, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .bold))
                .frame(width: 44, height: 44)
                .background(DesignSystem.Color.surfaceRaised)
                .foregroundStyle(aktiv ? DesignSystem.Color.text : DesignSystem.Color.textFaint)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.neben))
        }
        .buttonStyle(PressButtonStyle())
        .disabled(!aktiv)
        .accessibilityHidden(true)
    }
}
```

- [ ] **Step 2: Die drei Schritte schreiben**

Create `apps/ios-member/FitnessMember/Screens/Geraet/EinweisungSchritt.swift`:

```swift
import AVKit
import SwiftUI

/// Schritt 1 von 3.
///
/// Zwei Abweichungen vom Artboard (Spec Abschnitt 9): Der Link heisst nur
/// "Kenne ich schon" und ueberspringt NUR die Einweisung -- uebersprunge er
/// den ganzen Dreischritt, gaebe es weder Kalibrierung noch Startwert, und
/// die Regel "kein Vorschlag beim ersten Mal" haette nichts, worauf sie
/// fallen koennte. Und es gibt eine Variante ohne Video, die als Artboard
/// fehlt: ein Geraet ohne Video ist nutzbar (M1-Spec SS8.2).
struct EinweisungSchritt: View {
    let modell: GeraetModel
    let beiWeiter: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
                Text("SCHRITT 1 VON 3 · EINWEISUNG")
                    .font(DesignSystem.Typography.label)
                    .tracking(1.5)
                    .foregroundStyle(DesignSystem.Color.textFaint)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                    Text(modell.maschine.equipmentModel.name.uppercased())
                        .font(DesignSystem.Typography.geraetename)
                        .tracking(-0.8)
                        .foregroundStyle(DesignSystem.Color.text)
                    Text(modell.aktiveUebung?.name ?? "")
                        .font(DesignSystem.Typography.uebungsname)
                        .foregroundStyle(DesignSystem.Color.textMuted)
                }

                medien

                if let beschreibung = modell.kontext?.exercises
                    .first(where: { $0.id == modell.uebungId })?.description {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
                        Text("Worauf du achten musst")
                            .font(DesignSystem.Typography.uebungsname)
                            .foregroundStyle(DesignSystem.Color.text)
                        Text(beschreibung)
                            .font(DesignSystem.Typography.fliesstext)
                            .foregroundStyle(DesignSystem.Color.textMuted)
                            .lineSpacing(4)
                    }
                }

                Text(modell.produktgrenze)
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Color.textFaint)
                    .lineSpacing(3)

                PrimaryButton(title: "Einstellungen erfassen") { beiWeiter() }

                Button("Kenne ich schon", action: beiWeiter)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .buttonStyle(PressButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, DesignSystem.Spacing.s32)
        }
        .background(DesignSystem.Color.bg)
    }

    /// Die Variante ohne Video ist kein Fehlerzustand -- ein Geraet ohne
    /// Video ist nutzbar. Nur das Skelett ist hier erlaubt (SS5: Skelette
    /// ausschliesslich fuer Medien).
    @ViewBuilder
    private var medien: some View {
        if let video = modell.aktiveUebung?.videoURL {
            VideoPlayer(player: AVPlayer(url: video))
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        } else if modell.kontext == nil {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                .fill(DesignSystem.Color.surfaceRaised)
                .frame(height: 200)
                .overlay(
                    Text("Einweisungsvideo braucht Empfang.")
                        .font(.system(size: 13))
                        .foregroundStyle(DesignSystem.Color.textFaint)
                )
        } else {
            Text("Für diese Übung hat dein Studio kein Video hinterlegt.")
                .font(.system(size: 13))
                .foregroundStyle(DesignSystem.Color.textFaint)
        }
    }
}
```

Create `apps/ios-member/FitnessMember/Screens/Geraet/KalibrierungSchritt.swift`:

```swift
import SwiftUI

/// Schritt 2 von 3 -- und zugleich der Screen hinter "aendern" auf
/// GeraetView. Genau dieser Fall ausserhalb des Dreischritts macht den
/// eigenen Endpoint noetig.
struct KalibrierungSchritt: View {
    @Bindable var modell: GeraetModel
    let titel: String
    let beiFertig: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
                Text(titel.uppercased())
                    .font(DesignSystem.Typography.label)
                    .tracking(1.5)
                    .foregroundStyle(DesignSystem.Color.textFaint)

                Text(modell.maschine.equipmentModel.name.uppercased())
                    .font(DesignSystem.Typography.geraetename)
                    .tracking(-0.8)
                    .foregroundStyle(DesignSystem.Color.text)

                Text("Stell das Gerät jetzt so ein, wie es für dich passt. Beim nächsten Mal steht es hier — du musst nicht nachdenken.")
                    .font(DesignSystem.Typography.fliesstext)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .lineSpacing(4)

                ForEach(modell.einstellDefinitionen) { definition in
                    Stepper44(
                        definition: definition,
                        wert: Binding(
                            get: { modell.entwurfEinstellung[definition.key] ?? definition.minValue ?? 0 },
                            set: { modell.entwurfEinstellung[definition.key] = $0 }
                        )
                    )
                }

                Toggle("Ein Trainer war dabei", isOn: $modell.trainerDabei)
                    .tint(DesignSystem.Color.accent)
                    .foregroundStyle(DesignSystem.Color.text)
                Text("Wird an der Einstellung vermerkt. Ändern darfst du sie trotzdem jederzeit selbst.")
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Color.textFaint)

                if let fehler = modell.kalibrierungFehler {
                    InlineBanner(tone: .danger, message: fehler)
                }

                PrimaryButton(title: "Speichern und weiter") {
                    if await modell.kalibrierungSichern() { beiFertig() }
                }

                Text("Deine vorherigen Einstellungen bleiben erhalten — jede Änderung legt eine neue Zeile an.")
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Color.textFaint)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, DesignSystem.Spacing.s32)
        }
        .background(DesignSystem.Color.bg)
    }
}
```

**Hinweis:** `InlineBanner` stammt unverändert aus Sub-Projekt 1: `InlineBanner(tone: BannerTone, message: String, icon: String? = nil)` mit `BannerTone.danger`. Keine zweite bauen.

Create `apps/ios-member/FitnessMember/Screens/Geraet/ErsteWerteSchritt.swift`:

```swift
import SwiftUI

/// Schritt 3 von 3. Fuehrt die Rad-Geste zum ersten Mal ein -- deshalb ist
/// die Groesse hier dieselbe wie ueberall (64pt), nicht 58 wie im Artboard.
///
/// gymodo schlaegt beim ersten Mal bewusst nichts vor: es hat keine
/// Historie, und ein Vorschlag ohne Daten waere eine Trainingsempfehlung
/// (designsystem.md SS8). Das Rad startet am Geraetminimum.
struct ErsteWerteSchritt: View {
    @Bindable var modell: GeraetModel
    let beiSichern: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
                Text("SCHRITT 3 VON 3 · ERSTE WERTE")
                    .font(DesignSystem.Typography.label)
                    .tracking(1.5)
                    .foregroundStyle(DesignSystem.Color.textFaint)

                Text(modell.maschine.equipmentModel.name.uppercased())
                    .font(DesignSystem.Typography.geraetename)
                    .tracking(-0.8)
                    .foregroundStyle(DesignSystem.Color.text)

                Text("Womit fängst du an? Stell ein, was sich für dich richtig anfühlt — ab dem nächsten Mal steht dein Wert hier von allein.")
                    .font(DesignSystem.Typography.fliesstext)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .lineSpacing(4)

                WertZeile(modell: modell)

                Text("gymodo schlägt beim ersten Mal bewusst nichts vor — es kennt dich noch nicht. Vorschläge entstehen erst aus deiner eigenen Historie.")
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Color.textFaint)
                    .lineSpacing(3)

                PrimaryButton(title: "Ersten Satz sichern") {
                    await modell.satzSichern(problemFlag: false, problemReason: nil)
                    beiSichern()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, DesignSystem.Spacing.s32)
        }
        .background(DesignSystem.Color.bg)
        .onAppear { modell.radOffen = true }
    }
}
```

- [ ] **Step 3: Die Hülle schreiben**

Create `apps/ios-member/FitnessMember/Screens/Geraet/ErstkontaktFlow.swift`:

```swift
import SwiftUI

/// Der modale Dreischritt. fullScreenCover verdeckt die Tab-Leiste -- genau
/// das verlangt designsystem.md SS8 ("ohne Tab-Leiste"). Er laeuft genau
/// einmal je Geraet UND Uebung.
struct ErstkontaktFlow: View {
    @Bindable var modell: GeraetModel
    let beiAbschluss: () -> Void

    @State private var schritt = 1

    var body: some View {
        Group {
            switch schritt {
            case 1: EinweisungSchritt(modell: modell) { schritt = 2 }
            case 2: KalibrierungSchritt(modell: modell,
                                        titel: "Schritt 2 von 3 · Deine Einstellung") { schritt = 3 }
            default: ErsteWerteSchritt(modell: modell, beiSichern: beiAbschluss)
            }
        }
        .background(DesignSystem.Color.bg)
    }
}
```

- [ ] **Step 4: `GeraetModel` um die Kalibrierung erweitern**

In `GeraetModel.swift`:

```swift
    var entwurfEinstellung: [String: Double] = [:]
    var trainerDabei = false
    private(set) var kalibrierungFehler: String?

    var einstellDefinitionen: [TagContextResponse.SettingDefinition] { definitionen }

    /// Fuellt den Entwurf mit den bisherigen Werten, sonst mit dem Minimum.
    func kalibrierungVorbereiten() {
        var entwurf: [String: Double] = [:]
        let bisherige: [String: JSONValue]
        if case .object(let werte)? = kalibrierungswerte { bisherige = werte } else { bisherige = [:] }
        for definition in definitionen {
            if case .number(let zahl)? = bisherige[definition.key] {
                entwurf[definition.key] = zahl
            } else {
                entwurf[definition.key] = definition.minValue ?? 0
            }
        }
        entwurfEinstellung = entwurf
        kalibrierungFehler = nil
    }

    /// Gibt zurueck, ob gespeichert wurde. Die Fehlermeldung kommt vom
    /// Server -- er kennt die Grenzen und formuliert, was gilt
    /// (designsystem.md SS5).
    func kalibrierungSichern() async -> Bool {
        kalibrierungFehler = nil
        let werte = entwurfEinstellung.mapValues { JSONValue.number($0) }
        do {
            _ = try await loader.recordCalibration(
                CalibrationWrite(
                    machineId: maschine.id, exerciseId: uebungId,
                    settingValues: werte, schemaVersion: 1,
                    source: trainerDabei ? "trainer_assisted" : "self"
                )
            )
            kalibrierungOffen = false
            return true
        } catch {
            kalibrierungFehler = switch error {
            case .offline: "Ohne Empfang lässt sich die Einstellung nicht speichern. Deine Sätze gehen trotzdem raus."
            case .validation(let text), .server(let text), .notFound(let text),
                 .conflict(let text), .unauthorized(let text): text
            case .decodingFailed: "Unerwartete Antwort vom Server."
            }
            return false
        }
    }
```

Und `kalibrierungswerte` von `private var` auf `private(set) var`/intern zugreifbar lassen — es wird jetzt aus `kalibrierungVorbereiten()` gelesen, steht aber im selben Typ, also genügt `private`.

- [ ] **Step 5: Bauen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" build 2>&1 | tail -20
```

Erwartet: BUILD SUCCEEDED.

- [ ] **Step 6: Gegen drei Artboards abnehmen**

1. Der Dreischritt zeigt **keine** Tab-Leiste.
2. „Kenne ich schon" springt zu Schritt 2, nicht ans Ende.
3. Ein Gerät ohne Video zeigt Schritt 1 ohne Player und ohne Fehlermeldung.
4. Der deaktivierte Stepper (am Minimum) ist `surface-raised` auf `text-faint`, nicht `surface`.
5. Der Gewichtswert in Schritt 3 ist 64 pt, wie überall.
6. Schritt 3 zeigt keinen Vorschlag; das Rad steht am Gerätminimum.
7. Ein ungültiger Einstellwert (Simulator: `sitz` über das Maximum steppen ist unmöglich — teste stattdessen den Offline-Fall im Flugmodus) zeigt den Serversatz, nicht „ungültig".

- [ ] **Step 7: Commit**

```bash
git add apps/ios-member/FitnessMember/Screens/Geraet apps/ios-member/FitnessMember/DesignSystem/Components/Stepper44.swift
git commit -m "feat(ios): Erstkontakt-Dreischritt

fullScreenCover verdeckt die Tab-Leiste -- genau das verlangt
designsystem.md SS8. Der Dreischritt laeuft einmal je Geraet UND Uebung.

Drei Abweichungen vom Artboard (Spec Abschnitt 9): 'Kenne ich schon'
ueberspringt nur die Einweisung, nicht den ganzen Dreischritt -- sonst gaebe
es weder Kalibrierung noch Startwert. Der Gewichtswert ist 64pt wie ueberall.
Der deaktivierte Stepper traegt surface-raised. Dazu die Variante ohne
Video, die als Artboard fehlt: ein Geraet ohne Video ist nutzbar.

Kalibrierungsfehler kommen woertlich vom Server -- er kennt die Grenzen und
formuliert, was gilt, statt nur 'ungueltig'."
```

---

### Aufgabe 14: Die zwei Sheets — Übung wechseln, Problem melden

Beide Artboards tragen den Kommentar „abgedunkelter Geräte-Screen dahinter · Sheet". Das ist keine Gestaltungslaune: Der Geräte-Screen bleibt sichtbar, weil beide Aktionen sich auf ihn beziehen.

**Die Problemmeldung braucht keinen eigenen Endpoint** — sie sind zwei Felder im Satz-`PUT` (M1-Spec §6.3). Und sie ist **ohne Freitext**: Boolean plus feste Liste. Ein Feld, das nicht existiert, muss nicht geschützt, exportiert oder gelöscht werden.

**Artboards:** `GeraetUebungWechseln.dc.html`, `GeraetProblem.dc.html`. **Abweichungen (Spec Abschnitt 9):** Das Warn-Badge ist Umriss statt Fläche; die Hauptaktion ist 64 pt (das Artboard zeigt 60 px).

**Files:**
- Create: `apps/ios-member/FitnessMember/Screens/Geraet/UebungWechselnSheet.swift`
- Create: `apps/ios-member/FitnessMember/Screens/Geraet/ProblemSheet.swift`

**Interfaces:**
- Consumes: `GeraetModel` (Aufgabe 10), `Zahlformat`/`PressButtonStyle`/`DesignSystem` (Aufgabe 3), `ProblemReason` (Sub-Projekt 1).
- Produces: `struct UebungWechselnSheet: View { let modell: GeraetModel; let beiWechsel: (String) -> Void }` — von Aufgabe 16 konsumiert.
- Produces: `struct ProblemSheet: View { let modell: GeraetModel; let beiSichern: () -> Void }` — von Aufgabe 16 konsumiert.

- [ ] **Step 1: `UebungWechselnSheet` schreiben**

Create `apps/ios-member/FitnessMember/Screens/Geraet/UebungWechselnSheet.swift`:

```swift
import SwiftUI

/// Sheet statt Push: der Geraete-Screen bleibt dahinter sichtbar, weil sich
/// die Aktion auf ihn bezieht (Artboard-Kommentar).
struct UebungWechselnSheet: View {
    let modell: GeraetModel
    let beiWechsel: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
                    Text("\(modell.maschine.equipmentModel.name) · \(modell.maschine.label)")
                        .font(.system(size: 13))
                        .foregroundStyle(DesignSystem.Color.textMuted)

                    ForEach(modell.uebungen) { uebung in
                        Button {
                            beiWechsel(uebung.id)
                            dismiss()
                        } label: {
                            zeile(uebung)
                        }
                        .buttonStyle(PressButtonStyle())
                    }

                    Text("Ein Wechsel öffnet einen neuen Block im Training. Deine bisherigen Sätze bleiben erhalten — du kannst jederzeit zurück.")
                        .font(.system(size: 12))
                        .foregroundStyle(DesignSystem.Color.textFaint)
                        .lineSpacing(3)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, DesignSystem.Spacing.s24)
            }
            .background(DesignSystem.Color.bg)
            .navigationTitle("Übung wechseln")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                        .foregroundStyle(DesignSystem.Color.textMuted)
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func zeile(_ uebung: GeraetUebung) -> some View {
        let laeuft = uebung.id == modell.uebungId
        return HStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                Text(uebung.name)
                    .font(DesignSystem.Typography.uebungsname)
                    .foregroundStyle(DesignSystem.Color.text)
                Text(untertitel(uebung, laeuft: laeuft))
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }
            Spacer()
        }
        .padding(DesignSystem.Spacing.s16)
        .frame(minHeight: 44)
        .background(laeuft ? DesignSystem.Color.surfaceRaised : DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        .accessibilityElement(children: .combine)
    }

    private func untertitel(_ uebung: GeraetUebung, laeuft: Bool) -> String {
        if laeuft { return "läuft" }
        if let gewicht = modell.letztesGewicht(fuer: uebung.id) {
            return "\(Zahlformat.gewichtMitEinheit(gewicht)) · zuletzt"
        }
        return "Noch nie trainiert · Ziel \(uebung.targetRepsMin) – \(uebung.targetRepsMax) Wdh."
    }
}
```

- [ ] **Step 2: `ProblemSheet` schreiben**

Create `apps/ios-member/FitnessMember/Screens/Geraet/ProblemSheet.swift`:

```swift
import SwiftUI

/// Boolean plus feste Liste, kein Freitext -- Freitext ueber Schmerzen waeren
/// besondere Kategorien nach Art. 9 DSGVO. Ein Feld, das nicht existiert,
/// muss nicht geschuetzt, exportiert oder geloescht werden (M1-Spec SS5.8).
///
/// Die Meldung braucht keinen eigenen Endpoint: sie sind zwei Felder im
/// Satz-PUT (M1-Spec SS6.3).
struct ProblemSheet: View {
    let modell: GeraetModel
    let beiSichern: () -> Void

    @State private var grund: ProblemReason?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
                    kopf
                    Text("Was ist los?")
                        .font(DesignSystem.Typography.uebungsname)
                        .foregroundStyle(DesignSystem.Color.text)
                    Text("Wird an diesem Satz vermerkt. Solange etwas gemeldet ist, schlägt gymodo keine Steigerung vor.")
                        .font(.system(size: 13))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                        .lineSpacing(3)

                    VStack(spacing: DesignSystem.Spacing.s8) {
                        ForEach(ProblemReason.allCases, id: \.self) { ursache in
                            Button { grund = ursache } label: { zeile(ursache) }
                                .buttonStyle(PressButtonStyle())
                        }
                    }

                    Text("Kein Freitextfeld — mit Absicht. Was du nicht schreiben kannst, muss auch niemand schützen, exportieren oder löschen. Sprich mit deinem Studio, wenn mehr dahintersteckt.")
                        .font(.system(size: 12))
                        .foregroundStyle(DesignSystem.Color.textFaint)
                        .lineSpacing(3)

                    PrimaryButton(
                        title: "Melden und Satz sichern",
                        isEnabled: grund != nil,
                        disabledHint: "Wähle aus, was los ist."
                    ) {
                        await modell.satzSichern(problemFlag: true, problemReason: grund)
                        beiSichern()
                        dismiss()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, DesignSystem.Spacing.s24)
            }
            .background(DesignSystem.Color.bg)
            .navigationTitle("Problem melden")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                        .foregroundStyle(DesignSystem.Color.textMuted)
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var kopf: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("\(modell.maschine.equipmentModel.name) · \(modell.aktiveUebung?.name ?? "")")
                .font(.system(size: 13))
                .foregroundStyle(DesignSystem.Color.textMuted)
            Spacer()
            Text(Zahlformat.gewichtMitEinheit(modell.gewicht))
                .font(DesignSystem.Typography.wertSekundaer)
                .foregroundStyle(DesignSystem.Color.text)
        }
    }

    private func zeile(_ ursache: ProblemReason) -> some View {
        let gewaehlt = grund == ursache
        return HStack(spacing: DesignSystem.Spacing.s12) {
            // warn NUR als Umriss, nie als Flaeche -- das Artboard fuellt hier
            // faelschlich (Spec Abschnitt 9). Eine warngelbe Flaeche liesse
            // die Meldung als Fehlverhalten lesen.
            Circle()
                .strokeBorder(gewaehlt ? DesignSystem.Color.warn : DesignSystem.Color.line,
                              lineWidth: gewaehlt ? 6 : 1.5)
                .frame(width: 22, height: 22)
            Text(beschriftung(ursache))
                .font(DesignSystem.Typography.uebungsname)
                .foregroundStyle(DesignSystem.Color.text)
            Spacer()
        }
        .padding(DesignSystem.Spacing.s16)
        .frame(minHeight: 44)
        .background(DesignSystem.Color.surface)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                .stroke(gewaehlt ? DesignSystem.Color.warn : Color.clear, lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(gewaehlt ? [.isButton, .isSelected] : .isButton)
    }

    private func beschriftung(_ ursache: ProblemReason) -> String {
        switch ursache {
        case .schmerz: "Schmerzen"
        case .geraetePasstNicht: "Gerät passt mir nicht"
        case .zuSchwer: "Zu schwer"
        case .sonstiges: "Etwas anderes"
        }
    }
}
```

- [ ] **Step 3: Bauen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" build 2>&1 | tail -20
```

Erwartet: BUILD SUCCEEDED. Schlägt `ProblemReason.allCases` fehl, prüfe `DTOs/WorkoutSet.swift` — dort ist `CaseIterable` bereits deklariert.

- [ ] **Step 4: Gegen beide Artboards abnehmen**

1. Beide öffnen als Sheet mit Anfasser; der Geräte-Screen bleibt abgedunkelt dahinter sichtbar.
2. `GeraetProblem`: Das Auswahl-Badge ist ein **Umriss** in `warn`, keine gefüllte Fläche. Die Hauptaktion ist 64 pt.
3. Ohne Auswahl ist „Melden und Satz sichern" deaktiviert **und nicht stumm** — daneben steht „Wähle aus, was los ist."
4. Es gibt **nirgends** ein Textfeld.
5. `GeraetUebungWechseln`: Die laufende Übung ist als „läuft" markiert; ein Wechsel schließt das Sheet und öffnet einen neuen Block.

- [ ] **Step 5: Commit**

```bash
git add apps/ios-member/FitnessMember/Screens/Geraet
git commit -m "feat(ios): Sheets fuer Uebungswechsel und Problemmeldung

Beide als Sheet, nicht als Push: der Geraete-Screen bleibt dahinter
sichtbar, weil sich beide Aktionen auf ihn beziehen.

Die Problemmeldung ist Boolean plus feste Liste, ohne Freitext -- Freitext
ueber Schmerzen waeren besondere Kategorien nach Art. 9 DSGVO. Sie braucht
keinen eigenen Endpoint: zwei Felder im Satz-PUT.

Abweichung vom Artboard (Spec Abschnitt 9): das Warn-Badge ist Umriss statt
Flaeche. Eine warngelbe Flaeche liesse die Meldung als Fehlverhalten lesen --
genau davor warnt designsystem.md SS2 selbst."
```

---

### Aufgabe 15: Offline-Zustand und der Reconnect-Moment

`GeraetOffline` ist laut Design-Challenge die sauberste Umsetzung von §5 in der ganzen Canvas — mit einer Lücke: der Reconnect-Moment fehlt. Er wird hier festgelegt.

**Der Ton ist nicht verhandelbar:** „gespeichert, wird gesendet", **nie** „fehlgeschlagen". Der Satz ist lokal sicher; das muss die Sprache tragen.

**Artboard:** `GeraetOffline.dc.html`. **Abweichungen (Spec Abschnitt 9):** Statt des Gerätefotos steht der Platzhalter, weil `bootstrap` keine signierte URL liefert und in diesem Sub-Projekt bewusst kein Medien-Cache gebaut wird; dazu kommt der Reconnect-Zustand.

**Files:**
- Create: `apps/ios-member/FitnessMember/Screens/Geraet/OfflineLeiste.swift`
- Modify: `apps/ios-member/FitnessMember/Screens/Geraet/GeraetView.swift`

**Interfaces:**
- Consumes: `NetzwerkMonitor` (Aufgabe 4), `CatalogStore.pendingWrites`/`verworfeneWrites`/`verworfeneQuittieren()` (Aufgabe 4), `DesignSystem` (Aufgabe 3).
- Produces: `struct OfflineLeiste: View { let istOnline: Bool }`
- Produces: `struct WarteschlangeKarte: View { let offen: Int; let geradeGesendet: Bool }`
- Produces: `struct AbgelehnteKarte: View { let anzahl: Int; let beiQuittieren: () -> Void }`

- [ ] **Step 1: Die drei Bausteine schreiben**

Create `apps/ios-member/FitnessMember/Screens/Geraet/OfflineLeiste.swift`:

```swift
import SwiftUI

/// danger-Umriss auf 10 % danger-Flaeche (designsystem.md SS5).
struct OfflineLeiste: View {
    let istOnline: Bool

    var body: some View {
        if !istOnline {
            HStack(spacing: DesignSystem.Spacing.s8) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 15, weight: .semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Kein Empfang")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Alles hier kommt aus dem Speicher deines iPhones.")
                        .font(.system(size: 13))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                }
                Spacer()
            }
            .foregroundStyle(DesignSystem.Color.danger)
            .padding(DesignSystem.Spacing.s12)
            .background(DesignSystem.Color.danger.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                    .stroke(DesignSystem.Color.danger, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
            .accessibilityElement(children: .combine)
        }
    }
}

/// Die Warteschlange.
///
/// Die Formulierung ist nicht verhandelbar: "gespeichert, wird gesendet",
/// nie "fehlgeschlagen" (designsystem.md SS5). Der Satz ist lokal sicher;
/// das muss die Sprache tragen.
///
/// `geradeGesendet` ist der Reconnect-Moment, der als Artboard fehlt: zwei
/// Sekunden "Gesendet", dann aus. Kein Toast, kein Haekchen-Jubel -- SS10
/// verbietet den Motivationston, und ein erfolgreicher Normalfall braucht
/// keine Feier.
struct WarteschlangeKarte: View {
    let offen: Int
    let geradeGesendet: Bool

    var body: some View {
        if offen > 0 || geradeGesendet {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                Text(geradeGesendet ? "GESENDET" : "WARTET AUF EMPFANG · \(offen) \(offen == 1 ? "SATZ" : "SÄTZE")")
                    .font(DesignSystem.Typography.label)
                    .tracking(1.5)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                if !geradeGesendet {
                    Text("Sicher gespeichert. Sie gehen automatisch raus, sobald du wieder Netz hast — auch wenn du die App schließt.")
                        .font(.system(size: 13))
                        .foregroundStyle(DesignSystem.Color.textFaint)
                        .lineSpacing(3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignSystem.Spacing.s16)
            .background(DesignSystem.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
            .accessibilityElement(children: .combine)
        }
    }
}

/// Dauerhaft abgelehnte Schreibvorgaenge. Sie verschwinden nicht
/// stillschweigend -- SS5 verlangt, dass ein Fehler sagt, was falsch ist UND
/// was gilt.
struct AbgelehnteKarte: View {
    let anzahl: Int
    let beiQuittieren: () -> Void

    var body: some View {
        if anzahl > 0 {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
                Text("\(anzahl) \(anzahl == 1 ? "Satz konnte" : "Sätze konnten") nicht gespeichert werden.")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.danger)
                Text("Das Gerät oder die Übung gibt es in deinem Studio nicht mehr. Deine übrigen Sätze sind unberührt.")
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .lineSpacing(3)
                Button("Verstanden", action: beiQuittieren)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.text)
                    .frame(minHeight: 44)
                    .buttonStyle(PressButtonStyle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignSystem.Spacing.s16)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.card)
                    .stroke(DesignSystem.Color.danger, lineWidth: 1)
            )
            .accessibilityElement(children: .combine)
        }
    }
}
```

- [ ] **Step 2: In `GeraetView` einhängen**

In `GeraetView.swift` die Umgebung und den Reconnect-Zustand ergänzen:

```swift
    @Environment(NetzwerkMonitor.self) private var netz
    @Environment(CatalogStore.self) private var katalog
    @State private var geradeGesendet = false
```

Im `VStack`, direkt unter `kopfzeile`:

```swift
                OfflineLeiste(istOnline: netz.istOnline)
                WarteschlangeKarte(offen: katalog.pendingWrites.count,
                                   geradeGesendet: geradeGesendet)
                AbgelehnteKarte(anzahl: katalog.verworfeneWrites.count,
                                beiQuittieren: katalog.verworfeneQuittieren)
```

Und am Ende der `body`-Modifikatoren:

```swift
        // Der Reconnect-Moment: laeuft die Schlange leer, steht zwei
        // Sekunden "Gesendet", dann verschwindet die Karte.
        .onChange(of: katalog.pendingWrites.count) { alt, neu in
            guard alt > 0, neu == 0 else { return }
            geradeGesendet = true
            Task {
                try? await Task.sleep(for: .seconds(2))
                geradeGesendet = false
            }
        }
```

- [ ] **Step 3: Bauen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" build 2>&1 | tail -20
```

Erwartet: BUILD SUCCEEDED. `NetzwerkMonitor` und `CatalogStore` kommen erst in Aufgabe 16 in die Umgebung — bis dahin baut es, stürzt aber beim Öffnen des Screens ab. Das ist erwartet; Aufgabe 16 schließt es.

- [ ] **Step 4: Commit**

```bash
git add apps/ios-member/FitnessMember/Screens/Geraet
git commit -m "feat(ios): Offline-Zustand und der Reconnect-Moment

Die Formulierung ist nicht verhandelbar: 'gespeichert, wird gesendet', nie
'fehlgeschlagen'. Der Satz ist lokal sicher; das muss die Sprache tragen.

Der Reconnect-Moment fehlte als Artboard und wird hier festgelegt: zwei
Sekunden 'Gesendet', dann aus. Kein Toast, kein Haekchen-Jubel -- ein
erfolgreicher Normalfall braucht keine Feier.

Dauerhaft abgelehnte Schreibvorgaenge verschwinden nicht stillschweigend:
SS5 verlangt, dass ein Fehler sagt, was falsch ist und was gilt."
```

---

### Aufgabe 16: Training-Wurzel, Navigation und Verdrahtung

Der letzte Schritt: Der Geräte-Screen bekommt seinen Platz. Er ist ein Push **innerhalb** des Training-Tabs und behält die Tab-Leiste (§11) — nie ein eigener Tab.

Die minimale Training-Wurzel kommt mit, weil der Kernflow sonst nicht schließbar wäre: `POST .../complete` hätte keinen Auslöser, „Zurück zum Training" liefe ins Leere, und der Zirkelfall aus M1-Spec §5.3 wäre nicht baubar.

**Files:**
- Create: `apps/ios-member/FitnessMember/Navigation/GeraetRoute.swift`
- Create: `apps/ios-member/FitnessMember/Screens/Training/TrainingRootView.swift`
- Modify: `apps/ios-member/FitnessMember/Navigation/MainTabView.swift`
- Modify: `apps/ios-member/FitnessMember/FitnessMemberApp.swift`
- Modify: `apps/ios-member/FitnessMember/Navigation/RootView.swift`

**Interfaces:**
- Consumes: alles aus den Aufgaben 4 bis 15.
- Produces: `enum GeraetRoute: Hashable { case erkannt(machineId: String, token: String?); case geraet(machineId: String, exerciseId: String, token: String?) }`
- Produces: `struct TrainingRootView: View`

- [ ] **Step 1: Die Route anlegen**

Create `apps/ios-member/FitnessMember/Navigation/GeraetRoute.swift`:

```swift
import Foundation

/// Der typisierte Pfad des Training-Tabs.
///
/// Der Geraete-Screen ist kein Tab -- er wird als Push INNERHALB von
/// Training geoeffnet und behaelt die Tab-Leiste (designsystem.md SS11).
enum GeraetRoute: Hashable {
    case erkannt(machineId: String, token: String?)
    case geraet(machineId: String, exerciseId: String, token: String?)
}
```

- [ ] **Step 2: Die Training-Wurzel schreiben**

Create `apps/ios-member/FitnessMember/Screens/Training/TrainingRootView.swift`:

```swift
import SwiftUI

/// Bewusst schmucklos: Scan-Button, Blockliste, "Training beenden".
///
/// Der Artboard-Ausbau nach TrainingLeer / TrainingLaeuft / TrainingAbschluss
/// gehoert zu Sub-Projekt 3. Diese Wurzel kommt hier mit, weil der Kernflow
/// sonst nicht schliessbar waere: POST .../complete haette keinen Ausloeser,
/// "Zurueck zum Training" liefe ins Leere, und der Zirkelfall aus M1-Spec
/// SS5.3 waere nicht baubar.
struct TrainingRootView: View {
    @Environment(CatalogStore.self) private var katalog
    @Environment(WorkoutSessionStore.self) private var sessions
    @Environment(PendingTagStore.self) private var pendingTag

    let apiClient: APIClient

    @State private var pfad: [GeraetRoute] = []
    @State private var scannerOffen = false
    @State private var scanFehler: String?

    var body: some View {
        NavigationStack(path: $pfad) {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
                    kopf
                    if let session = sessions.aktiveSession(), !session.bloecke.isEmpty {
                        ForEach(session.bloecke) { block in
                            Button { oeffne(block) } label: { blockZeile(block) }
                                .buttonStyle(PressButtonStyle())
                        }
                    } else {
                        Text("Tippe ein Gerät an oder scanne den Code — dein Training beginnt von allein.")
                            .font(DesignSystem.Typography.fliesstext)
                            .foregroundStyle(DesignSystem.Color.textMuted)
                            .lineSpacing(4)
                    }
                    if let scanFehler {
                        InlineBanner(tone: .danger, message: scanFehler)
                    }
                    PrimaryButton(title: "Gerät scannen") { scannerOffen = true }
                    if sessions.aktiveSession() != nil {
                        SecondaryButton(title: "Training beenden") { await beenden() }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, DesignSystem.Spacing.s24)
            }
            .background(DesignSystem.Color.bg)
            .navigationDestination(for: GeraetRoute.self, destination: ziel)
            .sheet(isPresented: $scannerOffen) {
                MemberScannerView { code in
                    scannerOffen = false
                    oeffneToken(code)
                }
            }
            // Ein ueber Universal Link erfasster Token wird hier verbraucht --
            // Sub-Projekt 1 hat ihn nur fuer das Banner auf LoginMail genutzt.
            .task {
                if let token = pendingTag.consume() { oeffneToken(token) }
            }
        }
    }

    // MARK: - Kopf und Zeilen

    private var kopf: some View {
        Text(sessions.aktiveSession() == nil ? "TRAINING" : "TRAINING LÄUFT")
            .font(DesignSystem.Typography.screentitel)
            .tracking(-1)
            .foregroundStyle(DesignSystem.Color.text)
    }

    private func blockZeile(_ block: LokalerBlock) -> some View {
        let maschine = katalog.bootstrap?.machines.first { $0.id == block.machineId }
        let uebung = maschine?.exercises.first { $0.id == block.exerciseId }
        let letztes = block.saetze.last
        return HStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                Text([maschine?.equipmentModel.name, uebung?.name]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(DesignSystem.Typography.uebungsname)
                    .foregroundStyle(DesignSystem.Color.text)
                Text("\(block.saetze.count) \(block.saetze.count == 1 ? "Satz" : "Sätze")"
                     + (letztes.map { " · \(Zahlformat.gewichtMitEinheit($0.weightKg))" } ?? ""))
                    .font(.system(size: 13))
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DesignSystem.Color.textFaint)
        }
        .padding(DesignSystem.Spacing.s16)
        .frame(minHeight: 44)
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Öffnet das Gerät")
    }

    // MARK: - Navigation

    @ViewBuilder
    private func ziel(_ route: GeraetRoute) -> some View {
        switch route {
        case .erkannt(let machineId, let token):
            if let modell = modell(machineId: machineId, exerciseId: nil, token: token) {
                GeraetErkanntView(modell: modell) { uebungId in
                    pfad.append(.geraet(machineId: machineId, exerciseId: uebungId, token: token))
                }
            }
        case .geraet(let machineId, let exerciseId, let token):
            if let modell = modell(machineId: machineId, exerciseId: exerciseId, token: token) {
                GeraetScreen(modell: modell) { pfad.removeAll() }
            }
        }
    }

    private func modell(machineId: String, exerciseId: String?, token: String?) -> GeraetModel? {
        guard let bootstrap = katalog.bootstrap,
              let maschine = bootstrap.machines.first(where: { $0.id == machineId })
        else { return nil }
        // Vorauswahl: zuletzt genutzte Uebung, sonst die erste aus der vom
        // Studio gepflegten Reihenfolge (M1-Spec SS5.7).
        let zuletzt = bootstrap.lastSets
            .filter { $0.machineId == machineId }
            .max { $0.performedAt < $1.performedAt }?.exerciseId
        let gewaehlt = exerciseId ?? zuletzt ?? maschine.exercises.first?.id
        guard let gewaehlt else { return nil }
        return GeraetModel(
            maschine: maschine, uebungId: gewaehlt, token: token,
            bootstrap: bootstrap, loader: apiClient, sessions: sessions,
            enqueue: { katalog.enqueue($0); Task { await katalog.flushPending() } }
        )
    }

    /// Der Kalteinstieg: Token lokal hashen, Geraet im Prefetch finden,
    /// sofort rendern (M1-Spec SS8.1 Schritt 3).
    private func oeffneToken(_ token: String) {
        scanFehler = nil
        guard let bootstrap = katalog.bootstrap else { return }
        guard let maschine = MachineResolver.maschine(fuerToken: token, in: bootstrap) else {
            // Ein Geraet, das nach dem letzten Prefetch dazukam. Einmal neu
            // laden, dann erneut versuchen -- sonst dieselbe neutrale
            // Antwort wie serverseitig fuer unbekannt/gesperrt.
            Task {
                await katalog.load()
                guard let frisch = katalog.bootstrap,
                      let maschine = MachineResolver.maschine(fuerToken: token, in: frisch) else {
                    scanFehler = "Dieser Code ist nicht aktiv. Frag im Studio nach."
                    return
                }
                navigiere(zu: maschine, token: token, in: frisch)
            }
            return
        }
        navigiere(zu: maschine, token: token, in: bootstrap)
    }

    private func navigiere(zu maschine: BootstrapResponse.Machine, token: String, in bootstrap: BootstrapResponse) {
        let genutzte = GeraetEinstiegRechner.genutzteUebungen(machineId: maschine.id, in: bootstrap)
        switch GeraetEinstiegRechner.einstieg(visitCount: maschine.visitCount,
                                              genutzteUebungen: genutzte) {
        case .erkannt:
            pfad.append(.erkannt(machineId: maschine.id, token: token))
        case .direktZumSatz:
            let uebung = bootstrap.lastSets.first { $0.machineId == maschine.id }?.exerciseId
                ?? maschine.exercises.first?.id
            guard let uebung else { return }
            pfad.append(.geraet(machineId: maschine.id, exerciseId: uebung, token: token))
        }
    }

    private func oeffne(_ block: LokalerBlock) {
        // Der Zirkelfall: ein Tap statt eines Scans (M1-Spec SS5.3).
        pfad.append(.geraet(machineId: block.machineId, exerciseId: block.exerciseId, token: nil))
    }

    private func beenden() async {
        guard let id = sessions.beenden() else { return }
        _ = try? await apiClient.completeSession(sessionId: id)
    }
}
```

- [ ] **Step 3: `GeraetScreen` als Zusammenbau schreiben**

Ans Ende von `GeraetView.swift` anhängen — die Hülle, die Sheets und Dreischritt an `GeraetView` hängt:

```swift
/// Bindet Sheets und den Dreischritt an GeraetView. Getrennt, damit
/// GeraetView selbst nur den Screen beschreibt und in der Preview ohne
/// Umgebung lauffaehig bleibt.
struct GeraetScreen: View {
    @State var modell: GeraetModel
    let beiZurueckZumTraining: () -> Void

    @State private var uebungWechselnOffen = false
    @State private var problemOffen = false

    var body: some View {
        GeraetView(
            modell: modell,
            beiUebungWechseln: { uebungWechselnOffen = true },
            beiProblem: { problemOffen = true },
            beiZurueckZumTraining: beiZurueckZumTraining
        )
        .sheet(isPresented: $uebungWechselnOffen) {
            UebungWechselnSheet(modell: modell) { modell.uebungWechseln(zu: $0) }
        }
        .sheet(isPresented: $problemOffen) {
            ProblemSheet(modell: modell) {}
        }
        // Der Dreischritt: fullScreenCover verdeckt die Tab-Leiste.
        .fullScreenCover(isPresented: Binding(
            get: { modell.istErstkontakt || modell.kalibrierungOffen },
            set: { if !$0 { modell.kalibrierungOffen = false } }
        )) {
            if modell.kalibrierungOffen && !modell.istErstkontakt {
                // "aendern" ausserhalb des Dreischritts.
                KalibrierungSchritt(modell: modell, titel: "Deine Einstellung") {
                    modell.kalibrierungOffen = false
                }
            } else {
                ErstkontaktFlow(modell: modell) { modell.erstkontaktAbschliessen() }
            }
        }
        .onAppear { modell.kalibrierungVorbereiten() }
    }
}
```

**Achtung, zwei Fallstricke.**

Erstens: `navigationDestination(for:)` wertet seinen Aufbau bei jeder Neuzeichnung aus, `modell(machineId:…)` erzeugt also jedes Mal ein neues `GeraetModel`. `GeraetScreen` hält es in `@State` — dort gewinnt die **erste** Instanz, und genau das ist gewollt: Radstellung, Pause und Kalibrierungsentwurf überleben jede Neuzeichnung. `GeraetErkanntView` bekommt dagegen bei jeder Neuzeichnung ein frisches Modell; das ist unkritisch, weil sie nur liest, darf aber nicht als Muster für weitere Screens dienen.

Zweitens: `istErstkontakt` liest aus dem beim Erzeugen übergebenen `bootstrap` und ändert sich nach dem ersten Satz nicht von selbst. Damit der Dreischritt nach seinem Abschluss nicht erneut aufgeht, ergänze in `GeraetModel`:

```swift
    /// Der Dreischritt laeuft genau einmal je Geraet und Uebung -- nach
    /// seinem Abschluss darf er in dieser Sitzung nicht erneut aufgehen.
    private var erstkontaktErledigt = false

    func erstkontaktAbschliessen() { erstkontaktErledigt = true }
```

und erweitere `istErstkontakt` um `!erstkontaktErledigt &&`. `ErstkontaktFlow`s `beiAbschluss` ruft dann zusätzlich `modell.erstkontaktAbschliessen()`.

- [ ] **Step 4: `MainTabView` und die App verdrahten**

In `MainTabView.swift` den Training-Platzhalter ersetzen; `MainTabView` bekommt dafür den Client durchgereicht:

```swift
struct MainTabView: View {
    let apiClient: APIClient

    var body: some View {
        TabView {
            NavigationStack { PlaceholderView(title: "Home") }
                .tabItem { Label("Home", systemImage: "house") }

            TrainingRootView(apiClient: apiClient)
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

In `RootView.swift` den `.main`-Zweig zu `MainTabView(apiClient: apiClient)` machen und `let apiClient: APIClient` als Eigenschaft ergänzen.

In `FitnessMemberApp.swift`: `apiClient`, `WorkoutSessionStore` und `NetzwerkMonitor` festhalten und in die Umgebung geben.

```swift
@main
struct FitnessMemberApp: App {
    @State private var sessionStore: SessionStore
    @State private var catalogStore: CatalogStore
    @State private var workoutStore = WorkoutSessionStore()
    @State private var netzwerkMonitor = NetzwerkMonitor()
    @State private var pendingTagStore = PendingTagStore()
    private let apiClient: APIClient

    init() {
        let session = SessionStore(backend: SupabaseAuthBackend())
        let client = APIClient(baseURL: AppConfig.apiBaseURL) { await session.currentAccessToken() }
        _sessionStore = State(initialValue: session)
        _catalogStore = State(initialValue: CatalogStore(loader: client, pendingWriteStore: PendingWriteStore()))
        apiClient = client
    }

    var body: some Scene {
        WindowGroup {
            RootView(apiClient: apiClient)
                .environment(sessionStore)
                .environment(catalogStore)
                .environment(workoutStore)
                .environment(netzwerkMonitor)
                .environment(pendingTagStore)
                .task {
                    await sessionStore.restoreSession()
                    // Der bisher fehlende Ausloeser der Schreib-Warteschlange.
                    netzwerkMonitor.start {
                        Task { await catalogStore.flushPending() }
                    }
                    await catalogStore.flushPending()
                }
                .onOpenURL { url in
                    if let token = TagLink.token(from: url) {
                        pendingTagStore.capture(token)
                    }
                }
        }
    }
}
```

In `RootView.swift` beim Abmelden zusätzlich `workoutStore.reset()` aufrufen — die laufende Einheit trägt Kennungen des abgemeldeten Kontos. Dafür `@Environment(WorkoutSessionStore.self) private var workoutStore` ergänzen und im `else if hatteSession`-Zweig neben `catalogStore.reset()` aufrufen.

- [ ] **Step 5: Vollständiger Testlauf**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test 2>&1 | tail -40
```

Erwartet: alle Tests grün.

- [ ] **Step 6: Der vollständige Durchgang im Simulator**

Gegen ein echtes Studio mit mindestens einem Gerät, einer Übung und einem Tag:

1. **Kalteinstieg:** Universal Link `https://gymodo-web.vercel.app/t/<token>` im Simulator öffnen. Die App landet im Training-Tab und pusht den Geräte-Screen — nicht in einem eigenen Tab.
2. **Erstkontakt:** Beim ersten Mal läuft der Dreischritt ohne Tab-Leiste. Nach „Ersten Satz sichern" steht der Resttimer.
3. **Zweiter Satz:** „Satz 2 sichern" mit vorbelegtem Gewicht. Ein Tap auf das Gewicht öffnet beide Räder; sichern ohne Zwischentap.
4. **Zirkel:** Zurück zum Training, zweites Gerät scannen, dann über die Blockliste zum ersten zurück — der `setIndex` läuft im Block weiter, nicht in der Session.
5. **Flugmodus:** Werte und Historie bleiben, das Video fehlt, die Offline-Leiste steht, ein Satz wird „gespeichert, wird gesendet".
6. **App-Kill im Flugmodus**, neu starten: Session und Warteschlange sind noch da, die Satznummer stimmt.
7. **Flugmodus aus:** Die Warteschlange läuft leer, zwei Sekunden „Gesendet", dann verschwindet die Karte.
8. **„Training beenden"** im Training-Tab; in der Datenbank prüfen, dass `workout_sessions.completed_reason = 'manual'` steht.
9. **VoiceOver-Durchgang** über alle sechs Views.
10. **Dynamic Type XXL** und **Reduce Motion** über alle sechs Views.

- [ ] **Step 7: Commit**

```bash
git add apps/ios-member/FitnessMember
git commit -m "feat(ios): Geraete-Screen im Training-Tab verdrahtet

Der Geraete-Screen ist kein Tab -- er wird als Push innerhalb von Training
geoeffnet und behaelt die Tab-Leiste (designsystem.md SS11).

Die minimale Training-Wurzel kommt mit, weil der Kernflow sonst nicht
schliessbar waere: POST .../complete haette keinen Ausloeser, 'Zurueck zum
Training' liefe ins Leere, und der Zirkelfall aus M1-Spec SS5.3 waere nicht
baubar. Der Artboard-Ausbau bleibt Sub-Projekt 3.

Der PendingTagStore aus Sub-Projekt 1 wird hier erstmals verbraucht, und
NWPathMonitor bekommt seinen Aufrufer."
```

---

## Abnahme des Sub-Projekts

Erst wenn **alle** Punkte belegt sind:

- [ ] `pnpm typecheck` ohne Fehler
- [ ] `cd packages/domain && pnpm vitest run` grün
- [ ] `xcodebuild … test` grün, keine übersprungenen Tests
- [ ] Alle zehn Artboards abgenommen — gegen die Abweichungstabelle in Abschnitt 9 der Spec, nicht wörtlich
- [ ] Interaktionsbudget nachgemessen: Normalfall eine Interaktion, Abweichungsfall zwei (`designsystem.md` §9 — eine Abnahmebedingung, kein Ziel)
- [ ] Genau eine Akzentfläche je Screen, auf allen sechs Views nachgezählt
- [ ] `warn` nirgends als Fläche
- [ ] VoiceOver-Durchgang je View, insbesondere `adjustable` am Rad und die 15-s-Drosselung des Resttimers
- [ ] Dynamic Type bis XXL ohne Layoutbruch
- [ ] Reduce Motion über alle vier Bewegungen aus Abschnitt 6 der Spec
- [ ] Vollständiger Flugmodus-Durchgang inklusive App-Kill und Reconnect
