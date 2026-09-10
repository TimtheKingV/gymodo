# Gerät ohne Scan wählen — Umsetzungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ein Mitglied, das einem Studio zugeordnet ist, kann ein Gerät über Suche und Liste wählen, auch wenn kein Aufkleber daran klebt — mit demselben Gerätefoto, Video und Gewichtsvorschlag wie nach einem Scan.

**Architecture:** Der Rumpf von `getTagContext` zieht nach `getMachineContext` um; `tag-context` bleibt als Auflöser stehen und delegiert. Eine zweite Next.js-Route serviert denselben Kontext über die `machineId`. In der App entscheidet `GeraetModel.kontextLaden()` künftig zwischen beiden Wegen. Liste und Suche sind eine reine Ableitung auf dem Prefetch (`enum GeraeteAuswahl`), ohne Netz und ohne Ladezustand.

**Tech Stack:** TypeScript / Next.js App Router / Supabase (`packages/domain`, `apps/web`), Swift 6 / SwiftUI / Swift Testing / XcodeGen (`apps/ios-member`), Vitest für Integrationstests.

**Spec:** `docs/superpowers/specs/2026-09-10-ios-geraet-ohne-scan-design.md`
**Entwurf:** `docs/superpowers/design/geraet-ohne-scan/` (Blatt 01–09)

## Global Constraints

- **Kommentare in Swift ohne Umlaute** (ASCII), wie im gesamten iOS-Ziel. Nutzertexte tragen selbstverständlich Umlaute.
- **Kommentare begründen, sie beschreiben nicht.** Sie sagen, warum etwas so ist, nicht was der Code tut.
- **Design-Tokens kommen aus `DesignSystem.swift`**, nie als Literal: `Color.bg` `#0A0B0D`, `surface` `#14161A`, `surfaceRaised` `#1D2026`, `line` `#2A2E36`, `text` `#F2F4F7`, `textMuted` `#9BA3AF`, `textFaint` `#5C636E`, `accent` `#D4FF3F`, `warn` `#FFB020`. Radien `card` 12, `neben` 14, `haupt` 16, `pille` 999. Abstände 4/8/12/16/24/32/48.
- **Eine Akzentfläche pro Screen** (§2). Auf dem Auswahlscreen ist das das fokussierte Suchfeld; die Zeilen tragen Akzent nur als Text.
- **Hit-Targets nie unter 44 pt.**
- **Die App misst nichts** (§10): kein Text darf eine Messung behaupten, die nicht stattgefunden hat.
- **Swift-Tests laufen mit Swift Testing** (`import Testing`, `@Test`, `#expect`), als `struct`-Suite, nicht XCTest.
- **Neue Swift-Dateien brauchen keinen pbxproj-Eingriff:** `apps/ios-member/project.yml` zieht Verzeichnisse; nach dem Anlegen `xcodegen generate` laufen lassen.
- **Integrationstests brauchen ein laufendes Supabase** und die Variablen `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` aus `.env`.

---

## Task 1: `getMachineContext` aus `getTagContext` herauslösen

Der Rumpf zieht um, das Verhalten des Scan-Wegs bleibt Byte für Byte gleich. Der Beweis dafür ist, dass `tests/integration/domain-tag-context.test.ts` **unverändert** grün bleibt — diese Datei wird in dieser Aufgabe nicht angefasst.

**Files:**
- Create: `packages/domain/src/machine-context.ts`
- Modify: `packages/domain/src/tag-context.ts`
- Modify: `packages/domain/src/index.ts:82-84`
- Create: `tests/integration/domain-machine-context.test.ts`

**Interfaces:**
- Consumes: nichts aus früheren Aufgaben.
- Produces:
  - `getMachineContext(client: SupabaseClient, machineId: string): Promise<MachineContext>`
  - `type MachineContext` — feldgleich mit dem heutigen `TagContext`
  - `getTagContext(client, token)` bleibt, Signatur und Rückgabetyp unverändert
  - `type TagContext` bleibt als Alias exportiert

- [ ] **Step 1: Den neuen Integrationstest schreiben**

Create `tests/integration/domain-machine-context.test.ts`:

```ts
import { beforeAll, describe, expect, it } from "vitest";
import {
  createTagToken,
  getMachineContext,
  getTagContext,
} from "@fitretro/domain";
import {
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";
import { tagsAnlegen } from "../helpers/tags.js";

let studioA: string;
let studioB: string;
let memberAEmail: string;
let memberAId: string;
let machineA: string;
let machineForeign: string;
let breitId: string;
let tokenA: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioError } = await admin
    .from("studios")
    .insert([{ name: "MC Studio A" }, { name: "MC Studio B" }])
    .select("id");
  if (studioError) throw studioError;
  studioA = studios[0]!.id;
  studioB = studios[1]!.id;

  memberAEmail = uniqueEmail("mc-member-a");
  memberAId = await createTestUser(memberAEmail);

  const { error: membershipError } = await admin
    .from("studio_memberships")
    .insert({ studio_id: studioA, user_id: memberAId, role: "member" });
  if (membershipError) throw membershipError;

  const { data: model, error: modelError } = await admin
    .from("equipment_models")
    .insert({
      studio_id: studioA,
      name: "Kabelzug",
      manufacturer: "Technogym",
      weight_step_kg: 2.5,
      min_weight_kg: 5,
      max_weight_kg: 100,
    })
    .select("id")
    .single();
  if (modelError) throw modelError;

  const { error: settingError } = await admin
    .from("equipment_setting_definitions")
    .insert({
      equipment_model_id: model.id,
      key: "sitz",
      label: "Sitzposition",
      kind: "number",
      min_value: 1,
      max_value: 8,
      step_value: 1,
      sort_order: 1,
    });
  if (settingError) throw settingError;

  const { data: exercises, error: exerciseError } = await admin
    .from("exercises")
    .insert({
      studio_id: studioA,
      name: "Latzug breit",
      target_reps_min: 8,
      target_reps_max: 12,
    })
    .select("id");
  if (exerciseError) throw exerciseError;
  breitId = exercises[0]!.id;

  const { error: linkError } = await admin
    .from("equipment_model_exercises")
    .insert({ equipment_model_id: model.id, exercise_id: breitId, sort_order: 1 });
  if (linkError) throw linkError;

  const { data: machines, error: machineError } = await admin
    .from("machines")
    .insert({ studio_id: studioA, equipment_model_id: model.id, label: "12" })
    .select("id")
    .single();
  if (machineError) throw machineError;
  machineA = machines.id;

  const { data: foreignModel, error: foreignModelError } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioB, name: "Fremdgeraet", weight_step_kg: 5 })
    .select("id")
    .single();
  if (foreignModelError) throw foreignModelError;

  const { data: foreign, error: foreignMachineError } = await admin
    .from("machines")
    .insert({
      studio_id: studioB,
      equipment_model_id: foreignModel.id,
      label: "99",
    })
    .select("id")
    .single();
  if (foreignMachineError) throw foreignMachineError;
  machineForeign = foreign.id;

  tokenA = createTagToken();
  await tagsAnlegen(admin, [
    { studioId: studioA, machineId: machineA, token: tokenA, status: "active" },
  ]);
});

describe("getMachineContext", () => {
  it("liefert Geraet, Modell, Einstellparameter und Uebungen", async () => {
    const client = await userClient(memberAEmail);

    const context = await getMachineContext(client, machineA);

    expect(context.machine.id).toBe(machineA);
    expect(context.machine.label).toBe("12");
    expect(context.equipmentModel.name).toBe("Kabelzug");
    expect(context.equipmentModel.weightStepKg).toBe(2.5);
    expect(context.settingDefinitions.map((s) => s.key)).toEqual(["sitz"]);
    expect(context.exercises.map((e) => e.name)).toEqual(["Latzug breit"]);
    expect(context.selectedExerciseId).toBe(breitId);
  });

  // Der eigentliche Punkt der Aufteilung: beide Wege muessen dasselbe
  // liefern, sonst waere der Listenweg zweiter Klasse.
  it("liefert dasselbe wie getTagContext fuer dasselbe Geraet", async () => {
    const client = await userClient(memberAEmail);

    const ueberTag = await getTagContext(client, tokenA);
    const ueberId = await getMachineContext(client, machineA);

    expect(ueberId.machine).toEqual(ueberTag.machine);
    expect(ueberId.equipmentModel).toEqual(ueberTag.equipmentModel);
    expect(ueberId.settingDefinitions).toEqual(ueberTag.settingDefinitions);
    expect(ueberId.exercises).toEqual(ueberTag.exercises);
    expect(ueberId.selectedExerciseId).toBe(ueberTag.selectedExerciseId);
  });

  // Ein Token ist ein oeffentlicher Locator, den jeder scannen kann, der
  // davorsteht. Eine machineId ist erratbar -- deshalb ist DIESER Test der
  // Sicherheitsbeweis des ganzen Sub-Projekts.
  it("cross-tenant: ein Geraet aus einem fremden Studio ist nicht lesbar", async () => {
    const client = await userClient(memberAEmail);

    await expect(getMachineContext(client, machineForeign)).rejects.toMatchObject({
      code: "not_found",
    });
  });

  it("antwortet auf eine unbekannte machineId neutral mit not_found", async () => {
    const client = await userClient(memberAEmail);

    await expect(
      getMachineContext(client, crypto.randomUUID()),
    ).rejects.toMatchObject({ code: "not_found" });
  });

  it("haelt den Vorschlag in progression_suggestions fest", async () => {
    const client = await userClient(memberAEmail);
    const admin = serviceClient();

    await getMachineContext(client, machineA);

    const { data } = await admin
      .from("progression_suggestions")
      .select("machine_id, user_id")
      .eq("machine_id", machineA)
      .eq("user_id", memberAId);

    expect(data!.length).toBeGreaterThan(0);
  });
});
```

- [ ] **Step 2: Test laufen lassen und Fehlschlag bestätigen**

```bash
pnpm test:integration -- domain-machine-context
```

Erwartet: FAIL — `getMachineContext` ist kein Export von `@fitretro/domain`.

- [ ] **Step 3: `machine-context.ts` anlegen**

