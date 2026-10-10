# Geräteeinrichtung Etappe A: Vorbefüllen aus dem Gymtavo-Typ – Umsetzungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wer im Portal ein Gerätemodell anlegt und einen Gymtavo-Typ wählt, bekommt Belastung, Nebenbelastung, Name, Einstellungen und Foto vom Typ, statt sie abzutippen oder zu fotografieren.

**Architecture:** Der Browser füllt Name und Belastungsrad aus einer schlanken Typliste vor (`typVorlagen`). Nach dem Anlegen kopiert eine neue Domain-Funktion `copyTypeDefaults` Einstellungen und Typillustration ins Studio-Modell. Kopie statt Verweis (Spec G1), das Foto immer als eigene Datei im Studioordner (G5). Keine Migration.

**Tech Stack:** TypeScript, Zod, Supabase JS (nutzergebundener Client), Next.js 15 Server Actions, React 19, Vitest (+ jsdom, Testing Library), Playwright.

**Spec:** `docs/superpowers/specs/2026-10-10-gymtavo-katalog-geraeteeinrichtung-design.md`, Abschnitt 3 (G1, G5) und 5.

## Global Constraints

- Arbeit nur im Worktree `.claude/worktrees/katalog-produkte`, Branch `claude/gymtavo-katalog-produkte`. Nicht pushen, bis Tim es sagt.
- Integrationstests laufen gegen das **geteilte** lokale Supabase: nie `supabase db reset`, nie fremde Zeilen anfassen. Eigene Gymtavo-Typen mit eindeutigem Namen (`kennung = crypto.randomUUID().slice(0, 8)`), Prüfungen auf Enthaltensein, nie auf Gleichheit der ganzen Typliste. Eigene Storage-Objekte am Ende entfernen.
- Gymtavo-Studio-ID: `00000000-0000-4000-8000-000000000001`.
- Domain-Code nutzt den nutzergebundenen Client, nie die Service-Rolle (Kopfkommentar `catalog.ts`, `media-store.ts`).
- Commits: deutsch mit ae/oe/ue, ein Commit je Task, Form `feat(katalog): …`/`test(katalog): …`/`docs(plan): …`, Trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; nach jedem Commit `git log -1 --format=%B` prüfen.
- Kommentare im Code ASCII (ae/oe/ue), sie nennen einen Grund statt den Code nachzuerzählen. Sichtbare Texte im Portal mit echten Umlauten.
- Hinweistext nach der Typwahl wörtlich: `Werte vom Typ {Name} übernommen – bitte ans Gerät anpassen.`
- Hinweis am Fotofeld der Halle bei Typ mit Illustration wörtlich: `Ohne eigenes Foto zeigt das Gerät die Gymtavo-Zeichnung. Ein echtes Foto hilft Mitgliedern, das Gerät zu erkennen.`
- Vor dem Abschluss der volle Testsatz: `pnpm typecheck`, `pnpm test`, `pnpm test:integration`, `pnpm test:e2e` (iOS ist nicht betroffen, kein `xcodebuild`).

## Review Focus

1. **Typ mit kg-Schritt 1 (alle 46 Kraft-Typen heute):** Das kg-Rad kennt nur `1,25 / 2,5 / 5 / 10 / 20`; `EinstellungRad` springt auf den nächstgelegenen Wert. Erwartet: Das Rad steht auf `1,25`, und genau das wird gespeichert (kein Absturz, kein leerer Schritt). Test in Task 4.
2. **Typwechsel nach eigener Eingabe:** Trainer tippt Namen, wählt Typ A, dann Typ B. Erwartet: Ein selbst getippter Name bleibt; ein vom Typ A gesetzter Name wird durch B ersetzt; das Rad zeigt die Werte von B. Test in Task 4.
3. **Modell hat schon eine gleichnamige Einstellung** (zweiter Aufruf, Doppelklick, Wiederholung nach Fehler): Erwartet: kein `conflict`, nichts doppelt, Zähler meldet nur Neues. Test in Task 2.
4. **Typ ohne Illustration in der Halle:** Erwartet: Foto bleibt Pflicht, Knopf gesperrt, Server lehnt ohne Datei ab. Test in Task 6.
5. **Kopieren schlägt nach dem Anlegen fehl** (Storage weg, Typfoto gelöscht): Erwartet: Modell steht, Weiterleitung passiert trotzdem, Fehler im Serverprotokoll, Schritt 2 zeigt „Foto fehlt“. Test in Task 2 (Typfoto-Pfad zeigt ins Leere → `DomainError`, Einstellungen sind trotzdem kopiert).

---

## Dateien

| Datei | Aufgabe |
|---|---|
| `packages/domain/src/catalog.ts` | `CatalogType` und `listCatalogTypes` um Belastung, Nebenbelastung, `photoPath` erweitern |
| `packages/domain/src/typ-vorlage.ts` (neu) | `copyTypeDefaults`: Einstellungen und Foto vom Typ ins Studio-Modell kopieren |
| `packages/domain/src/index.ts` | Export `copyTypeDefaults` |
| `tests/integration/domain-typ-vorlage.test.ts` (neu) | Integration für beide Domain-Änderungen |
| `apps/web/app/portal/bausteine/typVorlage.ts` (neu) | rein: `TypVorlage`, `typVorlagen`, `belastungStart`, `nameNachTypwahl` |
| `apps/web/app/portal/bausteine/typVorlage.test.ts` (neu) | Unit |
| `apps/web/app/portal/bausteine/GymtavoTypFeld.tsx` | optionales `onChange` |
| `apps/web/app/portal/bausteine/ModellVorlageFelder.tsx` (neu) | Name, Hersteller, Typ, Hinweis, Belastungsrad – mit Vorbefüllen |
| `apps/web/app/portal/bausteine/ModellVorlageFelder.test.tsx` (neu) | Komponententest |
| `apps/web/app/portal/[studioId]/(schreibtisch)/geraete/ModellAnlegenFormular.tsx` | nutzt `ModellVorlageFelder` |
| `apps/web/app/portal/[studioId]/(schreibtisch)/geraete/neu/page.tsx` | Typliste nach Kategorie filtern, auf `TypVorlage` abbilden |
| `apps/web/app/portal/actions.ts` | `modellAnlegen` ruft `copyTypeDefaults` |
| `apps/web/app/portal/[studioId]/einrichten/modell/neu/ModellNeuFormular.tsx` | nutzt `ModellVorlageFelder`, Foto optional bei Typ mit Illustration |
| `apps/web/app/portal/[studioId]/einrichten/modell/neu/page.tsx` | `TypVorlage`, Notiztext |
| `apps/web/app/portal/[studioId]/einrichten/actions.ts` | `modellAnlegen`: Foto-Pflicht nach Typ, `copyTypeDefaults` |
| `apps/web/app/portal/[studioId]/(schreibtisch)/geraete/[modelId]/uebungen/gymtavo.test.ts` | Fixture um neue `CatalogType`-Felder ergänzen |
| `e2e/helpers/gymtavo.ts` | `gymtavoTyp` mit optionalen Werten, Einstellungen, Foto |
| `e2e/gymtavo.spec.ts`, `e2e/einrichten.spec.ts` | Abnahme beider Wege |

---

### Task 1: `listCatalogTypes` liefert Belastung und Foto des Typs

**Files:**
- Modify: `packages/domain/src/catalog.ts:1150-1218` (`CatalogType`, `listCatalogTypes`)
- Modify: `apps/web/app/portal/[studioId]/(schreibtisch)/geraete/[modelId]/uebungen/gymtavo.test.ts:19` (Fixture)
- Create: `tests/integration/domain-typ-vorlage.test.ts`

**Interfaces:**
- Produces:
  ```ts
  export type CatalogType = {
    id: string; name: string; manufacturer: string | null; category: Category;
    loadUnit: LoadUnit; loadStep: number; loadMin: number; loadMax: number | null;
    secondaryUnit: LoadUnit | null; secondaryStep: number | null;
    secondaryMin: number | null; secondaryMax: number | null;
    photoPath: string | null;
    exercises: CatalogTypeExercise[];
  };
  ```

