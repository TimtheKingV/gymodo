# iOS Member-App — Training & Kurse: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Den Training-Tab von einem Rumpf zu seiner vollen Gestalt bringen und den Kurse-Tab bauen — sieben Screens, zwei kleine Server-Erweiterungen, ein zusammengeführtes Scanner-Sheet.

**Architecture:** Zwei unabhängige Hälften. Training baut auf `TrainingRootView`, `WorkoutSessionStore` und `LokaleSession` aus Sub-Projekt 2 auf und rechnet seine Zahlen lokal — die App ist die einzige Instanz, die alle Sätze kennt, solange welche in der Schreib-Warteschlange liegen. Kurse spricht einen fertigen, screenorientierten Serververtrag und cacht bewusst **nur** die eigenen Buchungen: eine Belegungszahl von vorhin als aktuell zu zeigen wäre dieselbe Unwahrheit, die beim Satz-Status vermieden wird. Zwei additive Server-Änderungen schließen zwei Vertragslücken, ohne die zwei Screens nicht baubar sind.

**Tech Stack:** Swift 6.0, SwiftUI (iOS 17), Swift Testing, XcodeGen. Backend: TypeScript, Next.js App Router, Zod, Vitest. Keine neue Abhängigkeit, keine Migration.

**Spec:** `docs/superpowers/specs/2026-09-08-ios-training-kurse-design.md` — dieser Plan setzt sie um; Ausführende lesen beide Dokumente. Referenziert außerdem `docs/superpowers/specs/2026-08-28-fitness-retrofit-m1-design.md` (Produktverhalten), `docs/superpowers/specs/2026-08-30-designsystem.md` (Aussehen, Bewegung, Zustände) und `docs/superpowers/specs/2026-09-07-ios-geraet-kernflow-design.md` (die Bausteine aus Sub-Projekt 2).

**Artboards:** `docs/superpowers/design/member/{TrainingLeer,TrainingLaeuft,TrainingScan,TrainingAbschluss,Kurse,KursDetail,KurseMeine}.dc.html`. **Sie werden gegen die Abweichungstabelle in Abschnitt 6 der Spec gelesen, nicht wörtlich** — sie tragen dokumentierte Regelbrüche.

## Global Constraints