Create `packages/domain/src/machine-context.ts`. Der Inhalt ist der heutige `tag-context.ts`, mit vier Änderungen: der Typ heißt `MachineContext`, die Funktion heißt `getMachineContext` und nimmt `machineId` statt `token`, der Tag-Lookup entfällt, und die Fehlermeldung nennt keinen Code.

```ts
import type { SupabaseClient } from "@supabase/supabase-js";
import { requireUserId } from "./auth.js";
import { DomainError } from "./errors.js";
import {
  MEDIA_URL_TTL_SECONDS,
  PHOTO_BUCKET,
  VIDEO_BUCKET,
} from "./media.js";
import { signMediaUrl, signMediaUrls } from "./media-store.js";
import {
  PROGRESSION_ALGO_VERSION,
  suggestNextWeight,
  toBlocks,
  type BlockInput,
  type ProgressionSuggestion,
} from "./progression.js";

/** So viele Trainingstage schaut die Progressionsregel zurueck. */
const HISTORY_DAYS = 6;

export type MachineContext = {
  machine: { id: string; label: string; locationNote: string | null };
  equipmentModel: {
    id: string;
    name: string;
    manufacturer: string | null;
    /**
     * Kurzlebige signierte URL, kein Speicherpfad: der Bucket ist privat,
     * mit einem Pfad allein koennte der Screen nichts laden.
     */
    photoUrl: string | null;
    weightStepKg: number;
    minWeightKg: number;
    maxWeightKg: number | null;
  };
  settingDefinitions: Array<{
    key: string;
    label: string;
    kind: string;
    minValue: number | null;
    maxValue: number | null;
    stepValue: number | null;
    unit: string | null;
    /** Nur bei kind = 'enum' gesetzt; sonst null (Constraint aus 0017). */
    allowedValues: string[] | null;
  }>;
  exercises: Array<{
    id: string;
    name: string;
    description: string | null;
    targetRepsMin: number;
    targetRepsMax: number;
    /** Ebenfalls signiert; null, solange kein Video da ist (Spec 6.8). */
    instructionVideoUrl: string | null;
  }>;
  selectedExerciseId: string | null;
  calibration: {
    settingValues: unknown;
    schemaVersion: number;
    source: string;
    createdAt: string;
  } | null;
  history: Array<{
    performedOn: string;
    weightKg: number;
    reps: number[];
  }>;
  suggestion: ProgressionSuggestion;
};

type SetRow = {
  exercise_id: string;
  weight_kg: number | string;
  reps: number;
  rir: number | string | null;
  problem_flag: boolean;
  performed_at: string;
};

/**
 * Alles, was der Geraete-Screen braucht -- in einer Anfrage.
 *
 * Screenorientiert statt ressourcenorientiert (Spec 6.3): Geraet, Uebungen
 * mit Vorauswahl, Einstellparameter, eigene Kalibrierung, eigene Historie
 * und der Vorschlag kommen zusammen, statt in fuenf Roundtrips.
 *
 * Diese Funktion trug frueher den Namen getTagContext und begann mit einem
 * Tag-Lookup. Seit ein Geraet auch aus einer Liste gewaehlt werden kann,
 * haengt der Rumpf nur noch an der machineId -- getTagContext ist zum
 * Aufloeser geschrumpft und ruft hier herein.
 *
 * Die Autorisierung kommt von RLS: `machines` ist auf die Studios des
 * Mitglieds beschraenkt, ein fremdes Geraet liefert deshalb null. Die
 * Antwort darauf unterscheidet nicht zwischen "gibt es nicht" und "gehoert
 * dir nicht" -- eine machineId ist erratbar, anders als ein Tag-Token, das
 * man am Geraet ablesen muss.
 */
export async function getMachineContext(
  client: SupabaseClient,
  machineId: string,
): Promise<MachineContext> {
  const userId = await requireUserId(client);

  const { data: machine } = await client
    .from("machines")
    .select(
      "id, label, location_note, studio_id, equipment_models (id, name, manufacturer, photo_path, weight_step_kg, min_weight_kg, max_weight_kg)",
    )
    .eq("id", machineId)
    .maybeSingle<{
      id: string;
      label: string;
      location_note: string | null;
      studio_id: string;
      equipment_models: {
        id: string;
        name: string;
        manufacturer: string | null;
        photo_path: string | null;
        weight_step_kg: number | string;
        min_weight_kg: number | string;
        max_weight_kg: number | string | null;
      };
    }>();
  if (!machine) {
    throw new DomainError("not_found", "Dieses Geraet ist nicht verfuegbar.");
  }
  const model = machine.equipment_models;

  const { data: settings } = await client
    .from("equipment_setting_definitions")
    .select(
      "key, label, kind, min_value, max_value, step_value, unit, allowed_values",
    )
    .eq("equipment_model_id", model.id)
    .order("sort_order", { ascending: true });

  const { data: links } = await client
    .from("equipment_model_exercises")
    .select(
      "sort_order, exercises (id, name, description, target_reps_min, target_reps_max), instruction_assets (storage_path)",
    )
    .eq("equipment_model_id", model.id)
    .order("sort_order", { ascending: true });

  type LinkRow = {
    exercises: {
      id: string;
      name: string;
      description: string | null;
      target_reps_min: number;
      target_reps_max: number;
    };
    instruction_assets: Array<{ storage_path: string }>;
  };
  const linkRows = (links ?? []) as unknown as LinkRow[];

  // Alle Videopfade in einem Aufruf signieren statt je Uebung einzeln --
  // der Screen soll mit einer Anfrage auskommen (Spec 6.3).
  const videoPfade = linkRows
    .map((row) => row.instruction_assets[0]?.storage_path)
    .filter((pfad): pfad is string => Boolean(pfad));
  const [videoUrls, photoUrl] = await Promise.all([
    signMediaUrls(client, VIDEO_BUCKET, videoPfade, MEDIA_URL_TTL_SECONDS),
    model.photo_path
      ? signMediaUrl(client, PHOTO_BUCKET, model.photo_path, MEDIA_URL_TTL_SECONDS)
      : Promise.resolve(null),
  ]);

  const exercises = linkRows.map((row) => {
    const pfad = row.instruction_assets[0]?.storage_path;
    return {
      id: row.exercises.id,
      name: row.exercises.name,
      description: row.exercises.description,
      targetRepsMin: row.exercises.target_reps_min,
      targetRepsMax: row.exercises.target_reps_max,
      instructionVideoUrl: (pfad && videoUrls.get(pfad)) || null,
    };
  });

  // Vorauswahl: zuletzt an diesem Geraet genutzte Uebung, sonst die erste
  // aus der vom Studio gepflegten Reihenfolge (Spec 5.7).
  const { data: lastUsed } = await client
    .from("workout_sets")
    .select("exercise_id")
    .eq("user_id", userId)
    .eq("machine_id", machine.id)
    .order("performed_at", { ascending: false })
    .limit(1)
    .maybeSingle<{ exercise_id: string }>();

  const selectedExerciseId = lastUsed?.exercise_id ?? exercises[0]?.id ?? null;

  let calibration: MachineContext["calibration"] = null;
  let blocks: BlockInput[] = [];
  let suggestion: ProgressionSuggestion = suggestNextWeight({
    targetRepsMin: 0,
    targetRepsMax: 0,
    weightStepKg: Number(model.weight_step_kg),
    minWeightKg: Number(model.min_weight_kg),
    maxWeightKg: Number(model.max_weight_kg ?? 9999),
    history: [],
  });

  if (selectedExerciseId) {
    const selected = exercises.find((e) => e.id === selectedExerciseId);

    const { data: calibrationRow } = await client
      .from("member_machine_calibrations")
      .select("setting_values, schema_version, source, created_at")
      .eq("user_id", userId)
      .eq("machine_id", machine.id)
      .eq("exercise_id", selectedExerciseId)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle<{
        setting_values: unknown;
        schema_version: number;
        source: string;
        created_at: string;
      }>();
    if (calibrationRow) {
      calibration = {
        settingValues: calibrationRow.setting_values,
        schemaVersion: calibrationRow.schema_version,
        source: calibrationRow.source,
        createdAt: calibrationRow.created_at,
      };
    }

    const { data: setRows } = await client
      .from("workout_sets")
      .select("exercise_id, weight_kg, reps, rir, problem_flag, performed_at")
      .eq("user_id", userId)
      .eq("machine_id", machine.id)
      .eq("exercise_id", selectedExerciseId)
      .order("performed_at", { ascending: false })
      .limit(HISTORY_DAYS * 6);

    blocks = toBlocks((setRows ?? []) as SetRow[]);

    suggestion = suggestNextWeight({
      targetRepsMin: selected?.targetRepsMin ?? 8,
      targetRepsMax: selected?.targetRepsMax ?? 12,
      weightStepKg: Number(model.weight_step_kg),
      minWeightKg: Number(model.min_weight_kg),
      maxWeightKg: Number(model.max_weight_kg ?? 9999),
      history: blocks,
    });

    // In derselben Anfrage festhalten -- Nachvollziehbarkeit ohne Queue.
    await client.from("progression_suggestions").insert({
      studio_id: machine.studio_id,
      user_id: userId,
      machine_id: machine.id,
      exercise_id: selectedExerciseId,
      algo_version: PROGRESSION_ALGO_VERSION,
      inputs: suggestion.inputs,
      result_weight_kg: suggestion.resultWeightKg,
      reason_code: suggestion.reasonCode,
    });
  }

  return {
    machine: {
      id: machine.id,
      label: machine.label,
      locationNote: machine.location_note,
    },
    equipmentModel: {
      id: model.id,
      name: model.name,
      manufacturer: model.manufacturer,
      photoUrl,
      weightStepKg: Number(model.weight_step_kg),
      minWeightKg: Number(model.min_weight_kg),
      maxWeightKg:
        model.max_weight_kg === null ? null : Number(model.max_weight_kg),
    },
    settingDefinitions: (settings ?? []).map((setting) => {
      const row = setting as unknown as {
        key: string;
        label: string;
        kind: string;
        min_value: number | string | null;
        max_value: number | string | null;
        step_value: number | string | null;
        unit: string | null;
        allowed_values: string[] | null;
      };
      return {
        key: row.key,
        label: row.label,
        kind: row.kind,
        minValue: row.min_value === null ? null : Number(row.min_value),
        maxValue: row.max_value === null ? null : Number(row.max_value),
        stepValue: row.step_value === null ? null : Number(row.step_value),
        unit: row.unit,
        allowedValues: row.allowed_values,
      };
    }),
    exercises,
    selectedExerciseId,
    calibration,
    history: blocks.map((block) => ({
      performedOn: block.performedOn,
      weightKg: block.sets[0]?.weightKg ?? 0,
      reps: block.sets.map((set) => set.reps),
    })),
    suggestion,
  };
}
```