- [ ] **Step 1: Integrationstest schreiben** – neue Datei `tests/integration/domain-typ-vorlage.test.ts`:

```ts
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { PHOTO_BUCKET, listCatalogTypes } from "@fitretro/domain";
import { createTestUser, serviceClient, uniqueEmail, userClient } from "./helpers/clients.js";

// Spec 2026-10-10-gymtavo-katalog-geraeteeinrichtung-design.md, Abschnitt 5.
// Andere Testdateien legen ebenfalls Gymtavo-Typen an -- geprueft wird auf
// Enthaltensein, nie auf Gleichheit der Typliste.
const GYMTAVO = "00000000-0000-4000-8000-000000000001";
const kennung = crypto.randomUUID().slice(0, 8);

/** 1x1 PNG, gueltig genug fuer sniffMediaType und stripPngMetadata. */
const PNG_1X1 = Uint8Array.from(
  Buffer.from(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==",
    "base64",
  ),
);

let studioA: string;
let trainerA: string;
let mitgliedA: string;
let typKraft: string;
let typCardio: string;
const typFoto = `${GYMTAVO}/catalog/photos/t_${kennung}_kraft.png`;
const eigeneObjekte: string[] = [typFoto];

beforeAll(async () => {
  const admin = serviceClient();
  const { data: studio, error: studioError } = await admin
    .from("studios")
    .insert({ name: `Typvorlage ${kennung}` })
    .select("id")
    .single();
  if (studioError) throw studioError;
  studioA = studio.id;

  trainerA = uniqueEmail("typvorlage-trainer");
  mitgliedA = uniqueEmail("typvorlage-mitglied");
  const { error: rolleError } = await admin.from("studio_memberships").insert([
    { studio_id: studioA, user_id: await createTestUser(trainerA), role: "trainer" },
    { studio_id: studioA, user_id: await createTestUser(mitgliedA), role: "member" },
  ]);
  if (rolleError) throw rolleError;

  const { error: uploadError } = await admin.storage
    .from(PHOTO_BUCKET)
    .upload(typFoto, new Blob([PNG_1X1], { type: "image/png" }), { contentType: "image/png" });
  if (uploadError) throw uploadError;

  const { data: typen, error: typError } = await admin
    .from("equipment_models")
    .insert([
      {
        studio_id: GYMTAVO, name: `AA Brustpresse ${kennung}`, category: "kraft",
        load_unit: "kg", load_step: 5, load_min: 5, load_max: 100, photo_path: typFoto,
      },
      {
        studio_id: GYMTAVO, name: `AA Laufband ${kennung}`, category: "cardio",
        load_unit: "kmh", load_step: 0.1, load_min: 0, load_max: null,
        secondary_unit: "pct", secondary_step: 0.5, secondary_min: 0, secondary_max: 15,
      },
    ])
    .select("id");
  if (typError) throw typError;
  typKraft = typen[0]!.id;
  typCardio = typen[1]!.id;
});

afterAll(async () => {
  await serviceClient().storage.from(PHOTO_BUCKET).remove(eigeneObjekte);
});

describe("listCatalogTypes", () => {
  it("liefert Belastung, Nebenbelastung und Foto je Typ", async () => {
    const typen = await listCatalogTypes(await userClient(trainerA));
    expect(typen.find((t) => t.id === typKraft)).toMatchObject({
      category: "kraft", loadUnit: "kg", loadStep: 5, loadMin: 5, loadMax: 100,
      secondaryUnit: null, secondaryStep: null, secondaryMin: null, secondaryMax: null,
      photoPath: typFoto,
    });
    expect(typen.find((t) => t.id === typCardio)).toMatchObject({
      category: "cardio", loadUnit: "kmh", loadStep: 0.1, loadMin: 0, loadMax: null,
      secondaryUnit: "pct", secondaryStep: 0.5, secondaryMin: 0, secondaryMax: 15,
      photoPath: null,
    });
  });
});
```

- [ ] **Step 2: Test laufen lassen, er muss scheitern**

Run: `pnpm test:integration tests/integration/domain-typ-vorlage.test.ts`
Expected: FAIL, `toMatchObject` vermisst `loadUnit` usw.

- [ ] **Step 3: `CatalogType` und `listCatalogTypes` erweitern** – in `packages/domain/src/catalog.ts`:
  - `CatalogType` um die Felder aus „Produces“ ergänzen.
  - Select-String: `id, name, manufacturer, category, load_unit, load_step, load_min, load_max, secondary_unit, secondary_step, secondary_min, secondary_max, photo_path,` vor `equipment_model_exercises (…)`.
  - `Row` um `load_unit: LoadUnit; load_step: number | string; load_min: number | string; load_max: number | string | null; secondary_unit: LoadUnit | null; secondary_step: number | string | null; secondary_min: number | string | null; secondary_max: number | string | null; photo_path: string | null;` ergänzen.
  - Abbildung wie in `getStudioCatalog` (`catalog.ts:1051-1057`): `Number(...)` für Pflichtzahlen, den vorhandenen Helfer `zahl(...)` für nullable Zahlen. In `Row` die Zahlspalten als `number | string` bzw. `number | string | null` typisieren.

```ts
  return ((data ?? []) as unknown as Row[]).map((row) => ({
    id: row.id,
    name: row.name,
    manufacturer: row.manufacturer,
    category: row.category,
    loadUnit: row.load_unit,
    loadStep: Number(row.load_step),
    loadMin: Number(row.load_min),
    loadMax: zahl(row.load_max),
    secondaryUnit: row.secondary_unit,
    secondaryStep: zahl(row.secondary_step),
    secondaryMin: zahl(row.secondary_min),
    secondaryMax: zahl(row.secondary_max),
    photoPath: row.photo_path,
    exercises: /* unveraendert */,
  }));
```


- [ ] **Step 4: Fixture im Web nachziehen** – in `gymtavo.test.ts` jedem `CatalogType`-Literal ergänzen: `loadUnit: "kg", loadStep: 2.5, loadMin: 0, loadMax: null, secondaryUnit: null, secondaryStep: null, secondaryMin: null, secondaryMax: null, photoPath: null,`.

- [ ] **Step 5: Tests laufen lassen**

Run: `pnpm test:integration tests/integration/domain-typ-vorlage.test.ts tests/integration/domain-gymtavo-portal.test.ts && pnpm --filter web test && pnpm typecheck`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add packages/domain/src/catalog.ts tests/integration/domain-typ-vorlage.test.ts "apps/web/app/portal/[studioId]/(schreibtisch)/geraete/[modelId]/uebungen/gymtavo.test.ts"
git commit -m "feat(katalog): Typliste liefert Belastung und Foto des Gymtavo-Typs"
```

---

### Task 2: `copyTypeDefaults` kopiert Einstellungen und Typillustration

**Files:**
- Create: `packages/domain/src/typ-vorlage.ts`
- Modify: `packages/domain/src/index.ts` (Export)
- Modify: `tests/integration/domain-typ-vorlage.test.ts`

**Interfaces:**
- Consumes: `uploadEquipmentPhoto(client, { equipmentModelId, bytes })` aus `media-store.ts`, `PHOTO_BUCKET`, `requireStudioStaff`, `requireUserId`, `DomainError`.
- Produces:
  ```ts
  export async function copyTypeDefaults(
    client: SupabaseClient,
    equipmentModelId: string,
  ): Promise<{ settingsCopied: number; photoCopied: boolean }>;
  ```
  Ohne Typ am Modell: `{ settingsCopied: 0, photoCopied: false }`. Fremdes oder unbekanntes Modell: `DomainError("not_found")`. Kein Staff: `DomainError` aus `requireStudioStaff`. Foto nicht ladbar: `DomainError("internal")` **nachdem** die Einstellungen kopiert sind.

- [ ] **Step 1: Tests ergänzen** – in `domain-typ-vorlage.test.ts`: Import um `copyTypeDefaults, createEquipmentModel, uploadEquipmentPhoto` erweitern; im `beforeAll` nach den Typen zwei Einstellungen am Kraft-Typ und einen Typ mit kaputtem Fotopfad anlegen:

```ts
let typKaputt: string;
// … in beforeAll, nach dem Anlegen der Typen:
  const { error: settingError } = await admin.from("equipment_setting_definitions").insert([
    { equipment_model_id: typKraft, key: "seat_height", label: "Sitzhöhe", kind: "number",
      min_value: 1, max_value: 10, step_value: 1, unit: null, sort_order: 0 },
    { equipment_model_id: typKraft, key: "grip", label: "Griff", kind: "enum",
      allowed_values: ["neutral", "pronated"], sort_order: 1 },
  ]);
  if (settingError) throw settingError;

  const { data: kaputt, error: kaputtError } = await admin
    .from("equipment_models")
    .insert({
      studio_id: GYMTAVO, name: `AA Kaputt ${kennung}`, load_step: 5,
      photo_path: `${GYMTAVO}/catalog/photos/t_${kennung}_gibt_es_nicht.png`,
    })
    .select("id")
    .single();
  if (kaputtError) throw kaputtError;
  typKaputt = kaputt.id;
  const { error: kaputtSettingError } = await admin.from("equipment_setting_definitions").insert({
    equipment_model_id: typKaputt, key: "back_rest", label: "Lehne", kind: "number", sort_order: 0,
  });
  if (kaputtSettingError) throw kaputtSettingError;
