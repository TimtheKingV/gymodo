# Gymtavo-Katalog Etappe 5: Portal — Umsetzungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Studios ordnen im Trainerportal jedes Gerätemodell einem Gymtavo-Gerätetyp zu, sehen dessen Gymtavo-Übungen am Modell, ergänzen eigene Videos und hängen Gymtavo-Übungen anderer Typen an. Das Gymtavo-Studio selbst erscheint im Portal nur als lesbarer Katalog.

**Architecture:**
- **Domain (`packages/domain/src/catalog.ts`):** Zuordnung beim Anlegen und Ändern, Gymtavo-Übungen in `attachExerciseToModel`, drei neue Felder in `getStudioCatalog`, zwei neue Funktionen `listCatalogTypes` und `catalogTypeRequired`.
- **Portal:** Die Pflichtregel steht in den Server-Actions (reine Funktion `typAusFormular`). Ableitungen ohne Datenbank (`gymtavo.ts`, `offen.ts`) bekommen Unit-Tests vor den Seiten, die sie benutzen.
- **Keine Migration.** 0047 trägt Spalte, Trigger, Verknüpfungs-Policy und Videoablage bereits.

**Tech Stack:** TypeScript, Next.js (App Router, Server Actions), Supabase (RLS), Zod, Vitest, Testing Library, Playwright.

**Spec:** `docs/superpowers/specs/2026-10-06-gymtavo-katalog-offener-zugang-design.md`, Abschnitt 10 und Nachtrag 10.1 (dazu 5.3, 8.1)

## Global Constraints

- **Gymtavo-Studio:** `00000000-0000-4000-8000-000000000001`, `studios.is_catalog = true`. Jeder Angemeldete liest es, schreiben darf nur sein Personal (`is_studio_staff`).
- **Pflicht, sobald es Typen gibt:** Hat der Katalog mindestens einen Gerätetyp, verlangt das Portal den Typ beim Anlegen und beim Speichern der Stammdaten eines Studio-Modells. Ist er leer, entfallen Feld und Hinweis. Im Gymtavo-Studio selbst gilt die Regel nie.
- **Die Regel steht nicht in `createEquipmentModel`.** Das lokale Supabase ist geteilt; eine katalogabhängige Domain-Regel bräche fremde Integrationstests.
- **Geteiltes lokales Supabase, nie zurücksetzen.** Tests legen eigene Daten mit eindeutigen Namen an (`crypto.randomUUID()`), prüfen auf Enthaltensein und nie auf Gleichheit ganzer Listen. Andere Tests legen ebenfalls Gymtavo-Typen an.
- **Texte:** Nutzertexte im Portal mit Umlauten. Kommentare in TS/TSX in ASCII (ae/oe/ue), begründen statt beschreiben. Domain-Fehlermeldungen in ASCII wie die bestehenden („Geraetemodell“).
- **Eine Akzentfläche je Bildschirm.** Auf dem Reiter Übungen bleibt „Übung hinzufügen“ die einzige; „Gymtavo-Übung anhängen“ ist Nebenaktion (`secondary`).
- **Commits:** einer je Task, deutsch mit ae/oe/ue, Form `feat(portal): …` / `feat(domain): …` / `test(e2e): …`, Trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Nach jedem Commit `git log -1 --format=%B` prüfen.
- **Nicht pushen**, bis Tim es sagt.
- **Befehle** (aus dem Worktree-Wurzelverzeichnis):
  - Domain-Unit: `pnpm --filter @fitretro/domain test`
  - Portal-Unit: `pnpm --filter @fitretro/web exec vitest run <pfad>`
  - Integration: `pnpm test:integration tests/integration/<datei>`
  - E2E: `E2E_PORT=3017 pnpm test:e2e e2e/<datei>`; vorher prüfen, dass auf 3017 kein fremder Server läuft (`lsof -i :3017`).
  - Typen: `pnpm typecheck`

## Entscheidungen, die dieser Plan trifft

Diese Punkte stehen so nicht in der Spec. Tim prüft sie vor der Umsetzung.

1. **Kein „Video entfernen“.** Das Portal kennt heute für keine Übung ein Löschen des Videos, nur Ersetzen. Gymtavo-Übungen bekommen dasselbe: Ergänzen und Ersetzen. Der Nachtrag 10.1 wird entsprechend korrigiert (Task 1).
2. **Pflicht auch beim Bearbeiten.** Wer die Stammdaten eines alten, nicht zugeordneten Modells speichert, muss den Typ wählen. So verschwinden Altbestände mit der ersten Bearbeitung.
3. **`catalogTypeRequired(client, studioId)`** statt eines nackten „hat der Katalog Typen“: Die Funktion liefert `false` im Gymtavo-Studio selbst, sonst ob es Typen gibt.
4. **Reihenfolge-Dialog nur für eigene Übungen.** Gymtavo-Übungen kommen in der App nach den eigenen (Spec 8.1); eine angehängte oder mit eigenem Video versehene Gymtavo-Übung behält ihre Verknüpfung am Ende.
5. **„Keine Übung“ zählt die Typ-Übungen mit.** Ein Modell ohne eigene Übung, dessen Typ Übungen hat, ist am Gerät benutzbar. „Übungen ohne Einweisungsvideo“ zählt nur eigene Übungen, weil Gymtavo-Übungen das Katalogvideo zeigen.
6. **Gymtavo-Studio:** Überblick leitet auf `geraete`, Leute, Kurse, Tags, Einrichten, `geraete/neu` und `instanzen` liefern `notFound`. Die Rail zeigt „Gerätetypen“ und „Einstellungen“, die Einstellungen ohne Beitrittscode. Ein Trainer eines anderen Studios kann `/portal/<gymtavo-id>/geraete` lesen (RLS erlaubt es, der Inhalt ist ohnehin öffentlich); Schreiben scheitert an `requireStudioStaff`.

## Review Focus

- **Katalog wird zwischen Seitenaufruf und Absenden befüllt:** Das Formular hatte kein Typfeld, `catalogTypeRequired` ist jetzt `true`. Erwartet: verständliche Meldung, kein Absturz. Test in Task 4 (`typAusFormular` ohne Feld, Pflicht).
- **Typ-Übung ist zugleich angehängt** (Verknüpfung am Studio-Modell, weil ein eigenes Video ergänzt wurde): erscheint genau einmal, als „vom Typ“, mit eigenem Video. Test in Task 6.
- **Gymtavo-Übung hängt an mehreren Typen:** erscheint in „anhängen“ nur einmal. Test in Task 6.
- **Bestehende E2E-Tests bei gefülltem Katalog:** In der CI laufen die Integrationstests vor E2E auf derselben Datenbank, der Katalog ist dann gefüllt. Modelle per UI anlegen und „N Punkte offen“ müssen trotzdem stimmen. Task 9.
- **Typwechsel:** Nach dem Wechsel stehen die Übungen des neuen Typs da; mit eigenem Video versehene des alten Typs erscheinen als „angehängt“ und lassen sich lösen. Test in Task 6.

---

### Task 1: Spec-Nachtrag korrigieren

**Files:**
- Modify: `docs/superpowers/specs/2026-10-06-gymtavo-katalog-offener-zugang-design.md` (Abschnitt 10.1)

- [ ] **Step 1: Nachtrag anpassen**

Im Abschnitt „Pflicht, sobald es Typen gibt“ den ersten Punkt ersetzen durch:

```markdown
- Hat der Katalog mindestens einen Gerätetyp, verlangt das Portal den Gymtavo-Typ beim Anlegen eines Modells und beim Speichern seiner Stammdaten; eine Zuordnung lässt sich ändern, aber nicht entfernen. Ist der Katalog leer, entfallen Feld und Hinweis, und nichts blockiert. Im Gymtavo-Studio selbst gilt die Regel nicht (`catalogTypeRequired`).
```

Unter **Domain** den Punkt zu `listCatalogTypes` ergänzen um:

```markdown
- Neu: `catalogTypeRequired(client, studioId)` – `false` im Gymtavo-Studio, sonst ob der Katalog Typen hat. Die Server-Actions fragen damit die Pflicht ab.
```

Unter **Portal**, Reiter Übungen, Teil 1: „mit „Eigenes Video ergänzen“, Ersetzen und Entfernen“ ersetzen durch „mit „Eigenes Video ergänzen“ und Ersetzen (Löschen eines Videos kennt das Portal auch für eigene Übungen nicht)“. Teil 2 ergänzen: „Der Reihenfolge-Dialog ordnet nur eigene Übungen.“

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/specs/2026-10-06-gymtavo-katalog-offener-zugang-design.md docs/superpowers/plans/2026-10-10-gymtavo-katalog-etappe5-portal.md
git commit -m "docs(plan): Etappe 5 Portal -- Umsetzungsplan, Nachtrag 10.1 praezisiert

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Domain — Zuordnung am Modell und neue Felder im Studio-Katalog

**Files:**
- Modify: `packages/domain/src/catalog.ts` (`equipmentModelInputSchema` ~86, `createEquipmentModel` ~117, `equipmentModelPatchSchema` ~150, `updateEquipmentModel` ~163, Typen `CatalogExercise`/`CatalogModel`/`StudioCatalog` ~744–815, `getStudioCatalog` ~824)
- Create: `tests/integration/domain-gymtavo-portal.test.ts`

**Interfaces:**
- Produces:
  - `EquipmentModelInput.catalogModelId?: string | null`, Patch ebenso.
  - Trigger-Fehler `gymtavo_zuordnung_ungueltig` → `DomainError("validation_failed", "Diesen Gymtavo-Geraetetyp gibt es nicht.")`.
  - `StudioCatalog.isCatalog: boolean`, `CatalogModel.catalogModelId: string | null`, `CatalogExercise.fromCatalog: boolean`.

- [ ] **Step 1: Failing test schreiben**

`tests/integration/domain-gymtavo-portal.test.ts`:

```ts
import { beforeAll, describe, expect, it } from "vitest";
import {
  DomainError,
  createEquipmentModel,
  getStudioCatalog,
  updateEquipmentModel,
} from "@fitretro/domain";
import {
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";

// Spec 2026-10-06-gymtavo-katalog-offener-zugang-design.md, Nachtrag 10.1:
// Studio-Modelle zeigen auf einen Gymtavo-Typ, Gymtavo-Uebungen haengen per
// Verweis am Studio-Modell. Andere Testdateien legen ebenfalls Gymtavo-Typen
// an -- geprueft wird auf Enthaltensein, nie auf Gleichheit.
const GYMTAVO = "00000000-0000-4000-8000-000000000001";
const kennung = crypto.randomUUID().slice(0, 8);

let studioA: string;
let studioB: string;
let trainerA: string;
let typ1: string;
let typ2: string;
let fremdesModell: string;
let katalogUebung1: string;
let katalogUebung2: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioError } = await admin
    .from("studios")
    .insert([{ name: `Portal-Gymtavo A ${kennung}` }, { name: `Portal-Gymtavo B ${kennung}` }])
    .select("id");
  if (studioError) throw studioError;
  studioA = studios[0]!.id;
  studioB = studios[1]!.id;

  trainerA = uniqueEmail("gymtavo-portal-trainer");
  const { error: rolleError } = await admin
    .from("studio_memberships")
    .insert({ studio_id: studioA, user_id: await createTestUser(trainerA), role: "trainer" });
  if (rolleError) throw rolleError;

  const { data: typen, error: typError } = await admin
    .from("equipment_models")
    .insert([
      { studio_id: GYMTAVO, name: `AA Langhantel ${kennung}`, load_step: 2.5 },
      { studio_id: GYMTAVO, name: `AB Kabelzug ${kennung}`, load_step: 2.5 },
      { studio_id: studioB, name: `Fremdes Modell ${kennung}`, load_step: 2.5 },
    ])
    .select("id");
  if (typError) throw typError;
  typ1 = typen[0]!.id;
  typ2 = typen[1]!.id;
  fremdesModell = typen[2]!.id;

  const { data: uebungen, error: uebungError } = await admin
    .from("exercises")
    .insert([
      { studio_id: GYMTAVO, name: `Bankdruecken ${kennung}`, target_min: 8, target_max: 12 },
      { studio_id: GYMTAVO, name: `Face Pull ${kennung}`, target_min: 12, target_max: 15 },
    ])
    .select("id");
  if (uebungError) throw uebungError;
  katalogUebung1 = uebungen[0]!.id;
  katalogUebung2 = uebungen[1]!.id;

  const { error: linkError } = await admin.from("equipment_model_exercises").insert([
    { equipment_model_id: typ1, exercise_id: katalogUebung1, sort_order: 1 },
    { equipment_model_id: typ2, exercise_id: katalogUebung2, sort_order: 1 },
  ]);
  if (linkError) throw linkError;
});

describe("Zuordnung zum Gymtavo-Typ", () => {
  it("positiv: ein Modell wird mit Typ angelegt und der Katalog nennt ihn", async () => {
    const client = await userClient(trainerA);
    const { id } = await createEquipmentModel(client, {
      studioId: studioA,
      name: `Hantelbank ${kennung}`,
      loadStep: 2.5,
      catalogModelId: typ1,
    });

    const katalog = await getStudioCatalog(client, studioA);
    expect(katalog.isCatalog).toBe(false);
    expect(katalog.models.find((m) => m.id === id)?.catalogModelId).toBe(typ1);
  });

  it("positiv: ohne Typ angelegt, nachtraeglich zugeordnet und gewechselt", async () => {
    const client = await userClient(trainerA);
    const { id } = await createEquipmentModel(client, {
      studioId: studioA,
      name: `Altbestand ${kennung}`,
      loadStep: 2.5,
    });
    let katalog = await getStudioCatalog(client, studioA);
    expect(katalog.models.find((m) => m.id === id)?.catalogModelId).toBeNull();

    await updateEquipmentModel(client, id, { catalogModelId: typ1 });
    await updateEquipmentModel(client, id, { catalogModelId: typ2 });
    katalog = await getStudioCatalog(client, studioA);
    expect(katalog.models.find((m) => m.id === id)?.catalogModelId).toBe(typ2);
  });

  it("negativ: ein Modell eines anderen Studios ist kein Gymtavo-Typ", async () => {
    const client = await userClient(trainerA);
    await expect(
      createEquipmentModel(client, {
        studioId: studioA,
        name: `Falsch zugeordnet ${kennung}`,
        loadStep: 2.5,
        catalogModelId: fremdesModell,
      }),
    ).rejects.toMatchObject({ code: "validation_failed" });
  });

  it("negativ: eine erfundene id ergibt dieselbe Antwort", async () => {
    const client = await userClient(trainerA);
    const { id } = await createEquipmentModel(client, {
      studioId: studioA,
      name: `Erfunden ${kennung}`,
      loadStep: 2.5,
    });
    const fehler = await updateEquipmentModel(client, id, {
      catalogModelId: crypto.randomUUID(),
    }).catch((e: unknown) => e);
    expect(fehler).toBeInstanceOf(DomainError);
    expect((fehler as DomainError).code).toBe("validation_failed");
  });

  it("das Gymtavo-Studio liest jeder Angemeldete als Katalog", async () => {
    const client = await userClient(trainerA);
    const katalog = await getStudioCatalog(client, GYMTAVO);
    expect(katalog.isCatalog).toBe(true);
    expect(katalog.models.map((m) => m.id)).toEqual(expect.arrayContaining([typ1, typ2]));
  });
});
```

- [ ] **Step 2: Test laufen lassen, er muss scheitern**

Run: `pnpm test:integration tests/integration/domain-gymtavo-portal.test.ts`
Expected: FAIL (`isCatalog` undefined, `catalogModelId` undefined; der Fremd-Typ-Fall liefert `internal` statt `validation_failed`).

- [ ] **Step 3: Domain umsetzen**

In `catalog.ts`:

1. `equipmentModelInputSchema`: Feld `catalogModelId: uuid.nullish(),` nach `loadMax` ergänzen. `equipmentModelPatchSchema`: ebenso `catalogModelId: uuid.nullish(),`. (`uuid` ist in der Datei schon als Zod-Schema definiert und wird für `studioId` benutzt.)
2. Neue Hilfsfunktion oberhalb von `createEquipmentModel`:

```ts
/**
 * Der Trigger aus 0047 prueft die Zuordnung (Ziel im Gymtavo-Studio, Quelle
 * nicht). Sein Fehler kommt als Postgres-Exception mit festem Text; ohne
 * Uebersetzung landete er als "internal" beim Trainer, obwohl er nur einen
 * falschen Typ gewaehlt hat.
 */
function zuordnungsFehler(error: { message?: string } | null): DomainError | null {
  if (error?.message?.includes("gymtavo_zuordnung_ungueltig")) {
    return new DomainError("validation_failed", "Diesen Gymtavo-Geraetetyp gibt es nicht.");
  }
  return null;
}
```

3. `createEquipmentModel`: im Insert `catalog_model_id: werte.catalogModelId ?? null,` ergänzen. Fehlerzweig:

```ts
  if (error || !data) {
    throw zuordnungsFehler(error) ??
      new DomainError("internal", error?.message ?? "Modell nicht angelegt.");
  }
```

4. `updateEquipmentModel`: `if (werte.catalogModelId !== undefined) zeile.catalog_model_id = werte.catalogModelId;` ergänzen; Fehlerzweig `if (error) throw zuordnungsFehler(error) ?? new DomainError("internal", error.message);`
5. Typen: `CatalogExercise` bekommt `/** Gymtavo-Uebung per Verweis (Spec E2), nicht eigene. */ fromCatalog: boolean;`, `CatalogModel` bekommt `catalogModelId: string | null;`, `StudioCatalog` bekommt `/** Das Gymtavo-Studio selbst (Spec 5.1). */ isCatalog: boolean;`.
6. `getStudioCatalog`:
   - Studio-Abfrage: `.select("id, name, timezone, is_catalog")`, Typ um `is_catalog: boolean` erweitern; Rückgabe `isCatalog: studio.is_catalog`.
   - Modell-Select: `catalog_model_id` nach `secondary_max` ergänzen; in `exercises (…)` zusätzlich `studio_id`. `ModelRow` um `catalog_model_id: string | null` und `exercises.studio_id: string` erweitern.
   - Mapping: `catalogModelId: row.catalog_model_id,` und je Übung

```ts
          // Die Policy aus 0047 laesst nur eigene und Gymtavo-Uebungen zu --
          // was nicht aus diesem Studio stammt, ist also eine Gymtavo-Uebung.
          fromCatalog: link.exercises.studio_id !== studioId,
```

- [ ] **Step 4: Test laufen lassen, er muss bestehen**

Run: `pnpm test:integration tests/integration/domain-gymtavo-portal.test.ts tests/integration/domain-catalog.test.ts`
Expected: PASS. Danach `pnpm typecheck` – die Portal-Stellen, die `StudioCatalog`-Objekte von Hand bauen (Unit-Tests mit `as unknown as`), bleiben grün; scheitert eine, das fehlende Feld dort ergänzen.

- [ ] **Step 5: Commit**

```bash
git add packages/domain/src/catalog.ts tests/integration/domain-gymtavo-portal.test.ts
git commit -m "feat(domain): Studio-Modell dem Gymtavo-Typ zuordnen, Katalog nennt Zuordnung und Herkunft

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Domain — Gymtavo-Übungen anhängen, Typliste, Pflichtabfrage

**Files:**
- Modify: `packages/domain/src/catalog.ts` (`attachExerciseToModel` ~420, neue Funktionen am Dateiende), `packages/domain/src/index.ts` (Exporte aus `./catalog.js`)
- Modify: `tests/integration/domain-gymtavo-portal.test.ts`

**Interfaces:**
- Consumes: `CatalogExercise.fromCatalog` (Task 2).
- Produces:

```ts
export type CatalogTypeExercise = {
  exerciseId: string;
  name: string;
  description: string | null;
  volumeKind: VolumeKind;
  targetMin: number;
  targetMax: number;
  sortOrder: number;
  videoStoragePath: string | null;
  videoDurationS: number | null;
};
export type CatalogType = {
  id: string;
  name: string;
  manufacturer: string | null;
  category: Category;
  exercises: CatalogTypeExercise[];
};
export async function listCatalogTypes(client: SupabaseClient): Promise<CatalogType[]>;
export async function catalogTypeRequired(client: SupabaseClient, studioId: string): Promise<boolean>;
```

- [ ] **Step 1: Failing tests ergänzen**

Import in der Testdatei erweitern um `attachExerciseToModel, catalogTypeRequired, createExercise, listCatalogTypes, prepareInstructionVideoUpload` (letzteres wird schon aus `@fitretro/domain` exportiert; sonst Import-Pfad aus `media-store.ts` im Index nachsehen). Neue Blöcke:

```ts
describe("Gymtavo-Uebung am Studio-Modell", () => {
  it("positiv: eine Gymtavo-Uebung haengt am Studio-Modell und ist als Verweis markiert", async () => {
    const client = await userClient(trainerA);
    const { id } = await createEquipmentModel(client, {
      studioId: studioA,
      name: `Anhaengen ${kennung}`,
      loadStep: 2.5,
      catalogModelId: typ1,
    });
    const eigene = await createExercise(client, {
      studioId: studioA,
      name: `Hausuebung ${kennung}`,
      targetMin: 8,
      targetMax: 12,
    });
    await attachExerciseToModel(client, { equipmentModelId: id, exerciseId: eigene.id });
    await attachExerciseToModel(client, { equipmentModelId: id, exerciseId: katalogUebung2 });

    const katalog = await getStudioCatalog(client, studioA);
    const uebungen = katalog.models.find((m) => m.id === id)!.exercises;
    expect(uebungen.find((u) => u.exerciseId === eigene.id)?.fromCatalog).toBe(false);
    expect(uebungen.find((u) => u.exerciseId === katalogUebung2)?.fromCatalog).toBe(true);
  });

  it("negativ: die Uebung eines dritten Studios bleibt unsichtbar", async () => {
    const admin = serviceClient();
    const { data: fremd, error } = await admin
      .from("exercises")
      .insert({ studio_id: studioB, name: `Fremduebung ${kennung}`, target_min: 8, target_max: 12 })
      .select("id")
      .single();
    if (error) throw error;

    const client = await userClient(trainerA);
    const { id } = await createEquipmentModel(client, {
      studioId: studioA,
      name: `Fremd anhaengen ${kennung}`,
      loadStep: 2.5,
    });
    await expect(
      attachExerciseToModel(client, { equipmentModelId: id, exerciseId: fremd.id }),
    ).rejects.toMatchObject({ code: "not_found" });
  });

  it("das eigene Video zu einer Gymtavo-Uebung liegt im Ordner des Studios", async () => {
    const client = await userClient(trainerA);
    const { id } = await createEquipmentModel(client, {
      studioId: studioA,
      name: `Video ${kennung}`,
      loadStep: 2.5,
      catalogModelId: typ1,
    });
    const link = await attachExerciseToModel(client, {
      equipmentModelId: id,
      exerciseId: katalogUebung1,
    });
    const ziel = await prepareInstructionVideoUpload(client, {
      equipmentModelExerciseId: link.id,
      sizeBytes: 1024,
    });
    expect(ziel.storagePath.startsWith(`${studioA}/exercises/${link.id}/`)).toBe(true);
  });
});

describe("listCatalogTypes", () => {
  it("liefert die Gymtavo-Typen mit ihren Uebungen und Katalogvideo, nach Namen", async () => {
    const admin = serviceClient();
    const { data: link } = await admin
      .from("equipment_model_exercises")
      .select("id")
      .eq("equipment_model_id", typ1)
      .eq("exercise_id", katalogUebung1)
      .single();
    const { error } = await admin.from("instruction_assets").insert({
      equipment_model_exercise_id: link!.id,
      kind: "video",
      storage_path: `${GYMTAVO}/exercises/${link!.id}/${kennung}.mp4`,
      duration_s: 20,
    });
    if (error) throw error;

    const client = await userClient(trainerA);
    const typen = await listCatalogTypes(client);
    const eigene = typen.filter((t) => t.id === typ1 || t.id === typ2);
    expect(eigene.map((t) => t.id)).toEqual([typ1, typ2]);
    expect(eigene[0]!.exercises).toEqual([
      expect.objectContaining({
        exerciseId: katalogUebung1,
        name: `Bankdruecken ${kennung}`,
        videoStoragePath: `${GYMTAVO}/exercises/${link!.id}/${kennung}.mp4`,
        videoDurationS: 20,
      }),
    ]);
    expect(typen.some((t) => t.id === fremdesModell)).toBe(false);
  });
});