- [ ] **Step 4: `tag-context.ts` auf den Auflöser eindampfen**

Replace the entire content of `packages/domain/src/tag-context.ts` with:

```ts
import type { SupabaseClient } from "@supabase/supabase-js";
import { DomainError } from "./errors.js";
import { hashTagToken, isValidTagToken } from "./tags.js";
import { getMachineContext, type MachineContext } from "./machine-context.js";

/**
 * Ein Tag-Kontext ist ein Geraetekontext -- der Tag sagt nur, welches
 * Geraet gemeint ist. Der Alias bleibt exportiert, damit vorhandene
 * Importe nicht brechen.
 */
export type TagContext = MachineContext;

/**
 * Token -> Geraetekontext.
 *
 * Diese Funktion trug bis zur Geraeteauswahl ohne Scan den gesamten Rumpf.
 * Er liegt jetzt in machine-context.ts, weil ein Geraet auch aus einer
 * Liste gewaehlt werden kann und dann kein Token existiert.
 *
 * Der Token wird nur gehasht verwendet und nie protokolliert (Spec 10.4).
 */
export async function getTagContext(
  client: SupabaseClient,
  token: string,
): Promise<TagContext> {
  if (!isValidTagToken(token)) {
    throw new DomainError("validation_failed", "Ungueltiges Tokenformat.");
  }

  // RLS blendet Tags fremder Studios aus. Unbekannt, ungueltig und gesperrt
  // liefern deshalb dieselbe Antwort -- sonst liessen sich gueltige Tokens
  // durch Ausprobieren unterscheiden.
  const { data: tag } = await client
    .from("machine_tags")
    .select("machine_id")
    .eq("token_hash", hashTagToken(token))
    .eq("status", "active")
    .maybeSingle<{ machine_id: string | null }>();
  if (!tag?.machine_id) {
    throw new DomainError("not_found", "Dieser Code ist nicht aktiv.");
  }

  return getMachineContext(client, tag.machine_id);
}
```

- [ ] **Step 5: Export ergänzen**

In `packages/domain/src/index.ts`, direkt unter den beiden vorhandenen `tag-context`-Zeilen:

```ts
export { getTagContext } from "./tag-context.js";
export type { TagContext } from "./tag-context.js";
export { getMachineContext } from "./machine-context.js";
export type { MachineContext } from "./machine-context.js";
```

- [ ] **Step 6: Neuen Test laufen lassen**

```bash
pnpm test:integration -- domain-machine-context
```

Erwartet: PASS, alle fünf Fälle.

- [ ] **Step 7: Beweisen, dass der Scan-Weg unberührt ist**

```bash
pnpm test:integration -- domain-tag-context
git diff --stat tests/integration/domain-tag-context.test.ts
```

Erwartet: PASS, und `git diff` gibt **nichts** aus. Wurde die Datei angefasst, ist der Beweis wertlos — dann rückgängig machen und die Ursache im Rumpf suchen.

- [ ] **Step 8: Typen prüfen**

```bash
pnpm typecheck
```

Erwartet: keine Fehler.

- [ ] **Step 9: Commit**

```bash
git add packages/domain/src/machine-context.ts packages/domain/src/tag-context.ts \
        packages/domain/src/index.ts tests/integration/domain-machine-context.test.ts
git commit -m "refactor(domain): Geraetekontext ueber machineId aufloesbar machen"
```

---

## Task 2: Route, `APIClient` und `kontextLaden`

Nach dieser Aufgabe hat der Listenweg alles, was der Scan-Weg hat — bevor es einen Listenweg gibt. Das ist Absicht: der Kontext ist damit prüfbar, ohne dass eine UI im Weg steht.

**Files:**
- Create: `apps/web/app/api/v1/machines/[machineId]/context/route.ts`
- Modify: `apps/ios-member/FitnessMember/Networking/APIClient.swift:26-28`
- Modify: `apps/ios-member/FitnessMember/Workout/GeraetLoading.swift`
- Modify: `apps/ios-member/FitnessMember/Screens/Geraet/GeraetModel.swift:298-304`
- Create: `apps/ios-member/FitnessMemberTests/GeraetKontextLadenTests.swift`

**Interfaces:**
- Consumes: `getMachineContext(client, machineId)` aus Task 1.
- Produces:
  - `GET /api/v1/machines/{machineId}/context` → dasselbe JSON wie `tags/{token}/context`
  - `APIClient.machineContext(machineId: String) async throws(APIError) -> TagContextResponse`
  - `GeraetLoading.machineContext(machineId:)` als Protokollanforderung
  - `GeraetModel.kontextLaden()` lädt ohne Token über die machineId

- [ ] **Step 1: Den fehlschlagenden Swift-Test schreiben**

Das Testziel hat bereits `FakeGeraetLoader` und `GeraetTestdaten` (beide in `GeraetModelTests.swift`, beide nicht `private`). Keine zweiten Fassungen anlegen — den vorhandenen Fake erweitern.

**1a.** In `apps/ios-member/FitnessMemberTests/GeraetModelTests.swift` den `FakeGeraetLoader` erweitern (nur die mit NEU markierten Stellen):

```swift
actor FakeGeraetLoader: GeraetLoading {
    var kontextResult: Result<TagContextResponse, APIError> = .failure(.offline)
    var calibrationResult: Result<RecordedCalibration, APIError> = .failure(.offline)

    /// NEU -- wer gerufen wurde. Seit ein Geraet auch ohne Token erreichbar
    /// ist, ist die Wegwahl selbst pruefenswert, nicht nur das Ergebnis.
    private(set) var tagAufrufe: [String] = []
    private(set) var machineAufrufe: [String] = []

    func setKontext(_ value: Result<TagContextResponse, APIError>) { kontextResult = value }
    func setCalibration(_ value: Result<RecordedCalibration, APIError>) { calibrationResult = value }

    func tagContext(token: String) async throws(APIError) -> TagContextResponse {
        tagAufrufe.append(token)   // NEU
        switch kontextResult {
        case .success(let value): return value
        case .failure(let error): throw error
        }
    }

    /// NEU. Liefert dasselbe wie tagContext: der Server liefert auf beiden
    /// Wegen dieselbe Form, und geprueft wird hier der Weg, nicht der Inhalt.
    func machineContext(machineId: String) async throws(APIError) -> TagContextResponse {
        machineAufrufe.append(machineId)
        switch kontextResult {
        case .success(let value): return value
        case .failure(let error): throw error
        }
    }

    func recordCalibration(_ body: CalibrationWrite) async throws(APIError) -> RecordedCalibration {
        switch calibrationResult {
        case .success(let value): return value
        case .failure(let error): throw error
        }
    }

    func completeSession(sessionId: UUID) async throws(APIError) -> CompletedSession {
        throw APIError.offline
    }
}
```

**1b.** Create `apps/ios-member/FitnessMemberTests/GeraetKontextLadenTests.swift`:

```swift
import Foundation
import Testing
@testable import FitnessMember

/// Welchen der beiden Wege `kontextLaden()` nimmt.
///
/// Bis zur Geraeteauswahl ohne Scan gab es nur einen: ohne Token stieg die
/// Methode in der ersten Zeile aus, und der Screen blieb ohne Foto, Video
/// und Vorschlag stehen. Genau das darf nicht zurueckkommen.
@MainActor
struct GeraetKontextLadenTests {

    private func modell(token: String?, loader: FakeGeraetLoader) -> GeraetModel {
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        return GeraetModel(
            maschine: GeraetTestdaten.maschine,
            uebungId: "e1",
            token: token,
            bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
            loader: loader,
            sessions: WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis)),
            enqueue: { _ in }
        )
    }

    /// Ein Kontext mit Foto -- das Einzige, was die Auswahl ohne ein Wort
    /// bestaetigen wuerde, und ohne Token bisher nie ankam.
    private var kontextMitFoto: TagContextResponse {
        GeraetTestdaten.dekodiere("""
        {"machine":{"id":"m1","label":"Gerät 7","locationNote":"Fensterseite"},
         "equipmentModel":{"id":"em1","name":"Beinpresse","manufacturer":"Technogym",
           "photoUrl":"https://example.test/foto.jpg","weightStepKg":2.5,
           "minWeightKg":5.0,"maxWeightKg":150.0},
         "settingDefinitions":[],
         "exercises":[{"id":"e1","name":"Beidbeinig","description":null,
           "targetRepsMin":8,"targetRepsMax":12,"instructionVideoUrl":null}],
         "selectedExerciseId":"e1","calibration":null,"history":[],
         "suggestion":{"resultWeightKg":40.0,"reasonCode":"keine_historie",
           "inputs":{"currentWeightKg":null}}}
        """)
    }

    @Test func mitTokenGehtEsUeberDenTagWeg() async {
        let loader = FakeGeraetLoader()
        await loader.setKontext(.success(kontextMitFoto))

        await modell(token: "abc123", loader: loader).kontextLaden()

        #expect(await loader.tagAufrufe == ["abc123"])
        #expect(await loader.machineAufrufe.isEmpty)
    }

    /// Der Fall, um den es geht: aus der Liste gewaehlt, kein Token.
    @Test func ohneTokenGehtEsUeberDieMachineId() async {
        let loader = FakeGeraetLoader()
        await loader.setKontext(.success(kontextMitFoto))

        await modell(token: nil, loader: loader).kontextLaden()

        #expect(await loader.machineAufrufe == ["m1"])
        #expect(await loader.tagAufrufe.isEmpty)
    }

    @Test func ohneTokenKommtDasFotoAn() async {
        let loader = FakeGeraetLoader()
        await loader.setKontext(.success(kontextMitFoto))
        let modell = modell(token: nil, loader: loader)

        await modell.kontextLaden()

        #expect(modell.kontext?.equipmentModel.photoUrl == "https://example.test/foto.jpg")
    }

    /// Ein Fehlschlag bleibt kein Fehlerzustand -- der Screen steht aus
    /// dem Prefetch.
    @Test func einFehlschlagLaesstDenScreenStehen() async {
        let loader = FakeGeraetLoader()
        await loader.setKontext(.failure(.offline))
        let modell = modell(token: nil, loader: loader)

        await modell.kontextLaden()

        #expect(modell.kontext == nil)
    }
}
```