```

Hilfsfunktionen und Tests am Dateiende:

```ts
async function modellMitTyp(typId: string | undefined, name: string): Promise<string> {
  const { id } = await createEquipmentModel(await userClient(trainerA), {
    studioId: studioA, name: `${name} ${kennung}`, loadStep: 5, catalogModelId: typId,
  });
  return id;
}

async function einstellungen(modelId: string) {
  const { data, error } = await serviceClient()
    .from("equipment_setting_definitions")
    .select("key, label, kind, min_value, max_value, step_value, unit, allowed_values, sort_order")
    .eq("equipment_model_id", modelId)
    .order("sort_order");
  if (error) throw error;
  return data;
}

async function fotoPfad(modelId: string): Promise<string | null> {
  const { data, error } = await serviceClient()
    .from("equipment_models").select("photo_path").eq("id", modelId).single();
  if (error) throw error;
  return data.photo_path;
}

describe("copyTypeDefaults", () => {
  it("kopiert die Einstellungen des Typs samt Werteliste und Reihenfolge", async () => {
    const modelId = await modellMitTyp(typKraft, "Brustpresse");
    const ergebnis = await copyTypeDefaults(await userClient(trainerA), modelId);
    expect(ergebnis.settingsCopied).toBe(2);
    const zeilen = await einstellungen(modelId);
    expect(zeilen).toEqual([
      expect.objectContaining({ key: "seat_height", label: "Sitzhöhe", kind: "number", sort_order: 0 }),
      expect.objectContaining({ key: "grip", kind: "enum",
        allowed_values: ["neutral", "pronated"], sort_order: 1 }),
    ]);
    // numeric kann als Text kommen -- verglichen wird der Wert.
    expect([zeilen[0]!.min_value, zeilen[0]!.max_value, zeilen[0]!.step_value].map(Number))
      .toEqual([1, 10, 1]);
  });

  it("kopiert die Typillustration in den Studioordner, nicht als Verweis", async () => {
    const modelId = await modellMitTyp(typKraft, "Brustpresse Foto");
    const ergebnis = await copyTypeDefaults(await userClient(trainerA), modelId);
    expect(ergebnis.photoCopied).toBe(true);
    const pfad = await fotoPfad(modelId);
    expect(pfad?.startsWith(`${studioA}/models/${modelId}/`)).toBe(true);
    eigeneObjekte.push(pfad!);
  });

  it("laesst ein eigenes Foto stehen", async () => {
    const modelId = await modellMitTyp(typKraft, "Brustpresse eigenes Foto");
    const client = await userClient(trainerA);
    const { storagePath } = await uploadEquipmentPhoto(client, {
      equipmentModelId: modelId, bytes: PNG_1X1,
    });
    eigeneObjekte.push(storagePath);
    const ergebnis = await copyTypeDefaults(client, modelId);
    expect(ergebnis.photoCopied).toBe(false);
    expect(await fotoPfad(modelId)).toBe(storagePath);
  });

  it("ein zweiter Aufruf legt nichts doppelt an und meldet keinen Konflikt", async () => {
    const modelId = await modellMitTyp(typKraft, "Brustpresse doppelt");
    const client = await userClient(trainerA);
    const erster = await copyTypeDefaults(client, modelId);
    eigeneObjekte.push((await fotoPfad(modelId))!);
    const zweiter = await copyTypeDefaults(client, modelId);
    expect(erster.settingsCopied).toBe(2);
    expect(zweiter).toEqual({ settingsCopied: 0, photoCopied: false });
    expect(await einstellungen(modelId)).toHaveLength(2);
  });

  it("ein Modell ohne Typ bleibt unveraendert", async () => {
    const modelId = await modellMitTyp(undefined, "Ohne Typ");
    const ergebnis = await copyTypeDefaults(await userClient(trainerA), modelId);
    expect(ergebnis).toEqual({ settingsCopied: 0, photoCopied: false });
    expect(await einstellungen(modelId)).toHaveLength(0);
    expect(await fotoPfad(modelId)).toBeNull();
  });

  it("negativ: ein Mitglied darf nicht kopieren", async () => {
    const modelId = await modellMitTyp(typKraft, "Mitglied");
    await expect(copyTypeDefaults(await userClient(mitgliedA), modelId)).rejects.toMatchObject({
      code: "unauthorized",
    });
    expect(await einstellungen(modelId)).toHaveLength(0);
  });

  it("ein fehlendes Typfoto ist ein Fehler, die Einstellungen sind trotzdem da", async () => {
    const modelId = await modellMitTyp(typKaputt, "Kaputt");
    await expect(copyTypeDefaults(await userClient(trainerA), modelId)).rejects.toMatchObject({
      code: "internal",
    });
    expect(await einstellungen(modelId)).toEqual([expect.objectContaining({ key: "back_rest" })]);
    expect(await fotoPfad(modelId)).toBeNull();
  });
});
```

  `requireStudioStaff` (`studio.ts:19-35`) wirft für ein Mitglied `DomainError("unauthorized")`.

- [ ] **Step 2: Tests laufen lassen, sie müssen scheitern**

Run: `pnpm test:integration tests/integration/domain-typ-vorlage.test.ts`
Expected: FAIL, `copyTypeDefaults` ist nicht exportiert.

- [ ] **Step 3: `packages/domain/src/typ-vorlage.ts` schreiben**

```ts
import type { SupabaseClient } from "@supabase/supabase-js";
import { requireUserId } from "./auth.js";
import { DomainError } from "./errors.js";
import { PHOTO_BUCKET } from "./media.js";
import { uploadEquipmentPhoto } from "./media-store.js";
import { requireStudioStaff } from "./studio.js";

/**
 * Was der Gymtavo-Typ weiss, bekommt das Studio-Modell beim Anlegen als
 * Kopie (Spec 2026-10-10 ..., G1): Einstellungen und Typillustration.
 * Kopie statt Verweis, weil ein Studio-Geraet eigene Stufen und eine eigene
 * Historie hat und Katalogkorrekturen laufende Geraete nicht still aendern
 * sollen. Die Belastung kommt nicht von hier -- sie stand im Formular, der
 * Trainer hat sie gesehen.
 */
export async function copyTypeDefaults(
  client: SupabaseClient,
  equipmentModelId: string,
): Promise<{ settingsCopied: number; photoCopied: boolean }> {
  const userId = await requireUserId(client);
  const { data: modell } = await client
    .from("equipment_models")
    .select("studio_id, photo_path, catalog_model_id")
    .eq("id", equipmentModelId)
    .maybeSingle<{ studio_id: string; photo_path: string | null; catalog_model_id: string | null }>();
  if (!modell) throw new DomainError("not_found", "Dieses Geraetemodell gibt es nicht.");
  await requireStudioStaff(client, modell.studio_id, userId);
  // Im Gymtavo-Studio verbietet der Trigger aus 0047 eine Zuordnung --
  // dort endet die Funktion also immer hier.
  if (!modell.catalog_model_id) return { settingsCopied: 0, photoCopied: false };

  const settingsCopied = await einstellungenKopieren(
    client,
    modell.catalog_model_id,
    equipmentModelId,
  );
  // Foto zuletzt: es ist der Teil, der am ehesten scheitert (Storage), und
  // die Einstellungen sollen dann trotzdem da sein.
  const photoCopied = modell.photo_path
    ? false
    : await fotoKopieren(client, modell.catalog_model_id, equipmentModelId);
  return { settingsCopied, photoCopied };
}