describe("catalogTypeRequired", () => {
  it("ist im Studio wahr, sobald es Typen gibt -- im Gymtavo-Studio nie", async () => {
    const client = await userClient(trainerA);
    expect(await catalogTypeRequired(client, studioA)).toBe(true);
    expect(await catalogTypeRequired(client, GYMTAVO)).toBe(false);
  });
});
```

- [ ] **Step 2: Test laufen lassen, er muss scheitern**

Run: `pnpm test:integration tests/integration/domain-gymtavo-portal.test.ts`
Expected: FAIL (`listCatalogTypes is not a function`; Anhängen der Gymtavo-Übung liefert `not_found`).

- [ ] **Step 3: Umsetzen**

`attachExerciseToModel`: Doc-Kommentar ersetzen und Prüfung erweitern:

```ts
/**
 * Uebung an ein Modell haengen. Erlaubt sind eigene Uebungen und
 * Gymtavo-Uebungen (Spec 5.3, Verweis statt Kopie). Die Uebung eines
 * dritten Studios ist fuer den Trainer gar nicht sichtbar und faellt als
 * not_found heraus -- dieselbe Antwort wie fuer eine erfundene id.
 */
```

```ts
  if (
    !uebung ||
    (uebung.studio_id !== studioId && !(await istKatalogStudio(client, uebung.studio_id)))
  ) {
    throw new DomainError("not_found", "Diese Uebung gibt es nicht.");
  }
```

Neue Hilfsfunktion (neben `studioOfModel`):

```ts
/** studios_select laesst das Gymtavo-Studio fuer jeden Angemeldeten durch. */
async function istKatalogStudio(client: SupabaseClient, studioId: string): Promise<boolean> {
  const { data } = await client
    .from("studios")
    .select("is_catalog")
    .eq("id", studioId)
    .maybeSingle<{ is_catalog: boolean }>();
  return data?.is_catalog === true;
}

async function katalogStudioId(client: SupabaseClient): Promise<string | null> {
  const { data } = await client
    .from("studios")
    .select("id")
    .eq("is_catalog", true)
    .maybeSingle<{ id: string }>();
  return data?.id ?? null;
}
```

Am Dateiende die Typen `CatalogTypeExercise`, `CatalogType` (siehe Interfaces) und:

```ts
/**
 * Alle Gymtavo-Geraetetypen mit ihren Uebungen -- fuer die Typauswahl am
 * Modell und den Reiter Uebungen. Eigene Funktion statt eines Felds in
 * getStudioCatalog: der Studio-Katalog haengt an jeder Portalseite, die
 * Typliste brauchen nur drei.
 */
export async function listCatalogTypes(client: SupabaseClient): Promise<CatalogType[]> {
  await requireUserId(client);
  const katalogId = await katalogStudioId(client);
  if (!katalogId) return [];

  const { data, error } = await client
    .from("equipment_models")
    .select(
      `id, name, manufacturer, category,
       equipment_model_exercises (sort_order, exercises (id, name, description, volume_kind, target_min, target_max), instruction_assets (storage_path, duration_s))`,
    )
    .eq("studio_id", katalogId)
    .order("name", { ascending: true });
  if (error) throw new DomainError("internal", error.message);

  type Row = {
    id: string;
    name: string;
    manufacturer: string | null;
    category: Category;
    equipment_model_exercises: Array<{
      sort_order: number;
      exercises: {
        id: string;
        name: string;
        description: string | null;
        volume_kind: VolumeKind;
        target_min: number;
        target_max: number;
      };
      instruction_assets: Array<{ storage_path: string; duration_s: number }>;
    }>;
  };

  return ((data ?? []) as unknown as Row[]).map((row) => ({
    id: row.id,
    name: row.name,
    manufacturer: row.manufacturer,
    category: row.category,
    exercises: [...row.equipment_model_exercises]
      .sort((a, b) => a.sort_order - b.sort_order)
      .map((link) => {
        const video = link.instruction_assets[0] ?? null;
        return {
          exerciseId: link.exercises.id,
          name: link.exercises.name,
          description: link.exercises.description,
          volumeKind: link.exercises.volume_kind,
          targetMin: link.exercises.target_min,
          targetMax: link.exercises.target_max,
          sortOrder: link.sort_order,
          videoStoragePath: video?.storage_path ?? null,
          videoDurationS: video?.duration_s ?? null,
        };
      }),
  }));
}

/**
 * Ob ein Modell dieses Studios einen Gymtavo-Typ braucht (Nachtrag 10.1).
 * Steht hier und nicht in createEquipmentModel: eine Regel, die vom Inhalt
 * des Katalogs abhaengt, braeche im geteilten lokalen Supabase jeden Test,
 * der Modelle ohne Typ anlegt, sobald ein anderer Test Typen anlegt.
 */
export async function catalogTypeRequired(
  client: SupabaseClient,
  studioId: string,
): Promise<boolean> {
  await requireUserId(client);
  const katalogId = await katalogStudioId(client);
  if (!katalogId || katalogId === studioId) return false;

  const { count, error } = await client
    .from("equipment_models")
    .select("id", { count: "exact", head: true })
    .eq("studio_id", katalogId);
  if (error) throw new DomainError("internal", error.message);
  return (count ?? 0) > 0;
}
```

In `packages/domain/src/index.ts` beim Export-Block aus `./catalog.js` ergänzen: Werte `listCatalogTypes`, `catalogTypeRequired`, Typen `CatalogType`, `CatalogTypeExercise` (Muster der vorhandenen `export { … } from "./catalog.js"` und `export type { … } from "./catalog.js"` folgen).

- [ ] **Step 4: Tests laufen lassen**

Run: `pnpm test:integration tests/integration/domain-gymtavo-portal.test.ts tests/integration/domain-catalog.test.ts tests/integration/rls-gymtavo-katalog.test.ts && pnpm --filter @fitretro/domain test && pnpm typecheck`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/domain/src/catalog.ts packages/domain/src/index.ts tests/integration/domain-gymtavo-portal.test.ts
git commit -m "feat(domain): Gymtavo-Uebungen anhaengen, Typliste und Pflichtabfrage fuers Portal

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Portal — Typauswahl mit Suche und Pflichtregel in den Actions

**Files:**
- Modify: `apps/web/app/portal/bausteine/Auswahl.tsx` (optionale Suche)
- Create: `apps/web/app/portal/bausteine/Auswahl.test.tsx`
- Create: `apps/web/app/portal/gymtavoTyp.ts`, `apps/web/app/portal/gymtavoTyp.test.ts`
- Create: `apps/web/app/portal/bausteine/GymtavoTypFeld.tsx`
- Modify: `apps/web/app/portal/actions.ts` (`modellAnlegen` ~135, `modellAendern` ~162)
- Modify: `apps/web/app/portal/[studioId]/einrichten/actions.ts` (`modellAnlegen` ~74)
- Modify: `apps/web/app/portal/[studioId]/(schreibtisch)/geraete/ModellAnlegenFormular.tsx`, `…/geraete/neu/page.tsx`
- Modify: `apps/web/app/portal/[studioId]/einrichten/modell/neu/ModellNeuFormular.tsx`, `…/einrichten/modell/neu/page.tsx`
- Modify: `apps/web/app/portal/[studioId]/(schreibtisch)/geraete/[modelId]/StammdatenFormular.tsx`, `…/[modelId]/page.tsx`

**Interfaces:**
- Consumes: `listCatalogTypes`, `catalogTypeRequired`, `CatalogType` (Task 3); `CatalogModel.catalogModelId`, `StudioCatalog.isCatalog` (Task 2).
- Produces:
  - `Auswahl` neue Prop `suche?: string` (Beschriftung des Suchfelds; ohne sie keine Suche).
  - `TYP_FELD = "catalogModelId"`, `typAusFormular(formData: FormData, pflicht: boolean): { ok: true; catalogModelId: string | undefined } | { ok: false; error: string }`.
  - `<GymtavoTypFeld typen={CatalogType[]} start={string | null} gross?={boolean} />` – rendert nichts bei leerer Liste. Beschriftung „Gymtavo-Gerätetyp“, Suchfeld „Typ suchen“.

- [ ] **Step 1: Failing tests schreiben**

`apps/web/app/portal/gymtavoTyp.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { TYP_FELD, typAusFormular } from "./gymtavoTyp";

function formular(wert?: string): FormData {
  const daten = new FormData();
  if (wert !== undefined) daten.set(TYP_FELD, wert);
  return daten;
}