**Achtung, Nebenwirkung im Bestand:** `GeraetModelTests.modell(...)` baut alle Modelle mit `token: nil`. Bisher war `kontextLaden()` dort ein No-op. Nach Step 6 ruft es `machineContext`; mit der Vorgabe `.failure(.offline)` bleibt `kontext` zwar nil wie zuvor, aber jeder vorhandene Test, der `setKontext(.success(...))` setzt UND `kontextLaden()` ruft, aendert sein Verhalten. Kippt dadurch ein Test, ihn nicht abschwaechen, sondern in der Sache entscheiden: prueft er den Tag-Weg (dann `token:` setzen) oder den Listenweg (dann ist die neue Erwartung die richtige)?

- [ ] **Step 2: Test laufen lassen und Fehlschlag bestätigen**

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -derivedDataPath /tmp/dd-gos-t2 test 2>&1 | grep -E "error:|TEST SUCCEEDED|TEST FAILED"
```

Erwartet: FAIL — `Fake` erfüllt `GeraetLoading` nicht (`machineContext` ist keine Anforderung), bzw. `kontextLaden` ruft sie nie.

- [ ] **Step 3: Route anlegen**

Create `apps/web/app/api/v1/machines/[machineId]/context/route.ts`:

```ts
import { getMachineContext } from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

type Context = { params: Promise<{ machineId: string }> };

/**
 * Derselbe Kontext wie tags/[token]/context, nur ohne Tag -- fuer ein
 * Geraet, das aus der Liste gewaehlt wurde, weil kein Aufkleber daran
 * klebt.
 *
 * Eigene Route statt eines zweiten Parameters an der Tag-Route: eine
 * Route namens "tag-context", deren halber Verkehr keinen Tag sieht,
 * waere ein Name, der luegt.
 *
 * Die Autorisierung liegt in getMachineContext bei RLS -- ein Geraet aus
 * einem fremden Studio ist nicht lesbar und antwortet not_found.
 */
export async function GET(
  request: Request,
  context: Context,
): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) {
    return errorResponse("unauthorized", "Anmeldung erforderlich.");
  }

  const { machineId } = await context.params;

  try {
    const machineContext = await getMachineContext(client, machineId);
    return Response.json(machineContext, {
      status: 200,
      // Persoenliche Werte und Historie: nie in einem geteilten Cache.
      headers: { "cache-control": "private, no-store" },
    });
  } catch (error) {
    return fromDomainError(error);
  }
}
```

- [ ] **Step 4: `APIClient` erweitern**

In `apps/ios-member/FitnessMember/Networking/APIClient.swift`, direkt unter `tagContext(token:)`:

```swift
    /// Derselbe Kontext ohne Tag -- fuer ein Geraet aus der Liste.
    ///
    /// Liefert dasselbe DTO, weil der Server dieselbe Form liefert. Ein
    /// zweiter Typ mit identischen Feldern waere eine Wahrheit an zwei
    /// Orten.
    func machineContext(machineId: String) async throws(APIError) -> TagContextResponse {
        try await get("machines/\(machineId)/context")
    }
```

- [ ] **Step 5: `GeraetLoading` erweitern**

In `apps/ios-member/FitnessMember/Workout/GeraetLoading.swift`, in das Protokoll:

```swift
protocol GeraetLoading: Sendable {
    func tagContext(token: String) async throws(APIError) -> TagContextResponse
    func machineContext(machineId: String) async throws(APIError) -> TagContextResponse
    func recordCalibration(_ body: CalibrationWrite) async throws(APIError) -> RecordedCalibration
    func completeSession(sessionId: UUID) async throws(APIError) -> CompletedSession
}
```

- [ ] **Step 6: `kontextLaden()` beide Wege gehen lassen**

In `apps/ios-member/FitnessMember/Screens/Geraet/GeraetModel.swift`, `kontextLaden()` ersetzen:

```swift
    /// Laedt, was der Prefetch nicht hat: Foto, Einweisungsvideo und den
    /// Gewichtsvorschlag.
    ///
    /// Hier stand bis zur Geraeteauswahl ohne Scan ein
    /// `guard let token else { return }`. Damit blieb ein aus der Liste
    /// gewaehltes Geraet dauerhaft ohne diese drei Dinge -- und ohne Foto
    /// fehlt genau das, was die Auswahl ohne ein Wort bestaetigt.
    ///
    /// Ein Fehlschlag ist weiterhin kein Fehlerzustand: der Screen steht
    /// bereits aus dem Prefetch.
    func kontextLaden() async {
        let geladen: TagContextResponse? =
            if let token {
                try? await loader.tagContext(token: token)
            } else {
                try? await loader.machineContext(machineId: maschine.id)
            }
        guard let geladen else { return }
        kontextUebernehmen(geladen)
    }
```

- [ ] **Step 7: Tests laufen lassen**

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -derivedDataPath /tmp/dd-gos-t2 test 2>&1 | grep -E "error:|TEST SUCCEEDED|TEST FAILED"
rm -rf /tmp/dd-gos-t2
```

Erwartet: `TEST SUCCEEDED`. Schlagen andere Tests fehl, weil ihr Fake `GeraetLoading` erfüllt und die neue Methode nicht kennt, dort dieselbe Methode ergänzen — sie darf `Fake.antwort` oder den vorhandenen Rückgabewert liefern.

- [ ] **Step 8: Typen und Web-Tests prüfen**

```bash
pnpm typecheck
```

Erwartet: keine Fehler.

- [ ] **Step 9: Commit**

```bash
git add apps/web/app/api/v1/machines apps/ios-member/FitnessMember/Networking/APIClient.swift \
        apps/ios-member/FitnessMember/Workout/GeraetLoading.swift \
        apps/ios-member/FitnessMember/Screens/Geraet/GeraetModel.swift \
        apps/ios-member/FitnessMemberTests/GeraetKontextLadenTests.swift \
        apps/ios-member/FitnessMember.xcodeproj/project.pbxproj
git commit -m "feat(geraet): Kontext auch ohne Tag-Token laden"
```

---

## Task 3: Das reine Modul `GeraeteAuswahl`

Hier liegen die Regeln, die sonst niemand nachlesen kann. Kein UI-Code in dieser Aufgabe.

**Files:**
- Create: `apps/ios-member/FitnessMember/Workout/GeraeteAuswahl.swift`
- Create: `apps/ios-member/FitnessMemberTests/GeraeteAuswahlTests.swift`

**Interfaces:**
- Consumes: nichts aus Task 1 und 2.
- Produces:
  - `GeraeteAuswahl.Eintrag` mit `machineId`, `name`, `ortsangabe`, `zuletzt`, `trefferUebung`, `gesperrt`, `nichtScannbar`
  - `GeraeteAuswahl.Zuletzt` mit `performedAt`, `gewichtKg`
  - `GeraeteAuswahl.Gruppen` mit `zuletzt` und `alle`
  - `GeraeteAuswahl.gruppen(bootstrap:studioId:suchtext:) -> Gruppen`

- [ ] **Step 1: Die fehlschlagenden Tests schreiben**

Create `apps/ios-member/FitnessMemberTests/GeraeteAuswahlTests.swift`:

```swift
import Foundation
import Testing
@testable import FitnessMember

/// Liste und Suche fuer Geraete ohne Aufkleber.
///
/// Diese Suite haelt die Regeln fest, die im Entwurf nur als Bild
/// existieren: die Entdopplung zwischen den Gruppen und die Reihenfolge
/// der Treffer. Beide waeren sonst beim naechsten Anfassen weg.
struct GeraeteAuswahlTests {

    // MARK: - Bausteine

    private func zeit(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: iso)!
    }

    /// BootstrapResponse ist Decodable ohne Memberwise-Init: der einzige
    /// Weg, eine zu bauen, fuehrt ueber JSON. Deshalb baut dieser Helfer
    /// den Maschinen-JSON als Text, statt einen Wert zu erzeugen.
    private func maschineJSON(
        id: String, name: String, label: String, ort: String?,
        studio: String = "s1", status: String = "active",
        tags: [String] = ["hash"], besuche: Int = 0,
        uebungen: [(String, String)] = [("u1", "Latzug breit")]
    ) -> String {
        let ortJSON = ort.map { "\"\($0)\"" } ?? "null"
        let tagsJSON = tags.map { "\"\($0)\"" }.joined(separator: ", ")
        let uebungenJSON = uebungen.map {
            """
            { "id": "\($0.0)", "name": "\($0.1)", "targetRepsMin": 8, "targetRepsMax": 12 }
            """
        }.joined(separator: ", ")
        return """
        {
          "id": "\(id)", "studioId": "\(studio)", "label": "\(label)",
          "locationNote": \(ortJSON), "status": "\(status)",
          "tokenHashes": [\(tagsJSON)], "visitCount": \(besuche),
          "equipmentModel": {
            "id": "em-\(id)", "name": "\(name)", "manufacturer": "Technogym",
            "photoPath": null, "weightStepKg": 2.5, "minWeightKg": 5,
            "maxWeightKg": 100, "settingDefinitions": []
          },
          "exercises": [\(uebungenJSON)]
        }
        """
    }

    private func bootstrap(
        maschinen: [String],
        saetze: [(machine: String, uebung: String, kg: Double, wann: String)] = []
    ) -> BootstrapResponse {
        let saetzeJSON = saetze.map {
            """
            { "machineId": "\($0.machine)", "exerciseId": "\($0.uebung)",
              "weightKg": \($0.kg), "reps": 10, "rir": null,
              "performedAt": "\($0.wann)" }
            """
        }.joined(separator: ", ")
        return GeraetTestdaten.dekodiere("""
        {
          "member": { "displayName": "Tim" },
          "studios": [
            { "id": "s1", "name": "Gym Ost", "timezone": "Europe/Berlin" },
            { "id": "s2", "name": "Gym West", "timezone": "Europe/Berlin" }
          ],
          "machines": [\(maschinen.joined(separator: ", "))],
          "calibrations": [],
          "lastSets": [\(saetzeJSON)]
        }
        """)
    }

    // MARK: - Zwei Gruppen ohne Suchtext

    /// Der Kern der Gruppierung: benutzte Geraete oben, alles andere
    /// darunter -- und was oben steht, steht unten NICHT noch einmal.
    /// Ohne diese Regel an einem Ort baut sie jemand spaeter andersherum.
    @Test func benutzteGeraeteStehenObenUndNichtNochmalUnten() {
        let daten = bootstrap(
            maschinen: [
                maschineJSON(id: "m1", name: "Latzug", label: "14", ort: "Rueckwand", besuche: 3),
                maschineJSON(id: "m2", name: "Bauchtrainer", label: "21", ort: "Freiflaeche"),
            ],
            saetze: [(machine: "m1", uebung: "u1", kg: 45, wann: "2026-09-07T10:00:00Z")])

        let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, studioId: "s1", suchtext: "")

        #expect(gruppen.zuletzt.map(\.machineId) == ["m1"])
        #expect(gruppen.alle.map(\.machineId) == ["m2"])
    }

    /// Mehr als drei, und die Gruppe verdraengt die Liste, die sie
    /// abkuerzen soll.
    @Test func hoechstensDreiStehenUnterZuletzt() {
        let daten = bootstrap(
            maschinen: (1...5).map {
                maschineJSON(id: "m\($0)", name: "Geraet \($0)", label: "\($0)", ort: nil, besuche: 1)
            },
            saetze: (1...5).map {
                (machine: "m\($0)", uebung: "u1", kg: 40, wann: "2026-09-0\($0)T10:00:00Z")
            })

        let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, studioId: "s1", suchtext: "")

        #expect(gruppen.zuletzt.count == 3)
        #expect(gruppen.alle.count == 2)
    }

    @Test func zuletztIstNachJuengstemSatzSortiert() {
        let daten = bootstrap(
            maschinen: [
                maschineJSON(id: "alt", name: "Alt", label: "1", ort: nil, besuche: 1),
                maschineJSON(id: "neu", name: "Neu", label: "2", ort: nil, besuche: 1),
            ],
            saetze: [
                (machine: "alt", uebung: "u1", kg: 40, wann: "2026-09-01T10:00:00Z"),
                (machine: "neu", uebung: "u1", kg: 50, wann: "2026-09-09T10:00:00Z"),
            ])

        let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, studioId: "s1", suchtext: "")

        #expect(gruppen.zuletzt.map(\.machineId) == ["neu", "alt"])
        #expect(gruppen.zuletzt.first?.zuletzt?.gewichtKg == 50)
    }

    @Test func alleSindAlphabetischNachGeraetenamen() {
        let daten = bootstrap(maschinen: [
            maschineJSON(id: "m1", name: "Rudern sitzend", label: "9", ort: nil),
            maschineJSON(id: "m2", name: "Bauchtrainer", label: "21", ort: nil),
            maschineJSON(id: "m3", name: "Latzug", label: "14", ort: nil),
        ])

        let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, studioId: "s1", suchtext: "")

        #expect(gruppen.alle.map(\.name) == ["Bauchtrainer", "Latzug", "Rudern sitzend"])
    }

    /// Sichtbar, aber ans Ende. Auszublenden hiesse, das Mitglied sucht am
    /// Geraet weiter, statt zu wissen, dass es gesperrt ist.
    @Test func gesperrteGeraeteStehenAmEnde() {
        let daten = bootstrap(maschinen: [
            maschineJSON(id: "m1", name: "Aaa", label: "1", ort: nil, status: "maintenance"),
            maschineJSON(id: "m2", name: "Zzz", label: "2", ort: nil),
        ])

        let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, studioId: "s1", suchtext: "")

        #expect(gruppen.alle.map(\.name) == ["Zzz", "Aaa"])
        #expect(gruppen.alle.last?.gesperrt == true)
    }

    /// Leere tokenHashes heissen "kein AKTIVER Tag" -- getBootstrap liest
    /// machine_tags mit status = active. Die Marke sagt deshalb, was die
    /// App weiss, nicht was am Geraet klebt.
    @Test func geraeteOhneAktivenTagSindMarkiert() {
        let daten = bootstrap(maschinen: [
            maschineJSON(id: "m1", name: "Beinbeuger", label: "5", ort: nil, tags: []),
            maschineJSON(id: "m2", name: "Latzug", label: "14", ort: nil),
        ])

        let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, studioId: "s1", suchtext: "")

        #expect(gruppen.alle.first(where: { $0.name == "Beinbeuger" })?.nichtScannbar == true)
        #expect(gruppen.alle.first(where: { $0.name == "Latzug" })?.nichtScannbar == false)
    }

    @Test func dieOrtsangabeIstLabelUndPlatz() {
        let daten = bootstrap(maschinen: [
            maschineJSON(id: "m1", name: "Latzug", label: "Gerät 14", ort: "Rückwand rechts"),
            maschineJSON(id: "m2", name: "Bauchtrainer", label: "Gerät 21", ort: nil),
        ])

        let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, studioId: "s1", suchtext: "")

        #expect(gruppen.alle[0].ortsangabe == "Gerät 21")
        #expect(gruppen.alle[1].ortsangabe == "Gerät 14 · Rückwand rechts")
    }

    @Test func geraeteFremderStudiosFehlen() {
        let daten = bootstrap(maschinen: [
            maschineJSON(id: "m1", name: "Latzug", label: "14", ort: nil),
            maschineJSON(id: "m2", name: "Fremd", label: "99", ort: nil, studio: "s2"),
        ])

        let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, studioId: "s1", suchtext: "")

        #expect(gruppen.alle.map(\.name) == ["Latzug"])
    }

    // MARK: - Suche

    @Test func mitSuchtextGibtEsNurNochEineListe() {
        let daten = bootstrap(
            maschinen: [maschineJSON(id: "m1", name: "Latzug", label: "14", ort: nil, besuche: 1)],
            saetze: [(machine: "m1", uebung: "u1", kg: 45, wann: "2026-09-07T10:00:00Z")])

        let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, studioId: "s1", suchtext: "lat")

        #expect(gruppen.zuletzt.isEmpty)
        #expect(gruppen.alle.map(\.name) == ["Latzug"])
    }

    /// Die Reihenfolge aus Blatt 03, die dort nur als Bild existierte:
    /// Geraetetreffer vor Uebungstreffern, darin Historie zuerst, dann
    /// alphabetisch. Ohne diesen Test sortiert der naechste nach Alphabet.
    @Test func trefferReihenfolgeGeraetVorUebungUndHistorieZuerst() {
        let daten = bootstrap(
            maschinen: [
                maschineJSON(id: "m1", name: "Beinbeuger", label: "5", ort: nil),
                maschineJSON(id: "m2", name: "Beinpresse", label: "3", ort: nil, besuche: 2),
                maschineJSON(id: "m3", name: "Bauchtrainer", label: "21", ort: nil,
                             uebungen: [("u9", "Beinheben hängend")]),
            ],
            saetze: [(machine: "m2", uebung: "u1", kg: 90, wann: "2026-09-07T10:00:00Z")])

        let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, studioId: "s1", suchtext: "bein")

        #expect(gruppen.alle.map(\.name) == ["Beinpresse", "Beinbeuger", "Bauchtrainer"])
    }

    /// Die Uebungszeile erklaert, warum ein Geraet in der Trefferliste
    /// steht, dessen Name nichts mit der Eingabe zu tun hat. Bei einem
    /// Geraetetreffer erklaert sie nichts und darf deshalb fehlen.
    @Test func dieUebungszeileStehtNurBeimReinenUebungstreffer() {
        let daten = bootstrap(maschinen: [
            maschineJSON(id: "m1", name: "Beinpresse", label: "3", ort: nil),
            maschineJSON(id: "m2", name: "Bauchtrainer", label: "21", ort: nil,
                         uebungen: [("u9", "Beinheben hängend")]),
        ])

        let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, studioId: "s1", suchtext: "bein")

        #expect(gruppen.alle.first(where: { $0.name == "Beinpresse" })?.trefferUebung == nil)
        #expect(gruppen.alle.first(where: { $0.name == "Bauchtrainer" })?.trefferUebung == "Beinheben hängend")
    }

    @Test func gesuchtWirdAuchInNummerUndPlatz() {
        let daten = bootstrap(maschinen: [
            maschineJSON(id: "m1", name: "Latzug", label: "Gerät 14", ort: "Rückwand rechts"),
            maschineJSON(id: "m2", name: "Bauchtrainer", label: "Gerät 21", ort: "Freifläche"),
        ])

        let ueberNummer = GeraeteAuswahl.gruppen(bootstrap: daten, studioId: "s1", suchtext: "14")
        let ueberPlatz = GeraeteAuswahl.gruppen(bootstrap: daten, studioId: "s1", suchtext: "frei")

        #expect(ueberNummer.alle.map(\.name) == ["Latzug"])
        #expect(ueberPlatz.alle.map(\.name) == ["Bauchtrainer"])
    }

    @Test func grossschreibungUndUmlauteSindEgal() {
        let daten = bootstrap(maschinen: [
            maschineJSON(id: "m1", name: "Rückenstrecker", label: "22", ort: nil),
        ])

        for eingabe in ["RÜCKEN", "rucken", "Ruecken".replacingOccurrences(of: "ue", with: "ü")] {
            let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, studioId: "s1", suchtext: eingabe)
            #expect(gruppen.alle.count == 1, "\(eingabe) sollte treffen")
        }
    }

    @Test func nurLeerraumGiltAlsKeineSuche() {
        let daten = bootstrap(
            maschinen: [maschineJSON(id: "m1", name: "Latzug", label: "14", ort: nil, besuche: 1)],
            saetze: [(machine: "m1", uebung: "u1", kg: 45, wann: "2026-09-07T10:00:00Z")])

        let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, studioId: "s1", suchtext: "   ")

        #expect(gruppen.zuletzt.count == 1)
    }

    @Test func ohneTrefferSindBeideGruppenLeer() {
        let daten = bootstrap(maschinen: [
            maschineJSON(id: "m1", name: "Latzug", label: "14", ort: nil),
        ])

        let gruppen = GeraeteAuswahl.gruppen(bootstrap: daten, studioId: "s1", suchtext: "beinpresse xr")

        #expect(gruppen.zuletzt.isEmpty)
        #expect(gruppen.alle.isEmpty)
    }
}
```