type Einstellung = {
  key: string;
  label: string;
  kind: "number" | "enum";
  min_value: number | null;
  max_value: number | null;
  step_value: number | null;
  unit: string | null;
  allowed_values: string[] | null;
  sort_order: number;
};

async function einstellungenKopieren(
  client: SupabaseClient,
  typId: string,
  modelId: string,
): Promise<number> {
  const spalten = "key, label, kind, min_value, max_value, step_value, unit, allowed_values, sort_order";
  const [{ data: vomTyp, error: typFehler }, { data: vorhanden, error: modellFehler }] =
    await Promise.all([
      client.from("equipment_setting_definitions").select(spalten).eq("equipment_model_id", typId),
      client.from("equipment_setting_definitions").select("key").eq("equipment_model_id", modelId),
    ]);
  if (typFehler || modellFehler) {
    throw new DomainError("internal", (typFehler ?? modellFehler)!.message);
  }
  // Ein Schluessel, den das Modell schon hat, bleibt wie er ist: ein
  // zweiter Aufruf (Doppelklick, Wiederholung nach Fehler) darf weder
  // doppeln noch am unique (equipment_model_id, key) scheitern.
  const schonDa = new Set((vorhanden ?? []).map((zeile) => zeile.key as string));
  const neu = ((vomTyp ?? []) as Einstellung[]).filter((zeile) => !schonDa.has(zeile.key));
  if (neu.length === 0) return 0;

  const { error } = await client
    .from("equipment_setting_definitions")
    .insert(neu.map((zeile) => ({ ...zeile, equipment_model_id: modelId })));
  if (error) throw new DomainError("internal", error.message);
  return neu.length;
}

async function fotoKopieren(
  client: SupabaseClient,
  typId: string,
  modelId: string,
): Promise<boolean> {
  const { data: typ } = await client
    .from("equipment_models")
    .select("photo_path")
    .eq("id", typId)
    .maybeSingle<{ photo_path: string | null }>();
  if (!typ?.photo_path) return false;

  const { data: datei, error } = await client.storage.from(PHOTO_BUCKET).download(typ.photo_path);
  if (error || !datei) {
    throw new DomainError("internal", "Das Foto des Gymtavo-Typs liess sich nicht laden.");
  }
  // Eigene Datei im Studioordner statt Pfad in den Gymtavo-Ordner (G5):
  // uploadEquipmentPhoto loescht beim Ersetzen das bisherige Objekt, und
  // is_media_published (0021) gibt ueber photo_path anonym frei.
  await uploadEquipmentPhoto(client, {
    equipmentModelId: modelId,
    bytes: new Uint8Array(await datei.arrayBuffer()),
  });
  return true;
}
```

- [ ] **Step 4: Export** – in `packages/domain/src/index.ts` nach dem `media-store`-Block:

```ts
export { copyTypeDefaults } from "./typ-vorlage.js";
```

- [ ] **Step 5: Tests laufen lassen**

Run: `pnpm test:integration tests/integration/domain-typ-vorlage.test.ts && pnpm typecheck`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add packages/domain/src/typ-vorlage.ts packages/domain/src/index.ts tests/integration/domain-typ-vorlage.test.ts
git commit -m "feat(katalog): Einstellungen und Typillustration beim Anlegen ins Studio-Modell kopieren"
```

---

### Task 3: Reine Vorlage-Funktionen fürs Formular

**Files:**
- Create: `apps/web/app/portal/bausteine/typVorlage.ts`
- Create: `apps/web/app/portal/bausteine/typVorlage.test.ts`

**Interfaces:**
- Consumes: `CatalogType` (Task 1), `ModellBelastungStart` aus `ModellBelastungRad.tsx`.
- Produces:
  ```ts
  export type TypVorlage = Pick<CatalogType,
    "id" | "name" | "manufacturer" | "category" | "loadUnit" | "loadStep" | "loadMin" |
    "loadMax" | "secondaryUnit" | "secondaryStep" | "secondaryMin" | "secondaryMax"> & {
    hatFoto: boolean;
  };
  export function typVorlagen(typen: CatalogType[], kategorie?: Category): TypVorlage[];
  export function belastungStart(typ: TypVorlage): ModellBelastungStart;
  export function nameNachTypwahl(
    aktuell: string, vorigerTyp: TypVorlage | null, neuerTyp: TypVorlage | null,
  ): string;
  ```

- [ ] **Step 1: Unit-Test schreiben** – `typVorlage.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import type { CatalogType } from "@fitretro/domain";
import { belastungStart, nameNachTypwahl, typVorlagen, type TypVorlage } from "./typVorlage";

const basis: CatalogType = {
  id: "t1", name: "Brustpresse", manufacturer: null, category: "kraft",
  loadUnit: "kg", loadStep: 1, loadMin: 0, loadMax: null,
  secondaryUnit: null, secondaryStep: null, secondaryMin: null, secondaryMax: null,
  photoPath: "gymtavo/catalog/photos/chest_press-abcd1234.png",
  exercises: [{ exerciseId: "u1", name: "Brustpresse neutral", description: "lang", volumeKind: "reps",
    targetMin: 8, targetMax: 12, sortOrder: 1, videoStoragePath: null, videoDurationS: null }],
};
const laufband: CatalogType = {
  ...basis, id: "t2", name: "Laufband", category: "cardio", loadUnit: "kmh", loadStep: 0.1,
  secondaryUnit: "pct", secondaryStep: 0.5, secondaryMin: 0, secondaryMax: 15,
  photoPath: null, exercises: [],
};

describe("typVorlagen", () => {
  it("laesst Uebungen und Pfad weg und merkt nur, ob es ein Foto gibt", () => {
    const [vorlage] = typVorlagen([basis]);
    expect(vorlage).toEqual({
      id: "t1", name: "Brustpresse", manufacturer: null, category: "kraft",
      loadUnit: "kg", loadStep: 1, loadMin: 0, loadMax: null,
      secondaryUnit: null, secondaryStep: null, secondaryMin: null, secondaryMax: null,
      hatFoto: true,
    });
  });

  it("filtert nach Kategorie, wenn eine vorgegeben ist", () => {
    expect(typVorlagen([basis, laufband], "cardio").map((t) => t.id)).toEqual(["t2"]);
    expect(typVorlagen([basis, laufband]).map((t) => t.id)).toEqual(["t1", "t2"]);
  });
});

describe("belastungStart", () => {
  it("bildet einen Krafttyp ohne Nebenbelastung ab", () => {
    expect(belastungStart(typVorlagen([basis])[0]!)).toEqual({
      category: "kraft", loadUnit: "kg", loadMin: 0, loadMax: null, loadStep: 1,
      secondaryUnit: null, secondaryMin: null, secondaryMax: null, secondaryStep: null,
    });
  });

  it("bildet einen Cardiotyp mit Nebenbelastung ab", () => {
    expect(belastungStart(typVorlagen([laufband])[0]!)).toEqual({
      category: "cardio", loadUnit: "kmh", loadMin: 0, loadMax: null, loadStep: 0.1,
      secondaryUnit: "pct", secondaryMin: 0, secondaryMax: 15, secondaryStep: 0.5,
    });
  });
});

describe("nameNachTypwahl", () => {
  const [brust, band] = typVorlagen([basis, laufband]) as [TypVorlage, TypVorlage];

  it("ein leerer Name bekommt den Typnamen", () => {
    expect(nameNachTypwahl("", null, brust)).toBe("Brustpresse");
    expect(nameNachTypwahl("   ", null, brust)).toBe("Brustpresse");
  });

  it("ein vom vorigen Typ gesetzter Name folgt dem neuen Typ", () => {
    expect(nameNachTypwahl("Brustpresse", brust, band)).toBe("Laufband");
  });

  it("ein selbst getippter Name bleibt", () => {
    expect(nameNachTypwahl("Brustpresse links", brust, band)).toBe("Brustpresse links");
    expect(nameNachTypwahl("Kabelturm", null, brust)).toBe("Kabelturm");
  });

  it("ohne neuen Typ bleibt der Name", () => {
    expect(nameNachTypwahl("Brustpresse", brust, null)).toBe("Brustpresse");
  });
});
```