- iOS-Deployment-Ziel 17.0, Swift 6.0 (`apps/ios-member/project.yml`) — nicht ändern. Keine neue SPM-Abhängigkeit.
- **Kein Direktzugriff aus Swift auf Postgres/PostgREST** — jede Fachfunktion läuft über `/api/v1` (M1-Spec §6.1/§6.2).
- **Alle Ziffern tabellarisch** (`.monospacedDigit()`). **Gewichte immer mit einer Nachkommastelle und Dezimalkomma** über `Zahlformat`, nie selbst formatiert (§3).
- **Zeitangaben in der Studio-Zeitzone** (`studios.timezone`, in `CourseWeek` mitgeliefert), Datum ausgeschrieben („Mi, 27. August") (§10).
- **Trefferflächen ≥ 44 pt. Hauptaktion exakt 64 pt hoch**, Nebenaktion 46–52 pt. Radius 16 Hauptaktion / 14 Nebenaktion / 12 Karten / Pille für Chips. Abstandsskala ausschließlich 4 · 8 · 12 · 16 · 24 · 32 · 48. Seitenrand 20 pt (§4).
- **Genau eine Akzentfläche je Screen** (§2, nicht verhandelbar). Wo es keine Hauptaktion gibt, markiert der Akzent den aktiven Wert — dasselbe Muster wie in Sub-Projekt 2.
- **`warn` (`#FFB020`) nur als Umriss, nie als Fläche** (§2, nicht verhandelbar).
- **`text-faint` nur für Text ≥ 15 pt oder nicht-tragende Information** — nie für etwas, das gelesen werden muss (§2).
- **Fünf Zustände, überall gleich** (§5): Skelett **nur für Medien**, nie über einer Zahl · Leer erklärt den nächsten Schritt, nie eine leere Statistik mit Nullen · Offline heißt „gespeichert, wird gesendet", nie „fehlgeschlagen" · Fehler sagt, was falsch ist **und** was gilt · Deaktiviert ist nie stumm.
- **Haptik nie als einzige Rückmeldung** (§6, M1-Spec §5.9).
- **Reduce Motion ersetzt jede Animation durch einen Zustandswechsel**, nie durch Weglassen von Information (§6).
- **Bewegungswerte** aus `DesignSystem.Motion` (Sub-Projekt 2): `.oeffnen`, `.pause`, `.press` — keine neuen erfinden.
- **Kein Freitext zu Gesundheit, nirgends** (§10).
- **Vorschläge sind eine Rechnung, keine Empfehlung** — „Vorschlag · +2,5", nie „Du solltest" (§10).
- **Kein Text verspricht eine Benachrichtigung.** Push existiert nicht (§11).
- **Durchgehend Deutsch, Du-Form, keine Ausrufezeichen, kein Motivationston** (§10).
- **Unbekannt, ungültig und gesperrt liefern dieselbe neutrale Antwort** — der Client darf das nicht unterlaufen, auch nicht über eine abweichende Meldung (M1-Spec §10.4).
- **Backend-Fehlerhülle:** `{ "error": { "code": "...", "message": "..." } }`, Status fest: `validation_failed`→422, `unauthorized`→401, `not_found`→404, `conflict`→409, `internal`→500 (`apps/web/lib/api/respond.ts` — nicht ändern).
- Neue Web-Routen folgen dem Muster der bestehenden `/api/v1`-Handler: `bearerClientFrom(request)`, `fromDomainError`/`errorResponse`, `export const dynamic = "force-dynamic"`.
- Deutsche Bezeichner in neuem Fachcode; englische nur, wo sie einen API-Vertrag oder eine Datenbankspalte abbilden.
- **Kommentare erklären, warum — nicht was.** Die bestehenden Dateien sind das Vorbild.
- **Jede Verifikation läuft als Kaltbau** mit isoliertem `-derivedDataPath`, und das Verzeichnis wird danach gelöscht. In Sub-Projekt 2 verdeckten warme Builds einen Übersetzungsfehler und sieben Warnungen; die stehengebliebenen Verzeichnisse belegten am Ende 5,2 GB und ließen den letzten Testlauf an einer vollen Platte scheitern.
- **Vier vorbestehende Warnungen** (`QRScannerController.swift` dreimal, `SupabaseAuthBackend.swift` einmal) sind bekannt und gehören nicht zu diesem Sub-Projekt. Nicht beheben, aber auch nicht vermehren: **jede Warnung in einer Datei, die du schreibst, ist deine.**

## Dateistruktur

**Neu, Server:**

| Datei | Verantwortung |
| --- | --- |
| `packages/domain/src/abschluss.ts` | Vorschläge je Block nach dem Training: Abfragen, Berechnung, Festhalten |
| `packages/domain/src/abschluss.test.ts` | Tests der reinen Gruppierung und Zuordnung |

**Neu, iOS:**

| Datei | Verantwortung |
| --- | --- |
| `FitnessMember/DesignSystem/Components/ScannerSheet.swift` | Das gemeinsame, parametrisierte Scanner-Sheet |
| `FitnessMember/Workout/Trainingszusammenfassung.swift` | Zahlen des Abschlusses aus der `LokaleSession` |
| `FitnessMember/Screens/Training/TrainingAbschlussView.swift` | `TrainingAbschluss` |
| `FitnessMember/Networking/DTOs/CourseWeek.swift` | Kurse-DTOs |
| `FitnessMember/Kurse/KursZustand.swift` | Die sechs Zustände, die Frist, der „meine Kurse"-Filter |
| `FitnessMember/Kurse/KurseFileStore.swift` | Persistenz der eigenen Buchungen |
| `FitnessMember/Kurse/KurseStore.swift` | Laden, buchen, stornieren, Offline-Cache |
| `FitnessMember/Screens/Kurse/KurseWochenView.swift` | `Kurse` |
| `FitnessMember/Screens/Kurse/KursDetailView.swift` | `KursDetail` |
| `FitnessMember/Screens/Kurse/KurseMeineView.swift` | `KurseMeine` |
| `FitnessMember/Navigation/KursRoute.swift` | Typisierter Pfad des Kurse-Tabs |

**Geändert:**

| Datei | Änderung |
| --- | --- |
| `packages/domain/src/progression.ts` | `toBlocks` hierher verschoben und exportiert |
| `packages/domain/src/tag-context.ts` | nutzt das verschobene `toBlocks` |
| `packages/domain/src/workout.ts` | `completeSession` liefert `vorschlaege` |
| `packages/domain/src/courses.ts` | `CourseWeek` trägt `cancellationDeadlineHours` |
| `packages/domain/src/index.ts` | neue Exporte |
| `FitnessMember/Networking/DTOs/WorkoutSet.swift` | `CompletedSession` trägt `vorschlaege` |
| `FitnessMember/Networking/APIClient.swift` | Kurse-Methoden |
| `FitnessMember/Screens/Zugang/MemberScannerView.swift` | ersetzt durch `ScannerSheet`, Aufrufstelle angepasst |
| `FitnessMember/Screens/Training/TrainingRootView.swift` | zwei Zustände nach Artboard, Abschluss-Push |
| `FitnessMember/Navigation/MainTabView.swift` | Kurse-Tab statt Platzhalter |
| `FitnessMember/FitnessMemberApp.swift` | `KurseStore` in die Umgebung |

---

### Aufgabe 1: `complete` liefert die Vorschläge je Block

`TrainingAbschluss` zeigt unter „Beim nächsten Mal" je Block einen Vorschlag. Dafür gibt es heute keine Quelle: `suggestNextWeight` wird ausschließlich in `getTagContext` aufgerufen — also wenn ein Gerät angetippt wird. `GET /me/sessions` liefert Blöcke und Sätze, aber keinen Vorschlag.

**Files:**
- Modify: `packages/domain/src/progression.ts`
- Modify: `packages/domain/src/tag-context.ts`
- Create: `packages/domain/src/abschluss.ts`
- Create: `packages/domain/src/abschluss.test.ts`
- Modify: `packages/domain/src/workout.ts`
- Modify: `packages/domain/src/index.ts`
- Modify: `apps/ios-member/FitnessMember/Networking/DTOs/WorkoutSet.swift`
- Modify: `apps/ios-member/FitnessMemberTests/DTOTests.swift`

**Interfaces:**
- Produces: `toBlocks(rows: Array<{ performed_at: string; weight_kg: number|string; reps: number; rir: number|string|null; problem_flag: boolean }>): BlockInput[]` — aus `progression.ts` exportiert, von `tag-context.ts` und `abschluss.ts` genutzt.
- Produces: `type Blockvorschlag = { machineId: string; exerciseId: string; resultWeightKg: number | null; deltaKg: number | null; reasonCode: ProgressionReasonCode; algoVersion: string }`
- Produces: `vorschlaegeFuerAbschluss(client: SupabaseClient, sessionId: string, userId: string): Promise<Blockvorschlag[]>`
- Produces: `CompletedSession` um `vorschlaege: Blockvorschlag[]` erweitert — von Aufgabe 4 und 6 konsumiert.
- Produces: Swift `CompletedSession.vorschlaege: [Blockvorschlag]` mit `struct Blockvorschlag: Decodable, Equatable`.

- [ ] **Step 1: Den Test für die reine Gruppierung schreiben**

Create `packages/domain/src/abschluss.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { blockPaare, zuVorschlag } from "./abschluss.js";

describe("blockPaare", () => {
  it("fasst Saetze zu Paaren aus Geraet und Uebung zusammen", () => {
    const paare = blockPaare([
      { machine_id: "m1", exercise_id: "e1" },
      { machine_id: "m1", exercise_id: "e1" },
      { machine_id: "m2", exercise_id: "e2" },
    ]);

    expect(paare).toEqual([
      { machineId: "m1", exerciseId: "e1" },
      { machineId: "m2", exerciseId: "e2" },
    ]);
  });

  it("haelt dasselbe Geraet mit zwei Uebungen auseinander", () => {
    const paare = blockPaare([
      { machine_id: "m1", exercise_id: "e1" },
      { machine_id: "m1", exercise_id: "e2" },
    ]);

    expect(paare).toHaveLength(2);
  });

  it("behaelt die Reihenfolge des ersten Auftretens", () => {
    const paare = blockPaare([
      { machine_id: "m2", exercise_id: "e2" },
      { machine_id: "m1", exercise_id: "e1" },
      { machine_id: "m2", exercise_id: "e2" },
    ]);

    expect(paare[0]).toEqual({ machineId: "m2", exerciseId: "e2" });
  });

  it("liefert fuer eine Session ohne Saetze nichts", () => {
    expect(blockPaare([])).toEqual([]);
  });
});

describe("zuVorschlag", () => {
  const basis = {
    machineId: "m1",
    exerciseId: "e1",
    suggestion: {
      algoVersion: "v1",
      resultWeightKg: 82.5,
      reasonCode: "korridor_oben_erreicht" as const,
      inputs: {
        targetRepsMin: 8,
        targetRepsMax: 12,
        weightStepKg: 2.5,
        minWeightKg: 5,
        maxWeightKg: 150,
        currentWeightKg: 80,
        consideredBlocks: 1,
      },
    },
  };

  it("rechnet das Delta aus Vorschlag und bisherigem Gewicht", () => {
    expect(zuVorschlag(basis).deltaKg).toBe(2.5);
  });

  it("laesst das Delta offen, wenn es keinen Vorschlag gibt", () => {
    const ohne = {
      ...basis,
      suggestion: {
        ...basis.suggestion,
        resultWeightKg: null,
        reasonCode: "problem_gemeldet" as const,
      },
    };

    expect(zuVorschlag(ohne).deltaKg).toBeNull();
    expect(zuVorschlag(ohne).resultWeightKg).toBeNull();
    expect(zuVorschlag(ohne).reasonCode).toBe("problem_gemeldet");
  });

  it("laesst das Delta offen, wenn es kein bisheriges Gewicht gibt", () => {
    const ersterKontakt = {
      ...basis,
      suggestion: {
        ...basis.suggestion,
        inputs: { ...basis.suggestion.inputs, currentWeightKg: null },
      },
    };

    expect(zuVorschlag(ersterKontakt).deltaKg).toBeNull();
  });

  it("gibt ein negatives Delta unveraendert weiter", () => {
    const runter = {
      ...basis,
      suggestion: {
        ...basis.suggestion,
        resultWeightKg: 77.5,
        reasonCode: "korridor_unten_verfehlt" as const,
      },
    };

    expect(zuVorschlag(runter).deltaKg).toBe(-2.5);
  });
});
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag bestätigen**

```bash
cd packages/domain && pnpm vitest run src/abschluss.test.ts
```

Erwartet: FAIL — Modul `./abschluss.js` existiert nicht.

- [ ] **Step 3: `toBlocks` nach `progression.ts` verschieben**

`toBlocks` steht heute privat in `tag-context.ts` und baut `BlockInput`, dessen Typ in `progression.ts` wohnt. Zwei Aufrufer brauchen ihn jetzt.

Schneide die Funktion aus `tag-context.ts` aus und füge sie in `packages/domain/src/progression.ts` ein, direkt unter `BlockInput`, mit `export` davor und einem Zeilentyp, der beide Aufrufer trägt:

```ts
/** Die Satzzeile, so wie beide Aufrufer sie aus der Datenbank lesen. */
export type SatzZeile = {
  performed_at: string;
  weight_kg: number | string;
  reps: number;
  rir: number | string | null;
  problem_flag: boolean;
};

/**
 * Saetze zu Bloecken je Trainingstag. Liegt hier statt beim Aufrufer, weil
 * seit dem Abschluss-Screen zwei Stellen dieselbe Gruppierung brauchen --
 * und weil sie den Typ baut, der hier wohnt.
 */
export function toBlocks(rows: SatzZeile[]): BlockInput[] {
  const byDay = new Map<string, BlockInput>();
  for (const row of rows) {
    const day = row.performed_at.slice(0, 10);
    let block = byDay.get(day);
    if (!block) {
      block = { performedOn: day, sets: [] };
      byDay.set(day, block);
    }
    block.sets.push({
      weightKg: Number(row.weight_kg),
      reps: row.reps,
      rir: row.rir === null ? null : Number(row.rir),
      problemFlag: row.problem_flag,
    });
  }
  // Innerhalb eines Tages chronologisch, damit "letzter Satz" stimmt.
  for (const block of byDay.values()) block.sets.reverse();
  return [...byDay.values()];
}
```

In `tag-context.ts`: die lokale Definition entfernen und `toBlocks` aus `./progression.js` importieren, dort wo bereits `suggestNextWeight` importiert wird. **Sonst nichts an `tag-context.ts` ändern.**

- [ ] **Step 4: Die Fachschicht des Abschlusses schreiben**

Create `packages/domain/src/abschluss.ts`:

```ts
import type { SupabaseClient } from "@supabase/supabase-js";
import {
  PROGRESSION_ALGO_VERSION,
  suggestNextWeight,
  toBlocks,
  type ProgressionReasonCode,
  type ProgressionSuggestion,
  type SatzZeile,
} from "./progression.js";

/**
 * Was TrainingAbschluss unter "Beim naechsten Mal" je Block zeigt.
 *
 * deltaKg ist der sichtbare Teil ("+2,5"), resultWeightKg der Wert dahinter.
 * Beide sind null, wenn es keinen Vorschlag gibt -- der reasonCode sagt
 * dann, warum.
 */
export type Blockvorschlag = {
  machineId: string;
  exerciseId: string;
  resultWeightKg: number | null;
  deltaKg: number | null;
  reasonCode: ProgressionReasonCode;
  algoVersion: string;
};

/**
 * Die Paare aus Geraet und Uebung dieser Session, in der Reihenfolge ihres
 * ersten Auftretens -- dieselbe Blockdefinition wie im Training selbst
 * (M1-Spec SS5.3: ein Block ist ein Geraet plus eine Uebung).
 */
export function blockPaare(
  rows: Array<{ machine_id: string; exercise_id: string }>,
): Array<{ machineId: string; exerciseId: string }> {
  const gesehen = new Set<string>();
  const paare: Array<{ machineId: string; exerciseId: string }> = [];
  for (const row of rows) {
    const schluessel = `${row.machine_id}:${row.exercise_id}`;
    if (gesehen.has(schluessel)) continue;
    gesehen.add(schluessel);
    paare.push({ machineId: row.machine_id, exerciseId: row.exercise_id });
  }
  return paare;
}

/**
 * Das Delta ist die Zahl, die der Screen zeigt. Es entsteht nur, wenn es
 * beides gibt: einen Vorschlag und ein bisheriges Gewicht, gegen das er
 * sich vergleichen laesst.
 */
export function zuVorschlag(eingabe: {
  machineId: string;
  exerciseId: string;
  suggestion: ProgressionSuggestion;
}): Blockvorschlag {
  const { resultWeightKg, reasonCode, algoVersion, inputs } = eingabe.suggestion;
  const bisher = inputs.currentWeightKg;
  const deltaKg =
    resultWeightKg === null || bisher === null || bisher === undefined
      ? null
      : Number((resultWeightKg - bisher).toFixed(2));

  return {
    machineId: eingabe.machineId,
    exerciseId: eingabe.exerciseId,
    resultWeightKg,
    deltaKg,
    reasonCode,
    algoVersion,
  };
}

/**
 * Vorschlaege fuer alle Bloecke einer beendeten Session.
 *
 * Fuenf Abfragen, unabhaengig von der Blockzahl -- Saetze der Session,
 * Uebungen, Geraetemodelle, Historie ueber alle betroffenen Geraete, und
 * ein Sammel-Insert. Ein Aufruf je Block waere N+1 auf einem Pfad, den
 * jedes beendete Training nimmt.
 *
 * Wird in derselben Anfrage festgehalten wie berechnet (M1-Spec SS8.4):
 * Nachvollziehbarkeit ohne Queue, genau wie beim Geraetevorschlag.
 */
export async function vorschlaegeFuerAbschluss(
  client: SupabaseClient,
  sessionId: string,
  userId: string,
): Promise<Blockvorschlag[]> {
  const { data: sessionSaetze } = await client
    .from("workout_sets")
    .select("machine_id, exercise_id, studio_id")
    .eq("session_id", sessionId)
    .eq("user_id", userId)
    .order("performed_at", { ascending: true });

  const zeilen = (sessionSaetze ?? []) as Array<{
    machine_id: string;
    exercise_id: string;
    studio_id: string;
  }>;
  const paare = blockPaare(zeilen);
  if (paare.length === 0) return [];

  const studioId = zeilen[0]!.studio_id;
  const machineIds = [...new Set(paare.map((p) => p.machineId))];
  const exerciseIds = [...new Set(paare.map((p) => p.exerciseId))];

  const { data: uebungen } = await client
    .from("exercises")
    .select("id, target_reps_min, target_reps_max")
    .in("id", exerciseIds);

  const { data: geraete } = await client
    .from("machines")
    .select(
      "id, equipment_models (weight_step_kg, min_weight_kg, max_weight_kg)",
    )
    .in("id", machineIds);

  // Die Historie aller betroffenen Geraete in einer Abfrage. Dieselbe
  // Fenstergroesse wie in tag-context: mehr als sechs Saetze je Tag ueber
  // den Betrachtungszeitraum traegt der Algorithmus ohnehin nicht.
  const { data: historie } = await client
    .from("workout_sets")
    .select(
      "machine_id, exercise_id, performed_at, weight_kg, reps, rir, problem_flag",
    )
    .eq("user_id", userId)
    .in("machine_id", machineIds)
    .order("performed_at", { ascending: false })
    .limit(paare.length * 60);

  const uebungNach = new Map(
    (uebungen ?? []).map((u) => {
      const row = u as { id: string; target_reps_min: number; target_reps_max: number };
      return [row.id, row];
    }),
  );
  const modellNach = new Map(
    (geraete ?? []).map((g) => {
      const row = g as unknown as {
        id: string;
        equipment_models: {
          weight_step_kg: number | string;
          min_weight_kg: number | string;
          max_weight_kg: number | string | null;
        };
      };
      return [row.id, row.equipment_models];
    }),
  );

  const historieNach = new Map<string, SatzZeile[]>();
  for (const row of (historie ?? []) as Array<SatzZeile & {
    machine_id: string;
    exercise_id: string;
  }>) {
    const schluessel = `${row.machine_id}:${row.exercise_id}`;
    const liste = historieNach.get(schluessel) ?? [];
    liste.push(row);
    historieNach.set(schluessel, liste);
  }

  const vorschlaege: Blockvorschlag[] = [];
  for (const paar of paare) {
    const uebung = uebungNach.get(paar.exerciseId);
    const modell = modellNach.get(paar.machineId);
    if (!uebung || !modell) continue;

    const suggestion = suggestNextWeight({
      targetRepsMin: uebung.target_reps_min,
      targetRepsMax: uebung.target_reps_max,
      weightStepKg: Number(modell.weight_step_kg),
      minWeightKg: Number(modell.min_weight_kg),
      maxWeightKg: Number(modell.max_weight_kg ?? 9999),
      history: toBlocks(
        historieNach.get(`${paar.machineId}:${paar.exerciseId}`) ?? [],
      ),
    });

    vorschlaege.push(zuVorschlag({ ...paar, suggestion }));
  }

  if (vorschlaege.length > 0) {
    await client.from("progression_suggestions").insert(
      vorschlaege.map((v) => ({
        studio_id: studioId,
        user_id: userId,
        machine_id: v.machineId,
        exercise_id: v.exerciseId,
        algo_version: PROGRESSION_ALGO_VERSION,
        inputs: {},
        result_weight_kg: v.resultWeightKg,
        reason_code: v.reasonCode,
      })),
    );
  }

  return vorschlaege;
}
```

**Zwei Dinge vor dem Schreiben prüfen und melden:**
1. `progression_suggestions.inputs` ist in Migration `0015` vermutlich `not null`. Sieh nach. Wenn ja, schreibe statt `{}` die tatsächlichen `suggestion.inputs` mit — sie stehen zur Verfügung und sind genau das, was die Spalte für die Nachvollziehbarkeit will.
2. Ob `PROGRESSION_ALGO_VERSION` aus `progression.ts` exportiert wird. Falls nicht, exportiere es dort.

- [ ] **Step 5: `completeSession` erweitern**

In `packages/domain/src/workout.ts`:

```ts
export type CompletedSession = {
  id: string;
  startedAt: string;
  completedAt: string;
  completedReason: "manual" | "auto";
  /**
   * Was beim naechsten Mal an jedem Geraet dieser Einheit ansteht. Kommt
   * mit dem Abschluss statt aus einem eigenen Endpoint, weil der Screen
   * genau das rendert (M1-Spec SS6.3, screenorientiert).
   */
  vorschlaege: Blockvorschlag[];
};
```

Beide `return`-Zweige — der für die bereits beendete Session und der nach dem `update` — bekommen `vorschlaege: await vorschlaegeFuerAbschluss(client, parsed.data.sessionId, userId)`.

**Auch der Zweig für die bereits beendete Session.** Wer den Abschluss-Screen erneut öffnet oder offline war und der Aufruf später durchgeht, soll dieselbe Antwort bekommen; `PUT`-artige Idempotenz gilt hier genauso.

Import ergänzen: `import { vorschlaegeFuerAbschluss, type Blockvorschlag } from "./abschluss.js";`

- [ ] **Step 6: Exportieren**

In `packages/domain/src/index.ts`:

```ts
export { vorschlaegeFuerAbschluss, blockPaare, zuVorschlag } from "./abschluss.js";
export type { Blockvorschlag } from "./abschluss.js";
export { toBlocks } from "./progression.js";
export type { SatzZeile } from "./progression.js";
```

- [ ] **Step 7: Tests und Typprüfung**

```bash
cd packages/domain && pnpm vitest run && cd ../.. && pnpm typecheck 2>&1 | tail -10
```

Erwartet: alle Domain-Tests grün (99 bestehende plus 9 neue), keine Typfehler. `tag-context.ts` muss nach der Verschiebung von `toBlocks` weiter übersetzen.

- [ ] **Step 8: Das Swift-DTO nachziehen**

In `apps/ios-member/FitnessMember/Networking/DTOs/WorkoutSet.swift`, unter `CompletedSession`:

```swift
/// Was beim naechsten Mal an einem Geraet dieser Einheit ansteht.
/// deltaKg ist die Zahl, die der Screen zeigt ("+2,5"); ist sie nil,
/// sagt reasonCode warum es keinen Vorschlag gibt.
struct Blockvorschlag: Decodable, Equatable {
    let machineId: String
    let exerciseId: String
    let resultWeightKg: Double?
    let deltaKg: Double?
    let reasonCode: String
    let algoVersion: String
}
```

und `CompletedSession` um `let vorschlaege: [Blockvorschlag]` erweitern.

- [ ] **Step 9: DTO-Test ergänzen**

In `apps/ios-member/FitnessMemberTests/DTOTests.swift`:

```swift
@Test func completedSessionDecodiertVorschlaege() throws {
    let json = """
    {
      "id": "s1", "startedAt": "2026-09-08T18:04:00Z",
      "completedAt": "2026-09-08T18:51:00Z", "completedReason": "manual",
      "vorschlaege": [
        { "machineId": "m1", "exerciseId": "e1", "resultWeightKg": 82.5,
          "deltaKg": 2.5, "reasonCode": "korridor_oben_erreicht",
          "algoVersion": "v1" },
        { "machineId": "m2", "exerciseId": "e2", "resultWeightKg": null,
          "deltaKg": null, "reasonCode": "problem_gemeldet",
          "algoVersion": "v1" }
      ]
    }
    """.data(using: .utf8)!

    let beendet = try JSONDecoder().decode(CompletedSession.self, from: json)

    #expect(beendet.vorschlaege.count == 2)
    #expect(beendet.vorschlaege[0].deltaKg == 2.5)
    // Kein Vorschlag heisst: beide Zahlen fehlen, der Grund bleibt.
    #expect(beendet.vorschlaege[1].deltaKg == nil)
    #expect(beendet.vorschlaege[1].reasonCode == "problem_gemeldet")
}
```

Schlagen andere Tests fehl, weil sie ein `CompletedSession`-JSON ohne `vorschlaege` enthalten, ergänze dort `"vorschlaege": []`.

- [ ] **Step 10: Kaltbau**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -derivedDataPath /tmp/dd-sp3-t1 test 2>&1 | grep -E "warning:|error:|TEST SUCCEEDED|TEST FAILED"
rm -rf /tmp/dd-sp3-t1
```

Erwartet: `TEST SUCCEEDED`, nur die vier vorbestehenden Warnungen.

- [ ] **Step 11: Commit**

```bash
git add packages/domain apps/ios-member/FitnessMember/Networking/DTOs/WorkoutSet.swift \
        apps/ios-member/FitnessMemberTests/DTOTests.swift
git commit -m "feat(api): complete liefert die Vorschlaege je Block

TrainingAbschluss zeigt 'Beim naechsten Mal' je Geraet, aber
suggestNextWeight lief bisher ausschliesslich in getTagContext -- also beim
Antippen eines Geraets. Nach dem Training gab es keine Quelle.

Fuenf Abfragen unabhaengig von der Blockzahl statt einer je Block: ein
beendetes Training ist ein Pfad, den jede Einheit nimmt.

Berechnet und in derselben Anfrage festgehalten, wie M1-Spec SS8.4 es fuer
den Geraetevorschlag vorsieht -- Nachvollziehbarkeit ohne Queue.

toBlocks wandert von tag-context nach progression: zwei Aufrufer brauchen
jetzt dieselbe Gruppierung, und die Funktion baut den Typ, der dort wohnt."
```

---

### Aufgabe 2: `CourseWeek` liefert die Abmeldefrist

`KursDetail` schreibt „Abmelden ist bis 2 Stunden vor Beginn möglich", `KurseMeine` schreibt „Abmelden bis 16:00 möglich". Beides braucht die Frist — und die steht in `studios.cancellation_deadline_hours`, ist also **je Studio verschieden**. Die „2" im Artboard ist der Spaltenvorgabewert, keine allgemeine Wahrheit. Der Client erfährt sie heute nur aus der Fehlermeldung *nach* einem gescheiterten Versuch.

**Files:**
- Modify: `packages/domain/src/courses.ts`
- Create: `packages/domain/src/courses-frist.test.ts`

**Interfaces:**
- Produces: `CourseWeek.cancellationDeadlineHours: number` — von Aufgabe 7, 10 und 11 konsumiert.

- [ ] **Step 1: Den Test schreiben**

Create `packages/domain/src/courses-frist.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { abmeldenBis } from "./courses.js";

describe("abmeldenBis", () => {
  it("zieht die Frist vom Beginn ab", () => {
    const grenze = abmeldenBis("2026-09-10T18:00:00Z", 2);

    expect(grenze).toBe("2026-09-10T16:00:00.000Z");
  });

  it("bei Frist null ist der Beginn die Grenze", () => {
    expect(abmeldenBis("2026-09-10T18:00:00Z", 0)).toBe(
      "2026-09-10T18:00:00.000Z",
    );
  });

  it("vertraegt eine Frist ueber einen Tag hinaus", () => {
    expect(abmeldenBis("2026-09-10T18:00:00Z", 48)).toBe(
      "2026-09-08T18:00:00.000Z",
    );
  });
});
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag bestätigen**

```bash
cd packages/domain && pnpm vitest run src/courses-frist.test.ts
```

Erwartet: FAIL — `abmeldenBis` ist kein Export von `./courses.js`.

- [ ] **Step 3: Feld und Hilfsfunktion ergänzen**

In `packages/domain/src/courses.ts`, am `CourseWeek`-Typ:

```ts
export type CourseWeek = {
  from: string;
  to: string;
  timezone: string;
  /**
   * Aus studios.cancellation_deadline_hours (0032) -- je Studio
   * verschieden. Ohne sie koennte kein Screen die Frist nennen, ohne zu
   * raten; der Client erfuehre sie sonst erst aus der Fehlermeldung nach
   * einem gescheiterten Versuch.
   */
  cancellationDeadlineHours: number;
  sessions: CourseWeekSession[];
};

/** Der spaeteste Zeitpunkt, zu dem eine Abmeldung noch durchgeht. */
export function abmeldenBis(startsAt: string, fristStunden: number): string {
  return new Date(
    Date.parse(startsAt) - fristStunden * 60 * 60 * 1000,
  ).toISOString();
}
```

In `listCourseWeek`, nach dem RPC-Aufruf und der `not_found`-Prüfung:

```ts
  // Eigene Abfrage statt einer Aenderung an course_week: die Frist ist eine
  // Studio-Eigenschaft, keine Termin-Eigenschaft, und RLS auf studios
  // beschraenkt sie ohnehin auf die Studios des Mitglieds (0001).
  const { data: studio } = await client
    .from("studios")
    .select("cancellation_deadline_hours")
    .eq("id", studioId)
    .maybeSingle<{ cancellation_deadline_hours: number }>();
```

und im Rückgabeobjekt `cancellationDeadlineHours: studio?.cancellation_deadline_hours ?? 0`.

**Warum `?? 0` und nicht `?? 2`:** Eine fehlende Frist darf nicht so aussehen, als gäbe es Spielraum. Null heißt „bis zum Beginn" und ist die vorsichtige Annahme; die Zeile ist ohnehin unerreichbar, weil der RPC vorher `not_found` wirft, wenn das Studio nicht zugänglich ist.

- [ ] **Step 4: Exportieren und prüfen**

`abmeldenBis` in `packages/domain/src/index.ts` exportieren, dann:

```bash
cd packages/domain && pnpm vitest run && cd ../.. && pnpm typecheck 2>&1 | tail -6
```

Erwartet: alle grün, keine Typfehler. Der Kurse-Endpoint erbt das Feld ohne eigene Änderung — er reicht `CourseWeek` unverändert durch.

- [ ] **Step 5: Die überholte Aussage im Designsystem richtigstellen**

`docs/superpowers/specs/2026-08-30-designsystem.md` §11 sagt: „**Kurse ist gestaltet, aber nicht gebaut.** Es gibt dafür weder Tabelle noch Endpoint — siehe `docs/superpowers/plans/2026-08-30-kurse-datenmodell.md`. Die Artboards sind Entwurf, kein Versprechen."

Das war beim Schreiben richtig und ist es seit Phase 4 nicht mehr. Ersetze den Absatz so, dass er den heutigen Stand nennt (Migrationen `0035`–`0038`, `courses.ts`, zwei Endpoints unter `/api/v1`) und den Zeitpunkt der Richtigstellung festhält.

**Der Satz danach bleibt wörtlich stehen** — der über die Benachrichtigung, die es nicht gibt und die kein Screen versprechen darf. Er ist weiterhin gültig und wird in diesem Sub-Projekt eingehalten. Kürze ihn nicht mit.

- [ ] **Step 6: Commit**

```bash
git add packages/domain docs/superpowers/specs/2026-08-30-designsystem.md
git commit -m "feat(api): CourseWeek liefert die Abmeldefrist

KursDetail und KurseMeine zeigen die Frist an, bevor jemand auf Abmelden
tippt. Sie steht in studios.cancellation_deadline_hours und ist je Studio
verschieden -- die '2 Stunden' im Artboard sind der Spaltenvorgabewert,
keine allgemeine Wahrheit. Der Client erfuhr sie bisher erst aus der
Fehlermeldung nach einem gescheiterten Versuch.

Auf Huellenebene, wo schon timezone steht: beides ist eine
Studio-Eigenschaft, keine Termin-Eigenschaft. Eine eigene kleine Abfrage
statt einer Aenderung an der course_week-RPC, damit keine Migration noetig
wird -- RLS auf studios beschraenkt sie ohnehin richtig."
```

---

### Aufgabe 3: Ein Scanner-Sheet für beide Wege

Sub-Projekt 1 hat `MemberScannerView` für den Studio-Beitritt gebaut; Sub-Projekt 2 hat den Scan-Knopf der Training-Wurzel daran verdrahtet. `TrainingScan.dc.html` ist derselbe Screen mit anderem Text und einem gleichwertigen NFC-Hinweis. Die Kamera-, Erkennungs- und Schließmechanik wird **eine**, damit die zwei Korrekturen aus der Design-Challenge an einer Stelle wirken.

**Files:**
- Create: `apps/ios-member/FitnessMember/DesignSystem/Components/ScannerSheet.swift`
- Delete: `apps/ios-member/FitnessMember/Screens/Zugang/MemberScannerView.swift`
- Modify: `apps/ios-member/FitnessMember/Screens/Zugang/MemberKeinStudioView.swift`
- Modify: `apps/ios-member/FitnessMember/Screens/Training/TrainingRootView.swift`

**Interfaces:**
- Produces: `struct ScannerSheet: View` mit `titel: String`, `hinweis: String`, `nebenweg: String?`, `nebenwegAktion: (() -> Void)?`, `beiCode: (String) -> Void` — von Aufgabe 5 und von `MemberKeinStudioView` konsumiert.

- [ ] **Step 1: Das gemeinsame Sheet schreiben**

Create `apps/ios-member/FitnessMember/DesignSystem/Components/ScannerSheet.swift`:

```swift
import SwiftUI

/// Ein Sheet fuer beide Scan-Wege: Studio beitreten und Geraet finden.
///
/// Die Kamera-, Erkennungs- und Schliessmechanik ist dieselbe; nur der Text
/// unterscheidet sich. Zwei Sheets haetten geheissen, dass die Maengel aus
/// der Design-Challenge zweimal behoben werden -- oder nur einmal. Der
/// Beitritts-Scan steht im selben schummrigen Keller wie der Geraete-Scan.
///
/// Das Sheet erkennt einen Code und reicht ihn weiter, mehr nicht. Ob ein
/// Tag unbekannt, ungueltig oder gesperrt ist, entscheidet der Weg dahinter
/// -- und antwortet dort fuer alle drei gleich (M1-Spec SS10.4). Ein eigener
/// Fehlerzustand hier wuerde genau die Unterscheidung wieder einfuehren,
/// die der Server bewusst vermeidet.
struct ScannerSheet: View {
    let titel: String
    let hinweis: String
    /// Der zweite Weg, gleichwertig danebengestellt (SS11). Bei "Geraet
    /// finden" der NFC-Satz, beim Beitritt die manuelle Code-Eingabe.
    let nebenweg: String?
    var nebenwegAktion: (() -> Void)? = nil
    let beiCode: (String) -> Void

    @State private var erkannt = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .top) {
            QRScannerController(onCode: codeEmpfangen)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                kopf
                Spacer()
                if erkannt { bestaetigung } else { fuss }
            }
        }
        .animation(reduceMotion ? nil : DesignSystem.Motion.oeffnen, value: erkannt)
        .sensoryFeedback(.success, trigger: erkannt)
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(DesignSystem.Radius.haupt)
    }

    private var kopf: some View {
        VStack(spacing: DesignSystem.Spacing.s12) {
            Capsule()
                .fill(DesignSystem.Color.line)
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            HStack {
                Text(titel.uppercased())
                    .font(DesignSystem.Typography.label)
                    .tracking(1.5)
                    .foregroundStyle(DesignSystem.Color.text)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(DesignSystem.Color.text)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(PressButtonStyle())
                .accessibilityLabel("Schließen")
            }
            .padding(.horizontal, DesignSystem.Spacing.s16)

            Text(hinweis)
                .font(.system(size: 13))
                .foregroundStyle(DesignSystem.Color.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DesignSystem.Spacing.s16)
        }
    }

    @ViewBuilder
    private var fuss: some View {
        if let nebenweg {
            VStack(spacing: DesignSystem.Spacing.s8) {
                if let nebenwegAktion {
                    Button(nebenweg) {
                        dismiss()
                        nebenwegAktion()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DesignSystem.Color.text)
                    .frame(minHeight: 44)
                    .buttonStyle(PressButtonStyle())
                } else {
                    // Kein Knopf, sondern ein Hinweis: NFC braucht diesen
                    // Bildschirm gar nicht, es gibt also nichts zu tippen.
                    Text(nebenweg)
                        .font(.system(size: 13))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DesignSystem.Spacing.s24)
                }
            }
            .padding(.bottom, DesignSystem.Spacing.s24)
        }
    }

    /// Sichtbare Bestaetigung, nicht nur haptische (SS6). Die
    /// Design-Challenge fand, dass nach dem Scan gar nichts passierte.
    private var bestaetigung: some View {
        HStack(spacing: DesignSystem.Spacing.s8) {
            Image(systemName: "checkmark")
            Text("Erkannt")
        }
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(DesignSystem.Color.onAccent)
        .padding(.horizontal, DesignSystem.Spacing.s24)
        .frame(height: 44)
        .background(DesignSystem.Color.accent)
        .clipShape(Capsule())
        .padding(.bottom, DesignSystem.Spacing.s48)
        .accessibilityElement(children: .combine)
    }

    /// QRScannerController feuert je Bild; ohne die Sperre liefe der
    /// Aufrufer mehrfach an, waehrend die Bestaetigung noch steht.
    private func codeEmpfangen(_ code: String) {
        guard !erkannt else { return }
        erkannt = true
        beiCode(code)
    }
}
```

- [ ] **Step 2: Beide Aufrufstellen umstellen**

In `MemberKeinStudioView.swift` den `.sheet`-Inhalt ersetzen. Die bestehende Beschriftung und der Nebenweg („Code stattdessen eingeben") bleiben wörtlich erhalten — dieser Screen wurde in Sub-Projekt 1 abgenommen:

```swift
ScannerSheet(
    titel: "Code scannen",
    hinweis: "QR-Code am Studioeingang ins Feld halten.",
    nebenweg: "Code stattdessen eingeben",
    nebenwegAktion: { /* das Eingabefeld liegt direkt darunter */ },
    beiCode: { scanned in ... }
)
```

In `TrainingRootView.swift`, nach `TrainingScan.dc.html`:

```swift
ScannerSheet(
    titel: "Gerät finden",
    hinweis: "QR-Code auf dem Aufkleber ins Feld halten.",
    nebenweg: "Oder einfach antippen: Halt die Oberkante deines iPhones an den Aufkleber — dafür musst du diesen Bildschirm nicht offen haben.",
    beiCode: { code in
        scannerOffen = false
        oeffneToken(TagLink.token(fromScan: code))
    }
)
```

**Achtung:** `TagLink.token(fromScan:)` muss erhalten bleiben. Sub-Projekt 2 hat dort einen Fehler behoben, bei dem der ganze Universal Link gehasht wurde und jeder QR-Scan ins Leere lief.

Dann `MemberScannerView.swift` löschen und XcodeGen neu laufen lassen.

- [ ] **Step 3: Kaltbau und Abnahme**

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -derivedDataPath /tmp/dd-sp3-t3 test 2>&1 | grep -E "warning:|error:|TEST SUCCEEDED|TEST FAILED"
rm -rf /tmp/dd-sp3-t3
```