- [ ] **Step 2: Tests laufen lassen und Fehlschlag bestätigen**

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -derivedDataPath /tmp/dd-gos-t3 test 2>&1 | grep -E "error:|TEST SUCCEEDED|TEST FAILED"
```

Erwartet: FAIL — `cannot find 'GeraeteAuswahl' in scope`.

- [ ] **Step 3: Das Modul schreiben**

Create `apps/ios-member/FitnessMember/Workout/GeraeteAuswahl.swift`:

```swift
import Foundation

/// Liste und Suche der Geraete eines Studios -- der Weg zum Geraet, wenn
/// kein Aufkleber daran klebt.
///
/// Das Gegenstueck zu `MachineResolver`: der loest ein Geraet ueber den
/// Token auf, dieser ueber die Suche. Beide rechnen auf demselben
/// Prefetch und brauchen kein Netz.
///
/// Reines `enum` statt `@Observable`: es gibt kein Netz, keinen
/// Lebenszyklus und keinen Ladezustand -- dieselbe Aufteilung wie bei
/// `KurseWochenInhalt` und `GeraetEinstiegRechner`, damit die Regeln ohne
/// UI pruefbar sind.
enum GeraeteAuswahl {

    /// Der letzte Satz an diesem Geraet.
    struct Zuletzt: Equatable {
        let performedAt: Date
        let gewichtKg: Double
    }

    struct Eintrag: Equatable, Identifiable {
        var id: String { machineId }
        let machineId: String
        /// `equipmentModel.name` -- das Wort, das am Geraet steht.
        let name: String
        /// `label · locationNote`, dieselbe Fuegung wie die Kopfzeile auf
        /// dem Geraete-Screen.
        let ortsangabe: String
        let zuletzt: Zuletzt?
        /// Gesetzt, wenn der Treffer NUR ueber eine Uebung kam. Bei einem
        /// Geraetetreffer erklaert die Zeile nichts und bleibt leer.
        let trefferUebung: String?
        /// `status != "active"`.
        let gesperrt: Bool
        /// `tokenHashes.isEmpty` -- also kein AKTIVER Tag. getBootstrap
        /// liest machine_tags mit status = active, ein abgeschalteter
        /// Aufkleber klebt also weiter am Geraet.
        let nichtScannbar: Bool
    }

    struct Gruppen: Equatable {
        /// Hoechstens drei; bei aktiver Suche leer.
        let zuletzt: [Eintrag]
        let alle: [Eintrag]
    }

    /// Mehr, und die Gruppe verdraengt die Liste, die sie abkuerzen soll.
    private static let deckel = 3

    static func gruppen(
        bootstrap: BootstrapResponse,
        studioId: String?,
        suchtext: String
    ) -> Gruppen {
        let maschinen = bootstrap.machines.filter { $0.studioId == studioId }
        let letzteSaetze = juengsteSaetze(in: bootstrap)
        let gesucht = normalisiert(suchtext)

        guard !gesucht.isEmpty else {
            let benutzt = maschinen
                .filter { $0.visitCount > 0 && letzteSaetze[$0.id] != nil }
                .sorted { letzteSaetze[$0.id]!.performedAt > letzteSaetze[$1.id]!.performedAt }
                .prefix(deckel)
            let obenIds = Set(benutzt.map(\.id))

            return Gruppen(
                zuletzt: benutzt.map { eintrag($0, zuletzt: letzteSaetze[$0.id], trefferUebung: nil) },
                // Was oben steht, steht unten nicht noch einmal.
                alle: maschinen
                    .filter { !obenIds.contains($0.id) }
                    .map { eintrag($0, zuletzt: letzteSaetze[$0.id], trefferUebung: nil) }
                    .sorted(by: alphabetischGesperrteAnsEnde)
            )
        }

        let treffer = maschinen.compactMap { maschine -> Eintrag? in
            let imGeraet = felder(maschine).contains { normalisiert($0).contains(gesucht) }
            // Die Uebungszeile nur setzen, wenn das Geraet selbst NICHT
            // trifft -- sonst bekaeme bei "bein" auch die Beinpresse eine,
            // und die Zeile verloere ihren Zweck.
            let uebung = imGeraet ? nil : maschine.exercises.first {
                normalisiert($0.name).contains(gesucht)
            }?.name
            guard imGeraet || uebung != nil else { return nil }
            return eintrag(maschine, zuletzt: letzteSaetze[maschine.id], trefferUebung: uebung)
        }

        return Gruppen(zuletzt: [], alle: treffer.sorted(by: trefferReihenfolge))
    }

    // MARK: - Reihenfolgen

    private static func alphabetischGesperrteAnsEnde(_ a: Eintrag, _ b: Eintrag) -> Bool {
        if a.gesperrt != b.gesperrt { return !a.gesperrt }
        return a.name.localizedStandardCompare(b.name) == .orderedAscending
    }

    /// Blatt 03: Geraetetreffer vor Uebungstreffern, darin Geraete mit
    /// Historie zuerst, dann alphabetisch. Deshalb steht dort die
    /// Beinpresse vor dem Beinbeuger, obwohl B vor P kommt.
    private static func trefferReihenfolge(_ a: Eintrag, _ b: Eintrag) -> Bool {
        if a.gesperrt != b.gesperrt { return !a.gesperrt }
        let aNurUebung = a.trefferUebung != nil
        let bNurUebung = b.trefferUebung != nil
        if aNurUebung != bNurUebung { return !aNurUebung }
        if (a.zuletzt != nil) != (b.zuletzt != nil) { return a.zuletzt != nil }
        return a.name.localizedStandardCompare(b.name) == .orderedAscending
    }

    // MARK: - Bausteine

    private static func eintrag(
        _ maschine: BootstrapResponse.Machine,
        zuletzt: Zuletzt?,
        trefferUebung: String?
    ) -> Eintrag {
        Eintrag(
            machineId: maschine.id,
            name: maschine.equipmentModel.name,
            ortsangabe: [maschine.label, maschine.locationNote]
                .compactMap { $0 }
                .joined(separator: " · "),
            zuletzt: zuletzt,
            trefferUebung: trefferUebung,
            gesperrt: maschine.status != "active",
            nichtScannbar: maschine.tokenHashes.isEmpty
        )
    }

    private static func felder(_ maschine: BootstrapResponse.Machine) -> [String] {
        [maschine.equipmentModel.name, maschine.label, maschine.locationNote]
            .compactMap { $0 }
    }

    /// Klein, ohne Diakritika, ohne Rand -- damit "RÜCKEN" und "rucken"
    /// dasselbe treffen.
    private static func normalisiert(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    /// Der juengste Satz je Geraet. Rechnet selbst, statt sich auf die
    /// Serversortierung von `lastSets` zu verlassen -- dieselbe Vorsicht
    /// wie in `GeraetEinstiegRechner.letzteUebung`.
    private static func juengsteSaetze(in bootstrap: BootstrapResponse) -> [String: Zuletzt] {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fOhne = ISO8601DateFormatter()
        fOhne.formatOptions = [.withInternetDateTime]

        var juengste: [String: Zuletzt] = [:]
        for satz in bootstrap.lastSets {
            guard let datum = f.date(from: satz.performedAt) ?? fOhne.date(from: satz.performedAt)
            else { continue }
            if let vorhanden = juengste[satz.machineId], vorhanden.performedAt >= datum { continue }
            juengste[satz.machineId] = Zuletzt(performedAt: datum, gewichtKg: satz.weightKg)
        }
        return juengste
    }
}
```

- [ ] **Step 4: Tests laufen lassen**

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -derivedDataPath /tmp/dd-gos-t3 test 2>&1 | grep -E "error:|TEST SUCCEEDED|TEST FAILED"
rm -rf /tmp/dd-gos-t3
```

Erwartet: `TEST SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
git add apps/ios-member/FitnessMember/Workout/GeraeteAuswahl.swift \
        apps/ios-member/FitnessMemberTests/GeraeteAuswahlTests.swift \
        apps/ios-member/FitnessMember.xcodeproj/project.pbxproj
git commit -m "feat(geraet): Liste und Suche als reine Ableitung"
```

---

## Task 4: Der Screen, der dritte Weg und „Ausgewählt"

Der sichtbare Teil zuletzt. Entwurf: Blatt 01–05.

**Files:**
- Create: `apps/ios-member/FitnessMember/Screens/Geraet/GeraeteAuswahlView.swift`
- Modify: `apps/ios-member/FitnessMember/DesignSystem/Components/ScanWege.swift`
- Modify: `apps/ios-member/FitnessMember/Navigation/GeraetRoute.swift`
- Modify: `apps/ios-member/FitnessMember/Screens/Training/TrainingRootView.swift`
- Modify: `apps/ios-member/FitnessMember/Screens/Geraet/GeraetModel.swift`
- Modify: `apps/ios-member/FitnessMember/Screens/Geraet/GeraetErkanntView.swift:35-41`
- Create: `apps/ios-member/FitnessMemberTests/GeraetEinstiegsartTests.swift`

**Interfaces:**
- Consumes: `GeraeteAuswahl.gruppen(bootstrap:studioId:suchtext:)` aus Task 3; `GeraetRoute.erkannt(machineId:token:)` (vorhanden).
- Produces:
  - `GeraetRoute.auswahl`
  - `ScanWege(beiQR:beiNFC:beiListe:)`
  - `GeraetModel.einstiegsart: GeraetModel.Einstiegsart` (`.erkannt` / `.ausgewaehlt`)

- [ ] **Step 1: Den fehlschlagenden Test für die Einstiegsart schreiben**

Create `apps/ios-member/FitnessMemberTests/GeraetEinstiegsartTests.swift`:

```swift
import Foundation
import Testing
@testable import FitnessMember

/// „Erkannt" oder „Ausgewaehlt" -- der Unterschied ist keine Kosmetik.
///
/// Nach einem Scan war das Telefon nachweislich am Geraet. Nach einer
/// Auswahl hat jemand etwas angetippt. Ein Wort, das eine Messung
/// behauptet, wo keine stattfand, verstoesst gegen die Produktgrenze
/// (designsystem.md SS10).
struct GeraetEinstiegsartTests {

    @Test func mitTokenHeisstEsErkannt() {
        #expect(GeraetModel.Einstiegsart(token: "abc123") == .erkannt)
    }

    @Test func ohneTokenHeisstEsAusgewaehlt() {
        #expect(GeraetModel.Einstiegsart(token: nil) == .ausgewaehlt)
    }

    @Test func dieBeschriftungBehauptetKeineMessung() {
        #expect(GeraetModel.Einstiegsart.erkannt.beschriftung == "ERKANNT")
        #expect(GeraetModel.Einstiegsart.ausgewaehlt.beschriftung == "AUSGEWÄHLT")
    }

    /// Listensymbol statt NFC-Wellen: das Zeichen muss denselben
    /// Unterschied tragen wie das Wort.
    @Test func dasSymbolPasstZumWeg() {
        #expect(GeraetModel.Einstiegsart.erkannt.symbol == "wave.3.right")
        #expect(GeraetModel.Einstiegsart.ausgewaehlt.symbol == "list.bullet")
    }
}
```

- [ ] **Step 2: Test laufen lassen und Fehlschlag bestätigen**

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -derivedDataPath /tmp/dd-gos-t4 test 2>&1 | grep -E "error:|TEST SUCCEEDED|TEST FAILED"
```

Erwartet: FAIL — `Einstiegsart` gibt es nicht.

- [ ] **Step 3: `Einstiegsart` im Modell ergänzen**

In `apps/ios-member/FitnessMember/Screens/Geraet/GeraetModel.swift`, innerhalb von `GeraetModel`, oberhalb von `init`:

```swift
    /// Wie das Mitglied an diesem Geraet gelandet ist.
    ///
    /// Nach einem Scan war das Telefon am Geraet. Nach einer Auswahl aus
    /// der Liste hat jemand etwas angetippt -- die App weiss nicht, wo er
    /// steht. Das Wort auf dem Screen darf den Unterschied nicht
    /// verwischen (designsystem.md SS10).
    enum Einstiegsart: Equatable {
        case erkannt
        case ausgewaehlt