- [ ] **Step 2: Test laufen lassen, er muss scheitern**

Run: `pnpm --filter web exec vitest run app/portal/bausteine/typVorlage.test.ts`
Expected: FAIL, Modul `./typVorlage` fehlt.

- [ ] **Step 3: `typVorlage.ts` schreiben**

```ts
import type { CatalogType } from "@fitretro/domain";
import type { Category } from "@fitretro/domain/belastung";
import type { ModellBelastungStart } from "./ModellBelastungRad";

/**
 * Was das Modellformular vom Gymtavo-Typ braucht, um vorzubefuellen
 * (Spec 2026-10-10 ..., 5.2). Schlank, weil die Liste als Prop in den
 * Browser geht: 55 Typen mit allen Uebungstexten waeren ein Vielfaches.
 */
export type TypVorlage = Pick<
  CatalogType,
  | "id" | "name" | "manufacturer" | "category" | "loadUnit" | "loadStep" | "loadMin"
  | "loadMax" | "secondaryUnit" | "secondaryStep" | "secondaryMin" | "secondaryMax"
> & {
  /** Der Pfad bleibt auf dem Server; das Formular muss nur wissen, ob. */
  hatFoto: boolean;
};

export function typVorlagen(typen: CatalogType[], kategorie?: Category): TypVorlage[] {
  return typen
    .filter((typ) => kategorie === undefined || typ.category === kategorie)
    .map((typ) => ({
      id: typ.id,
      name: typ.name,
      manufacturer: typ.manufacturer,
      category: typ.category,
      loadUnit: typ.loadUnit,
      loadStep: typ.loadStep,
      loadMin: typ.loadMin,
      loadMax: typ.loadMax,
      secondaryUnit: typ.secondaryUnit,
      secondaryStep: typ.secondaryStep,
      secondaryMin: typ.secondaryMin,
      secondaryMax: typ.secondaryMax,
      hatFoto: typ.photoPath !== null,
    }));
}

export function belastungStart(typ: TypVorlage): ModellBelastungStart {
  return {
    category: typ.category,
    loadUnit: typ.loadUnit,
    loadMin: typ.loadMin,
    loadMax: typ.loadMax,
    loadStep: typ.loadStep,
    secondaryUnit: typ.secondaryUnit,
    secondaryMin: typ.secondaryMin,
    secondaryMax: typ.secondaryMax,
    secondaryStep: typ.secondaryStep,
  };
}

/**
 * Der Typname ist ein Vorschlag, kein Ueberschreiben: was der Trainer
 * selbst getippt hat, bleibt. Erkannt wird der Vorschlag daran, dass der
 * Name noch genau der des vorigen Typs ist.
 */
export function nameNachTypwahl(
  aktuell: string,
  vorigerTyp: TypVorlage | null,
  neuerTyp: TypVorlage | null,
): string {
  if (!neuerTyp) return aktuell;
  const leer = aktuell.trim().length === 0;
  const vomTyp = vorigerTyp !== null && aktuell === vorigerTyp.name;
  return leer || vomTyp ? neuerTyp.name : aktuell;
}
```

- [ ] **Step 4: Test laufen lassen**

Run: `pnpm --filter web exec vitest run app/portal/bausteine/typVorlage.test.ts`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add apps/web/app/portal/bausteine/typVorlage.ts apps/web/app/portal/bausteine/typVorlage.test.ts
git commit -m "feat(katalog): Vorlagewerte des Gymtavo-Typs fuers Modellformular"
```

---

### Task 4: `ModellVorlageFelder` füllt Name und Belastung beim Typwechsel vor

**Files:**
- Modify: `apps/web/app/portal/bausteine/GymtavoTypFeld.tsx`
- Create: `apps/web/app/portal/bausteine/ModellVorlageFelder.tsx`
- Create: `apps/web/app/portal/bausteine/ModellVorlageFelder.test.tsx`

**Interfaces:**
- Consumes: `TypVorlage`, `belastungStart`, `nameNachTypwahl` (Task 3); `ModellBelastungRad({ gross, start, kategorie })`; `Feld`; `Auswahl` (sendet ein `input`-Ereignis, siehe Etappe-5-Ergebnis).
- Produces:
  ```tsx
  // GymtavoTypFeld: neue optionale Prop
  onChange?: (typId: string) => void;

  export function ModellVorlageFelder(props: {
    typen: TypVorlage[];
    gross?: boolean;
    /** Vorher gefragt (geraete/neu); fehlt in der Halle. */
    kategorie?: Category;
    /** Die Halle macht davon die Fotopflicht abhaengig. */
    onTyp?: (typ: TypVorlage | null) => void;
  }): JSX.Element;
  ```
  Felder im Formular: `name`, `manufacturer`, `catalogModelId` (`TYP_FELD`), dazu alles aus `ModellBelastungRad`.

- [ ] **Step 1: Komponententest schreiben** – `ModellVorlageFelder.test.tsx`:

```tsx
// @vitest-environment jsdom
import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, beforeAll, describe, expect, it, vi } from "vitest";
import { ModellVorlageFelder } from "./ModellVorlageFelder";
import type { TypVorlage } from "./typVorlage";

afterEach(cleanup);
beforeAll(() => {
  Element.prototype.scrollIntoView = vi.fn();
});

const brust: TypVorlage = {
  id: "t1", name: "Brustpresse", manufacturer: null, category: "kraft",
  loadUnit: "kg", loadStep: 5, loadMin: 0, loadMax: 100,
  secondaryUnit: null, secondaryStep: null, secondaryMin: null, secondaryMax: null, hatFoto: true,
};
const platzhalter: TypVorlage = { ...brust, id: "t2", name: "Beinpresse", loadStep: 1, loadMax: null, hatFoto: false };
const laufband: TypVorlage = {
  ...brust, id: "t3", name: "Laufband", category: "cardio", loadUnit: "kmh", loadStep: 0.5,
  loadMax: null, secondaryUnit: "pct", secondaryStep: 0.5, secondaryMin: 0, secondaryMax: 15,
};

function feldwert(name: string): string | null {
  return document.querySelector<HTMLInputElement>(`input[name="${name}"]`)?.value ?? null;
}

async function typWaehlen(name: string) {
  fireEvent.click(screen.getByRole("button", { name: "Gymtavo-Gerätetyp" }));
  fireEvent.click(await screen.findByRole("option", { name }));
}