Gegen `TrainingScan.dc.html` statisch prüfen: NFC steht als gleichwertiger zweiter Weg da, nicht als kleiner Textknopf; Schließen ist 44 pt; genau eine Akzentfläche (die Bestätigung, und die nur, während sie sichtbar ist).

**Ohne Simulator-Interaktion ist die Erkennung selbst nicht prüfbar.** Melde das als offen, statt es zu behaupten.

- [ ] **Step 4: Commit**

```bash
git add apps/ios-member
git commit -m "refactor(ios): ein Scanner-Sheet fuer beide Wege

Studio beitreten und Geraet finden teilen Kamera, Erkennung und
Schliessmechanik; nur der Text unterscheidet sich. Zwei Sheets haetten
geheissen, dass die Maengel aus der Design-Challenge zweimal behoben werden
-- oder nur einmal.

Neu dabei: eine sichtbare Bestaetigung beim Erkennen. Bisher passierte
nichts, was SS6 verletzt (Haptik nie als einzige Rueckmeldung).

Das Sheet erkennt einen Code und reicht ihn weiter, mehr nicht. Unbekannt,
ungueltig und gesperrt bleiben ununterscheidbar -- ein eigener
Fehlerzustand hier haette genau die Unterscheidung wieder eingefuehrt, die
der Server bewusst vermeidet."
```