        init(token: String?) {
            self = token == nil ? .ausgewaehlt : .erkannt
        }

        var beschriftung: String {
            switch self {
            case .erkannt: "ERKANNT"
            case .ausgewaehlt: "AUSGEWÄHLT"
            }
        }

        var symbol: String {
            switch self {
            case .erkannt: "wave.3.right"
            case .ausgewaehlt: "list.bullet"
            }
        }
    }

    var einstiegsart: Einstiegsart { Einstiegsart(token: token) }
```

- [ ] **Step 4: Test laufen lassen**

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -derivedDataPath /tmp/dd-gos-t4 test 2>&1 | grep -E "error:|TEST SUCCEEDED|TEST FAILED"
```

Erwartet: `TEST SUCCEEDED`.

- [ ] **Step 5: `GeraetErkanntView` die Einstiegsart lesen lassen**

In `apps/ios-member/FitnessMember/Screens/Geraet/GeraetErkanntView.swift`, in `kopfzeile` das feste `Label` ersetzen:

```swift
            Label(modell.einstiegsart.beschriftung, systemImage: modell.einstiegsart.symbol)
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)
```

- [ ] **Step 6: `ScanWege` um den dritten Weg erweitern**

In `apps/ios-member/FitnessMember/DesignSystem/Components/ScanWege.swift`, `ScanWege` ersetzen (die private `KonturScanKnopf` bleibt unveraendert):

```swift
/// Die drei Wege zum Geraet, gleichwertig uebereinander (SS11).
///
/// Bis zur Geraeteauswahl ohne Scan waren es zwei, und beide setzten
/// voraus, dass am Geraet ein AKTIVER Aufkleber klebt. Fehlt er, gab es
/// keinen Weg -- der dritte schliesst diese Luecke.
///
/// Alle drei sind Kontur, keiner ist Akzentflaeche: gleichwertig heisst
/// gleich aussehend, und die eine Akzentflaeche pro Screen bleibt frei
/// (designsystem.md SS2).
struct ScanWege: View {
    let beiQR: () -> Void
    let beiNFC: () -> Void
    /// Optional: ohne geladenen Prefetch gibt es nichts zu waehlen, und
    /// ein Knopf, der auf einen leeren Screen fuehrt, ist schlechter als
    /// einer, der fehlt.
    let beiListe: (() -> Void)?

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.s12) {
            KonturScanKnopf(symbol: "qrcode", titel: "QR-Code scannen", aktion: beiQR)
            // Auf iPads, aelteren iPhones und im Simulator gibt es keinen
            // aktiven NFC-Scan. Dann steht der QR-Weg allein da, statt dass
            // ein Knopf ins Leere greift -- der passive Weg ueber das
            // Systembanner bleibt davon unberuehrt.
            if NFCTagLeser.verfuegbar {
                KonturScanKnopf(symbol: "wave.3.right", titel: "NFC-Tag scannen", aktion: beiNFC)
            }
            if let beiListe {
                KonturScanKnopf(symbol: "list.bullet", titel: "Aus der Liste wählen", aktion: beiListe)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
```

Die `#Preview` am Dateiende auf die neue Signatur ziehen:

```swift
#Preview {
    ScanWege(beiQR: {}, beiNFC: {}, beiListe: {})
        .padding()
        .background(DesignSystem.Color.bg)
}
```

- [ ] **Step 7: `GeraetRoute` um den Fall erweitern**

In `apps/ios-member/FitnessMember/Navigation/GeraetRoute.swift`, oberhalb von `.erkannt`:

```swift
    /// Die Geraeteliste -- ein Push wie die anderen Ziele, damit die
    /// Tab-Leiste stehen bleibt (designsystem.md SS11).
    case auswahl
```

- [ ] **Step 8: Den Screen bauen**

Create `apps/ios-member/FitnessMember/Screens/Geraet/GeraeteAuswahlView.swift`:

```swift
import SwiftUI

/// „Gerät wählen" -- der Weg zum Geraet ohne Aufkleber (Blatt 02-04).
///
/// Rechnet vollstaendig auf dem Prefetch: kein Netz, kein Ladezustand,
/// keine Fehlerzustaende. Die Regeln stehen in `GeraeteAuswahl`, hier
/// steht nur, wie sie aussehen.
struct GeraeteAuswahlView: View {
    @Environment(CatalogStore.self) private var katalog

    let beiAuswahl: (String) -> Void

    @State private var suchtext = ""
    /// Nur fuer diesen Screen, nicht `katalog.activeStudioId`: sonst
    /// wechselte eine Suche stillschweigend das aktive Studio, und das
    /// Mitglied faende danach auf Home ein anderes vor.
    @State private var studioId: String?
    @FocusState private var feldAktiv: Bool

    var body: some View {
        VStack(spacing: 0) {
            kopf
            suchfeld
            inhalt
        }
        .background(DesignSystem.Color.bg)
        .navigationBarTitleDisplayMode(.inline)
        .task { if studioId == nil { studioId = katalog.activeStudioId } }
    }

    // MARK: - Kopf

    private var kopf: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
            Text("GERÄT WÄHLEN")
                .font(DesignSystem.Typography.screentitel)
                .tracking(-1)
                .foregroundStyle(DesignSystem.Color.text)
            Text(untertitel)
                .font(.system(size: 13))
                .foregroundStyle(DesignSystem.Color.textMuted)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, DesignSystem.Spacing.s16)
    }

    private var untertitel: String {
        let anzahl = maschinenImStudio.count
        let name = katalog.bootstrap?.studios.first { $0.id == studioId }?.name
        guard let name else { return "Alle \(anzahl) Geräte — auch die ohne Aufkleber." }
        return "Alle \(anzahl) Geräte in \(name) — auch die ohne Aufkleber."
    }

    private var maschinenImStudio: [BootstrapResponse.Machine] {
        katalog.bootstrap?.machines.filter { $0.studioId == studioId } ?? []
    }

    // MARK: - Suchfeld

    /// Ein eigenes Feld, nicht `.searchable`: die Systemsuchleiste setzt
    /// sich unter den Navigationstitel, und das Feld gehoert hier in den
    /// Inhalt -- es ist die Hauptaktion des Screens.
    private var suchfeld: some View {
        HStack(spacing: DesignSystem.Spacing.s12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(feldAktiv ? DesignSystem.Color.accent : DesignSystem.Color.textFaint)
            TextField("", text: $suchtext, prompt: Text("Gerät, Übung oder Platz")
                .foregroundColor(DesignSystem.Color.textFaint))
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Color.text)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($feldAktiv)
                .submitLabel(.search)
            if !suchtext.isEmpty {
                Button {
                    suchtext = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                }
                .frame(width: 44, height: 44)
                .accessibilityLabel("Suche löschen")
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.s16)
        .frame(height: 52)
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.neben))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.neben)
                .stroke(feldAktiv ? DesignSystem.Color.accent : DesignSystem.Color.line,
                        lineWidth: feldAktiv ? 1.5 : 1)
        )
        .padding(.horizontal, 20)
        .padding(.top, DesignSystem.Spacing.s16)
    }

    // MARK: - Inhalt

    private var gruppen: GeraeteAuswahl.Gruppen {
        guard let bootstrap = katalog.bootstrap else {
            return GeraeteAuswahl.Gruppen(zuletzt: [], alle: [])
        }
        return GeraeteAuswahl.gruppen(bootstrap: bootstrap, studioId: studioId, suchtext: suchtext)
    }

    @ViewBuilder
    private var inhalt: some View {
        let g = gruppen
        if g.zuletzt.isEmpty && g.alle.isEmpty {
            leerZustand
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
                    if !g.zuletzt.isEmpty {
                        gruppe("ZULETZT BEI DIR", g.zuletzt)
                    }
                    if !g.alle.isEmpty {
                        gruppe(suchtext.isEmpty ? "ALLE GERÄTE · A–Z" : "\(g.alle.count) TREFFER", g.alle)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, DesignSystem.Spacing.s24)
            }
        }
    }

    private func gruppe(_ titel: String, _ eintraege: [GeraeteAuswahl.Eintrag]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s8) {
            Text(titel)
                .font(DesignSystem.Typography.label)
                .tracking(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)
            ForEach(eintraege) { eintrag in
                if eintrag.gesperrt {
                    zeile(eintrag).opacity(0.55)
                } else {
                    Button { beiAuswahl(eintrag.machineId) } label: { zeile(eintrag) }
                        .buttonStyle(PressButtonStyle())
                }
            }
        }
    }

    private func zeile(_ eintrag: GeraeteAuswahl.Eintrag) -> some View {
        HStack(spacing: DesignSystem.Spacing.s12) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                Text(eintrag.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(DesignSystem.Color.text)
                Text(eintrag.ortsangabe)
                    .font(.system(size: 12))
                    .foregroundStyle(DesignSystem.Color.textFaint)
                if let uebung = eintrag.trefferUebung {
                    Text("Übung · \(uebung)")
                        .font(.system(size: 12))
                        .foregroundStyle(DesignSystem.Color.textMuted)
                }
                if let zuletzt = eintrag.zuletzt {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(DesignSystem.Color.accent)
                            .frame(width: 5, height: 5)
                            .accessibilityHidden(true)
                        Text(zuletztText(zuletzt))
                            .font(.system(size: 12, weight: .bold).monospacedDigit())
                            .foregroundStyle(DesignSystem.Color.accent)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if eintrag.gesperrt {
                Marke(text: "GESPERRT", farbe: DesignSystem.Color.warn)
            } else if eintrag.nichtScannbar {
                // Nicht "ohne Aufkleber": leere tokenHashes heissen "kein
                // AKTIVER Tag", und ein abgeschalteter klebt weiter am
                // Geraet. Die Marke sagt, was die App weiss.
                Marke(text: "NICHT SCANNBAR", farbe: DesignSystem.Color.textFaint)
            }

            if !eintrag.gesperrt {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(DesignSystem.Color.textFaint)
            }
        }
        .padding(DesignSystem.Spacing.s16)
        .frame(minHeight: 64)
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.neben))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.neben)
                .stroke(DesignSystem.Color.line, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private func zuletztText(_ zuletzt: GeraeteAuswahl.Zuletzt) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.unitsStyle = .full
        let wann = formatter.localizedString(for: zuletzt.performedAt, relativeTo: .now)
        return "\(wann) · \(Zahlformat.gewichtMitEinheit(zuletzt.gewichtKg))"
    }

    /// Zwei Marken, die es sonst nirgends gibt.
    ///
    /// Bewusst kein `Chip`: der ist absichtlich zweizustaendig (Umriss in
    /// muted oder Akzent) und kennt kein warn. Ihn fuer diesen einen
    /// Screen um einen Ton zu erweitern hiesse, ein geteiltes Bauteil fuer
    /// einen Sonderfall aufzubohren.
    private struct Marke: View {
        let text: String
        let farbe: Color

        var body: some View {
            Text(text)
                .font(.system(size: 10, weight: .heavy))
                .tracking(0.6)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .foregroundStyle(farbe)
                .overlay(Capsule().stroke(farbe.opacity(0.4), lineWidth: 1))
                .fixedSize()
        }
    }

    // MARK: - Leer

    private var leerZustand: some View {
        VStack(spacing: DesignSystem.Spacing.s16) {
            Spacer()
            if suchtext.isEmpty {
                Text("In diesem Studio ist noch kein Gerät eingetragen.")
                    .font(DesignSystem.Typography.fliesstext)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .multilineTextAlignment(.center)
            } else {
                Text("Keine Treffer für „\(suchtext)“")
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundStyle(DesignSystem.Color.text)
                    .multilineTextAlignment(.center)
                Text("Studios benennen Geräte unterschiedlich. Such nach dem Platz — „Fensterreihe“ — oder nach der Übung, die du machen willst.")
                    .font(.system(size: 14))
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                anderesStudio
            }
            Spacer()
            Text("Fehlt das Gerät ganz in der Liste, ist es im Studio noch nicht eingetragen — sag dort einmal Bescheid.")
                .font(.system(size: 12))
                .foregroundStyle(DesignSystem.Color.textFaint)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.bottom, DesignSystem.Spacing.s24)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Nur bei mehr als einem Studio und nur im leeren Zustand: findet die
    /// Suche hier nichts, ist das andere Studio der wahrscheinlichste
    /// Grund. Als Dauerfilter ueber der Liste waere es Laerm.
    @ViewBuilder
    private var anderesStudio: some View {
        if let anderes = katalog.bootstrap?.studios.first(where: { $0.id != studioId }) {
            Button { studioId = anderes.id } label: {
                Text("Auch in \(anderes.name) suchen")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(DesignSystem.Color.accent)
                    .frame(minHeight: 44)
            }
            .buttonStyle(PressButtonStyle())
        }
    }
}
```

`Zahlformat.gewichtMitEinheit(_:)` und `PressButtonStyle` existieren im Projekt und werden hier nur benutzt, nicht verändert.

- [ ] **Step 9: `TrainingRootView` verdrahten**

In `apps/ios-member/FitnessMember/Screens/Training/TrainingRootView.swift`:

`scanWege` bekommt den dritten Weg:

```swift
    private var scanWege: some View {
        ScanWege(
            beiQR: { scannerOffen = true },
            beiNFC: { nfcStarten() },
            // Ohne geladenen Prefetch gaebe es nichts zu waehlen.
            beiListe: katalog.bootstrap == nil ? nil : { pfad.append(.auswahl) }
        )
    }
```

`ziel(_:)` bekommt den Fall, als erster im `switch`:

```swift
        case .auswahl:
            GeraeteAuswahlView { machineId in
                pfad.append(.erkannt(machineId: machineId, token: nil))
            }
```

- [ ] **Step 10: Kaltbau mit allen Tests**

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -derivedDataPath /tmp/dd-gos-t4 test 2>&1 | grep -E "warning:|error:|TEST SUCCEEDED|TEST FAILED"
rm -rf /tmp/dd-gos-t4
```

Erwartet: `TEST SUCCEEDED`, keine neuen Warnungen.

- [ ] **Step 11: Am Simulator gegen den Entwurf halten**

App starten, Training öffnen. Prüfen:

1. Drei Knöpfe gleicher Höhe und Kontur, keiner in Akzentfarbe (Blatt 01).
2. „Aus der Liste wählen" öffnet die Liste mit Tab-Leiste, Zurück-Pfeil oben links (Blatt 02).
3. Ein Gerät mit Historie steht oben mit Akzentzeile, dasselbe Gerät steht **nicht** noch einmal unter A–Z.
4. „bein" tippen: Treffer erscheinen, ein Gerät, das nur über eine Übung trifft, trägt die Übungszeile (Blatt 03).
5. Unsinn tippen: leerer Zustand mit dem Satz und — bei zwei Studios — der Zeile zum anderen Studio (Blatt 04).
6. Ein Gerät antippen: der Geräte-Screen zeigt **AUSGEWÄHLT** mit Listensymbol und, sobald das Netz antwortet, das Gerätefoto (Blatt 05).
7. Ein Gerät scannen: derselbe Screen zeigt **ERKANNT** mit NFC-Wellen.

- [ ] **Step 12: Commit**

```bash
git add apps/ios-member/FitnessMember/Screens/Geraet/GeraeteAuswahlView.swift \
        apps/ios-member/FitnessMember/DesignSystem/Components/ScanWege.swift \
        apps/ios-member/FitnessMember/Navigation/GeraetRoute.swift \
        apps/ios-member/FitnessMember/Screens/Training/TrainingRootView.swift \
        apps/ios-member/FitnessMember/Screens/Geraet/GeraetModel.swift \
        apps/ios-member/FitnessMember/Screens/Geraet/GeraetErkanntView.swift \
        apps/ios-member/FitnessMemberTests/GeraetEinstiegsartTests.swift \
        apps/ios-member/FitnessMember.xcodeproj/project.pbxproj
git commit -m "feat(geraet): Geraet ohne Scan ueber Liste und Suche waehlen"
```

---

## Selbstprüfung

**Spec-Deckung.** Jeder Abschnitt der Spec hat eine Aufgabe: §3.2 und §3.3 → Task 1; §3.4 und §4 → Task 2; §5 → Task 3; §6 und §7 → Task 4; §8 verteilt sich über alle vier. Die offenen Punkte aus §9 sind ausdrücklich nicht gebaut und tauchen deshalb in keiner Aufgabe auf.

**Nicht abgedeckt und bewusst so:** Das Foto eines echten Aufklebers auf Blatt 01 (Spec §2, nicht enthalten) — im Entwurf steht dort die gezeichnete Marke, in der App bleibt die Fläche vorerst leer, weil `TrainingRootView` sie nie hatte. Wer sie will, tauscht sie ein, wenn das Bild da ist.

**Typkonsistenz.** `machineContext(machineId:)` heißt in `APIClient`, `GeraetLoading`, dem Fake in Task 2 und dem Aufruf in `kontextLaden()` gleich. `GeraeteAuswahl.Gruppen` trägt in Task 3 und Task 4 dieselben zwei Felder `zuletzt` und `alle`. `Einstiegsart` wird in Task 4 Step 3 definiert und in Step 5 gelesen.

**Eine Abweichung von der Spec, absichtlich:** Die Spec sagt in §4, `GeraetLoading` wachse um die Methode. Der Plan lässt `beiListe` in `ScanWege` zusätzlich optional werden — das steht in Spec §7 („Bootstrap noch nicht geladen: der dritte Knopf erscheint nicht") und ist hier nur die technische Form davon.