describe("ModellVorlageFelder", () => {
  it("fuellt Name und Belastung vom Typ und sagt es", async () => {
    render(<ModellVorlageFelder typen={[brust, platzhalter]} kategorie="kraft" />);
    await typWaehlen("Brustpresse");
    expect(feldwert("catalogModelId")).toBe("t1");
    expect(feldwert("name")).toBe("Brustpresse");
    expect(feldwert("loadStep")).toBe("5");
    expect(feldwert("loadMax")).toBe("100");
    expect(screen.getByText("Werte vom Typ Brustpresse übernommen – bitte ans Gerät anpassen.")).toBeTruthy();
  });

  it("ein Typwechsel ueberschreibt Belastung und vorgeschlagenen Namen", async () => {
    render(<ModellVorlageFelder typen={[brust, platzhalter]} kategorie="kraft" />);
    await typWaehlen("Brustpresse");
    await typWaehlen("Beinpresse");
    expect(feldwert("name")).toBe("Beinpresse");
    // Review Focus 1: 1 kg gibt es im kg-Rad nicht, es rastet auf 1,25.
    expect(feldwert("loadStep")).toBe("1,25");
    expect(feldwert("loadMax")).toBe("");
  });

  it("ein selbst getippter Name bleibt beim Typwechsel", async () => {
    render(<ModellVorlageFelder typen={[brust, platzhalter]} kategorie="kraft" />);
    fireEvent.change(screen.getByLabelText("Name"), { target: { value: "Brustpresse links" } });
    await typWaehlen("Brustpresse");
    await typWaehlen("Beinpresse");
    expect(feldwert("name")).toBe("Brustpresse links");
  });

  it("in der Halle kommt die Kategorie vom Typ, samt Nebenbelastung", async () => {
    render(<ModellVorlageFelder typen={[brust, laufband]} />);
    await typWaehlen("Laufband");
    expect(feldwert("category")).toBe("cardio");
    expect(feldwert("loadUnit")).toBe("kmh");
    expect(feldwert("secondaryUnit")).toBe("pct");
    expect(feldwert("secondaryMax")).toBe("15");
  });

  it("meldet den gewaehlten Typ nach aussen", async () => {
    const onTyp = vi.fn();
    render(<ModellVorlageFelder typen={[brust]} onTyp={onTyp} />);
    await typWaehlen("Brustpresse");
    expect(onTyp).toHaveBeenLastCalledWith(brust);
  });
});
```

- [ ] **Step 2: Test laufen lassen, er muss scheitern**

Run: `pnpm --filter web exec vitest run app/portal/bausteine/ModellVorlageFelder.test.tsx`
Expected: FAIL, Modul fehlt.

- [ ] **Step 3: `GymtavoTypFeld` um `onChange` erweitern** – Prop-Typ `onChange?: (typId: string) => void;` und im `Auswahl`:

```tsx
        onChange={(neu) => {
          setWert(neu);
          onChange?.(neu);
        }}
```

  `typen` bleibt `Pick<CatalogType, "id" | "name" | "manufacturer">[]`, `TypVorlage` erfüllt das.

- [ ] **Step 4: `ModellVorlageFelder.tsx` schreiben**

```tsx
"use client";

import { useState } from "react";
import type { Category } from "@fitretro/domain/belastung";
import { Feld } from "../Form";
import { GymtavoTypFeld } from "./GymtavoTypFeld";
import { ModellBelastungRad } from "./ModellBelastungRad";
import { belastungStart, nameNachTypwahl, type TypVorlage } from "./typVorlage";
import styles from "../portal.module.css";

/**
 * Name, Hersteller, Gymtavo-Typ und Belastung beider Modellformulare
 * (Schreibtisch und Halle). Der Typ fuellt vor, was er weiss (Spec
 * 2026-10-10 ..., 5.2) -- der Trainer korrigiert nur Abweichungen.
 *
 * Das Rad bekommt die Typ-ID als `key`: nur ein Neuaufbau laedt seine
 * Startwerte neu (siehe Kopfkommentar ModellBelastungRad). Ohne Typ steht
 * es auf seinen eigenen Vorgaben wie bisher.
 */
export function ModellVorlageFelder({
  typen,
  gross = false,
  kategorie,
  onTyp,
}: {
  typen: TypVorlage[];
  gross?: boolean;
  kategorie?: Category;
  onTyp?: (typ: TypVorlage | null) => void;
}) {
  const [typ, setTyp] = useState<TypVorlage | null>(null);
  const [name, setName] = useState("");

  function typGewaehlt(typId: string) {
    const neu = typen.find((t) => t.id === typId) ?? null;
    setName((aktuell) => nameNachTypwahl(aktuell, typ, neu));
    setTyp(neu);
    onTyp?.(neu);
  }

  return (
    <>
      <div className={gross ? undefined : styles.grid}>
        <Feld
          gross={gross}
          name="name"
          label="Name"
          required
          placeholder="Latzug"
          value={name}
          onChange={(e) => setName(e.target.value)}
        />
        <Feld gross={gross} name="manufacturer" label="Hersteller" placeholder="Technogym" />
      </div>
      <GymtavoTypFeld gross={gross} typen={typen} start={null} onChange={typGewaehlt} />
      {typ ? (
        <p className={styles.hint} role="status">
          Werte vom Typ {typ.name} übernommen – bitte ans Gerät anpassen.
        </p>
      ) : null}
      <ModellBelastungRad
        key={typ?.id ?? "ohne-typ"}
        gross={gross}
        kategorie={kategorie}
        start={typ ? belastungStart(typ) : undefined}
      />
    </>
  );
}
```

  Der Hinweistext muss als **ein** Textknoten gefunden werden (`getByText` mit vollem Satz). Wenn React ihn in mehrere Knoten zerlegt und der Test daran scheitert, den Satz als Template-String rendern: ``{`Werte vom Typ ${typ.name} übernommen – bitte ans Gerät anpassen.`}``.

- [ ] **Step 5: Tests laufen lassen**

Run: `pnpm --filter web exec vitest run app/portal/bausteine/`
Expected: PASS (auch `ModellBelastungRad.test.tsx` unverändert grün)

- [ ] **Step 6: Commit**

```bash
git add apps/web/app/portal/bausteine/GymtavoTypFeld.tsx apps/web/app/portal/bausteine/ModellVorlageFelder.tsx apps/web/app/portal/bausteine/ModellVorlageFelder.test.tsx
git commit -m "feat(katalog): Modellformular uebernimmt Name und Belastung vom Gymtavo-Typ"
```

---

### Task 5: Schreibtisch-Assistent nutzt Vorlage und kopiert beim Anlegen

**Files:**
- Modify: `apps/web/app/portal/[studioId]/(schreibtisch)/geraete/ModellAnlegenFormular.tsx`
- Modify: `apps/web/app/portal/[studioId]/(schreibtisch)/geraete/neu/page.tsx:152-169`
- Modify: `apps/web/app/portal/actions.ts:138-166` (`modellAnlegen`)
- Modify: `e2e/helpers/gymtavo.ts`
- Modify: `e2e/gymtavo.spec.ts`

**Interfaces:**
- Consumes: `ModellVorlageFelder` (Task 4), `typVorlagen` (Task 3), `copyTypeDefaults` (Task 2).
- Produces: `gymtavoTyp(admin, name, uebungen?, optionen?)` mit
  ```ts
  type TypOptionen = {
    werte?: { category?: "kraft" | "cardio"; load_unit?: string; load_step?: number;
              load_min?: number; load_max?: number | null };
    einstellungen?: { key: string; label: string; kind: "number" | "enum";
                      allowed_values?: string[] }[];
    foto?: boolean;
  };
  ```

- [ ] **Step 1: E2E-Helfer erweitern** – `e2e/helpers/gymtavo.ts`: vierter Parameter `optionen: TypOptionen = {}`. Insert des Typs mit `{ studio_id: GYMTAVO, name: typName, load_step: 2.5, ...optionen.werte }`. Danach:

```ts
  if (optionen.einstellungen?.length) {
    const { error: einstellungFehler } = await admin.from("equipment_setting_definitions").insert(
      optionen.einstellungen.map((e, index) => ({
        equipment_model_id: typ.id, key: e.key, label: e.label, kind: e.kind,
        allowed_values: e.allowed_values ?? null, sort_order: index,
      })),
    );
    if (einstellungFehler) throw einstellungFehler;
  }
  if (optionen.foto) {
    // Ein echtes, kleines PNG -- uploadEquipmentPhoto prueft den Inhalt.
    const pfad = `${GYMTAVO}/catalog/photos/e2e-${crypto.randomUUID()}.png`;
    const png = Buffer.from(
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==",
      "base64",
    );
    const { error: uploadFehler } = await admin.storage
      .from("equipment-photos")
      .upload(pfad, png, { contentType: "image/png" });
    if (uploadFehler) throw uploadFehler;
    const { error: fotoFehler } = await admin
      .from("equipment_models").update({ photo_path: pfad }).eq("id", typ.id);
    if (fotoFehler) throw fotoFehler;
  }