---

### Aufgabe 4: Trainingszusammenfassung und die ausgelaufene Einheit

Zwei reine Ableitungen aus der `LokaleSession`, die zwei Screens tragen: die Zahlen des Abschlusses und die Erkennung, dass die letzte Einheit von selbst geendet hat.

**Files:**
- Create: `apps/ios-member/FitnessMember/Workout/Trainingszusammenfassung.swift`
- Modify: `apps/ios-member/FitnessMember/Workout/WorkoutSessionStore.swift`
- Create: `apps/ios-member/FitnessMemberTests/TrainingszusammenfassungTests.swift`

**Interfaces:**
- Produces: `struct Trainingszusammenfassung: Equatable` mit `von: Date`, `bis: Date`, `dauerMinuten: Int`, `geraeteAnzahl: Int`, `satzAnzahl: Int`, `bloecke: [Blockzeile]`, und `init?(_ session: LokaleSession)`.
- Produces: `struct Blockzeile: Equatable, Identifiable` mit `machineId`, `exerciseId`, `gewichtKg: Double?`, `satzAnzahl: Int`, `problemGemeldet: Bool`.
- Produces: `WorkoutSessionStore.abgelaufeneSession(jetzt: Date = Date()) -> LokaleSession?` und `func ausgelaufeneQuittieren()` — von Aufgabe 5 konsumiert.

- [ ] **Step 1: Die Tests schreiben**

Create `apps/ios-member/FitnessMemberTests/TrainingszusammenfassungTests.swift`:

```swift
import Foundation
import Testing
@testable import FitnessMember

struct TrainingszusammenfassungTests {
    private let start = Date(timeIntervalSince1970: 1_757_000_000)

    private func satz(_ index: Int, _ gewicht: Double, _ minuten: Double,
                      problem: Bool = false) -> LokalerSatz {
        LokalerSatz(id: UUID(), setIndex: index, weightKg: gewicht, reps: 10,
                    rir: nil, problemFlag: problem, problemReason: problem ? .schmerz : nil,
                    performedAt: start.addingTimeInterval(minuten * 60))
    }

    @Test func rechnetDauerVomErstenBisZumLetztenSatz() throws {
        let session = LokaleSession(id: UUID(), startedAt: start, bloecke: [
            LokalerBlock(machineId: "m1", exerciseId: "e1",
                         saetze: [satz(1, 80, 0), satz(2, 80, 47)]),
        ])

        let z = try #require(Trainingszusammenfassung(session))

        #expect(z.dauerMinuten == 47)
        #expect(z.von == start)
        #expect(z.bis == start.addingTimeInterval(47 * 60))
    }

    @Test func zaehltGeraeteUndSaetze() throws {
        let session = LokaleSession(id: UUID(), startedAt: start, bloecke: [
            LokalerBlock(machineId: "m1", exerciseId: "e1",
                         saetze: [satz(1, 80, 0), satz(2, 80, 5), satz(3, 80, 10)]),
            LokalerBlock(machineId: "m2", exerciseId: "e2",
                         saetze: [satz(1, 45, 15)]),
        ])

        let z = try #require(Trainingszusammenfassung(session))

        #expect(z.geraeteAnzahl == 2)
        #expect(z.satzAnzahl == 4)
    }

    @Test func zaehltZweiUebungenAmSelbenGeraetAlsEinGeraet() throws {
        // "3 Geraete" auf dem Artboard meint Geraete, nicht Bloecke.
        let session = LokaleSession(id: UUID(), startedAt: start, bloecke: [
            LokalerBlock(machineId: "m1", exerciseId: "e1", saetze: [satz(1, 80, 0)]),
            LokalerBlock(machineId: "m1", exerciseId: "e2", saetze: [satz(1, 60, 5)]),
        ])

        let z = try #require(Trainingszusammenfassung(session))

        #expect(z.geraeteAnzahl == 1)
        #expect(z.bloecke.count == 2)
    }

    @Test func nenntDasGewichtNurWennAlleSaetzeSichEinigSind() throws {
        let session = LokaleSession(id: UUID(), startedAt: start, bloecke: [
            LokalerBlock(machineId: "m1", exerciseId: "e1",
                         saetze: [satz(1, 80, 0), satz(2, 80, 5)]),
            LokalerBlock(machineId: "m2", exerciseId: "e2",
                         saetze: [satz(1, 45, 10), satz(2, 47.5, 15)]),
        ])

        let z = try #require(Trainingszusammenfassung(session))

        #expect(z.bloecke[0].gewichtKg == 80)
        // Uneinheitlich: lieber keine Zahl als eine falsche.
        #expect(z.bloecke[1].gewichtKg == nil)
    }

    @Test func merktSichEinGemeldetesProblemJeBlock() throws {
        let session = LokaleSession(id: UUID(), startedAt: start, bloecke: [
            LokalerBlock(machineId: "m1", exerciseId: "e1",
                         saetze: [satz(1, 80, 0), satz(2, 80, 5, problem: true)]),
        ])

        let z = try #require(Trainingszusammenfassung(session))

        #expect(z.bloecke[0].problemGemeldet)
    }

    @Test func eineEinheitOhneSaetzeHatKeineZusammenfassung() {
        let leer = LokaleSession(id: UUID(), startedAt: start, bloecke: [])

        #expect(Trainingszusammenfassung(leer) == nil)
    }
}

@MainActor
struct AbgelaufeneSessionTests {
    private let start = Date(timeIntervalSince1970: 1_757_000_000)

    private func store() -> WorkoutSessionStore {
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        return WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))
    }

    @Test func eineLaufendeEinheitGiltNichtAlsAbgelaufen() {
        let sut = store()
        _ = sut.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 80, reps: 10,
                            rir: nil, problemFlag: false, problemReason: nil, jetzt: start)

        #expect(sut.abgelaufeneSession(jetzt: start.addingTimeInterval(600)) == nil)
    }

    @Test func nachVierStundenGiltSieAlsAbgelaufen() {
        let sut = store()
        _ = sut.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 80, reps: 10,
                            rir: nil, problemFlag: false, problemReason: nil, jetzt: start)

        #expect(sut.abgelaufeneSession(jetzt: start.addingTimeInterval(4 * 3600 + 1)) != nil)
    }

    @Test func quittierenLaesstSieVerschwinden() {
        let sut = store()
        _ = sut.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 80, reps: 10,
                            rir: nil, problemFlag: false, problemReason: nil, jetzt: start)
        let spaeter = start.addingTimeInterval(5 * 3600)

        sut.ausgelaufeneQuittieren()

        // Der Satz auf dem leeren Tab steht einmal, nicht fuer immer.
        #expect(sut.abgelaufeneSession(jetzt: spaeter) == nil)
    }

    @Test func einManuellBeendetesTrainingGiltNichtAlsAusgelaufen() {
        let sut = store()
        _ = sut.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 80, reps: 10,
                            rir: nil, problemFlag: false, problemReason: nil, jetzt: start)
        sut.beenden()

        #expect(sut.abgelaufeneSession(jetzt: start.addingTimeInterval(5 * 3600)) == nil)
    }
}
```

- [ ] **Step 2: Tests laufen lassen, Fehlschlag bestätigen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -derivedDataPath /tmp/dd-sp3-t4 test -only-testing:FitnessMemberTests/TrainingszusammenfassungTests 2>&1 | tail -20
```

Erwartet: FAIL — `Trainingszusammenfassung` ist unbekannt.

- [ ] **Step 3: Die Zusammenfassung schreiben**

Create `apps/ios-member/FitnessMember/Workout/Trainingszusammenfassung.swift`:

```swift
import Foundation

/// Eine Zeile unter "Beim naechsten Mal" -- ohne den Vorschlag, der vom
/// Server kommt.
struct Blockzeile: Equatable, Identifiable {
    var id: String { "\(machineId):\(exerciseId)" }
    let machineId: String
    let exerciseId: String
    /// nil, wenn die Saetze sich nicht auf ein Gewicht einigen -- dann
    /// lieber keine Zahl als eine falsche.
    let gewichtKg: Double?
    let satzAnzahl: Int
    let problemGemeldet: Bool
}

/// Die Zahlen von TrainingAbschluss.
///
/// Sie kommen aus der lokalen Einheit, nicht vom Server: die App ist die
/// einzige Instanz, die alle Saetze sicher kennt, solange welche in der
/// Schreib-Warteschlange liegen. Ein serverseitig gerechneter Abschluss
/// zeigte nach einem Offline-Training zu wenig -- ausgerechnet dort, wo
/// das Mitglied am ehesten nachsieht, ob alles angekommen ist.
struct Trainingszusammenfassung: Equatable {
    let von: Date
    let bis: Date
    let dauerMinuten: Int
    let geraeteAnzahl: Int
    let satzAnzahl: Int
    let bloecke: [Blockzeile]