describe("typAusFormular", () => {
  it("uebernimmt einen gewaehlten Typ", () => {
    expect(typAusFormular(formular("typ-1"), true)).toEqual({ ok: true, catalogModelId: "typ-1" });
  });

  it("verlangt den Typ, sobald es Typen gibt -- leer gewaehlt", () => {
    const antwort = typAusFormular(formular(""), true);
    expect(antwort.ok).toBe(false);
    expect(!antwort.ok && antwort.error).toMatch(/Gymtavo-Gerätetyp/);
  });

  it("verlangt den Typ auch, wenn das Formular noch ohne Feld geladen war", () => {
    expect(typAusFormular(formular(), true).ok).toBe(false);
  });

  it("laesst ohne Typen alles beim Alten", () => {
    expect(typAusFormular(formular(), false)).toEqual({ ok: true, catalogModelId: undefined });
    expect(typAusFormular(formular(""), false)).toEqual({ ok: true, catalogModelId: undefined });
  });
});
```

`apps/web/app/portal/bausteine/Auswahl.test.tsx` (Muster von `EinstellungRad.test.tsx` übernehmen, dort stehen die Imports von Testing Library und `userEvent`):

```tsx
import { describe, expect, it, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { Auswahl } from "./Auswahl";

const optionen = [
  { wert: "a", anzeige: "Kabelzug" },
  { wert: "b", anzeige: "Langhantel" },
  { wert: "c", anzeige: "Beinpresse" },
];

describe("Auswahl mit Suche", () => {
  it("filtert die Zeilen nach dem Suchtext und waehlt mit Enter", async () => {
    const onChange = vi.fn();
    render(
      <Auswahl value="" onChange={onChange} optionen={optionen} ariaLabel="Typ" suche="Typ suchen" />,
    );
    await userEvent.click(screen.getByRole("button", { name: "Typ" }));
    await userEvent.type(screen.getByRole("searchbox", { name: "Typ suchen" }), "hant");
    expect(screen.getAllByRole("option").map((o) => o.textContent)).toEqual(["Langhantel"]);
    await userEvent.keyboard("{Enter}");
    expect(onChange).toHaveBeenCalledWith("b");
  });

  it("sagt, wenn nichts passt", async () => {
    render(
      <Auswahl value="" onChange={() => {}} optionen={optionen} ariaLabel="Typ" suche="Typ suchen" />,
    );
    await userEvent.click(screen.getByRole("button", { name: "Typ" }));
    await userEvent.type(screen.getByRole("searchbox", { name: "Typ suchen" }), "xyz");
    expect(screen.queryAllByRole("option")).toHaveLength(0);
    expect(screen.getByText("Kein Treffer.")).toBeTruthy();
  });

  it("ohne suche bleibt es die bisherige Auswahl", async () => {
    render(<Auswahl value="" onChange={() => {}} optionen={optionen} ariaLabel="Typ" />);
    await userEvent.click(screen.getByRole("button", { name: "Typ" }));
    expect(screen.queryByRole("searchbox")).toBeNull();
    expect(screen.getAllByRole("option")).toHaveLength(3);
  });
});
```

- [ ] **Step 2: Tests laufen lassen, sie müssen scheitern**

Run: `pnpm --filter @fitretro/web exec vitest run app/portal/gymtavoTyp.test.ts app/portal/bausteine/Auswahl.test.tsx`
Expected: FAIL (Modul `./gymtavoTyp` fehlt; kein `searchbox`).

- [ ] **Step 3: `gymtavoTyp.ts` schreiben**

```ts
/**
 * Pflichtregel fuer den Gymtavo-Typ (Nachtrag 10.1) als reine Funktion --
 * die Server-Actions fragen nur noch `pflicht` ab (catalogTypeRequired) und
 * geben das Ergebnis weiter. Ohne Datenbank pruefbar, deshalb nicht in
 * actions.ts.
 */
export const TYP_FELD = "catalogModelId";

const PFLICHT =
  "Wähle den Gymtavo-Gerätetyp. Er bestimmt, welche Gymtavo-Übungen Mitglieder an diesem Gerät sehen.";

export function typAusFormular(
  formData: FormData,
  pflicht: boolean,
): { ok: true; catalogModelId: string | undefined } | { ok: false; error: string } {
  const wert = String(formData.get(TYP_FELD) ?? "").trim();
  if (wert.length > 0) return { ok: true, catalogModelId: wert };
  // Auch ein fehlendes Feld zaehlt als leer: das Formular kann geladen worden
  // sein, als der Katalog noch leer war.
  return pflicht ? { ok: false, error: PFLICHT } : { ok: true, catalogModelId: undefined };
}
```

- [ ] **Step 4: Suche in `Auswahl.tsx`**

- Prop `suche?: string` ergänzen und im Doc-Kommentar einen Absatz: „Mit `suche` steht oben im Panel ein Suchfeld -- fuer lange Listen wie die Gymtavo-Typen, in denen Pfeiltasten allein zu langsam sind.“
- State `const [text, setText] = useState("")`, Ref `const suchfeld = useRef<HTMLInputElement>(null)`.
- `const sichtbar = suche ? optionen.filter((o) => o.anzeige.toLocaleLowerCase("de").includes(text.trim().toLocaleLowerCase("de"))) : optionen;`
- `oeffnen()` setzt `setText("")`; der Index für `hervorgehoben` bezieht sich ab jetzt auf `sichtbar` (in `oeffnen`, `waehlen`, `aufTaste` und beim Rendern `optionen` → `sichtbar` ersetzen; `gewaehlt` bleibt über `optionen`).
- Effekt: `useEffect(() => { if (offen && suche) suchfeld.current?.focus(); }, [offen, suche]);`
- `aufTaste` so umbauen, dass er mit `React.KeyboardEvent<HTMLElement>` arbeitet, und am Suchfeld als `onKeyDown` hängen. Beim Tippen `setHervorgehoben(0)`.
- Im Panel vor den Zeilen:

```tsx
          {suche ? (
            <input
              ref={suchfeld}
              type="search"
              className={styles.suche}
              aria-label={suche}
              placeholder={suche}
              value={text}
              onChange={(e) => {
                setText(e.target.value);
                setHervorgehoben(0);
              }}
              onKeyDown={aufTaste}
            />
          ) : null}
          {sichtbar.length === 0 ? <div className={styles.leer}>Kein Treffer.</div> : null}
```

- `role="listbox"` vom Panel-`div` auf einen inneren `div` um die Zeilen verschieben, damit das Suchfeld nicht im Listbox-Container liegt.
- In `Auswahl.module.css` `.suche` (volle Breite, Höhe 44 px, Rahmen wie `.knopf`, `margin-bottom: 4px`) und `.leer` (Farbe wie `.platzhalter`, `padding` wie `.zeile`) ergänzen.

- [ ] **Step 5: `GymtavoTypFeld.tsx` schreiben**

```tsx
"use client";

import { useId, useState } from "react";
import type { CatalogType } from "@fitretro/domain";
import { Auswahl } from "./Auswahl";
import { TYP_FELD } from "../gymtavoTyp";
import styles from "../portal.module.css";

/**
 * "Gymtavo-Gerätetyp" an beiden Modellformularen (Schreibtisch und Halle).
 * Ohne Typen im Katalog rendert es nichts -- dann gibt es auch keine Pflicht
 * (Nachtrag 10.1), und ein leeres Auswahlfeld waere eine Frage ohne Antwort.
 */
export function GymtavoTypFeld({
  typen,
  start,
  gross = false,
}: {
  typen: Pick<CatalogType, "id" | "name" | "manufacturer">[];
  start: string | null;
  gross?: boolean;
}) {
  const [wert, setWert] = useState(start ?? "");
  const id = useId();
  if (typen.length === 0) return null;

  return (
    <div className={styles.field}>
      <label className={styles.label} htmlFor={id}>
        Gymtavo-Gerätetyp
      </label>
      <Auswahl
        id={id}
        name={TYP_FELD}
        value={wert}
        onChange={setWert}
        optionen={typen.map((typ) => ({
          wert: typ.id,
          anzeige: typ.manufacturer ? `${typ.name} · ${typ.manufacturer}` : typ.name,
        }))}
        platzhalter="Typ wählen"
        suche="Typ suchen"
        gross={gross}
      />
      <span className={styles.hint}>
        Bestimmt, welche Gymtavo-Übungen Mitglieder an diesem Gerät sehen.
      </span>
    </div>
  );
}
```

`CatalogType` ist ein reiner Typ; der Import aus `@fitretro/domain` in einer Client-Datei ist nur ein `import type` und zieht keinen Servercode. Falls `typecheck`/Bau dennoch meckert, `@fitretro/domain/…`-Unterpfad nach dem Muster von `@fitretro/domain/belastung` verwenden.

- [ ] **Step 6: Actions verdrahten**

`apps/web/app/portal/actions.ts`: Imports um `catalogTypeRequired` (aus `@fitretro/domain`) und `typAusFormular` (aus `./gymtavoTyp`) erweitern.

In `modellAnlegen` vor `createEquipmentModel`, innerhalb des `try`:

```ts
    const typ = typAusFormular(formData, await catalogTypeRequired(client, studioId));
    if (!typ.ok) return typ;
```

und im Input `catalogModelId: typ.catalogModelId,`.

`modellAendern`: `fuehreAus` gibt nur `void` zurück; deshalb von Hand:

```ts
export async function modellAendern(
  studioId: string,
  modelId: string,
  _prev: unknown,
  formData: FormData,
): Promise<ActionResult> {
  return fuehreAus(`/portal/${studioId}/geraete/${modelId}`, async (client) => {
    const typ = typAusFormular(formData, await catalogTypeRequired(client, studioId));
    // Als DomainError geworfen, damit fehlerAus den Satz zeigt -- der Weg
    // ueber fuehreAus kennt kein vorzeitiges Ergebnis.
    if (!typ.ok) throw new DomainError("validation_failed", typ.error);
    await updateEquipmentModel(client, modelId, {
      name: text(formData, "name"),
      manufacturer: optionalerText(formData, "manufacturer"),
      ...belastungAusFormular(formData),
      ...(typ.catalogModelId === undefined ? {} : { catalogModelId: typ.catalogModelId }),
    });
  }, "layout");
}
```

(`DomainError` ist in `actions.ts` bereits importiert; sonst ergänzen.)

`apps/web/app/portal/[studioId]/einrichten/actions.ts` → `modellAnlegen`: nach der Fotoprüfung

```ts
  const typ = typAusFormular(formData, await catalogTypeRequired(client, studioId));
  if (!typ.ok) return typ;
```

und `catalogModelId: typ.catalogModelId` in `createEquipmentModel`. Import `typAusFormular` aus `../../gymtavoTyp`.

- [ ] **Step 7: Formulare und Seiten**

- `ModellAnlegenFormular`: Prop `typen: Pick<CatalogType, "id" | "name" | "manufacturer">[]`; `<GymtavoTypFeld typen={typen} start={null} />` direkt nach dem Grid mit Name/Hersteller.
- `geraete/neu/page.tsx`: `const typen = await listCatalogTypes(await createServerSupabaseClient());` (Import aus `@fitretro/domain` und `@/lib/supabase/server`) und `typen={typen}` an `ModellAnlegenFormular`.
- `ModellNeuFormular`: Prop `typen` wie oben; `<GymtavoTypFeld gross typen={typen} start={null} />` nach „Hersteller“.
- `einrichten/modell/neu/page.tsx`: Typen wie oben laden und durchreichen.
- `StammdatenFormular`: Props `typen` und `modell.catalogModelId: string | null`; `<GymtavoTypFeld typen={typen} start={modell.catalogModelId} />` nach dem Grid. `[modelId]/page.tsx`: Typen laden; im Gymtavo-Studio (`katalog.isCatalog`) `typen={[]}` übergeben – ein Typ wird keinem Typ zugeordnet.

- [ ] **Step 8: Tests und Typen**

Run: `pnpm --filter @fitretro/web exec vitest run app/portal && pnpm typecheck`
Expected: PASS (bestehende Formular-Tests eingeschlossen; scheitert ein bestehender Test an einer neuen Pflicht-Prop, dort `typen={[]}` setzen).

- [ ] **Step 9: Commit**

```bash
git add apps/web/app/portal
git commit -m "feat(portal): Gymtavo-Geraetetyp mit Suche beim Anlegen und Bearbeiten, Pflicht sobald es Typen gibt

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Portal — Hinweis „Kein Gymtavo-Typ“ und angepasste offene Punkte

**Files:**
- Modify: `apps/web/app/portal/[studioId]/offen.ts`, `apps/web/app/portal/[studioId]/offen.test.ts`
- Modify: `apps/web/app/portal/[studioId]/(schreibtisch)/geraete/[modelId]/layout.tsx`, `…/geraete/page.tsx`
- Modify: `apps/web/app/portal/[studioId]/einrichten/modell/page.tsx` (Meta-Zeile)

**Interfaces:**
- Consumes: `CatalogModel.catalogModelId`, `CatalogExercise.fromCatalog`, `StudioCatalog.isCatalog`, `listCatalogTypes`.
- Produces:

```ts
export type GymtavoKontext = {
  /** Das Gymtavo-Studio selbst: keine Geraete, keine Tags, keine Zuordnung. */
  istKatalog: boolean;
  /** Ob der Katalog Typen hat -- sonst gibt es nichts zuzuordnen. */
  katalogHatTypen: boolean;
  /** Uebungen des zugeordneten Typs; 0 ohne Zuordnung. */
  typUebungen: number;
};
export function offenePunkte(studioId: string, modell: StudioCatalog["models"][number], gymtavo?: GymtavoKontext): OffenerPunkt[];
```

Ohne `gymtavo` verhält sich die Funktion wie bisher (Rückwärtskompatibilität für bestehende Tests).

- [ ] **Step 1: Failing tests ergänzen** (in `offen.test.ts`, Helfer `modell()` um `catalogModelId: "typ-1"` und `exercises: [{ linkId: "l1", hasVideo: true, fromCatalog: false }]` ergänzen)

```ts
describe("offenePunkte mit Gymtavo-Katalog", () => {
  const mitTypen = { istKatalog: false, katalogHatTypen: true, typUebungen: 0 };

  it("nennt ein Modell ohne Typ, solange der Katalog Typen hat", () => {
    const punkte = offenePunkte("st1", modell({ catalogModelId: null }), mitTypen);
    expect(punkte).toContainEqual(
      expect.objectContaining({
        titel: "Kein Gymtavo-Typ",
        grund: "Mitglieder sehen an diesem Gerät keine Gymtavo-Übungen.",
        href: "/portal/st1/geraete/m1",
        label: "Typ wählen",
        art: "unvollstaendig",
      }),
    );
  });

  it("schweigt bei leerem Katalog und bei zugeordnetem Modell", () => {
    expect(
      offenePunkte("st1", modell({ catalogModelId: null }), { ...mitTypen, katalogHatTypen: false }),
    ).toEqual([]);
    expect(offenePunkte("st1", modell(), mitTypen)).toEqual([]);
  });

  it("ein Modell ohne eigene Uebung ist benutzbar, wenn sein Typ Uebungen hat", () => {
    const punkte = offenePunkte("st1", modell({ exercises: [] }), { ...mitTypen, typUebungen: 3 });
    expect(punkte.map((p) => p.titel)).not.toContain("Keine Übung");
  });

  it("zaehlt fehlende Videos nur bei eigenen Uebungen", () => {
    const punkte = offenePunkte(
      "st1",
      modell({
        exercises: [
          { linkId: "l1", hasVideo: true, fromCatalog: false },
          { linkId: "l2", hasVideo: false, fromCatalog: true },
        ] as never,
      }),
      mitTypen,
    );
    expect(punkte.map((p) => p.titel)).toEqual([]);
  });

  it("im Gymtavo-Studio gibt es weder Geraete noch Tags noch Zuordnung", () => {
    const punkte = offenePunkte("gy", modell({ catalogModelId: null, machines: [] }), {
      istKatalog: true,
      katalogHatTypen: true,
      typUebungen: 0,
    });
    expect(punkte.map((p) => p.titel)).toEqual([]);
  });
});
```

- [ ] **Step 2: Test laufen lassen, er muss scheitern**

Run: `pnpm --filter @fitretro/web exec vitest run "app/portal/[studioId]/offen.test.ts"`
Expected: FAIL (kein Punkt „Kein Gymtavo-Typ“).

- [ ] **Step 3: `offen.ts` umsetzen**

- Typ `GymtavoKontext` exportieren (siehe Interfaces), dritten Parameter `gymtavo?: GymtavoKontext` ergänzen.
- „Keine Übung“: Bedingung `modell.exercises.length === 0 && (gymtavo?.typUebungen ?? 0) === 0`.
- Block „Kein Gerät im Raum“/„ohne Tag“ nur, wenn `!gymtavo?.istKatalog`.
- „ohne Einweisungsvideo“: `modell.exercises.filter((uebung) => !uebung.fromCatalog && !uebung.hasVideo)`.
- Ganz am Ende, vor `return`, als letzter (`unvollstaendig`) Punkt:

```ts
  // Zuletzt und nur "unvollstaendig": ohne Typ ist das Geraet voll nutzbar,
  // nur ohne die Gymtavo-Uebungen (Nachtrag 10.1). Bei leerem Katalog gibt
  // es nichts zuzuordnen, im Gymtavo-Studio ist das Modell selbst der Typ.
  if (gymtavo && !gymtavo.istKatalog && gymtavo.katalogHatTypen && modell.catalogModelId === null) {
    punkte.push({
      titel: "Kein Gymtavo-Typ",
      grund: "Mitglieder sehen an diesem Gerät keine Gymtavo-Übungen.",
      href: basis,
      label: "Typ wählen",
      art: "unvollstaendig",
    });
  }
```

- Den Doc-Kommentar der Funktion um einen Satz ergänzen: „Der Gymtavo-Kontext ist optional, damit die reine Ableitung ohne Katalog pruefbar bleibt.“

- [ ] **Step 4: Aufrufer**

- `[modelId]/layout.tsx`: `const typen = katalog.isCatalog ? [] : await listCatalogTypes(await createServerSupabaseClient());` und

```ts
  const punkte = offenePunkte(studioId, modell, {
    istKatalog: katalog.isCatalog,
    katalogHatTypen: typen.length > 0,
    typUebungen: typen.find((typ) => typ.id === modell.catalogModelId)?.exercises.length ?? 0,
  });
```

- `geraete/page.tsx`: Typen einmal vor der Liste laden, gleiches Objekt je Modell übergeben.
- `einrichten/modell/page.tsx`: Typen laden; in `meta()` bei `typen.length > 0 && modell.catalogModelId === null` den Teil `"kein Gymtavo-Typ"` anhängen (wie heute `"kein Foto"`), und die Zeile dann ebenfalls `zeileMetaFaint` zeichnen.

- [ ] **Step 5: Tests**

Run: `pnpm --filter @fitretro/web exec vitest run app/portal && pnpm typecheck`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add "apps/web/app/portal/[studioId]"
git commit -m "feat(portal): Hinweis Kein Gymtavo-Typ, Typ-Uebungen zaehlen bei den offenen Punkten mit

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Portal — Reiter Übungen mit Gymtavo-Übungen

**Files:**
- Create: `apps/web/app/portal/[studioId]/(schreibtisch)/geraete/[modelId]/uebungen/gymtavo.ts`, `gymtavo.test.ts`
- Create: `…/uebungen/GymtavoZeile.tsx`, `…/uebungen/GymtavoAnhaengen.tsx`
- Modify: `…/uebungen/page.tsx`
- Modify: `apps/web/app/portal/actions.ts` (neue Action)
- Modify: `apps/web/app/portal/bausteine/Hinzufuegen.tsx` (Prop `neben`)
- Modify: `…/geraete/[modelId]/layout.tsx` (`uebungenZusatz` zählt Typ-Übungen mit)

**Interfaces:**
- Consumes: `CatalogType`, `listCatalogTypes`, `CatalogModel.catalogModelId`, `CatalogExercise.fromCatalog`, `attachExerciseToModel`.
- Produces:

```ts
// gymtavo.ts
export type Video = { storagePath: string; durationS: number | null };
export type GymtavoZeileDaten = {
  exerciseId: string;
  name: string;
  volumeKind: VolumeKind;
  targetMin: number;
  targetMax: number;
  herkunft: "typ" | "angehaengt";
  /** Verknuepfung am Studio-Modell -- nur sie traegt ein eigenes Video. */
  linkId: string | null;
  eigenesVideo: Video | null;
  katalogVideo: Video | null;
};
export function gymtavoZeilen(modell: Pick<CatalogModel, "catalogModelId" | "exercises">, typen: CatalogType[]): GymtavoZeileDaten[];
export function eigeneUebungen<T extends { fromCatalog: boolean }>(uebungen: T[]): T[];
export function anhaengbareUebungen(modell: Pick<CatalogModel, "catalogModelId" | "exercises">, typen: CatalogType[]): { exerciseId: string; name: string; typName: string }[];

// actions.ts
export async function gymtavoUebungVerknuepfen(studioId: string, modelId: string, exerciseId: string): Promise<ActionResult>;
```

- [ ] **Step 1: Failing test schreiben** — `gymtavo.test.ts`

```ts
import { describe, expect, it } from "vitest";
import type { CatalogType } from "@fitretro/domain";
import { anhaengbareUebungen, eigeneUebungen, gymtavoZeilen } from "./gymtavo";

function uebung(id: string, video: string | null = null) {
  return {
    exerciseId: id,
    name: `Übung ${id}`,
    description: null,
    volumeKind: "reps" as const,
    targetMin: 8,
    targetMax: 12,
    sortOrder: 1,
    videoStoragePath: video,
    videoDurationS: video ? 20 : null,
  };
}

const typen: CatalogType[] = [
  { id: "t1", name: "Kabelzug", manufacturer: null, category: "kraft", exercises: [uebung("e1", "gy/e1.mp4"), uebung("e2")] },
  { id: "t2", name: "Langhantel", manufacturer: null, category: "kraft", exercises: [uebung("e3", "gy/e3.mp4"), uebung("e1", "gy/e1.mp4")] },
];

function link(exerciseId: string, fromCatalog: boolean, video: string | null = null) {
  return {
    linkId: `l-${exerciseId}`,
    exerciseId,
    name: `Übung ${exerciseId}`,
    description: null,
    volumeKind: "reps" as const,
    targetMin: 8,
    targetMax: 12,
    sortOrder: 1,
    hasVideo: video !== null,
    videoAssetId: video ? "a" : null,
    videoStoragePath: video,
    videoDurationS: video ? 30 : null,
    fromCatalog,
  };
}

describe("gymtavoZeilen", () => {
  it("zeigt die Uebungen des Typs mit Katalogvideo, ohne Verknuepfung", () => {
    const zeilen = gymtavoZeilen({ catalogModelId: "t1", exercises: [] }, typen);
    expect(zeilen.map((z) => [z.exerciseId, z.herkunft, z.linkId])).toEqual([
      ["e1", "typ", null],
      ["e2", "typ", null],
    ]);
    expect(zeilen[0]!.katalogVideo).toEqual({ storagePath: "gy/e1.mp4", durationS: 20 });
  });

  it("eine Typ-Uebung mit eigenem Video erscheint genau einmal, als vom Typ", () => {
    const zeilen = gymtavoZeilen(
      { catalogModelId: "t1", exercises: [link("e1", true, "st/e1.mp4")] },
      typen,
    );
    expect(zeilen.filter((z) => z.exerciseId === "e1")).toHaveLength(1);
    expect(zeilen[0]).toMatchObject({
      herkunft: "typ",
      linkId: "l-e1",
      eigenesVideo: { storagePath: "st/e1.mp4", durationS: 30 },
    });
  });

  it("angehaengte Uebungen anderer Typen folgen, mit Katalogvideo", () => {
    const zeilen = gymtavoZeilen({ catalogModelId: "t1", exercises: [link("e3", true)] }, typen);
    expect(zeilen.at(-1)).toMatchObject({
      exerciseId: "e3",
      herkunft: "angehaengt",
      linkId: "l-e3",
      katalogVideo: { storagePath: "gy/e3.mp4", durationS: 20 },
    });
  });

  it("nach einem Typwechsel stehen alte Verknuepfungen als angehaengt da", () => {
    const zeilen = gymtavoZeilen({ catalogModelId: "t2", exercises: [link("e2", true)] }, typen);
    expect(zeilen.map((z) => [z.exerciseId, z.herkunft])).toEqual([
      ["e3", "typ"],
      ["e1", "typ"],
      ["e2", "angehaengt"],
    ]);
  });

  it("ohne Zuordnung nur die angehaengten", () => {
    expect(gymtavoZeilen({ catalogModelId: null, exercises: [link("e2", true)] }, typen)).toHaveLength(1);
  });
});

describe("eigeneUebungen", () => {
  it("laesst Gymtavo-Verknuepfungen weg", () => {
    expect(eigeneUebungen([link("x", false), link("e1", true)]).map((u) => u.exerciseId)).toEqual(["x"]);
  });
});

describe("anhaengbareUebungen", () => {
  it("bietet jede noch nicht gezeigte Gymtavo-Uebung einmal an, nach Namen", () => {
    expect(anhaengbareUebungen({ catalogModelId: "t1", exercises: [] }, typen)).toEqual([
      { exerciseId: "e3", name: "Übung e3", typName: "Langhantel" },
    ]);
  });

  it("ohne Zuordnung alle, eine an zwei Typen nur einmal", () => {
    const angebot = anhaengbareUebungen({ catalogModelId: null, exercises: [] }, typen);
    expect(angebot.map((u) => u.exerciseId)).toEqual(["e1", "e2", "e3"]);
    expect(angebot[0]!.typName).toBe("Kabelzug");
  });
});
```

- [ ] **Step 2: Test laufen lassen, er muss scheitern**

Run: `pnpm --filter @fitretro/web exec vitest run "app/portal/[studioId]/(schreibtisch)/geraete/[modelId]/uebungen/gymtavo.test.ts"`
Expected: FAIL (Modul fehlt).

- [ ] **Step 3: `gymtavo.ts` umsetzen**

```ts
import type { CatalogModel, CatalogType } from "@fitretro/domain";
import type { VolumeKind } from "@fitretro/domain/belastung";

/**
 * Was der Reiter Uebungen unter "Gymtavo-Übungen" zeigt -- eine reine
 * Ableitung aus Studio-Katalog und Typliste, ohne Datenbank und ohne React
 * (Muster wie offen.ts nebenan). Die App mischt dieselben Quellen
 * (Spec 8.1); hier steht, was der Trainer davon sieht.
 */
export type Video = { storagePath: string; durationS: number | null };

export type GymtavoZeileDaten = {
  exerciseId: string;
  name: string;
  volumeKind: VolumeKind;
  targetMin: number;
  targetMax: number;
  herkunft: "typ" | "angehaengt";
  /** Verknuepfung am Studio-Modell -- nur sie traegt ein eigenes Video. */
  linkId: string | null;
  eigenesVideo: Video | null;
  katalogVideo: Video | null;
};

type Modell = Pick<CatalogModel, "catalogModelId" | "exercises">;

function katalogVideos(typen: CatalogType[]): Map<string, Video> {
  const videos = new Map<string, Video>();
  for (const typ of typen) {
    for (const uebung of typ.exercises) {
      if (uebung.videoStoragePath && !videos.has(uebung.exerciseId)) {
        videos.set(uebung.exerciseId, {
          storagePath: uebung.videoStoragePath,
          durationS: uebung.videoDurationS,
        });
      }
    }
  }
  return videos;
}

export function gymtavoZeilen(modell: Modell, typen: CatalogType[]): GymtavoZeileDaten[] {
  const videos = katalogVideos(typen);
  const verknuepft = new Map(
    modell.exercises.filter((u) => u.fromCatalog).map((u) => [u.exerciseId, u]),
  );
  const typ = typen.find((eintrag) => eintrag.id === modell.catalogModelId);

  function eigenesVideo(exerciseId: string): Video | null {
    const link = verknuepft.get(exerciseId);
    return link?.videoStoragePath
      ? { storagePath: link.videoStoragePath, durationS: link.videoDurationS }
      : null;
  }

  const vomTyp: GymtavoZeileDaten[] = (typ?.exercises ?? []).map((uebung) => ({
    exerciseId: uebung.exerciseId,
    name: uebung.name,
    volumeKind: uebung.volumeKind,
    targetMin: uebung.targetMin,
    targetMax: uebung.targetMax,
    herkunft: "typ",
    linkId: verknuepft.get(uebung.exerciseId)?.linkId ?? null,
    eigenesVideo: eigenesVideo(uebung.exerciseId),
    katalogVideo: videos.get(uebung.exerciseId) ?? null,
  }));

  const amTyp = new Set(vomTyp.map((zeile) => zeile.exerciseId));
  const angehaengt: GymtavoZeileDaten[] = [...verknuepft.values()]
    .filter((link) => !amTyp.has(link.exerciseId))
    .map((link) => ({
      exerciseId: link.exerciseId,
      name: link.name,
      volumeKind: link.volumeKind,
      targetMin: link.targetMin,
      targetMax: link.targetMax,
      herkunft: "angehaengt",
      linkId: link.linkId,
      eigenesVideo: eigenesVideo(link.exerciseId),
      katalogVideo: videos.get(link.exerciseId) ?? null,
    }));

  return [...vomTyp, ...angehaengt];
}

export function eigeneUebungen<T extends { fromCatalog: boolean }>(uebungen: T[]): T[] {
  return uebungen.filter((uebung) => !uebung.fromCatalog);
}

export function anhaengbareUebungen(
  modell: Modell,
  typen: CatalogType[],
): { exerciseId: string; name: string; typName: string }[] {
  const gezeigt = new Set(gymtavoZeilen(modell, typen).map((zeile) => zeile.exerciseId));
  const angebot = new Map<string, { exerciseId: string; name: string; typName: string }>();
  for (const typ of typen) {
    for (const uebung of typ.exercises) {
      if (gezeigt.has(uebung.exerciseId) || angebot.has(uebung.exerciseId)) continue;
      angebot.set(uebung.exerciseId, {
        exerciseId: uebung.exerciseId,
        name: uebung.name,
        typName: typ.name,
      });
    }
  }
  return [...angebot.values()].sort((a, b) => a.name.localeCompare(b.name, "de"));
}
```

Prüfen, dass `CatalogModel` aus `@fitretro/domain` exportiert ist (`export type { … CatalogModel … }` in `index.ts`); sonst dort ergänzen.

- [ ] **Step 4: Test laufen lassen, er muss bestehen**

Run: wie Step 2. Expected: PASS.

- [ ] **Step 5: Action und Bausteine**

`actions.ts`, nach `uebungLoesen`:

```ts
/**
 * Gymtavo-Uebung per Verweis ans Modell (Spec 5.3). Zwei Wege fuehren
 * hierher: "Gymtavo-Übung anhängen" fuer Uebungen anderer Typen und
 * "Eigenes Video ergänzen" an einer Typ-Uebung -- das Video braucht die
 * Verknuepfung, an der es haengt und durch die es dem Studio gehoert.
 */
export async function gymtavoUebungVerknuepfen(
  studioId: string,
  modelId: string,
  exerciseId: string,
): Promise<ActionResult> {
  return fuehreAus(`/portal/${studioId}/geraete/${modelId}`, async (client) => {
    await attachExerciseToModel(client, { equipmentModelId: modelId, exerciseId });
  }, "layout");
}
```

`Hinzufuegen.tsx`: Prop `neben?: boolean` (Default `false`); Knopf-Klasse `neben ? portalStyles.secondary : portalStyles.primary`. Doc-Satz: „`neben` fuer eine zweite Hinzufuegen-Leiste auf demselben Bildschirm -- die Akzentflaeche gehoert der Hauptaktion.“

`GymtavoZeile.tsx` (Client): Aufbau wie `UebungZeile.tsx`, aber schreibgeschützt.

```tsx
"use client";

import { useId, useState } from "react";
import { formatVolumeRange } from "@fitretro/domain/belastung";
import { AktionsKnopf } from "../../../../../Form";
import { VideoUpload } from "../../../../../VideoUpload";
import { MedienVorschau } from "../../../../../bausteine/MedienVorschau";
import { VideoAbspieler } from "../../../../../bausteine/VideoAbspieler";
import { StiftKnopf } from "../../../../../bausteine/Stift";
import type { ActionResult } from "../../../../../actions";
import type { GymtavoZeileDaten } from "./gymtavo";
import styles from "../../../../../portal.module.css";
import eigene from "./uebungen.module.css";

/**
 * Eine Gymtavo-Uebung am Modell. Name und Korridor gehoeren Gymtavo und
 * sind hier nicht aenderbar (Spec E2: Bankdruecken ist ueberall dieselbe
 * Uebung). Das Studio darf ein eigenes Video ergaenzen; es ersetzt am Geraet
 * das Katalogvideo (Spec 8.1, Geraetekontext).
 */
export function GymtavoZeile({
  studioId,
  modelId,
  zeile,
  eigeneVideoUrl,
  katalogVideoUrl,
  verknuepfen,
  loesen,
}: {
  studioId: string;
  modelId: string;
  zeile: GymtavoZeileDaten;
  eigeneVideoUrl: string | undefined;
  katalogVideoUrl: string | undefined;
  verknuepfen: () => Promise<ActionResult>;
  loesen: (() => Promise<ActionResult>) | null;
}) {
  const [offen, setOffen] = useState(false);
  const bereich = useId();
  const videoUrl = eigeneVideoUrl ?? katalogVideoUrl;
  const video = zeile.eigenesVideo ?? zeile.katalogVideo;

  return (
    <li className={eigene.zeile}>
      <div className={eigene.zeileKopf}>
        <div className={styles.zeileMitBild}>
          {videoUrl ? (
            <VideoAbspieler url={videoUrl} titel={zeile.name} groesse="zeile" />
          ) : (
            <MedienVorschau url={null} art="video" leerText="Kein Video" groesse="zeile" />
          )}
          <div className={styles.rowMain}>
            <div className={styles.rowTitle}>{zeile.name}</div>
            <div className={styles.rowMeta}>
              {formatVolumeRange(zeile.targetMin, zeile.targetMax, zeile.volumeKind)} ·{" "}
              {zeile.eigenesVideo
                ? `Eigenes Video ${zeile.eigenesVideo.durationS ?? "?"} s`
                : video
                  ? `Gymtavo-Video ${video.durationS ?? "?"} s`
                  : "ohne Video"}
            </div>
            <div className={styles.rowMarke}>
              <span className={styles.badge}>
                {zeile.herkunft === "typ" ? "vom Typ" : "angehängt"}
              </span>
            </div>
          </div>
        </div>
        <StiftKnopf
          label={`${zeile.name} bearbeiten`}
          offen={0}
          gedrueckt={offen}
          controls={bereich}
          onClick={() => setOffen((bisher) => !bisher)}
        />
      </div>

      {offen ? (
        <div id={bereich} className={eigene.bearbeiten}>
          {zeile.linkId ? (
            <div className={eigene.bearbeitenTeil}>
              <VideoUpload
                studioId={studioId}
                modelId={modelId}
                linkId={zeile.linkId}
                hatVideo={zeile.eigenesVideo !== null}
                videoUrl={eigeneVideoUrl}
                titel={zeile.name}
              />
            </div>
          ) : (
            // Erst die Verknuepfung, dann der Upload: nach der Revalidierung
            // traegt die Zeile ihre linkId, und offen bleibt sie, weil React
            // die Zeile ueber exerciseId wiedererkennt.
            <AktionsKnopf aktion={verknuepfen} label="Eigenes Video ergänzen" />
          )}
          {loesen ? (
            <div className={eigene.entfernen}>
              <AktionsKnopf
                aktion={loesen}
                label="Übung lösen"
                bestaetigung="Wirklich lösen?"
                art="destructive"
              />
            </div>
          ) : null}
        </div>
      ) : null}
    </li>
  );
}
```

Vor dem Schreiben die Props von `StiftKnopf` in `bausteine/Stift.tsx` prüfen: Wenn `offen={0}` eine Marke „0“ zeichnet, die Prop so setzen, dass keine Marke erscheint (die Datei sagt, welcher Wert das ist).

`GymtavoAnhaengen.tsx` (Client):

```tsx
"use client";

import { useState, useTransition } from "react";
import { Auswahl } from "../../../../../bausteine/Auswahl";
import type { ActionResult } from "../../../../../actions";
import styles from "../../../../../portal.module.css";

/** Suche ueber alle Gymtavo-Uebungen, die am Modell noch nicht stehen. */
export function GymtavoAnhaengen({
  angebot,
  anhaengen,
}: {
  angebot: { exerciseId: string; name: string; typName: string }[];
  anhaengen: (exerciseId: string) => Promise<ActionResult>;
}) {
  const [wahl, setWahl] = useState("");
  const [fehler, setFehler] = useState<string | null>(null);
  const [laeuft, starte] = useTransition();

  if (angebot.length === 0) {
    return <p className={styles.hint}>Alle Gymtavo-Übungen stehen schon an diesem Modell.</p>;
  }

  return (
    <div style={{ display: "grid", gap: 12 }}>
      <Auswahl
        value={wahl}
        onChange={setWahl}
        optionen={angebot.map((u) => ({ wert: u.exerciseId, anzeige: `${u.name} · ${u.typName}` }))}
        platzhalter="Übung wählen"
        ariaLabel="Gymtavo-Übung"
        suche="Übung suchen"
      />
      {fehler ? (
        <p className={styles.error} role="alert">
          {fehler}
        </p>
      ) : null}
      <button
        type="button"
        className={styles.secondary}
        disabled={!wahl || laeuft}
        onClick={() =>
          starte(async () => {
            const antwort = await anhaengen(wahl);
            if (antwort.ok) {
              setWahl("");
              setFehler(null);
            } else {
              setFehler(antwort.error);
            }
          })
        }
      >
        {laeuft ? "Wird angehängt …" : "Anhängen"}
      </button>
    </div>
  );
}
```

Klassennamen `styles.error`/`styles.hint` in `portal.module.css` prüfen (Form.tsx benutzt sie); bei abweichendem Namen den dort verwendeten nehmen.

- [ ] **Step 6: Seite umbauen** — `uebungen/page.tsx`

- Zusätzlich laden: `const typen = katalog.isCatalog ? [] : await listCatalogTypes(client);`
- `const gymtavo = gymtavoZeilen(modell, typen); const eigen = eigeneUebungen(modell.exercises); const angebot = anhaengbareUebungen(modell, typen);`
- `signMediaUrls` bekommt alle Pfade: eigene (`eigen`), `gymtavo` mit `eigenesVideo` und `katalogVideo`.
- Doc-Kommentar oben um einen Absatz ergänzen: „Seit Etappe 5 (Nachtrag 10.1) zwei Teile: Gymtavo-Übungen des Typs und angehaengte, schreibgeschuetzt mit eigenem Video; darunter die eigenen wie bisher.“
- Aufbau:

```tsx
      {typen.length > 0 || gymtavo.length > 0 ? (
        <Abschnitt
          titel="Gymtavo-Übungen"
          notiz={
            modell.catalogModelId === null
              ? "Ohne Gymtavo-Typ stehen hier nur angehängte Übungen."
              : "Kommen mit dem Gymtavo-Typ. Name und Wiederholungen pflegt Gymtavo."
          }
        >
          <Hinzufuegen neben knopf="Gymtavo-Übung anhängen" titel="Gymtavo-Übung anhängen">
            <GymtavoAnhaengen
              angebot={angebot}
              anhaengen={gymtavoUebungVerknuepfen.bind(null, studioId, modelId)}
            />
          </Hinzufuegen>
          {gymtavo.length > 0 ? (
            <ul className={styles.rows} aria-label="Gymtavo-Übungen am Modell">
              {gymtavo.map((zeile) => (
                <GymtavoZeile
                  key={zeile.exerciseId}
                  studioId={studioId}
                  modelId={modelId}
                  zeile={zeile}
                  eigeneVideoUrl={zeile.eigenesVideo ? videoUrls.get(zeile.eigenesVideo.storagePath) : undefined}
                  katalogVideoUrl={zeile.katalogVideo ? videoUrls.get(zeile.katalogVideo.storagePath) : undefined}
                  verknuepfen={gymtavoUebungVerknuepfen.bind(null, studioId, modelId, zeile.exerciseId)}
                  loesen={
                    zeile.herkunft === "angehaengt" && zeile.linkId
                      ? uebungLoesen.bind(null, studioId, modelId, zeile.linkId)
                      : null
                  }
                />
              ))}
            </ul>
          ) : null}
        </Abschnitt>
      ) : null}

      <Abschnitt titel="Eigene Übungen">
        {/* bisheriger Inhalt: Hinzufuegen "Übung hinzufügen", ReihenfolgeDialog,
            Liste "Übungen am Modell" -- jeweils mit `eigen` statt modell.exercises.
            offen={eigen.length === 0 && gymtavo.length === 0} */}
      </Abschnitt>
```

Den Kommentar-Platzhalter im Codeblock oben durch den bestehenden Code der Seite ersetzen, nicht stehen lassen. Die Liste „Übungen am Modell“ und der `ReihenfolgeDialog` bekommen `eigen`; der Leerzustand „Noch keine Übung.“ erscheint nur, wenn `eigen.length === 0`, mit dem Zusatz „Die Gymtavo-Übungen oben reichen zum Anfangen.“ wenn `gymtavo.length > 0`. Prüfen, ob `Abschnitt` ein `<h2>` rendert – der Kommentar „keine <h2>Übungen</h2>“ bezog sich auf den Reiternamen und bleibt gültig, weil die neuen Überschriften „Gymtavo-Übungen“ und „Eigene Übungen“ heißen. Im Gymtavo-Studio (`katalog.isCatalog`) entfällt der Gymtavo-Teil (dort sind alle Übungen eigene).

`[modelId]/layout.tsx`: `uebungenZusatz` und `uebungenAnzahl` zählen `eigen.length + gymtavo.length` (dieselben Ableitungen mit den in Task 5 geladenen `typen`), `mitVideo` zählt Zeilen mit eigenem oder Katalogvideo.

- [ ] **Step 7: Tests und Typen**

Run: `pnpm --filter @fitretro/web exec vitest run app/portal && pnpm typecheck`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add apps/web/app/portal
git commit -m "feat(portal): Reiter Uebungen zeigt Gymtavo-Uebungen, eigenes Video ergaenzen und Gymtavo-Uebung anhaengen

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Portal — Übungsschritt im Assistenten zeigt die Typ-Übungen

**Files:**
- Modify: `apps/web/app/portal/[studioId]/einrichten/geraet/[machineId]/uebungen/page.tsx`

**Interfaces:**
- Consumes: `listCatalogTypes`, `gymtavoZeilen`, `eigeneUebungen` (Task 6, Import aus `../../../../(schreibtisch)/geraete/[modelId]/uebungen/gymtavo`).

- [ ] **Step 1: Seite ergänzen**

- `const typen = await listCatalogTypes(client); const gymtavo = gymtavoZeilen(modell, typen);`
- Die bestehende Liste zeigt `eigeneUebungen(modell.exercises)`; `reihenfolge` und `schonDran` bleiben über alle Verknüpfungen (`schonDran` soll auch Gymtavo-Übungen enthalten, damit sie im Auswahl-Sheet nicht als Studio-Übung erscheinen – sie erscheinen dort ohnehin nicht, weil `listStudioExercises` nur das Studio liest).
- Vor der Liste der eigenen Übungen, wenn `gymtavo.length > 0`:

```tsx
          <section className={styles.abschnitt}>
            <div className={styles.abschnittKopf}>
              <h2 className={styles.label}>Kommen automatisch mit</h2>
            </div>
            {gymtavo.map((zeile) => (
              <div key={zeile.exerciseId} className={styles.zeile}>
                <div style={{ minWidth: 0 }}>
                  <div className={styles.zeileHaupt}>{zeile.name}</div>
                  <div className={styles.zeileMeta}>
                    {formatVolumeRange(zeile.targetMin, zeile.targetMax, zeile.volumeKind)} · Gymtavo
                  </div>
                </div>
              </div>
            ))}
          </section>
```

- Der Leerzustand „Noch keine Übung“ erscheint nur, wenn weder eigene noch Gymtavo-Übungen da sind.
- Notiz unter dem Sheet ergänzen: „Gymtavo-Übungen kommen mit dem Gerätetyp. Ein eigenes Video dazu ergänzt du am Schreibtisch.“

- [ ] **Step 2: Typen und Unit-Tests**

Run: `pnpm typecheck && pnpm --filter @fitretro/web exec vitest run app/portal`
Expected: PASS. Die Seite selbst prüft Task 9 per E2E.

- [ ] **Step 3: Commit**

```bash
git add "apps/web/app/portal/[studioId]/einrichten"
git commit -m "feat(portal): Uebungsschritt der Halle zeigt die Gymtavo-Uebungen des Typs

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Portal — das Gymtavo-Studio als lesbarer Katalog

**Files:**
- Create: `apps/web/app/portal/[studioId]/katalogStudio.ts`
- Create: `apps/web/app/portal/[studioId]/(schreibtisch)/kurse/layout.tsx`, `…/leute/layout.tsx`, `…/tags/layout.tsx`
- Modify: `apps/web/app/portal/[studioId]/(schreibtisch)/page.tsx` (Überblick), `…/einrichten/layout.tsx`, `…/geraete/neu/page.tsx`, `…/geraete/[modelId]/instanzen/page.tsx`, `…/geraete/page.tsx`, `…/geraete/[modelId]/layout.tsx`, `…/geraete/[modelId]/ModellRahmen.tsx`, `…/geraete/[modelId]/ModellReiter.tsx`, `…/einstellungen/page.tsx`
- Modify: `apps/web/app/portal/[studioId]/NavInhalt.tsx`, `Rail.tsx`, `MobileNav.tsx`, `(schreibtisch)/layout.tsx`
- Test: `apps/web/app/portal/[studioId]/MobileNav.test.tsx`

**Interfaces:**
- Consumes: `StudioCatalog.isCatalog` über `ladeKatalog`.
- Produces: `nichtImKatalog(studioId: string): Promise<void>` (ruft `notFound()`), `NavInhalt`/`Rail`/`MobileNav` Prop `istKatalog: boolean`, `ModellRahmen`/`ModellReiter` Prop `mitInstanzen: boolean`.

- [ ] **Step 1: Failing test** — in `MobileNav.test.tsx` (vorhandene Render-Hilfen dort benutzen):

```tsx
  it("zeigt im Gymtavo-Studio nur Geraetetypen und Einstellungen", async () => {
    // Render wie in den anderen Tests dieser Datei, zusaetzlich istKatalog
    // und die Schublade oeffnen.
    render(<MobileNav studioId="gy" studioName="Gymtavo" email="a@b.de" zahlen={ZAHLEN} istKatalog />);
    await userEvent.click(screen.getByRole("button", { name: /Menü/ }));
    expect(screen.getByRole("link", { name: /Gerätetypen/ })).toBeTruthy();
    expect(screen.getByRole("link", { name: /Einstellungen/ })).toBeTruthy();
    for (const name of [/Überblick/, /Kurse/, /Tags/, /Leute/]) {
      expect(screen.queryByRole("link", { name })).toBeNull();
    }
  });
```

`ZAHLEN` und den Namen des Menüknopfs aus den bestehenden Tests der Datei übernehmen.

- [ ] **Step 2: Test laufen lassen, er muss scheitern**

Run: `pnpm --filter @fitretro/web exec vitest run "app/portal/[studioId]/MobileNav.test.tsx"`
Expected: FAIL.

- [ ] **Step 3: Navigation**

- `NavInhalt`: Prop `istKatalog: boolean`. Wenn `true`: Gruppe „Katalog“ mit nur einem Link „Gerätetypen“ (`${basis}/geraete`, Meta `${zahlen.geraete}`-frei: keine Meta-Zeile), Gruppe „Verwaltung“ nur mit „Einstellungen“; die Gruppe „Studio“ (Überblick, Kurse), „Tags“ und „Leute“ entfallen. `studioMeta` zeigt „Gymtavo-Katalog“ statt „Trainerportal“. Kommentar: „Das Gymtavo-Studio hat keine Mitglieder, keine Geraete und keine Kurse (Spec 5.1) -- Links dorthin fuehrten auf leere oder gesperrte Seiten.“
- `Rail` und `MobileNav`: Prop `istKatalog?: boolean` (Default `false`) an `NavInhalt` durchreichen.
- `(schreibtisch)/layout.tsx` und `einrichten/layout.tsx`: `istKatalog={katalog.isCatalog}` übergeben.

- [ ] **Step 4: Sperren**

`katalogStudio.ts`:

```ts
import { notFound } from "next/navigation";
import { ladeKatalog } from "./catalog";

/**
 * Bereiche, die es im Gymtavo-Studio nicht gibt: Mitglieder, Kurse, Tags,
 * Geraete mit QR-Code (Spec 5.1, Waechter-Trigger aus 0047). Ein Aufruf
 * per URL endet auf 404 statt auf einer Seite, die so tut, als gaebe es sie.
 * Die Katalogpflege selbst kommt in Etappe 6.
 */
export async function nichtImKatalog(studioId: string): Promise<void> {
  const katalog = await ladeKatalog(studioId);
  if (katalog.isCatalog) notFound();
}
```

Neue Layouts `kurse/layout.tsx`, `leute/layout.tsx`, `tags/layout.tsx` (je gleich, Importpfad anpassen):

```tsx
import { nichtImKatalog } from "../../katalogStudio";

export default async function NurStudioLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: Promise<{ studioId: string }>;
}) {
  await nichtImKatalog((await params).studioId);
  return children;
}
```

- `einrichten/layout.tsx`: am Anfang `await nichtImKatalog(studioId);`.
- `geraete/neu/page.tsx` und `geraete/[modelId]/instanzen/page.tsx`: am Anfang `await nichtImKatalog(studioId);`.
- Überblick `(schreibtisch)/page.tsx`: `const katalog = await ladeKatalog(studioId); if (katalog.isCatalog) redirect(\`/portal/${studioId}/geraete\`);` am Anfang.
- `geraete/page.tsx` im Gymtavo-Studio: Seitentitel „Gerätetypen“, kein Knopf „Gerät hinzufügen“, in der Meta-Zeile entfällt der Teil zu Geräten und Erreichbarkeit.
- `ModellReiter`/`ModellRahmen`: Prop `mitInstanzen` (Default `true`); bei `false` fehlt der Reiter „Einzelne Geräte“. `[modelId]/layout.tsx` übergibt `mitInstanzen={!katalog.isCatalog}`.
- `einstellungen/page.tsx`: `BeitrittscodeKarte` nur, wenn `!katalog.isCatalog` (Katalog per `ladeKatalog` laden, falls die Seite ihn noch nicht hat).

- [ ] **Step 5: Tests und Typen**

Run: `pnpm --filter @fitretro/web exec vitest run app/portal && pnpm typecheck`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add "apps/web/app/portal/[studioId]"
git commit -m "feat(portal): Gymtavo-Studio nur als Katalog -- ohne Leute, Kurse, Tags, Geraete im Raum

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: E2E — neue Abläufe und bestehende Tests bei gefülltem Katalog

**Files:**
- Create: `e2e/helpers/gymtavo.ts`, `e2e/gymtavo.spec.ts`
- Modify: `e2e/einrichten.spec.ts` (~61–90, ~406–420), `e2e/schreibtisch.spec.ts` (Modellanlage über `geraete/neu`), `e2e/trainerportal.spec.ts` (~225 „4 Punkte offen“, ~356 „1 Punkt offen“) und jede weitere Stelle, die der Suchlauf in Step 5 findet

**Interfaces:**
- Produces:

```ts
export const GYMTAVO = "00000000-0000-4000-8000-000000000001";
export async function gymtavoTyp(
  admin: SupabaseClient,
  name: string,
  uebungen?: string[],
): Promise<{ typId: string; typName: string; uebungen: { id: string; name: string }[] }>;
export async function typWaehlen(page: Page, typName: string): Promise<void>;
```

- [ ] **Step 1: Helfer schreiben** — `e2e/helpers/gymtavo.ts`

```ts
import type { Page } from "@playwright/test";
import type { SupabaseClient } from "@supabase/supabase-js";

export const GYMTAVO = "00000000-0000-4000-8000-000000000001";

/**
 * Ein eigener Gymtavo-Typ je Test, mit eindeutigem Namen. Er macht den
 * Test unabhaengig davon, ob der geteilte Katalog gerade leer ist: sobald
 * es einen Typ gibt, ist das Feld "Gymtavo-Gerätetyp" Pflicht (Nachtrag
 * 10.1), und in der CI fuellen die Integrationstests den Katalog ohnehin.
 */
export async function gymtavoTyp(
  admin: SupabaseClient,
  name: string,
  uebungen: string[] = [],
): Promise<{ typId: string; typName: string; uebungen: { id: string; name: string }[] }> {
  const typName = `${name} ${crypto.randomUUID().slice(0, 6)}`;
  const { data: typ, error } = await admin
    .from("equipment_models")
    .insert({ studio_id: GYMTAVO, name: typName, load_step: 2.5 })
    .select("id")
    .single();
  if (error) throw error;

  const angelegt: { id: string; name: string }[] = [];
  for (const [index, uebungName] of uebungen.entries()) {
    const eindeutig = `${uebungName} ${crypto.randomUUID().slice(0, 6)}`;
    const { data: uebung, error: uebungFehler } = await admin
      .from("exercises")
      .insert({ studio_id: GYMTAVO, name: eindeutig, target_min: 8, target_max: 12 })
      .select("id")
      .single();
    if (uebungFehler) throw uebungFehler;
    const { error: linkFehler } = await admin
      .from("equipment_model_exercises")
      .insert({ equipment_model_id: typ.id, exercise_id: uebung.id, sort_order: index + 1 });
    if (linkFehler) throw linkFehler;
    angelegt.push({ id: uebung.id, name: eindeutig });
  }
  return { typId: typ.id, typName, uebungen: angelegt };
}

/** Typ ueber die Suche waehlen -- die Liste kann hunderte Testtypen tragen. */
export async function typWaehlen(page: Page, typName: string): Promise<void> {
  await page.getByRole("button", { name: "Gymtavo-Gerätetyp" }).click();
  await page.getByRole("searchbox", { name: "Typ suchen" }).fill(typName);
  await page.getByRole("option", { name: typName }).click();
}
```

- [ ] **Step 2: Neue Abläufe** — `e2e/gymtavo.spec.ts`

```ts
import { expect, test } from "@playwright/test";
import { createClient } from "@supabase/supabase-js";
import { studioMitTrainer } from "./helpers/studio";
import { anmelden, E2E_PASSWORD } from "./helpers/login";
import { GYMTAVO, gymtavoTyp, typWaehlen } from "./helpers/gymtavo";
import { radWaehlen } from "./helpers/rad";

// Spec 2026-10-06-gymtavo-katalog-offener-zugang-design.md, Nachtrag 10.1.

test("Ein neues Modell bekommt seinen Gymtavo-Typ, ohne Typ geht es nicht weiter", async ({ page }) => {
  const { admin, studioId } = await studioMitTrainer(page, "gymtavo-anlegen");
  const { typName, typId } = await gymtavoTyp(admin, "Kabelzug");

  await page.goto(`/portal/${studioId}/geraete/neu?art=typ&kategorie=kraft`);
  await page.getByLabel("Name").fill("Kabelturm");
  await radWaehlen(page, "Schritt", "5");
  await page.getByRole("button", { name: "Weiter" }).click();
  await expect(page.getByRole("alert")).toContainText("Wähle den Gymtavo-Gerätetyp");

  await typWaehlen(page, typName);
  await page.getByRole("button", { name: "Weiter" }).click();
  await expect(page).toHaveURL(new RegExp(`/portal/${studioId}/geraete/[0-9a-f-]+/einstellungen`));

  const { data } = await admin.from("equipment_models").select("catalog_model_id").eq("studio_id", studioId).single();
  expect(data?.catalog_model_id).toBe(typId);
});

test("Ein altes Modell zeigt den Hinweis, bis es zugeordnet ist", async ({ page }) => {
  const { admin, studioId } = await studioMitTrainer(page, "gymtavo-altbestand");
  const { typName } = await gymtavoTyp(admin, "Beinpresse");
  const { data: modell, error } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioId, name: "Beinpresse alt", load_step: 5 })
    .select("id")
    .single();
  if (error) throw error;

  await page.goto(`/portal/${studioId}/geraete/${modell.id}`);
  await page.getByText(/Punkte? offen/).click();
  const band = page.getByRole("list", { name: "Noch zu tun" });
  await expect(band).toContainText("Kein Gymtavo-Typ");

  await typWaehlen(page, typName);
  await page.getByRole("button", { name: "Änderungen speichern" }).click();
  await expect(page.getByText("Gespeichert ✓")).toBeVisible();
  await page.reload();
  await expect(page.getByText("Kein Gymtavo-Typ")).toHaveCount(0);
});

test("Gymtavo-Uebungen stehen am Modell, eine weitere laesst sich anhaengen, ein eigenes Video ergaenzen", async ({ page }) => {
  const { admin, studioId } = await studioMitTrainer(page, "gymtavo-uebungen");
  const typ = await gymtavoTyp(admin, "Langhantel", ["Bankdrücken"]);
  const anderer = await gymtavoTyp(admin, "Kabelzug", ["Face Pull"]);
  const { data: modell, error } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioId, name: "Hantelbank", load_step: 2.5, catalog_model_id: typ.typId })
    .select("id")
    .single();
  if (error) throw error;

  await page.goto(`/portal/${studioId}/geraete/${modell.id}/uebungen`);
  const gymtavo = page.getByRole("list", { name: "Gymtavo-Übungen am Modell" });
  await expect(gymtavo).toContainText(typ.uebungen[0]!.name);
  await expect(gymtavo).toContainText("vom Typ");

  await page.getByRole("button", { name: "Gymtavo-Übung anhängen" }).click();
  await page.getByRole("button", { name: "Gymtavo-Übung" }).click();
  await page.getByRole("searchbox", { name: "Übung suchen" }).fill(anderer.uebungen[0]!.name);
  await page.getByRole("option", { name: new RegExp(anderer.uebungen[0]!.name) }).click();
  await page.getByRole("button", { name: "Anhängen" }).click();
  await expect(gymtavo).toContainText(anderer.uebungen[0]!.name);
  await expect(gymtavo).toContainText("angehängt");

  await page.getByRole("button", { name: `${typ.uebungen[0]!.name} bearbeiten` }).click();
  await page.getByRole("button", { name: "Eigenes Video ergänzen" }).click();
  await expect(page.getByLabel("Einweisungsvideo hochladen")).toBeVisible();

  const { data: links } = await admin
    .from("equipment_model_exercises")
    .select("exercise_id")
    .eq("equipment_model_id", modell.id);
  expect(links?.map((l) => l.exercise_id).sort()).toEqual(
    [typ.uebungen[0]!.id, anderer.uebungen[0]!.id].sort(),
  );
});

test("Das Gymtavo-Studio zeigt keine Mitglieder, keine Geraete im Raum und keine Tags", async ({ page }) => {
  const admin = createClient(process.env.SUPABASE_URL!, process.env.SUPABASE_SERVICE_ROLE_KEY!, {
    auth: { persistSession: false },
  });
  const email = `gymtavo-team-${crypto.randomUUID()}@example.test`;
  const { data: nutzer, error } = await admin.auth.admin.createUser({
    email,
    password: E2E_PASSWORD,
    email_confirm: true,
  });
  if (error) throw error;
  const { error: rolleFehler } = await admin
    .from("studio_memberships")
    .insert({ studio_id: GYMTAVO, user_id: nutzer.user.id, role: "trainer" });
  if (rolleFehler) throw rolleFehler;
  const typ = await gymtavoTyp(admin, "Katalogtyp");
  await anmelden(page, email);

  await page.goto(`/portal/${GYMTAVO}`);
  await expect(page).toHaveURL(new RegExp(`/portal/${GYMTAVO}/geraete$`));
  await expect(page.getByRole("heading", { name: "Gerätetypen" })).toBeVisible();
  await expect(page.getByRole("link", { name: /Leute/ })).toHaveCount(0);
  await expect(page.getByRole("link", { name: /Tags/ })).toHaveCount(0);
  await expect(page.getByRole("link", { name: /Gerät hinzufügen/ })).toHaveCount(0);

  await page.goto(`/portal/${GYMTAVO}/geraete/${typ.typId}`);
  await expect(page.getByRole("link", { name: /Einzelne Geräte/ })).toHaveCount(0);
  await expect(page.getByText("Kein Gymtavo-Typ")).toHaveCount(0);

  for (const pfad of ["leute", "tags", "kurse", "einrichten", `geraete/${typ.typId}/instanzen`]) {
    const antwort = await page.goto(`/portal/${GYMTAVO}/${pfad}`);
    expect(antwort?.status(), pfad).toBe(404);
  }
});
```

Vor dem Lauf prüfen: Name der Kategorie-Abfrage auf `geraete/neu` (`?art=typ&kategorie=kraft` öffnet laut Kommentar in `neu/page.tsx` direkt das Formular; falls nicht, den Klickweg aus `schreibtisch.spec.ts` übernehmen), Signatur von `radWaehlen` (`e2e/helpers/rad.ts`) und von `anmelden` (`e2e/helpers/login.ts`). Wenn der Gymtavo-Trainer nur ein Studio hat, leitet `/portal` direkt dorthin – der Test geht deshalb gleich auf `/portal/${GYMTAVO}`.

- [ ] **Step 3: Neue Abläufe laufen lassen**

Run: `E2E_PORT=3017 pnpm test:e2e e2e/gymtavo.spec.ts`
Expected: PASS. Schlägt ein Lauf wegen Kompilierung des Dev-Servers fehl („Execution context was destroyed“), einmal wiederholen; bei wiederholtem Fehlschlag gegen einen Produktionsbau prüfen (Memory „Lokale Testumgebung: Fallen“).

- [ ] **Step 4: Bestehende Tests anpassen**

Grundsatz: Jeder Test, der ein Modell per UI anlegt oder offene Punkte zählt, legt mit `gymtavoTyp` einen eigenen Typ an. Damit ist der Katalog im Test sicher gefüllt, und das Ergebnis hängt nicht davon ab, was andere Tests liegen lassen.

- Modellanlage per UI (`einrichten.spec.ts` ~61 und ~406, `schreibtisch.spec.ts` beim Formular auf `geraete/neu`): nach den Namensfeldern `await typWaehlen(page, (await gymtavoTyp(admin, "Kabelzug")).typName);`. Wo der Test `admin` nicht destrukturiert, `const { admin, studioId } = await studioMitTrainer(…)` schreiben.
- Zählungen offener Punkte (`trainerportal.spec.ts` ~225 „4 Punkte offen“, ~356 „1 Punkt offen“): das per `admin` angelegte Modell bekommt `catalog_model_id: (await gymtavoTyp(admin, "…")).typId`. Damit bleibt die Zahl gleich, egal ob der Katalog sonst leer ist.

- [ ] **Step 5: Weitere betroffene Stellen finden**

Run: `grep -n "Neues Modell anlegen\|geraete/neu\|Punkte\? offen\|Punkt offen\|Weiter zu den Einstellungen\|uebungen\`" e2e/*.spec.ts`
Jede Fundstelle prüfen: Legt sie ein Modell per UI an, zählt sie offene Punkte oder prüft sie den Inhalt des Reiters Übungen (dort stehen jetzt die Überschriften „Gymtavo-Übungen“/„Eigene Übungen“ und die Liste heißt weiter „Übungen am Modell“)? Dann nach Step 4 anpassen.

- [ ] **Step 6: Gesamten E2E-Lauf mit gefülltem Katalog**

Run: `E2E_PORT=3017 pnpm test:e2e`
Expected: PASS. Vorher sicherstellen, dass der Katalog nicht leer ist (die neuen Tests legen Typen an; zur Not `pnpm test:integration tests/integration/domain-gymtavo-portal.test.ts` vorher laufen lassen). Rote Tests mit der Memory „Lokale Testumgebung: Fallen“ abgleichen und umgebungsbedingte Fehler im Bericht als solche benennen.

- [ ] **Step 7: Commit**

```bash
git add e2e
git commit -m "test(e2e): Gymtavo-Typ zuordnen, Gymtavo-Uebungen am Modell, Gymtavo-Studio im Portal

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: Gesamtprüfung und Plan abhaken

**Files:**
- Modify: `docs/superpowers/plans/2026-10-10-gymtavo-katalog-etappe5-portal.md` (Ergebnis-Abschnitt am Ende)

- [ ] **Step 1: Volle Testreihe**

Run nacheinander:
```bash
pnpm typecheck
pnpm test
pnpm test:integration
E2E_PORT=3017 pnpm test:e2e
```
Expected: alles grün. Bekannte Umgebungsfehler (`completeSession`-Tests wegen Docker-Uhr, siehe Memory) gegen einen sauberen `master`-Worktree gegenprüfen und im Bericht benennen.

- [ ] **Step 2: Sichtcheck im Browser** gegen das lokale Backend (`pnpm --filter @fitretro/web dev -p 3017`): Modell mit Typ anlegen, Reiter Übungen, Gymtavo-Studio. Eine Akzentfläche je Bildschirm.

- [ ] **Step 3: Ergebnis-Abschnitt anhängen**

```markdown
## Ergebnis (umgesetzt am <Datum>)

- Alle Tasks abgehakt; Testläufe: <Zahlen aus Step 1>.
- Für Etappe 6: Die Katalogpflege baut auf `isCatalog` in `getStudioCatalog` und den Sperren in `katalogStudio.ts` auf. Neue Typen und Übungen legt das Portal dort noch nicht an.
```

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/plans/2026-10-10-gymtavo-katalog-etappe5-portal.md
git commit -m "docs(plan): Etappe 5 umgesetzt und abgehakt

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