```

- [ ] **Step 2: E2E-Test schreiben** – in `e2e/gymtavo.spec.ts` nach dem ersten Test:

```ts
test("Der Gymtavo-Typ fuellt Name und Belastung vor, Einstellungen und Foto kommen beim Anlegen mit", async ({ page }) => {
  const { admin, studioId } = await studioMitTrainer(page, "gymtavo-vorlage");
  const { typName } = await gymtavoTyp(admin, "Brustpresse", [], {
    werte: { load_step: 5, load_min: 0, load_max: 100 },
    einstellungen: [
      { key: "seat_height", label: "Sitzhöhe", kind: "number" },
      { key: "grip", label: "Griff", kind: "enum", allowed_values: ["neutral", "pronated"] },
    ],
    foto: true,
  });

  await page.goto(`/portal/${studioId}/geraete/neu?art=typ&kategorie=kraft`);
  await typWaehlen(page, typName);
  await expect(page.getByLabel("Name")).toHaveValue(typName);
  await expect(page.getByText(`Werte vom Typ ${typName} übernommen – bitte ans Gerät anpassen.`)).toBeVisible();
  await expect(
    page.getByRole("listbox", { name: "Schritt", exact: true }).getByRole("option", { name: "5", exact: true }),
  ).toHaveAttribute("aria-selected", "true");

  await page.getByRole("button", { name: "Weiter", exact: true }).click();
  await expect(page).toHaveURL(new RegExp(`/portal/${studioId}/geraete/[0-9a-f-]+/einstellungen`));
  await expect(page.getByText("Sitzhöhe")).toBeVisible();
  await expect(page.getByText("Griff")).toBeVisible();

  const { data } = await admin
    .from("equipment_models")
    .select("name, load_step, load_max, photo_path")
    .eq("studio_id", studioId)
    .single();
  expect(data).toMatchObject({ name: typName, load_step: 5, load_max: 100 });
  expect(data?.photo_path?.startsWith(`${studioId}/models/`)).toBe(true);
});
```

- [ ] **Step 3: Test laufen lassen, er muss scheitern**

Run: `pnpm test:e2e e2e/gymtavo.spec.ts -g "fuellt Name und Belastung vor"`
Expected: FAIL, das Namensfeld bleibt leer.

- [ ] **Step 4: Formular, Seite und Action umstellen**

  `ModellAnlegenFormular.tsx`: Prop `typen: TypVorlage[]`, Inhalt des `AktionsFormular` ersetzen durch

```tsx
      <ModellVorlageFelder typen={typen} kategorie={kategorie} />
```

  Imports von `Feld`, `GymtavoTypFeld`, `ModellBelastungRad`, `CatalogType`, `styles` entfernen, falls ungenutzt; Kopfkommentar um einen Satz ergänzen: „Name und Belastung fuellt der Gymtavo-Typ vor (ModellVorlageFelder).“

  `geraete/neu/page.tsx`, Zeilen 162-166:

```tsx
        <ModellAnlegenFormular
          typen={typVorlagen(
            await listCatalogTypes(await createServerSupabaseClient()),
            kategorie === "cardio" ? "cardio" : "kraft",
          )}
          action={modellAnlegen.bind(null, studioId)}
          kategorie={kategorie === "cardio" ? "cardio" : "kraft"}
        />
```

  mit `import { typVorlagen } from "../../../../bausteine/typVorlage";` (Pfad an die Tiefe der Datei anpassen, wie der bestehende Import von `ModellAnlegenFormular`).

  `actions.ts`, `modellAnlegen`: `copyTypeDefaults` aus `@fitretro/domain` importieren; nach `modelId = modell.id;` und **vor** dem `catch`-Block nichts ändern, sondern zwischen dem `try/catch` und `revalidatePath` einfügen:

```ts
  try {
    await copyTypeDefaults(client, modelId);
  } catch (fehler) {
    // Das Modell steht; was fehlt, zeigen die naechsten Schritte (Foto,
    // Einstellungen). Ein Abbruch hier liesse den Trainer vor einem
    // angelegten Modell stehen, das er fuer nicht angelegt haelt.
    console.error("Typvorlage nicht vollstaendig kopiert:", fehler);
  }
```

- [ ] **Step 5: Tests laufen lassen**

Run: `pnpm test:e2e e2e/gymtavo.spec.ts && pnpm --filter web test && pnpm typecheck`
Expected: PASS (auch der bestehende Test „Ein neues Modell bekommt seinen Gymtavo-Typ …“)

- [ ] **Step 6: Commit**

```bash
git add "apps/web/app/portal/[studioId]/(schreibtisch)/geraete/ModellAnlegenFormular.tsx" "apps/web/app/portal/[studioId]/(schreibtisch)/geraete/neu/page.tsx" apps/web/app/portal/actions.ts e2e/helpers/gymtavo.ts e2e/gymtavo.spec.ts
git commit -m "feat(katalog): Schreibtisch legt Modelle mit Werten, Einstellungen und Foto des Typs an"
```

---

### Task 6: Hallen-Assistent ohne Fotopflicht bei Typ mit Illustration

**Files:**
- Modify: `apps/web/app/portal/[studioId]/einrichten/modell/neu/ModellNeuFormular.tsx`
- Modify: `apps/web/app/portal/[studioId]/einrichten/modell/neu/page.tsx`
- Modify: `apps/web/app/portal/[studioId]/einrichten/actions.ts:71-127` (`modellAnlegen`)
- Modify: `e2e/einrichten.spec.ts`

**Interfaces:**
- Consumes: `ModellVorlageFelder` mit `onTyp` (Task 4), `typVorlagen` (Task 3), `copyTypeDefaults` (Task 2), `listCatalogTypes` (Task 1), `typAusFormular` (`gymtavoTyp.ts`).

- [ ] **Step 1: E2E-Tests schreiben** – in `e2e/einrichten.spec.ts` nach „Schritt 1 legt ein Modell mit Pflichtfoto an …“:

```ts
test("Schritt 1 kommt ohne eigenes Foto aus, wenn der Typ eine Zeichnung hat", async ({ page }) => {
  const { admin, studioId } = await studioMitTrainer(page, "einrichten-typfoto");
  const { typName } = await gymtavoTyp(admin, "Beinstrecker", [], {
    einstellungen: [{ key: "back_rest", label: "Lehne", kind: "number" }],
    foto: true,
  });

  await page.goto(`/portal/${studioId}/einrichten/modell/neu`);
  const weiter = page.getByRole("button", { name: "Weiter zu den Einstellungen" });
  await expect(weiter).toBeDisabled();
  await typWaehlen(page, typName);
  await expect(page.getByText(
    "Ohne eigenes Foto zeigt das Gerät die Gymtavo-Zeichnung. Ein echtes Foto hilft Mitgliedern, das Gerät zu erkennen.",
  )).toBeVisible();
  await expect(weiter).toBeEnabled();
  await weiter.click();

  await expect(page).toHaveURL(
    new RegExp(`/portal/${studioId}/einrichten/modell/[0-9a-f-]+/einstellungen$`),
    { timeout: 60_000 },
  );
  await expect(page.getByText("Foto · Steht")).toBeVisible();
  await expect(page.getByText("Lehne")).toBeVisible();
});

test("Schritt 1 verlangt ein Foto, wenn der Typ keine Zeichnung hat", async ({ page }) => {
  const { admin, studioId } = await studioMitTrainer(page, "einrichten-ohne-typfoto");
  const { typName } = await gymtavoTyp(admin, "Sonstiges");

  await page.goto(`/portal/${studioId}/einrichten/modell/neu`);
  await typWaehlen(page, typName);
  await expect(page.getByRole("button", { name: "Weiter zu den Einstellungen" })).toBeDisabled();
});
```

  Imports `gymtavoTyp`, `typWaehlen` aus `./helpers/gymtavo` sind schon da (Test „Schritt 1 …“ nutzt sie); sonst ergänzen.

- [ ] **Step 2: Tests laufen lassen, sie müssen scheitern**

Run: `pnpm test:e2e e2e/einrichten.spec.ts -g "Schritt 1"`
Expected: FAIL im ersten neuen Test, der Knopf bleibt gesperrt.

- [ ] **Step 3: Formular umstellen** – `ModellNeuFormular.tsx`:
  - Prop `typen: TypVorlage[]`.
  - State `const [typ, setTyp] = useState<TypVorlage | null>(null);` und `const fotoNoetig = !typ?.hatFoto;`.
  - `FotoFeld`-Hinweis:

```tsx
        hinweis={
          fotoNoetig
            ? "Das ganze Gerät ins Bild. Ein Foto je Modell, nicht je Gerät — zwei baugleiche Kabelzüge zeigen dasselbe Bild."
            : "Ohne eigenes Foto zeigt das Gerät die Gymtavo-Zeichnung. Ein echtes Foto hilft Mitgliedern, das Gerät zu erkennen."
        }