    /// nil fuer eine Einheit ohne Saetze -- die gibt es zwar nicht, weil
    /// die Session mit dem ersten Satz entsteht, aber ein Abschluss ohne
    /// Inhalt waere eine leere Statistik mit Nullen (SS5).
    init?(_ session: LokaleSession) {
        let alle = session.bloecke.flatMap(\.saetze)
        guard let erster = alle.map(\.performedAt).min(),
              let letzter = alle.map(\.performedAt).max()
        else { return nil }

        von = erster
        bis = letzter
        dauerMinuten = Int(letzter.timeIntervalSince(erster) / 60)
        // Geraete, nicht Bloecke: zwei Uebungen an derselben Maschine sind
        // ein Geraet (so zaehlt es auch der Server in machineCount).
        geraeteAnzahl = Set(session.bloecke.map(\.machineId)).count
        satzAnzahl = alle.count
        bloecke = session.bloecke.map { block in
            let gewichte = Set(block.saetze.map(\.weightKg))
            return Blockzeile(
                machineId: block.machineId,
                exerciseId: block.exerciseId,
                gewichtKg: gewichte.count == 1 ? gewichte.first : nil,
                satzAnzahl: block.saetze.count,
                problemGemeldet: block.saetze.contains(where: \.problemFlag)
            )
        }
    }
}
```

- [ ] **Step 4: Den Store um die ausgelaufene Einheit erweitern**

In `WorkoutSessionStore.swift`:

```swift
    /// Ob der Satz auf dem leeren Tab schon gezeigt wurde. Er steht einmal,
    /// nicht bei jedem Oeffnen.
    private var ausgelaufeneQuittiert = false

    /// Die gespeicherte Einheit, sofern sie NICHT mehr laeuft.
    ///
    /// Vergessenes Beenden ist laut M1-Spec SS5.2 der Regelfall. Ohne diesen
    /// Zugriff saehe das Mitglied am naechsten Tag einen leeren Tab und
    /// wuesste nicht, ob sein Training angekommen ist.
    func abgelaufeneSession(jetzt: Date = Date()) -> LokaleSession? {
        guard !ausgelaufeneQuittiert,
              gespeicherteSession != nil,
              aktiveSession(jetzt: jetzt) == nil
        else { return nil }
        return gespeicherteSession
    }

    func ausgelaufeneQuittieren() {
        ausgelaufeneQuittiert = true
    }
```

`beenden()` setzt `ausgelaufeneQuittiert = false` zurück und löscht `gespeicherteSession` — ein manuell beendetes Training ist nicht ausgelaufen, und die nächste Einheit soll den Satz wieder zeigen können.

**Und:** `gespeicherteSession` wird von `private(set) var` auf `private var` gestellt. Die Schlussdurchsicht von Sub-Projekt 2 hat angemerkt, dass die rohe Eigenschaft den Vier-Stunden-Filter umgeht; mit `abgelaufeneSession(jetzt:)` gibt es jetzt für jeden Zweck eine gefilterte Tür. Prüfe mit `grep -rn "gespeicherteSession" apps/ios-member`, dass außerhalb der Klasse niemand darauf zugreift, und melde das Ergebnis.

- [ ] **Step 5: Tests laufen lassen, Erfolg bestätigen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -derivedDataPath /tmp/dd-sp3-t4 test 2>&1 | grep -E "warning:|error:|TEST SUCCEEDED|TEST FAILED|Test run with"
rm -rf /tmp/dd-sp3-t4
```

Erwartet: `TEST SUCCEEDED`, zehn neue Tests, nur die vier vorbestehenden Warnungen.

- [ ] **Step 6: Commit**

```bash
git add apps/ios-member
git commit -m "feat(ios): Trainingszusammenfassung und die ausgelaufene Einheit

Zwei reine Ableitungen aus der lokalen Einheit. Die Zahlen des Abschlusses
kommen von dort, weil nur die App alle Saetze kennt, solange welche in der
Warteschlange liegen -- ein serverseitig gerechneter Abschluss zeigte nach
einem Offline-Training zu wenig.

Das Gewicht eines Blocks bleibt offen, wenn die Saetze sich nicht einig
sind: lieber keine Zahl als eine falsche.

abgelaufeneSession traegt den Satz auf dem leeren Tab. Vergessenes Beenden
ist laut M1-Spec SS5.2 der Regelfall; ohne ihn saehe das Mitglied am
naechsten Tag einen leeren Tab und wuesste nicht, ob sein Training
angekommen ist.

gespeicherteSession wird private -- die Schlussdurchsicht von Sub-Projekt 2
hatte angemerkt, dass die rohe Eigenschaft den Vier-Stunden-Filter umgeht.
Jetzt gibt es fuer jeden Zweck eine gefilterte Tuer."
```

---

### Aufgabe 5: Die Training-Wurzel bekommt ihre zwei Zustände

Sub-Projekt 2 hat `TrainingRootView` als Rumpf gebaut, damit der Kernflow schließbar wird. Hier bekommt sie ihre Gestalt: leer und laufend sind **keine zwei Screens**, sondern zwei Zustände derselben Wurzel.

**Artboards:** `TrainingLeer.dc.html`, `TrainingLaeuft.dc.html`. **Abweichungen (Spec Abschnitt 6):** der Satz zum automatischen Ende neben „Training beenden"; „seit 18:04" unter der verstrichenen Zeit.

**Files:**
- Modify: `apps/ios-member/FitnessMember/Screens/Training/TrainingRootView.swift`

**Interfaces:**
- Consumes: `Trainingszusammenfassung`, `WorkoutSessionStore.abgelaufeneSession(jetzt:)` / `.ausgelaufeneQuittieren()` (Aufgabe 4), `ScannerSheet` (Aufgabe 3), `Zahlformat` / `DesignSystem` / `PrimaryButton` / `SecondaryButton` / `PressButtonStyle` (Sub-Projekt 2).
- Produces: kein neues öffentliches Symbol — die Wurzel behält ihre Signatur `TrainingRootView(apiClient:)`.

- [ ] **Step 1: Den leeren Zustand bauen**