```

  - Die beiden `Feld` (Name, Hersteller), `GymtavoTypFeld` und `ModellBelastungRad gross` ersetzen durch

```tsx
      <ModellVorlageFelder gross typen={typen} onTyp={setTyp} />
```

  - Knopf: `disabled={(fotoNoetig && !hatFoto) || laeuft || dateiFehler !== null}`. Prüfen, dass `dateiFehler` heute `hatFoto` auf `false` setzt; die Bedingung `dateiFehler !== null` hält einen zu großen Upload auch dann zurück, wenn das Foto nicht nötig wäre.
  - Kopfkommentar: Satz „Ohne eigenes Foto geht es nur weiter, wenn der Gymtavo-Typ eine Zeichnung hat (Spec 2026-10-10 ..., 5.2); die kopiert copyTypeDefaults.“

  `modell/neu/page.tsx`: `typen={typVorlagen(typen)}` (Import aus `../../../../bausteine/typVorlage`); Notiz ersetzen durch

```tsx
        <p className={styles.notiz}>
          Ein Foto hilft, das Gerät in der Halle wiederzufinden. Ohne eigenes
          Foto zeigt das Gerät die Zeichnung seines Gymtavo-Typs, wenn es eine
          gibt. Beschreibungen trägst du am Schreibtisch nach, die
          Einstellungen kommen im nächsten Schritt.
        </p>
```

- [ ] **Step 4: Action umstellen** – `einrichten/actions.ts`, `modellAnlegen`; Imports um `copyTypeDefaults, listCatalogTypes` ergänzen:

```ts
export async function modellAnlegen(
  studioId: string,
  _prev: unknown,
  formData: FormData,
): Promise<Ergebnis<{ modelId: string }>> {
  const client = await createServerSupabaseClient();
  const datei = formData.get("photo");
  const eigenesFoto = datei instanceof File && datei.size > 0 ? datei : null;

  let modelId: string;
  try {
    const typ = typAusFormular(formData, await catalogTypeRequired(client, studioId));
    if (!typ.ok) return typ;
    // Ohne eigenes Foto nur, wenn der Typ eine Zeichnung hat -- sonst
    // stuende ein Geraet ohne jedes Bild in der Liste (Entscheidung 10).
    if (!eigenesFoto && !(await typHatFoto(client, typ.catalogModelId))) {
      return {
        ok: false,
        error:
          "Ohne Foto geht es nicht weiter — es ist der einzige Grund, warum jemand vor dem falschen Gerät merkt, dass er falsch steht.",
      };
    }
    const modell = await createEquipmentModel(client, {
      studioId,
      name: text(formData, "name"),
      manufacturer: optionalerText(formData, "manufacturer"),
      ...belastungAusFormular(formData),
      loadStep: zahl(formData, "loadStep") ?? Number.NaN,
      loadMin: zahl(formData, "loadMin") ?? 0,
      catalogModelId: typ.catalogModelId,
    });
    modelId = modell.id;
  } catch (fehler) {
    return fehlerAus(fehler, "Das Modell liess sich nicht anlegen.");
  }

  if (eigenesFoto) {
    try {
      // Das Foto laeuft bewusst durch den Server: nur hier lassen sich die
      // Aufnahmedaten entfernen, bevor die Datei im Bucket landet.
      await uploadEquipmentPhoto(client, {
        equipmentModelId: modelId,
        bytes: new Uint8Array(await eigenesFoto.arrayBuffer()),
      });
    } catch (fehler) {
      const antwort = fehlerAus(fehler, "Das Foto liess sich nicht speichern.");
      // Das Modell steht trotzdem -- der Gang geht weiter, Schritt 2 fragt das
      // Foto nach. Ein Rollback waere hier der schlechtere Zustand.
      revalidatePath(`/portal/${studioId}/einrichten`);
      return antwort;
    }
  }

  try {
    // Nach dem eigenen Foto: copyTypeDefaults laesst ein vorhandenes Foto
    // stehen und nimmt die Zeichnung nur, wenn keins da ist.
    await copyTypeDefaults(client, modelId);
  } catch (fehler) {
    // Was fehlt, fragt Schritt 2 nach (Foto) oder zeigt es (Einstellungen).
    console.error("Typvorlage nicht vollstaendig kopiert:", fehler);
  }

  revalidatePath(`/portal/${studioId}/einrichten`);
  return { ok: true, modelId };
}

async function typHatFoto(
  client: Awaited<ReturnType<typeof createServerSupabaseClient>>,
  typId: string | undefined,
): Promise<boolean> {
  if (!typId) return false;
  const typen = await listCatalogTypes(client);
  return typen.find((typ) => typ.id === typId)?.photoPath != null;
}
```

  Den bestehenden Kopfkommentar der Funktion anpassen: „Das Foto ist Pflicht, ausser der Gymtavo-Typ hat eine Zeichnung (Spec 2026-10-10 ..., 5.2).“ Der Rest bleibt.

- [ ] **Step 5: Tests laufen lassen**

Run: `pnpm test:e2e e2e/einrichten.spec.ts && pnpm --filter web test && pnpm typecheck`
Expected: PASS (auch „Schritt 1 legt ein Modell mit Pflichtfoto an …“ – sein Typ hat kein Foto, der Knopf bleibt dort ohne Datei gesperrt)

- [ ] **Step 6: Commit**

```bash
git add "apps/web/app/portal/[studioId]/einrichten/modell/neu/ModellNeuFormular.tsx" "apps/web/app/portal/[studioId]/einrichten/modell/neu/page.tsx" "apps/web/app/portal/[studioId]/einrichten/actions.ts" e2e/einrichten.spec.ts
git commit -m "feat(katalog): Halle legt Modelle ohne eigenes Foto an, wenn der Typ eine Zeichnung hat"
```

---

### Task 7: Abschluss – voller Testsatz und Ergebnis

**Files:**
- Modify: `docs/superpowers/plans/2026-10-10-gymtavo-geraeteeinrichtung-etappe-a.md` (Abschnitt „Ergebnis“ anhängen)

- [ ] **Step 1: Voller Testsatz**

Run: `pnpm typecheck && pnpm test && pnpm test:integration && pnpm test:e2e`
Expected: alles PASS. Schlägt ein Test fehl, der nichts mit dieser Etappe zu tun hat, zweimal laufen lassen und im Ergebnis mit Ausgabe festhalten (bekannt flakig, siehe Memory „Lokale Testumgebung: Fallen“), nicht still übergehen.

- [ ] **Step 2: Sichtprobe lokal** – Dev-Server, Studio mit Trainer, lokal importierter Katalog (`pnpm catalog:import` gegen `127.0.0.1`, falls die lokale DB ihn noch nicht hat): Schreibtisch „Gerät hinzufügen → Kraft → Brustpresse“ und Halle „Neues Modell → Beinstrecker ohne Foto“. Prüfen: Name, Rad (1,25 kg bei Platzhaltertypen), Hinweis, Einstellungen im nächsten Schritt, Zeichnung als Foto.

- [ ] **Step 3: Ergebnis-Abschnitt anhängen** – am Ende dieses Plans:

```markdown
## Ergebnis

- Umgesetzt: Tasks 1–6, Commits <Hashes>.
- Abweichungen vom Plan: <je Punkt ein Satz mit Grund, oder „keine“>.
- Tests: typecheck, test, test:integration, test:e2e – <Zahlen>, <bekannte Flakes mit Ausgabe>.
- Sichtprobe: <was geprüft, was aufgefallen>.
- Offen für Etappe B: Plan schreiben (Spec Abschnitt 6).
```

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/plans/2026-10-10-gymtavo-geraeteeinrichtung-etappe-a.md
git commit -m "docs(plan): Etappe A der Geraeteeinrichtung umgesetzt"
```

Nicht pushen. Tim entscheidet über Push, PR und Merge.