Nach `TrainingLeer.dc.html`: NFC dominant mit Zeichnung und eigener Überschrift („Halt dein iPhone an den Aufkleber"), darunter der Erklärsatz zum fehlenden Startknopf, dann QR als kleinerer zweiter Weg, dann der Gleichwertigkeitssatz.

Die NFC-Zeichnung ist im Artboard eine Illustration. Baue sie als SF-Symbol-Komposition (`wave.3.right` o. ä.) — **kein Bild-Asset**, das Projekt hat keine und soll keine bekommen, solange ein Symbol reicht.

Wortlaut unverändert aus dem Artboard:

```swift
Text("Am Gerät klebt ein Aufkleber mit dem gymodo-Zeichen. Dein Training startet von selbst, sobald du den ersten Satz sicherst — es gibt keinen Startknopf.")
```

```swift
Text("Auf jedem Aufkleber ist beides — antippen oder scannen, gleiches Ergebnis.")
```

Der zweite Satz trägt die Gleichwertigkeit, die die Optik allein nicht zeigt (§11). Er darf nicht gekürzt werden.

**Und der Satz zur ausgelaufenen Einheit**, nur wenn `sessions.abgelaufeneSession()` etwas liefert:

```swift
Text("Dein letztes Training wurde automatisch beendet.")
```

in `text-muted`, nicht `text-faint` — er ist tragende Information (§2). Beim Erscheinen einmal `sessions.ausgelaufeneQuittieren()` aufrufen, damit er nicht bei jedem Öffnen wieder steht.

- [ ] **Step 2: Den laufenden Zustand bauen**

Nach `TrainingLaeuft.dc.html`: Kopfzeile „Training läuft" mit verstrichener Zeit, Statistik (Geräte, Sätze), Blockliste mit „gemeldet"-Kennzeichen, Zirkel-Hinweis, „Nächstes Gerät", „Training beenden".

Die verstrichene Zeit über `TimelineView(.periodic(from: .now, by: 1))` gegen `session.startedAt`, tabellarisch — dasselbe Muster wie der Resttimer aus Sub-Projekt 2, aus demselben Grund: ein gespeicherter Zeitpunkt überlebt Hintergrund und Sperrbildschirm, ein Zähler nicht.

**Zwei Sätze aus der Abweichungstabelle:**

Unter der verstrichenen Zeit, in `text-muted`:

```swift
Text("seit \(Zahlformat.uhrzeit(session.startedAt))")
```

Es gibt keinen Startknopf (M1-Spec §5.6); ohne diesen Satz weiß niemand, warum plötzlich ein Training läuft.

Neben „Training beenden", in `text-faint` (das ist hier zulässig — es erklärt eine Alternative, es trägt nichts):

```swift
Text("Ohne neuen Satz endet das Training nach vier Stunden von selbst.")
```

**`Zahlformat` bekommt dafür eine Uhrzeit-Funktion.** Ergänze in `Zahlformat.swift`:

```swift
    /// "18:04" -- die Studio-Zeitzone spielt hier keine Rolle, weil die
    /// Einheit auf diesem Geraet lief.
    static func uhrzeit(_ zeitpunkt: Date) -> String {
        uhrzeitFormatter.string(from: zeitpunkt)
    }
```

mit einem `DateFormatter` auf `de_DE` und `dateFormat = "HH:mm"`, nach dem Muster des bestehenden `gewichtFormatter`.

Das „gemeldet"-Kennzeichen je Blockzeile kommt aus `problemFlag` und ist ein **Umriss** in `warn`, nie eine Fläche (§2).

- [ ] **Step 3: „Training beenden" führt zum Abschluss**

Heute ruft `beenden()` nur `sessions.beenden()` und feuert `completeSession` mit `try?`. Das reicht nicht mehr — der Abschluss-Screen braucht die Zahlen, und die sind nach `beenden()` weg.

**Reihenfolge festschreiben:**

```swift
private func beenden() {
    guard let session = sessions.aktiveSession(),
          let zusammenfassung = Trainingszusammenfassung(session)
    else { return }
    // Erst festhalten, dann beenden -- andersherum sind die Zahlen weg,
    // bevor der Screen sie zeigt.
    sessions.beenden()
    pfad.append(.abschluss(sessionId: session.id, zusammenfassung: zusammenfassung))
}
```

`GeraetRoute` bekommt dafür einen Fall. Da `Trainingszusammenfassung` `Equatable` ist und `GeraetRoute` `Hashable` sein muss, mach `Trainingszusammenfassung` und `Blockzeile` zusätzlich `Hashable` — beide bestehen nur aus `Hashable`-Bestandteilen, das ist eine Konformanzzeile ohne Umbau.

Der `completeSession`-Aufruf wandert in den Abschluss-Screen (Aufgabe 6), der seine Antwort braucht.

- [ ] **Step 4: Kaltbau und Abnahme**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -derivedDataPath /tmp/dd-sp3-t5 test 2>&1 | grep -E "warning:|error:|TEST SUCCEEDED|TEST FAILED"
rm -rf /tmp/dd-sp3-t5
```

Statisch gegen beide Artboards prüfen und im Bericht festhalten: **Zähle die Akzentflächen je Zustand — es muss genau eine sein** (leer: „QR-Code am Gerät scannen"? nein — die Hauptaktion ist der NFC-Weg, der kein Knopf ist; entscheide begründet und schreib die Begründung in den Bericht). Trefferflächen ≥ 44 pt, Abstände aus der Skala, Wortlaut unverändert.

**Ohne Simulator ist nichts Visuelles prüfbar.** Melde es als offen.

- [ ] **Step 5: Commit**

```bash
git add apps/ios-member
git commit -m "feat(ios): Training-Wurzel mit ihren zwei Zustaenden

Leer und laufend sind kein zweiter Screen, sondern zwei Zustaende derselben
Wurzel -- Sub-Projekt 2 hatte sie als Rumpf gebaut, damit der Kernflow
schliessbar wird.

Zwei Saetze, die die Design-Challenge angemahnt hatte: 'seit 18:04' erklaert
den impliziten Start, denn ohne Startknopf weiss sonst niemand, warum
ploetzlich ein Training laeuft. Und der Satz zum automatischen Ende steht
neben 'Training beenden' -- dort, wo er erklaert, was passiert, wenn man den
Knopf nicht drueckt.

'Training beenden' haelt die Zahlen fest, bevor es beendet. Andersherum
waeren sie weg, bevor der Abschluss sie zeigt."
```

---

### Aufgabe 6: `TrainingAbschluss`

Push innerhalb des Training-Tabs; die Tab-Leiste bleibt.

**Artboard:** `TrainingAbschluss.dc.html`. **Abweichungen (Spec Abschnitt 6):** „Training im Detail ansehen" entfällt — sein Ziel `SessionDetail` gehört zu Sub-Projekt 4, und ein Link, der nichts tut, ist schlechter als kein Link. Die Problemmeldung sieht aus wie auf `TrainingLaeuft`, nicht anders.

**Files:**
- Create: `apps/ios-member/FitnessMember/Screens/Training/TrainingAbschlussView.swift`
- Modify: `apps/ios-member/FitnessMember/Navigation/GeraetRoute.swift`

**Interfaces:**
- Consumes: `Trainingszusammenfassung` (Aufgabe 4), `CompletedSession.vorschlaege` (Aufgabe 1), `APIClient.completeSession` (Sub-Projekt 1), `CatalogStore` für die Namen von Gerät und Übung.
- Produces: `struct TrainingAbschlussView: View { let sessionId: UUID; let zusammenfassung: Trainingszusammenfassung; let apiClient: APIClient; let beiFertig: () -> Void }`

- [ ] **Step 1: Den Screen schreiben**

Aufbau nach Artboard: Zeitraum („Heute · 18:04 – 18:51"), „Training beendet", drei Zahlen (Minuten, Geräte, Sätze), „Beim nächsten Mal" mit einer Zeile je Block, der Satz zur Produktgrenze, „Fertig".

**Die Zahlen stehen sofort** — sie kommen aus der übergebenen `Trainingszusammenfassung`, nicht aus dem Netz.

**Die Vorschläge werden geladen:**

```swift
@State private var vorschlaege: [Blockvorschlag]?
@State private var vorschlagFehlt = false

.task {
    do {
        vorschlaege = try await apiClient.completeSession(sessionId: sessionId).vorschlaege
    } catch {
        // Kein Fehlerzustand: die Zahlen stehen, nur der Blick nach vorn
        // fehlt. Der Satz unten sagt genau das.
        vorschlagFehlt = true
    }
}
```

Solange `vorschlaege == nil && !vorschlagFehlt`, zeigt der Abschnitt „Beim nächsten Mal" **nichts** — kein Skelett. §5 lässt Skelette nur für Medien zu, nie über einer Zahl, und ein Vorschlag ist eine Zahl.

Bei `vorschlagFehlt`:

```swift
Text("Vorschläge brauchen Empfang. Deine Sätze sind gespeichert und gehen raus, sobald du wieder Netz hast.")
```

**Je Blockzeile** — Gerät und Übung aus `katalog.bootstrap`, das Delta aus dem Vorschlag:

| `reasonCode` | Anzeige |
| --- | --- |
| `korridor_oben_erreicht` | das Delta, z. B. „+2,5 kg" |
| `korridor_unten_verfehlt` | das Delta mit Minuszeichen |
| `im_korridor` | „Gewicht halten" |
| `problem_gemeldet` | „Kein Vorschlag" |
| `kein_verlauf`, `daten_uneindeutig`, `geraetegrenze_erreicht` | „Kein Vorschlag" |

Der Wortlaut des Artboards für die drei sichtbaren Fälle ist „+2,5 kg", „Gewicht halten", „Kein Vorschlag". Die übrigen `reasonCode`s zeigt das Artboard nicht; sie fallen auf „Kein Vorschlag", weil das stimmt und weil sieben Formulierungen für dieselbe Aussage niemandem helfen.

Das Delta über `Zahlformat.gewicht`, mit Vorzeichen — nie selbst formatiert.

**Der Satz zur Produktgrenze bleibt wörtlich:**

```swift
Text("Vorschläge entstehen aus deiner Historie und dem Zielkorridor deines Studios. Sie sind eine Rechnung, keine Empfehlung — du entscheidest.")
```

**„Fertig"** ist die eine Hauptaktion und trägt den Akzent; sie ruft `beiFertig()`, das den Pfad zur Wurzel zurücknimmt.

- [ ] **Step 2: Kaltbau und Abnahme**

**Der `GeraetRoute`-Fall `abschluss` wurde bereits in Aufgabe 5 angelegt** — sie brauchte ihn, um zu übersetzen. Lege ihn nicht erneut an; wenn er fehlt, ist Aufgabe 5 unvollständig und du meldest das, statt es hier nachzuholen.

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -derivedDataPath /tmp/dd-sp3-t6 test 2>&1 | grep -E "warning:|error:|TEST SUCCEEDED|TEST FAILED"
rm -rf /tmp/dd-sp3-t6
```

Gegen `TrainingAbschluss.dc.html` statisch prüfen: genau eine Akzentfläche („Fertig"), kein „Training im Detail ansehen", Problemmeldung in derselben Form wie auf `TrainingLaeuft`, Wortlaut der Produktgrenze unverändert.

- [ ] **Step 3: Commit**

```bash
git add apps/ios-member
git commit -m "feat(ios): TrainingAbschluss

Die Zahlen stehen sofort -- sie kommen aus der lokalen Einheit, die beim
Druck auf 'Training beenden' festgehalten wurde. Die Vorschlaege werden
nachgeladen; faellt das aus, bleiben die Zahlen und ein Satz sagt, warum
der Blick nach vorn fehlt.

Kein Skelett ueber dem Vorschlagsbereich: SS5 laesst Skelette nur fuer
Medien zu, nie ueber einer Zahl.

'Training im Detail ansehen' entfaellt -- sein Ziel gehoert zu
Sub-Projekt 4, und ein Link, der nichts tut, ist schlechter als kein Link."
```

---

### Aufgabe 7: Kurse — DTOs, Netzwerk und die reine Logik

Der Serververtrag ist fertig und screenorientiert. Diese Aufgabe bringt ihn nach Swift und baut die Entscheidungen, die alle drei Kurse-Screens teilen, als reine Funktionen.

**Files:**
- Create: `apps/ios-member/FitnessMember/Networking/DTOs/CourseWeek.swift`
- Modify: `apps/ios-member/FitnessMember/Networking/APIClient.swift`
- Create: `apps/ios-member/FitnessMember/Kurse/KursZustand.swift`
- Create: `apps/ios-member/FitnessMemberTests/KursZustandTests.swift`

**Interfaces:**
- Produces: `struct CourseWeek: Codable, Equatable` mit `from`, `to`, `timezone`, `cancellationDeadlineHours: Int`, `sessions: [CourseWeekSession]`; `struct CourseWeekSession: Codable, Equatable, Identifiable` mit `id` aus `sessionId` und allen Feldern des Serververtrags; `struct BookOutcome: Decodable`, `struct CancelOutcome: Decodable`.
- Produces: `APIClient.courseWeek(studio:from:to:)`, `.bookCourse(sessionId:)`, `.cancelCourse(sessionId:)`.
- Produces: `enum KursZustand { case abgesagt, vorbei, angemeldet, warteliste, frei, voll }` und `KursZustandRechner.zustand(fuer:jetzt:)`, `.abmeldenBis(startsAt:fristStunden:)`, `.meineKurse(aus:)` — von Aufgabe 8, 9, 10, 11 konsumiert.
- Produces: `KursZeit.uhrzeit(_ zeitpunkt: Date, zeitzone: String) -> String` und `.datumAusgeschrieben(_ zeitpunkt: Date, zeitzone: String) -> String`. **Nicht `Zahlformat.uhrzeit`** — das aus Aufgabe 5 formatiert gerätelokal, was für die eigene Trainingseinheit richtig ist. Kurse zeigt Studio-Zeiten (§10: „Zeitangaben in der Studio-Zeitzone"), und `CourseWeek.timezone` liefert sie mit. Zwei Funktionen, weil zwei Dinge gemeint sind — nicht eine mit einem optionalen Parameter, an dem eine Aufrufstelle es später vergisst.

- [ ] **Step 1: Die Tests schreiben**

Create `apps/ios-member/FitnessMemberTests/KursZustandTests.swift`:

```swift
import Foundation
import Testing
@testable import FitnessMember

struct KursZustandTests {
    private let jetzt = Date(timeIntervalSince1970: 1_757_000_000)

    private func termin(
        startVersatzStunden: Double = 3,
        status: String = "planned",
        freeSeats: Int = 4,
        ownStatus: String? = nil
    ) -> CourseWeekSession {
        CourseWeekSession(
            sessionId: "k1", templateId: "t1", name: "Kraftzirkel",
            description: nil,
            startsAt: ISO8601DateFormatter().string(
                from: jetzt.addingTimeInterval(startVersatzStunden * 3600)),
            localDay: "2026-09-08", durationMin: 60, capacity: 16,
            room: "Kursraum 2", instructorName: "Marek T.", status: status,
            bookedCount: 12, waitlistCount: 0, freeSeats: freeSeats,
            ownStatus: ownStatus, ownBookingId: ownStatus == nil ? nil : "b1",
            ownWaitlistPosition: ownStatus == "waitlisted" ? 3 : nil
        )
    }

    // Die sechs Zeilen der Tabelle aus Spec Abschnitt 5.3, in ihrer
    // Auswertungsreihenfolge.

    @Test func abgesagtSchlaegtAlles() {
        let abgesagtUndAngemeldet = termin(status: "cancelled", ownStatus: "booked")

        #expect(KursZustandRechner.zustand(fuer: abgesagtUndAngemeldet, jetzt: jetzt) == .abgesagt)
    }

    @Test func vorbeiSchlaegtDenEigenenStatus() {
        let vorbeiUndAngemeldet = termin(startVersatzStunden: -2, ownStatus: "booked")

        #expect(KursZustandRechner.zustand(fuer: vorbeiUndAngemeldet, jetzt: jetzt) == .vorbei)
    }

    @Test func angemeldet() {
        #expect(KursZustandRechner.zustand(fuer: termin(ownStatus: "booked"), jetzt: jetzt) == .angemeldet)
    }

    @Test func warteliste() {
        #expect(KursZustandRechner.zustand(fuer: termin(freeSeats: 0, ownStatus: "waitlisted"), jetzt: jetzt) == .warteliste)
    }

    @Test func freieplaetze() {
        #expect(KursZustandRechner.zustand(fuer: termin(freeSeats: 4), jetzt: jetzt) == .frei)
    }

    @Test func voll() {
        #expect(KursZustandRechner.zustand(fuer: termin(freeSeats: 0), jetzt: jetzt) == .voll)
    }

    @Test func einTerminDerGeradeLaeuftGiltAlsVorbei() {
        // Beginn ist vorbei: anmelden geht nicht mehr, abmelden auch nicht.
        #expect(KursZustandRechner.zustand(fuer: termin(startVersatzStunden: -0.5), jetzt: jetzt) == .vorbei)
    }
}

struct AbmeldefristTests {
    private let jetzt = Date(timeIntervalSince1970: 1_757_000_000)

    @Test func ziehtDieFristVomBeginnAb() throws {
        let beginn = jetzt.addingTimeInterval(3 * 3600)
        let grenze = try #require(KursZustandRechner.abmeldenBis(
            startsAt: ISO8601DateFormatter().string(from: beginn), fristStunden: 2))

        #expect(grenze == beginn.addingTimeInterval(-2 * 3600))
    }

    @Test func beiFristNullIstDerBeginnDieGrenze() throws {
        let beginn = jetzt.addingTimeInterval(3 * 3600)
        let grenze = try #require(KursZustandRechner.abmeldenBis(
            startsAt: ISO8601DateFormatter().string(from: beginn), fristStunden: 0))

        #expect(grenze == beginn)
    }

    @Test func einUnlesbarerBeginnLiefertKeineGrenze() {
        // Lieber keine Uhrzeit als eine erfundene.
        #expect(KursZustandRechner.abmeldenBis(startsAt: "kein Datum", fristStunden: 2) == nil)
    }
}

struct MeineKurseTests {
    @Test func nimmtNurEigeneBuchungenUndWartelistenplaetze() {
        // Aufbau ueber JSON, damit der Test den Vertrag prueft und nicht
        // einen handgeschriebenen Initialisierer.
        let woche = KursTestdaten.woche(ownStatus: ["booked", nil, "waitlisted", nil])

        let meine = KursZustandRechner.meineKurse(aus: woche)

        #expect(meine.count == 2)
        #expect(meine.allSatisfy { $0.ownStatus != nil })
    }

    @Test func behaeltDieZeitlicheReihenfolge() {
        let woche = KursTestdaten.woche(ownStatus: ["booked", "booked"])

        let meine = KursZustandRechner.meineKurse(aus: woche)

        #expect(meine[0].startsAt <= meine[1].startsAt)
    }
}
```

Dazu die Testdaten in derselben Datei, über `JSONDecoder` aus einem Literal — so prüft der Test den Dekodiervertrag mit:

```swift
enum KursTestdaten {
    static func woche(ownStatus: [String?]) -> CourseWeek {
        let termine = ownStatus.enumerated().map { index, status in
            """
            {"sessionId":"k\(index)","templateId":"t1","name":"Kurs \(index)",
             "description":null,"startsAt":"2026-09-1\(index)T18:00:00Z",
             "localDay":"2026-09-1\(index)","durationMin":60,"capacity":16,
             "room":null,"instructorName":null,"status":"planned",
             "bookedCount":1,"waitlistCount":0,"freeSeats":15,
             "ownStatus":\(status.map { "\"\($0)\"" } ?? "null"),
             "ownBookingId":null,"ownWaitlistPosition":null}
            """
        }.joined(separator: ",")
        let json = """
        {"from":"2026-09-10T00:00:00Z","to":"2026-09-17T00:00:00Z",
         "timezone":"Europe/Berlin","cancellationDeadlineHours":2,
         "sessions":[\(termine)]}
        """
        return try! JSONDecoder().decode(CourseWeek.self, from: Data(json.utf8))
    }
}
```

- [ ] **Step 2: Tests laufen lassen, Fehlschlag bestätigen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -derivedDataPath /tmp/dd-sp3-t7 test -only-testing:FitnessMemberTests/KursZustandTests 2>&1 | tail -20
```

Erwartet: FAIL — `CourseWeekSession` ist unbekannt.

- [ ] **Step 3: Die DTOs schreiben**

Create `apps/ios-member/FitnessMember/Networking/DTOs/CourseWeek.swift` — Feldnamen **exakt** wie `CourseWeek` und `CourseWeekSession` in `packages/domain/src/courses.ts`. Vergleiche sie Feld für Feld; ein Tippfehler scheitert hier zur Laufzeit, nicht beim Übersetzen. `CourseWeek` ist `Codable` (nicht nur `Decodable`), weil Aufgabe 8 die eigenen Buchungen auf Platte schreibt.

`BookOutcome` und `CancelOutcome` nach den gleichnamigen Typen in `courses.ts`.

- [ ] **Step 4: Die drei APIClient-Methoden**

```swift
    // MARK: - Kurse (Sub-Projekt 3, ausserhalb M1-Spec SS6.3)

    func courseWeek(studio: String, from: String, to: String) async throws(APIError) -> CourseWeek {
        try await get("me/courses?studio=\(studio)&from=\(from)&to=\(to)")
    }

    func bookCourse(sessionId: String) async throws(APIError) -> BookOutcome {
        try await sendNoBody("course-sessions/\(sessionId)/booking", method: "PUT")
    }

    func cancelCourse(sessionId: String) async throws(APIError) -> CancelOutcome {
        try await sendNoBody("course-sessions/\(sessionId)/booking", method: "DELETE")
    }
```

**Zwei Punkte, die du prüfen und im Bericht festhalten musst:**
1. `baseURL.appendingPathComponent(path)` kodiert `?` und `&` — ein Pfad mit Abfrageparametern kommt so **nicht** durch. Bau die URL für `courseWeek` über `URLComponents` und die vorhandenen Bausteine, ohne die anderen fünf Methoden anzufassen. Beschreibe im Bericht, was du geändert hast.
2. `sendNoBody` existiert noch nicht — es gibt `postNoBody`. Verallgemeinere es auf eine Methode oder ergänze eine schwesterliche Hilfsmethode; nimm den kleineren Eingriff und begründe ihn.

- [ ] **Step 5: Die reine Logik schreiben**

Create `apps/ios-member/FitnessMember/Kurse/KursZustand.swift` mit `KursZustand` und `KursZustandRechner`. Die Auswertungsreihenfolge ist verbindlich: **abgesagt schlägt vorbei, vorbei schlägt jeden eigenen Status.** Ein abgesagter Kurs, für den man angemeldet ist, ist abgesagt — nicht angemeldet.

`meineKurse(aus:)` filtert auf `ownStatus != nil` und sortiert nach `startsAt`.

`abmeldenBis(startsAt:fristStunden:)` gibt `Date?` zurück — `nil` bei unlesbarem Beginn, weil eine erfundene Uhrzeit schlimmer ist als keine.

- [ ] **Step 6: Tests laufen lassen und commiten**

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -derivedDataPath /tmp/dd-sp3-t7 test 2>&1 | grep -E "warning:|error:|TEST SUCCEEDED|TEST FAILED|Test run with"
rm -rf /tmp/dd-sp3-t7
```

```bash
git add apps/ios-member
git commit -m "feat(ios): Kurse -- DTOs, Netzwerk und die Zustandslogik

Die sechs Zustaende von KursDetail als reine Funktion, mit verbindlicher
Auswertungsreihenfolge: abgesagt schlaegt vorbei, vorbei schlaegt jeden
eigenen Status. Ein abgesagter Kurs, fuer den man angemeldet ist, ist
abgesagt.

Die Abmeldefrist liefert nichts, wenn der Beginn unlesbar ist -- eine
erfundene Uhrzeit waere schlimmer als keine.

Testdaten kommen aus JSON-Literalen statt aus handgeschriebenen
Initialisierern, damit die Tests den Dekodiervertrag mitpruefen."
```

---

### Aufgabe 8: `KurseStore` — laden, buchen, stornieren, und der Cache mit Grenze

Der Store hält den Wochenplan, führt Buchung und Stornierung aus und persistiert **ausschließlich** die eigenen Buchungen.

**Die Grenze ist der Kern dieser Aufgabe.** Eine Belegungszahl von vorhin ohne Netz als aktuell zu zeigen wäre dieselbe Unwahrheit, die beim Satz-Status vermieden wird — „6 von 20 frei", man geht hin, der Kurs ist voll. Die eigene Anmeldung dagegen ändert sich nicht und ist genau das, was man ohne Empfang wissen will.

**Files:**
- Create: `apps/ios-member/FitnessMember/Kurse/KurseFileStore.swift`
- Create: `apps/ios-member/FitnessMember/Kurse/KurseStore.swift`
- Create: `apps/ios-member/FitnessMemberTests/KurseStoreTests.swift`

**Interfaces:**
- Consumes: `CourseWeek`, `APIClient`-Kurse-Methoden, `KursZustandRechner.meineKurse` (Aufgabe 7).
- Produces: `protocol KurseLoading: Sendable` mit den drei Methoden, plus `extension APIClient: KurseLoading {}` — nach dem Muster von `BootstrapLoading` und `GeraetLoading`.
- Produces: `final class KurseFileStore { init(directory:); func load() -> GespeicherteBuchungen?; func save(_:) }` mit `struct GespeicherteBuchungen: Codable { let stand: Date; let termine: [CourseWeekSession]; let cancellationDeadlineHours: Int; let timezone: String }`.
- Produces: `@MainActor @Observable final class KurseStore` mit `private(set) var woche: CourseWeek?`, `private(set) var ladeZustand`, `private(set) var eigene: GespeicherteBuchungen?`, `func laden(studioId:von:bis:) async`, `func buchen(sessionId:) async throws(APIError)`, `func stornieren(sessionId:) async throws(APIError)`, `func reset()` — von Aufgabe 9, 10, 11, 12 konsumiert.

- [ ] **Step 1: Die Tests schreiben**

Create `apps/ios-member/FitnessMemberTests/KurseStoreTests.swift`. Ein Fake nach dem Muster von `FakeBootstrapLoader`, dann:

```swift
@MainActor
struct KurseStoreTests {
    @Test func speichertNurDieEigenenBuchungen() async {
        let (sut, verzeichnis) = store()
        await lade(sut, mit: KursTestdaten.woche(ownStatus: ["booked", nil, nil, "waitlisted"]))

        let aufPlatte = KurseFileStore(directory: verzeichnis).load()

        // Vier Termine kamen, zwei gehoeren dem Mitglied.
        #expect(aufPlatte?.termine.count == 2)
        #expect(aufPlatte?.termine.allSatisfy { $0.ownStatus != nil } == true)
    }

    @Test func speichertKeineBelegungszahlenFremderTermine() async {
        let (sut, verzeichnis) = store()
        await lade(sut, mit: KursTestdaten.woche(ownStatus: [nil, nil]))

        let aufPlatte = KurseFileStore(directory: verzeichnis).load()

        // Ohne eigene Buchung liegt nichts auf Platte -- eine
        // Belegungszahl von vorhin ist keine Information, die wir offline
        // zeigen duerfen.
        #expect(aufPlatte?.termine.isEmpty ?? true)
    }

    @Test func eigeneBuchungenUeberstehenEinenNeustart() async {
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let ersterLauf = KurseStore(loader: FakeKurseLoader(),
                                    fileStore: KurseFileStore(directory: verzeichnis))
        await lade(ersterLauf, mit: KursTestdaten.woche(ownStatus: ["booked"]))

        let zweiterLauf = KurseStore(loader: FakeKurseLoader(),
                                     fileStore: KurseFileStore(directory: verzeichnis))

        #expect(zweiterLauf.eigene?.termine.count == 1)
    }

    @Test func ohneNetzBleibenDieEigenenBuchungenStehenUndDerPlanFehlt() async {
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let ersterLauf = KurseStore(loader: FakeKurseLoader(),
                                    fileStore: KurseFileStore(directory: verzeichnis))
        await lade(ersterLauf, mit: KursTestdaten.woche(ownStatus: ["booked"]))

        let loader = FakeKurseLoader()
        await loader.setWoche(.failure(.offline))
        let zweiterLauf = KurseStore(loader: loader,
                                     fileStore: KurseFileStore(directory: verzeichnis))
        await zweiterLauf.laden(studioId: "s1", von: Date(), bis: Date())

        #expect(zweiterLauf.woche == nil)          // kein Wochenplan
        #expect(zweiterLauf.eigene?.termine.count == 1)  // aber meine Kurse
    }

    @Test func einErfolgreichesBuchenLaedtNeu() async {
        // Sonst zeigte der Screen nach dem Anmelden weiter "Anmelden".
        let (sut, _) = store()
        await lade(sut, mit: KursTestdaten.woche(ownStatus: [nil]))

        try? await sut.buchen(sessionId: "k0")

        #expect(sut.ladeZaehler == 2)
    }

    @Test func resetRaeumtSpeicherUndPlatte() async {
        let (sut, verzeichnis) = store()
        await lade(sut, mit: KursTestdaten.woche(ownStatus: ["booked"]))

        sut.reset()

        // Nach dem Abmelden gehoeren die Buchungen dem vorigen Konto.
        #expect(sut.eigene == nil)
        #expect(KurseFileStore(directory: verzeichnis).load()?.termine.isEmpty ?? true)
    }
}
```

`ladeZaehler` ist ein `private(set) var` auf dem Store, das nur für diesen Test existiert — vermerke das im Kommentar dort, damit niemand ihn später für Fachlogik hält.

- [ ] **Step 2: Test laufen lassen, Fehlschlag bestätigen**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -derivedDataPath /tmp/dd-sp3-t8 test -only-testing:FitnessMemberTests/KurseStoreTests 2>&1 | tail -20
```

Erwartet: FAIL — `KurseStore` ist unbekannt.

- [ ] **Step 3: Die Persistenz schreiben**

`KurseFileStore` nach dem Muster von `PendingWriteStore` und `SessionFileStore`: App-Support-Verzeichnis, JSON, atomar, Fehler still. Datei `eigene-kurse.json`.

Der Stand (`stand: Date`) wird mitgeschrieben, weil „Meine Kurse" ohne Netz sagen muss, **wann** dieser Stand war. Ohne die Zeitangabe wäre der Cache eine stille Behauptung.

- [ ] **Step 4: Den Store schreiben**

`laden(studioId:von:bis:)`:
1. `ladeZustand = .laedt`
2. `woche = try await loader.courseWeek(...)`
3. Bei Erfolg: `eigene` aus `KursZustandRechner.meineKurse(aus: woche)` bilden, mit `stand: Date()`, `cancellationDeadlineHours` und `timezone` aus der Antwort, und persistieren.
4. Bei Fehler: `woche` bleibt `nil`, `ladeZustand = .fehlgeschlagen`, **`eigene` bleibt unangetastet** — der Cache ist das, was den Screen dann trägt.

`buchen` und `stornieren` rufen den Client und laden danach neu. **Sie fangen den Fehler nicht** — der Servertext ist die Fehlermeldung, die der Screen zeigt (§5: sagt, was falsch ist und was gilt), und nur der Server weiß, ob der Platz weg ist oder die Frist vorbei.

`reset()` räumt Speicher und Platte, für den Aufruf beim Abmelden.

- [ ] **Step 5: Tests laufen lassen und commiten**

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -derivedDataPath /tmp/dd-sp3-t8 test 2>&1 | grep -E "warning:|error:|TEST SUCCEEDED|TEST FAILED|Test run with"
rm -rf /tmp/dd-sp3-t8
```

```bash
git add apps/ios-member
git commit -m "feat(ios): KurseStore mit der Grenze des Offline-Caches

Persistiert ausschliesslich die eigenen Buchungen. Eine Belegungszahl von
vorhin ohne Netz als aktuell zu zeigen waere dieselbe Unwahrheit, die wir
beim Satz-Status vermeiden -- '6 von 20 frei', man geht hin, der Kurs ist
voll. Die eigene Anmeldung dagegen aendert sich nicht und ist genau das,
was man ohne Empfang wissen will.

Der Stand wird mitgeschrieben: ohne Zeitangabe waere der Cache eine stille
Behauptung.

Buchen und Stornieren fangen ihren Fehler nicht -- nur der Server weiss,
ob der Platz weg ist oder die Frist vorbei, und er formuliert es."
```

---

### Aufgabe 9: `Kurse` — der Wochenplan

**Artboard:** `Kurse.dc.html`. **Abweichungen (Spec Abschnitt 6):** der warngelb gefüllte Wartelisten-Balken entfällt ganz; vier Akzentflächen werden eine, auf dem gewählten Tag; Chip-Radius Pille statt 6 px; alle vier Zeilen bekommen dieselbe Tap-Affordance, nicht nur eine.

**Files:**
- Create: `apps/ios-member/FitnessMember/Screens/Kurse/KurseWochenView.swift`

**Interfaces:**
- Consumes: `KurseStore`, `KursZustandRechner`, `CatalogStore.activeStudioId`, `Zahlformat`, `DesignSystem`.
- Produces: `struct KurseWochenView: View { let beiAuswahl: (CourseWeekSession) -> Void; let beiMeineKurse: () -> Void }` — von Aufgabe 12 konsumiert.

- [ ] **Step 1: Den Screen schreiben**

Aufbau nach Artboard: Kopf mit „Kurse" und dem Studionamen, Wochenstreifen (Mo–So mit Datum), „Heute · Donnerstag" plus Link „Meine Kurse", dann die Termine des gewählten Tages, dann die Fußnote „Kursplan und Plätze verwaltet dein Studio."

**Der Wochenstreifen trägt die eine Akzentfläche** — der gewählte Tag. Alles andere ist `surface`/`text-muted`. Das ist derselbe Gedanke wie beim Übungswechsel in Sub-Projekt 2: kein Screen ohne Hauptaktion bleibt ohne Akzent, aber er markiert dann den aktiven Wert und nichts sonst.

**Je Terminzeile:** Uhrzeit und Dauer, Name, „Trainer · Raum", die Belegung als **Zahl** („12 von 16"), und ein Statuschip als **Umriss** in Pillenform:

| Zustand | Chip |
| --- | --- |
| `.vorbei` | „VORBEI", `text-faint` |
| `.angemeldet` | „ANGEMELDET", `text-muted` |
| `.warteliste` | „WARTELISTE", `text-muted` |
| `.abgesagt` | „ABGESAGT", `warn` als **Umriss** |
| `.frei`, `.voll` | kein Chip |

Kein Balken. Die Zahl sagt dasselbe, und ein Balken, der Knappheit einfärbt, verstößt gegen die zweite nicht verhandelbare Regel.

**Jede Zeile ist antippbar, alle mit Chevron** — im Artboard trägt nur eine von vier eine Affordance, was den Rest wie tote Information aussehen lässt.

Uhrzeiten in der **Studio-Zeitzone** aus `woche.timezone` (§10), nicht in der Gerätezeitzone.

- [ ] **Step 2: Die vier Zustände**

- **Skelett** nur beim ersten Laden, nur über der Terminliste, nie über einer Zahl.
- **Leer:** „Für diesen Tag hat dein Studio keinen Kurs eingetragen." — Überschrift plus nächster Schritt, keine leere Statistik mit Nullen.
- **Offline:** `danger`-Umriss auf 10 % `danger`-Fläche, mit dem Hinweis, dass „Meine Kurse" weiter verfügbar ist.
- **Fehler:** der Servertext wörtlich.

- [ ] **Step 3: Kaltbau und Abnahme**

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -derivedDataPath /tmp/dd-sp3-t9 test 2>&1 | grep -E "warning:|error:|TEST SUCCEEDED|TEST FAILED"
rm -rf /tmp/dd-sp3-t9
```

Statisch prüfen und im Bericht festhalten: **`grep -c accent`** in der neuen Datei — genau ein Treffer, auf dem gewählten Tag. **`grep warn`** — nur als `stroke`, nie als `fill`. Kein `ProgressView`, kein Balken.

- [ ] **Step 4: Commit**

```bash
git add apps/ios-member
git commit -m "feat(ios): Kurse -- der Wochenplan

Der warngelb gefuellte Wartelisten-Balken entfaellt ganz: 'warn nie als
Flaeche' ist nicht verhandelbar, und die Zahl '20 von 20' sagt dasselbe,
ohne Knappheit als Fehlverhalten einzufaerben.

Vier Akzentflaechen werden eine, auf dem gewaehlten Tag -- derselbe
Gedanke wie beim Uebungswechsel: ein Screen ohne Hauptaktion bleibt nicht
ohne Akzent, aber der markiert dann den aktiven Wert und nichts sonst.

Alle vier Zeilen bekommen dieselbe Tap-Affordance. Im Artboard traegt nur
eine eine, was den Rest wie tote Information aussehen laesst."
```

---

### Aufgabe 10: `KursDetail`

**Artboard:** `KursDetail.dc.html`. **Abweichungen (Spec Abschnitt 6):** zwei Akzentflächen werden eine; statt eines Zustands sechs; „bis 2 Stunden" kommt aus `cancellationDeadlineHours` statt hartkodiert.

**Files:**
- Create: `apps/ios-member/FitnessMember/Screens/Kurse/KursDetailView.swift`

**Interfaces:**
- Consumes: `KurseStore`, `KursZustandRechner` (Aufgabe 7), `DesignSystem`, `PrimaryButton`, `InlineBanner`.
- Produces: `struct KursDetailView: View { let sessionId: String }` — von Aufgabe 12 konsumiert. Der Termin wird aus dem Store gelesen, nicht durchgereicht, damit er nach Buchen oder Stornieren aktuell ist.

- [ ] **Step 1: Den Screen schreiben**

Aufbau nach Artboard: Datum ausgeschrieben („Donnerstag, 27. August", §10), Kursname, Eckdaten (Beginn, Trainer, Ort, Plätze), Beschreibung, Studio-Zuschreibung, Hauptaktion, Fußnote.

**Die Hauptaktion kommt aus der Sechsertabelle** (Spec Abschnitt 5.3) und ist die eine Akzentfläche:

| Zustand | Hauptaktion | Darunter |
| --- | --- | --- |
| `.abgesagt` | keine | „Dein Studio hat diesen Termin abgesagt." |
| `.vorbei` | keine | „Dieser Termin ist vorbei." |
| `.angemeldet` | „Abmelden" | „Abmelden ist bis \<Uhrzeit\> möglich." |
| `.warteliste` | „Warteliste verlassen" | „Du stehst auf Platz \<n\>." |
| `.frei` | „Anmelden" | die Frist, damit sie vor der Zusage bekannt ist |
| `.voll` | „Auf die Warteliste" | „Alle Plätze sind vergeben." |

Die Uhrzeit aus `KursZustandRechner.abmeldenBis(startsAt:fristStunden:)` mit `woche.cancellationDeadlineHours`, formatiert in der Studio-Zeitzone. Liefert die Funktion `nil`, entfällt die Zeile — eine erfundene Uhrzeit wäre schlimmer als keine.

**Fehler nach einem Versuch** über `InlineBanner(tone: .danger, message:)` mit dem **Servertext wörtlich**. Nur der Server weiß, ob der Platz gerade vergeben wurde oder die Frist vorbei ist; der Client formuliert das nicht um.

**Während der Aktion** ist die Hauptaktion `isLoading` — `PrimaryButton` kann das bereits.

- [ ] **Step 2: Kaltbau und Abnahme**

Wie Aufgabe 9. Zusätzlich prüfen: genau eine Akzentfläche, und in den beiden aktionslosen Zuständen **keine** — ein Screen ohne Hauptaktion hat hier auch keinen aktiven Wert, den der Akzent markieren müsste. Halte diese Begründung im Bericht fest.

- [ ] **Step 3: Commit**

```bash
git add apps/ios-member
git commit -m "feat(ios): KursDetail mit allen sechs Zustaenden

Das Artboard zeigt einen, obwohl der Screen laut Titel 'Detail und
Anmeldung' leistet -- voll, angemeldet, auf der Warteliste, vorbei und
abgesagt fehlten. Die Auswertungsreihenfolge ist verbindlich: abgesagt
schlaegt vorbei, vorbei schlaegt jeden eigenen Status.

Die Abmeldefrist kommt aus cancellationDeadlineHours statt aus der
hartkodierten Zwei im Artboard -- das ist der Spaltenvorgabewert, nicht
die Frist dieses Studios. Ist der Beginn unlesbar, entfaellt die Zeile:
eine erfundene Uhrzeit waere schlimmer als keine.

Der Fehlertext kommt woertlich vom Server. Nur er weiss, ob der Platz
gerade vergeben wurde oder die Frist vorbei ist."
```

---

### Aufgabe 11: `KurseMeine`

**Artboard:** `KurseMeine.dc.html` — der einzige der drei Kurse-Screens, der die Akzentregel bereits einhält. **Abweichungen (Spec Abschnitt 6):** der wichtigste Satz steht dort in `text-faint` und wird auf `text-muted` gehoben; „Abmelden bis 16:00" wird berechnet statt hartkodiert.

**Files:**
- Create: `apps/ios-member/FitnessMember/Screens/Kurse/KurseMeineView.swift`

**Interfaces:**
- Consumes: `KurseStore.eigene`, `KursZustandRechner`, `DesignSystem`.
- Produces: `struct KurseMeineView: View { let beiAuswahl: (String) -> Void }` — von Aufgabe 12 konsumiert.

- [ ] **Step 1: Den Screen schreiben**

Drei Abschnitte nach Artboard: „Angemeldet", „Auf der Warteliste", „Nächste Woche". Je Zeile ein Datumsblock (Wochentag kurz + Tag), Kursname, Zeitraum und Raum, Trainer.

**Bei „Angemeldet"** steht die berechnete Abmeldefrist und ein „Abmelden" als Nebenaktion.

**Bei „Auf der Warteliste"** steht die Position und darunter der Satz, der wörtlich bleibt:

```swift
Text("Rückt jemand ab, bekommst du den Platz automatisch. Du siehst es hier unter Meine Kurse. Bis dahin ist nichts reserviert.")
```

in **`text-muted`**, nicht `text-faint` — er ist die tragende Information dieses Abschnitts, und §2 lässt `text-faint` nur für nicht-tragende Information zu.

**Dieser Satz verspricht keine Benachrichtigung, und das ist Absicht.** Es gibt keine. Das Nachrücken passiert serverseitig stumm und unter Zeilensperre; das Mitglied erfährt es beim nächsten Öffnen. Kein Wort daran ändern (§11).

**Ohne Empfang** trägt der Screen den Cache: dieselben Zeilen plus eine Zeile mit dem Stand („Stand: heute, 14:03"). Ohne die Zeitangabe wäre der Cache eine stille Behauptung.

**Leer:** „Du bist für keinen Kurs angemeldet." plus der nächste Schritt — zurück zum Wochenplan.

- [ ] **Step 2: Kaltbau, Abnahme, Commit**

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -derivedDataPath /tmp/dd-sp3-t11 test 2>&1 | grep -E "warning:|error:|TEST SUCCEEDED|TEST FAILED"
rm -rf /tmp/dd-sp3-t11
```

```bash
git add apps/ios-member
git commit -m "feat(ios): KurseMeine

Der Wartelisten-Satz steht in text-muted statt text-faint -- er ist die
tragende Information des Abschnitts, und SS2 laesst text-faint nur fuer
nicht-tragende zu.

Er verspricht keine Benachrichtigung, und das ist Absicht: es gibt keine.
Das Nachruecken passiert serverseitig stumm; das Mitglied erfaehrt es beim
naechsten Oeffnen, genau wie der Satz es sagt.

Ohne Empfang traegt der Cache den Screen -- mit Zeitangabe des Stands.
Ohne sie waere er eine stille Behauptung."
```

---

### Aufgabe 12: Kurse-Tab verdrahten

Die letzte Aufgabe: der Kurse-Tab ist seit Sub-Projekt 1 ein Platzhalter. Hier bekommt er seinen Inhalt.

**Files:**
- Create: `apps/ios-member/FitnessMember/Navigation/KursRoute.swift`
- Modify: `apps/ios-member/FitnessMember/Navigation/MainTabView.swift`
- Modify: `apps/ios-member/FitnessMember/Navigation/RootView.swift`
- Modify: `apps/ios-member/FitnessMember/FitnessMemberApp.swift`

**Interfaces:**
- Produces: `enum KursRoute: Hashable { case detail(sessionId: String); case meine }`
- Consumes: alles aus den Aufgaben 7 bis 11.

- [ ] **Step 1: Route und Tab**

`KurseWochenView` bekommt einen `NavigationStack` mit typisiertem Pfad; `KursDetail` und `KurseMeine` sind Pushes und behalten die Tab-Leiste. In `MainTabView` ersetzt der Kurse-Tab den `PlaceholderView`.

- [ ] **Step 2: Den Store in die Umgebung**

`KurseStore` in `FitnessMemberApp` anlegen und über `.environment` weitergeben, nach dem Muster von `WorkoutSessionStore` aus Sub-Projekt 2.

**Beim Abmelden fällt er mit.** In `RootView` gibt es bereits den Zweig, der `catalogStore.reset()` und `workoutStore.reset()` aufruft — `kurseStore.reset()` gehört dazu. Die Buchungen des vorigen Kontos dürfen dem nächsten nicht erscheinen; dieselbe Begründung, die in Sub-Projekt 2 schon zweimal galt.

- [ ] **Step 3: Laden auslösen**

Der Wochenplan wird geladen, wenn der Kurse-Tab erscheint und wenn sich das aktive Studio ändert. `CatalogStore.activeStudioId` liefert es.

**Achtung, Lehre aus Sub-Projekt 2:** `TabView` feuert `.onAppear`/`.task` für einen **nicht ausgewählten** Tab beim ersten Aufbau **nicht**. Das hatte dort den Kaltstart über Universal Link stillgelegt. Hier ist die Folge harmloser — der Plan lädt einfach erst beim ersten Öffnen des Tabs, was richtig ist —, aber prüfe und beschreibe im Bericht, wann genau geladen wird, damit niemand später von einem leeren Tab überrascht wird.

- [ ] **Step 4: Voller Kaltbau**

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -derivedDataPath /tmp/dd-sp3-t12 test 2>&1 | grep -E "warning:|error:|TEST SUCCEEDED|TEST FAILED|Test run with"
rm -rf /tmp/dd-sp3-t12
pnpm typecheck 2>&1 | tail -4
cd packages/domain && pnpm vitest run 2>&1 | tail -4
```

Erwartet: alles grün, nur die vier vorbestehenden Warnungen.

- [ ] **Step 5: Commit**

```bash
git add apps/ios-member
git commit -m "feat(ios): Kurse-Tab verdrahtet

Seit Sub-Projekt 1 ein Platzhalter, jetzt mit Inhalt. KursDetail und
KurseMeine sind Pushes und behalten die Tab-Leiste.

Der KurseStore faellt beim Abmelden mit -- die Buchungen des vorigen
Kontos duerfen dem naechsten nicht erscheinen. Dieselbe Begruendung, die
in Sub-Projekt 2 schon fuer Katalog und laufende Einheit galt."
```

---

## Abnahme des Sub-Projekts

Erst wenn **alle** Punkte belegt sind:

- [ ] `pnpm typecheck` ohne Fehler
- [ ] `cd packages/domain && pnpm vitest run` grün
- [ ] **Kaltbau** mit isoliertem `-derivedDataPath` grün, **keine neue Warnung** über die vier vorbestehenden hinaus — und das Verzeichnis danach gelöscht
- [ ] Alle sieben Artboards abgenommen, gegen die Abweichungstabelle in Abschnitt 6 der Spec, nicht wörtlich
- [ ] Genau eine Akzentfläche je Screen, auf allen sieben nachgezählt; `warn` nirgends als Fläche
- [ ] VoiceOver-Durchgang je Screen
- [ ] Dynamic Type bis XXL ohne Layoutbruch
- [ ] Reduce Motion über alle Bewegungen
- [ ] **Flugmodus-Durchgang über beide Hälften:** Training zeigt Zahlen ohne Vorschlag; Kurse zeigt „Meine Kurse" mit Stand und den Wochenplan gesperrt
- [ ] Ein Kurs gebucht, ein Kurs storniert, ein Wartelistenplatz belegt — jeweils gegen ein echtes Studio
- [ ] Ein Training vergessen zu beenden, vier Stunden gewartet, den Satz auf dem leeren Tab gesehen

**Offen aus Sub-Projekt 2, blockiert dieses Sub-Projekt nicht:** die manuelle Abnahme des Gerät-Kernflows (`docs/superpowers/plans/2026-09-08-geraet-kernflow-abnahme.md`). Ihr wichtigster Punkt — das verschachtelte Scrollen im Wertrad — betrifft eine Komponente, die dieses Sub-Projekt nicht anfasst.
