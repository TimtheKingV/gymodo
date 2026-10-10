# Gymtavo-Katalog Etappe 2: Import — Umsetzungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `pnpm catalog:import [datei]` liest `catalog/gymtavo.json`, prüft sie vollständig und gleicht den Gymtavo-Katalog per Upsert über `catalog_key` ab, mit Trockenlauf, ohne je zu löschen. Dazu kommt der volle Bestand aus dem GYMTAVO-Paket als Datei im Repo.

**Architecture:** Nach dem Muster von `pnpm tags`: Die Logik liegt im Domain-Paket unter dem Unterpfad `@fitretro/domain/katalog-import`, das Skript `scripts/catalog-import.ts` ist nur die Kommandozeile.
- Prüfung (`katalog-datei.ts`, `katalog-medien.ts`) und Planbildung (`katalog-plan.ts`) sind reine Funktionen mit Unit-Tests.
- Lesen und Schreiben (`katalog-import.ts`) arbeiten mit einem Service-Client und sind gegen das lokale Supabase getestet.
- Migration 0048 ergänzt `catalog_key`.

**Tech Stack:** TypeScript, zod 3, supabase-js 2 (Service-Rolle, Storage), Vitest, tsx, Postgres-Migration. Für den Konverter ein einmaliges Python-3-Skript außerhalb des Repos.

**Spec:** `docs/superpowers/specs/2026-10-06-gymtavo-katalog-offener-zugang-design.md`, Abschnitt 9 und 9.1 (Nachtrag vom 10. Oktober 2026).

## Global Constraints

- Gymtavo-Studio: `00000000-0000-4000-8000-000000000001`, `is_catalog = true`.
- Schlüsselmuster: `^[a-z0-9_]+$`. `catalog_key` ist eindeutig über `(studio_id, catalog_key)`.
- Medienpfade: `<Gymtavo-ID>/catalog/photos/<key>-<sha256, 8 Zeichen>.<png|jpg>` in `equipment-photos`, `<Gymtavo-ID>/catalog/videos/<key>-<hash>.mp4` in `instruction-videos`.
- Video höchstens 45 s (`MAX_VIDEO_SECONDS`), Foto höchstens 10 MiB, Video höchstens 50 MiB (`media.ts`).
- Nie löschen: weder Zeilen noch Storage-Objekte. Fehlendes wird gemeldet.
- Außerhalb von `127.0.0.1`/`localhost` schreibt das Skript nur mit `--ja`. `--dry-run` braucht kein `--ja`.
- Integrationstests laufen gegen das **geteilte** lokale Supabase: nie `supabase db reset`, nur eigene Zeilen und Objekte (Präfix `t_<zufall>_`) abräumen.
- Produktion bekommt Migration und Import erst nach dem Merge und auf Tims Wort. Gepusht wird erst auf Ansage.
- Commits: deutsch mit ae/oe/ue, je Schritt ein Commit, `feat(katalog): …`, Trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Nach jedem Commit `git log -1 --format=%B` prüfen.
- Kommentare in ASCII, sie begründen statt zu beschreiben. Meldungen im Code ebenfalls ASCII (wie in `scripts/tags.ts`).
- TypeScript läuft mit `strict`, `noUncheckedIndexedAccess` und `exactOptionalPropertyTypes`.

## Review Focus

1. **Abgebrochener Lauf:** Der erste Import bricht nach den Gerätetypen ab, der zweite muss den Rest ergänzen, ohne Dubletten. Getestet in Task 6, „setzt nach einem Abbruch fort“.
2. **Zahlen aus der Datenbank:** `numeric`-Werte wie `0.1` kommen aus PostgREST unter Umständen als Text zurück. Ein zweiter Lauf muss trotzdem „unverändert“ melden. Getestet in Task 4 (Text gegen Zahl) und Task 6 (Laufband mit 0,1 km/h).
3. **Eine Übung an zwei Gerätetypen:** Das Video hängt an beiden Verknüpfungen, und ein Videowechsel aktualisiert beide. Getestet in Task 6, `trizeps_druecken`.
4. **Video aus dem Portal:** Ein im Portal hochgeladenes Video an einer Katalogverknüpfung darf der Import nie anfassen. Getestet in Task 4 und Task 6.
5. **Objekt schon im Storage:** Ein früherer, abgebrochener Lauf hat das Objekt schon hochgeladen. Der Upload muss das hinnehmen statt abzubrechen. Getestet in Task 6, „nimmt ein schon hochgeladenes Objekt hin“.

---

## Dateien

| Datei | Verantwortung |
|---|---|
| `supabase/migrations/0048_catalog_key.sql` | Spalte, Muster, Eindeutigkeit |
| `packages/domain/src/katalog-datei.ts` | Format (zod), Querprüfungen, Fehlerorte, `GYMTAVO_STUDIO_ID` |
| `packages/domain/src/katalog-medien.ts` | Medien lesen, Typ, Größe und Dauer prüfen, Storage-Pfade mit Hash |
| `packages/domain/src/katalog-laden.ts` | Datei von der Platte lesen, Medienpfade relativ zur Datei auflösen |
| `packages/domain/src/katalog-plan.ts` | Ist-Stand gegen Datei: Posten neu/geändert/unverändert, Gemeldetes, Uploads, Bericht |
| `packages/domain/src/katalog-import.ts` | Ist-Stand lesen, Plan ausführen, Re-Exporte des Unterpfads |
| `packages/domain/src/katalog-testdaten.ts` | Beispielkatalog und Medienbytes für Unit- und Integrationstests |
| `scripts/catalog-import.ts` | Kommandozeile |
| `catalog/gymtavo.json`, `catalog/media/` | Vom Konverter erzeugter Bestand |
| `tests/integration/katalog-key.test.ts` | Migration |
| `tests/integration/katalog-import.test.ts` | Import gegen echtes Postgres und Storage |

---

### Task 1: Migration 0048 `catalog_key`

**Files:**
- Create: `supabase/migrations/0048_catalog_key.sql`
- Test: `tests/integration/katalog-key.test.ts`

**Interfaces:**
- Produces: Spalte `catalog_key text null` an `equipment_models` und `exercises`, Constraints `equipment_models_catalog_key_format`, `equipment_models_catalog_key_unique` (`unique (studio_id, catalog_key)`), entsprechend `exercises_catalog_key_format` und `exercises_catalog_key_unique`. Die Upserts in Task 6 nutzen `onConflict: "studio_id,catalog_key"`.

- [ ] **Step 1: Den fehlschlagenden Test schreiben**

```ts
import { afterAll, describe, expect, it } from "vitest";
import { serviceClient } from "./helpers/clients.js";

// Spec 2026-10-06-gymtavo-katalog-offener-zugang-design.md, Abschnitt 9.1.
const GYMTAVO = "00000000-0000-4000-8000-000000000001";
const admin = serviceClient();
const angelegt: { tabelle: "equipment_models" | "exercises"; id: string }[] = [];
const studios: string[] = [];

function schluessel(rest: string): string {
  return `t_${crypto.randomUUID().slice(0, 8)}_${rest}`;
}

async function modell(studioId: string, catalogKey: string | null) {
  const ergebnis = await admin
    .from("equipment_models")
    .insert({ studio_id: studioId, name: "Schluesseltest", load_step: 1, catalog_key: catalogKey })
    .select("id")
    .maybeSingle();
  if (ergebnis.data) angelegt.push({ tabelle: "equipment_models", id: ergebnis.data.id });
  return ergebnis;
}

async function uebung(studioId: string, catalogKey: string | null) {
  const ergebnis = await admin
    .from("exercises")
    .insert({ studio_id: studioId, name: "Schluesseltest", target_min: 8, target_max: 12, catalog_key: catalogKey })
    .select("id")
    .maybeSingle();
  if (ergebnis.data) angelegt.push({ tabelle: "exercises", id: ergebnis.data.id });
  return ergebnis;
}

afterAll(async () => {
  for (const { tabelle, id } of angelegt) await admin.from(tabelle).delete().eq("id", id);
  if (studios.length > 0) await admin.from("studios").delete().in("id", studios);
});

describe("catalog_key", () => {
  it("ist je Studio eindeutig", async () => {
    const key = schluessel("doppelt");
    expect((await modell(GYMTAVO, key)).error).toBeNull();
    expect((await modell(GYMTAVO, key)).error?.code).toBe("23505");
    expect((await uebung(GYMTAVO, key)).error).toBeNull();
    expect((await uebung(GYMTAVO, key)).error?.code).toBe("23505");
  });

  it("erlaubt denselben Schluessel in einem anderen Studio", async () => {
    const { data, error } = await admin.from("studios").insert({ name: "Schluessel Studio" }).select("id").single();
    if (error) throw error;
    studios.push(data.id);
    const key = schluessel("anderes_studio");

    expect((await modell(GYMTAVO, key)).error).toBeNull();
    expect((await modell(data.id, key)).error).toBeNull();
  });

  it("erlaubt beliebig viele Zeilen ohne Schluessel", async () => {
    expect((await modell(GYMTAVO, null)).error).toBeNull();
    expect((await modell(GYMTAVO, null)).error).toBeNull();
  });

  it("lehnt einen Schluessel ausserhalb des Musters ab", async () => {
    expect((await modell(GYMTAVO, "Brust-Presse")).error?.code).toBe("23514");
    expect((await uebung(GYMTAVO, "bank drücken")).error?.code).toBe("23514");
  });
});
```

- [ ] **Step 2: Test laufen lassen, er muss scheitern**

Run: `pnpm vitest run --config vitest.config.ts tests/integration/katalog-key.test.ts`
Expected: FAIL. PostgREST meldet `PGRST204 Could not find the 'catalog_key' column`.

- [ ] **Step 3: Migration schreiben**

```sql
-- Gymtavo-Katalog Etappe 2: Import aus Datei, Spec
-- 2026-10-06-gymtavo-katalog-offener-zugang-design.md, Abschnitt 9.1.
--
-- Der Import gleicht catalog/gymtavo.json mit dem Gymtavo-Studio ab. Er
-- braucht eine Identitaet, die nicht die UUID ist: die Datei kennt keine
-- UUIDs, und ein umbenannter Geraetetyp muss derselbe Datensatz bleiben,
-- weil Saetze und Studio-Zuordnungen auf ihn zeigen.

-- Ein echter Unique-Constraint statt eines Teilindex "where catalog_key is
-- not null": PostgREST-Upserts (on_conflict) brauchen einen Constraint oder
-- einen Index ohne Bedingung. NULL kollidiert in Postgres ohnehin nicht --
-- von Hand angelegte Katalogzeilen und alle Studiozeilen bleiben frei.
--
-- Kein Zwang auf das Gymtavo-Studio: ein Studio, das seinem eigenen Modell
-- einen Schluessel gibt, beruehrt den Katalog nicht, weil die Eindeutigkeit
-- je Studio gilt und der Import nur das Gymtavo-Studio liest.
alter table public.equipment_models
  add column catalog_key text
    constraint equipment_models_catalog_key_format
    check (catalog_key ~ '^[a-z0-9_]+$'),
  add constraint equipment_models_catalog_key_unique
    unique (studio_id, catalog_key);

alter table public.exercises
  add column catalog_key text
    constraint exercises_catalog_key_format
    check (catalog_key ~ '^[a-z0-9_]+$'),
  add constraint exercises_catalog_key_unique
    unique (studio_id, catalog_key);
```

- [ ] **Step 4: Migration lokal anwenden, ohne Reset**

Run: `pnpm exec supabase migration up`
Expected: `Applying migration 0048_catalog_key.sql...`, danach `Local database is up to date.` Kein `db reset`, die Datenbank teilen sich mehrere Sitzungen.

- [ ] **Step 5: Test laufen lassen, er muss bestehen**

Run: `pnpm vitest run --config vitest.config.ts tests/integration/katalog-key.test.ts`
Expected: PASS (4 Tests).

- [ ] **Step 6: Commit**

```bash
git add supabase/migrations/0048_catalog_key.sql tests/integration/katalog-key.test.ts
git commit -m "feat(katalog): catalog_key an Geraetetypen und Uebungen (Migration 0048)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log -1 --format=%B
```

---

### Task 2: Format und Prüfung der Datei

**Files:**
- Create: `packages/domain/src/katalog-datei.ts`
- Create: `packages/domain/src/katalog-testdaten.ts`
- Modify: `packages/domain/package.json` (exports: `"./katalog-testdaten": "./src/katalog-testdaten.ts"`)
- Test: `packages/domain/src/katalog-datei.test.ts`

**Interfaces:**
- Produces:
  - `GYMTAVO_STUDIO_ID: string`
  - `type KatalogDatei`, `type Geraetetyp`, `type Uebung`, `type Einstellung` (zod-Infer)
  - `type Pruefung<T> = { ok: true; wert: T } | { ok: false; fehler: string[] }`
  - `pruefeKatalog(roh: unknown): Pruefung<KatalogDatei>`
  - `ort(roh: unknown, pfad: ReadonlyArray<string | number>): string`
  - Testdaten: `beispielKatalog(praefix?: string): { roh: BeispielRoh; dateien: Map<string, Uint8Array> }`, `pngBytes(rauschen?: number): Uint8Array`, `jpegBytes(rauschen?: number): Uint8Array`, `mp4Bytes(sekunden: number | null, rauschen?: number): Uint8Array`

- [ ] **Step 1: Testdaten anlegen**

`packages/domain/src/katalog-testdaten.ts`:

```ts
/**
 * Ein kleiner, gueltiger Katalog fuer Unit- und Integrationstests.
 *
 * Er deckt mit Absicht die Faelle ab, an denen ein Import scheitern kann:
 * eine Uebung an zwei Geraetetypen (Video an beiden Verknuepfungen), ein
 * Cardiotyp mit Nachkomma-Rastung und Nebenbelastung, eine Enum-Einstellung
 * und eine Uebung ohne Video. Der Praefix trennt Testlaeufe in der geteilten
 * lokalen Datenbank voneinander.
 */

function ascii(text: string): number[] {
  return [...text].map((zeichen) => zeichen.charCodeAt(0));
}

function uint32(wert: number): number[] {
  return [(wert >>> 24) & 0xff, (wert >>> 16) & 0xff, (wert >>> 8) & 0xff, wert & 0xff];
}

function box(typ: string, inhalt: number[]): number[] {
  return [...uint32(8 + inhalt.length), ...ascii(typ), ...inhalt];
}

/** Gueltige PNG-Signatur; das Rauschen macht den Hash und damit den Pfad verschieden. */
export function pngBytes(rauschen = 0): Uint8Array {
  return new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, ...uint32(rauschen)]);
}

export function jpegBytes(rauschen = 0): Uint8Array {
  return new Uint8Array([0xff, 0xd8, 0xff, 0xe0, ...uint32(rauschen), 0xff, 0xd9]);
}

/**
 * MP4 mit ftyp und, wenn Sekunden gegeben sind, moov/mvhd -- genug fuer
 * sniffMediaType und readVideoDurationSeconds. null laesst mvhd weg: eine
 * Datei, deren Dauer sich nicht lesen laesst.
 */
export function mp4Bytes(sekunden: number | null, rauschen = 0): Uint8Array {
  const ftyp = box("ftyp", [...ascii("isom"), ...uint32(512), ...ascii("isomiso2")]);
  const moov =
    sekunden === null
      ? []
      : box("moov", box("mvhd", [0, 0, 0, 0, ...uint32(0), ...uint32(0), ...uint32(1000), ...uint32(sekunden * 1000)]));
  return new Uint8Array([...ftyp, ...moov, ...box("free", uint32(rauschen))]);
}

export function beispielKatalog(p = "") {
  const roh = {
    format: 1,
    muscles: [
      { key: "brust", name: "Brust" },
      { key: "trizeps", name: "Trizeps" },
      { key: "beine", name: "Beine" },
    ],
    sources: [{ key: "quelle_a", title: "Quelle A", url: "https://example.org/a", accessed_at: "2026-09-13" }],
    equipment: [
      {
        key: `${p}brustpresse`,
        name: "Brustpresse",
        category: "kraft",
        manufacturer: null as string | null,
        photo: "media/photos/brustpresse.png" as string | null,
        load_unit: "kg",
        load_step: 2.5,
        load_min: 0,
        load_max: 120 as number | null,
        secondary: null as { unit: string; step: number; min: number; max: number } | null,
        settings: [
          { key: "sitzhoehe", label: "Sitzhoehe", kind: "number", min: 1, max: 10, step: 1, unit: null } as Record<string, unknown>,
          { key: "griff", label: "Griff", kind: "enum", allowed_values: ["eng", "weit"] } as Record<string, unknown>,
        ],
        exercises: [`${p}brustpresse_neutral`, `${p}trizeps_druecken`],
      },
      {
        key: `${p}trizepsmaschine`,
        name: "Trizepsmaschine",
        category: "kraft",
        manufacturer: null as string | null,
        photo: null as string | null,
        load_unit: "kg",
        load_step: 5,
        load_min: 0,
        load_max: null as number | null,
        secondary: null as { unit: string; step: number; min: number; max: number } | null,
        settings: [] as Record<string, unknown>[],
        exercises: [`${p}trizeps_druecken`],
      },
      {
        key: `${p}laufband`,
        name: "Laufband",
        category: "cardio",
        manufacturer: "Precor" as string | null,
        photo: null as string | null,
        load_unit: "kmh",
        load_step: 0.1,
        load_min: 0,
        load_max: 25 as number | null,
        secondary: { unit: "pct", step: 0.5, min: 0, max: 15 } as { unit: string; step: number; min: number; max: number } | null,
        settings: [] as Record<string, unknown>[],
        exercises: [`${p}gehen`],
      },
    ],
    exercises: [
      {
        key: `${p}brustpresse_neutral`,
        name: "Brustpresse neutral",
        description: "Einstellen:\n- Sitz auf Brusthoehe." as string | null,
        volume_kind: "reps",
        target_min: 8,
        target_max: 12,
        video: { file: "media/videos/brustpresse_neutral.mp4", duration_s: 6 } as { file: string; duration_s: number } | null,
        grip: "neutral" as string | null,
        muscles: [
          { muscle: "brust", role: "primary" },
          { muscle: "trizeps", role: "secondary" },
        ],
        review: "draft",
        sources: ["quelle_a"],
      },
      {
        key: `${p}trizeps_druecken`,
        name: "Trizepsdruecken",
        description: null as string | null,
        volume_kind: "reps",
        target_min: 10,
        target_max: 15,
        video: { file: "media/videos/trizeps.mp4", duration_s: 5 } as { file: string; duration_s: number } | null,
        grip: "pronated" as string | null,
        muscles: [{ muscle: "trizeps", role: "primary" }],
        review: "reviewed",
        sources: [] as string[],
      },
      {
        key: `${p}gehen`,
        name: "Laufband Gehen",
        description: null as string | null,
        volume_kind: "seconds",
        target_min: 60,
        target_max: 1800,
        video: null as { file: string; duration_s: number } | null,
        grip: null as string | null,
        muscles: [{ muscle: "beine", role: "primary" }],
        review: "draft",
        sources: [] as string[],
      },
    ],
  };
  const dateien = new Map<string, Uint8Array>([
    ["media/photos/brustpresse.png", pngBytes(1)],
    ["media/videos/brustpresse_neutral.mp4", mp4Bytes(6, 2)],
    ["media/videos/trizeps.mp4", mp4Bytes(5, 3)],
  ]);
  return { roh, dateien };
}

export type BeispielRoh = ReturnType<typeof beispielKatalog>["roh"];
```

In `packages/domain/package.json` unter `exports` ergänzen: `"./katalog-testdaten": "./src/katalog-testdaten.ts"`. Den Unterpfad `./katalog-import` legt Task 6 an.

- [ ] **Step 2: Die fehlschlagenden Tests schreiben**

`packages/domain/src/katalog-datei.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { pruefeKatalog } from "./katalog-datei.js";
import { beispielKatalog } from "./katalog-testdaten.js";

function fehlerVon(aendern: (roh: ReturnType<typeof beispielKatalog>["roh"]) => void): string[] {
  const { roh } = beispielKatalog();
  aendern(roh);
  const pruefung = pruefeKatalog(roh);
  if (pruefung.ok) throw new Error("Pruefung haette scheitern muessen");
  return pruefung.fehler;
}

describe("pruefeKatalog", () => {
  it("laesst den Beispielkatalog durch", () => {
    const pruefung = pruefeKatalog(beispielKatalog().roh);
    expect(pruefung.ok).toBe(true);
    if (pruefung.ok) expect(pruefung.wert.equipment.map((g) => g.key)).toEqual(["brustpresse", "trizepsmaschine", "laufband"]);
  });

  it("nennt den Ort mit Index und Schluessel", () => {
    expect(fehlerVon((roh) => delete (roh.equipment[2] as Record<string, unknown>).load_step)).toEqual([
      'equipment[2] "laufband" load_step: fehlt',
    ]);
  });

  it("sammelt alle Fehler auf einmal", () => {
    const fehler = fehlerVon((roh) => {
      roh.equipment[0]!.load_unit = "lbs";
      (roh.exercises[0] as Record<string, unknown>).grp = "x";
    });
    expect(fehler).toEqual([
      'equipment[0] "brustpresse" load_unit: ist "lbs", erlaubt: kg, watt, level, kmh, pct, rpm',
      'exercises[0] "brustpresse_neutral": unbekanntes Feld "grp"',
    ]);
  });

  it("verlangt die Nebenbelastung vollstaendig", () => {
    expect(fehlerVon((roh) => delete (roh.equipment[2]!.secondary as Record<string, unknown>).max)).toEqual([
      'equipment[2] "laufband" secondary.max: fehlt',
    ]);
  });

  it("prueft Schluessel, Format und Wurzel", () => {
    expect(fehlerVon((roh) => (roh.equipment[0]!.key = "Brust-Presse"))).toContain(
      'equipment[0] "Brust-Presse" key: darf nur a-z, 0-9 und _ enthalten',
    );
    expect(fehlerVon((roh) => (roh.format = 2))).toEqual(["format: muss 1 sein"]);
    const liste = pruefeKatalog([]);
    expect(liste.ok ? [] : liste.fehler).toEqual(["Datei: muss Objekt sein, ist Liste"]);
  });

  it("prueft Einstellungen", () => {
    expect(fehlerVon((roh) => (roh.equipment[0]!.settings[1]!.allowed_values = ["eng"]))).toEqual([
      'equipment[0] "brustpresse" settings[1] "griff" allowed_values: braucht mindestens zwei Werte',
    ]);
    expect(fehlerVon((roh) => (roh.equipment[0]!.settings[1]!.allowed_values = ["eng", "eng"]))).toEqual([
      'equipment[0] "brustpresse" settings[1] "griff": allowed_values enthaelt "eng" mehrfach',
    ]);
    expect(fehlerVon((roh) => (roh.equipment[0]!.settings[0]!.allowed_values = ["a", "b"]))).toEqual([
      'equipment[0] "brustpresse" settings[0] "sitzhoehe": unbekanntes Feld "allowed_values"',
    ]);
    expect(fehlerVon((roh) => (roh.equipment[0]!.settings[0]!.kind = "slider"))).toEqual([
      'equipment[0] "brustpresse" settings[0] "sitzhoehe" kind: muss number oder enum sein',
    ]);
    expect(fehlerVon((roh) => (roh.equipment[0]!.settings[0]!.min = 11))).toEqual([
      'equipment[0] "brustpresse" settings[0] "sitzhoehe": max ist kleiner als min',
    ]);
  });

  it("prueft Belastungsgrenzen", () => {
    expect(fehlerVon((roh) => (roh.equipment[0]!.load_max = -1))).toEqual([
      'equipment[0] "brustpresse" load_max: darf nicht negativ sein',
    ]);
    expect(fehlerVon((roh) => (roh.equipment[0]!.load_min = 130))).toEqual([
      'equipment[0] "brustpresse": load_max ist kleiner als load_min',
    ]);
    expect(fehlerVon((roh) => (roh.equipment[0]!.load_step = 0))).toEqual([
      'equipment[0] "brustpresse" load_step: muss groesser als 0 sein',
    ]);
  });

  it("prueft Schluessel und Verweise ueber Listen hinweg", () => {
    expect(fehlerVon((roh) => (roh.equipment[1]!.key = "brustpresse"))).toEqual([
      'equipment: Schluessel "brustpresse" kommt mehrfach vor',
    ]);
    expect(fehlerVon((roh) => roh.equipment[2]!.exercises.push("rudern"))).toEqual([
      'equipment[2] "laufband" exercises: Uebung "rudern" gibt es in exercises nicht',
    ]);
    expect(fehlerVon((roh) => (roh.equipment[2]!.exercises = []))).toEqual([
      'exercises[2] "gehen": haengt an keinem Geraetetyp',
    ]);
  });

  it("prueft den Zielkorridor gegen die Umfangsart", () => {
    expect(fehlerVon((roh) => (roh.exercises[0]!.target_min = 13))).toEqual([
      'exercises[0] "brustpresse_neutral": target_max ist kleiner als target_min',
    ]);
    expect(fehlerVon((roh) => (roh.exercises[0]!.target_max = 1001))).toEqual([
      'exercises[0] "brustpresse_neutral": target_max ist groesser als 1000 (Obergrenze fuer reps)',
    ]);
    expect(fehlerVon((roh) => (roh.exercises[0]!.target_min = 8.5))).toEqual([
      'exercises[0] "brustpresse_neutral" target_min: muss eine ganze Zahl sein',
    ]);
  });

  it("prueft Video, Muskeln und Quellen", () => {
    expect(fehlerVon((roh) => (roh.exercises[0]!.video = { file: "a.mp4", duration_s: 46 }))).toEqual([
      'exercises[0] "brustpresse_neutral" video.duration_s: darf hoechstens 45 sein',
    ]);
    expect(fehlerVon((roh) => (roh.exercises[0]!.video = { file: "../a.mp4", duration_s: 6 }))).toEqual([
      'exercises[0] "brustpresse_neutral" video.file: muss relativ zur Datei sein und darf nicht mit .. hinausfuehren',
    ]);
    expect(fehlerVon((roh) => (roh.exercises[1]!.muscles = [{ muscle: "trizeps", role: "secondary" }]))).toEqual([
      'exercises[1] "trizeps_druecken": braucht mindestens einen Muskel mit role "primary"',
    ]);
    expect(fehlerVon((roh) => roh.exercises[1]!.muscles.push({ muscle: "bizeps", role: "secondary" }))).toEqual([
      'exercises[1] "trizeps_druecken" muscles: Muskel "bizeps" gibt es in muscles nicht',
    ]);
    expect(fehlerVon((roh) => roh.exercises[1]!.sources.push("quelle_b"))).toEqual([
      'exercises[1] "trizeps_druecken" sources: Quelle "quelle_b" gibt es in sources nicht',
    ]);
    expect(fehlerVon((roh) => (roh.sources[0]!.url = "http://example.org"))).toEqual([
      'sources[0] "quelle_a" url: muss eine https-Adresse sein',
    ]);
  });
});
```

- [ ] **Step 3: Tests laufen lassen, sie müssen scheitern**

Run: `pnpm --filter @fitretro/domain exec vitest run src/katalog-datei.test.ts`
Expected: FAIL mit `Failed to resolve import "./katalog-datei.js"`.

- [ ] **Step 4: Umsetzung schreiben**

`packages/domain/src/katalog-datei.ts`:

```ts
import { z } from "zod";
import { CATEGORIES, LOAD_UNITS, MAX_VOLUME, VOLUME_KINDS } from "./belastung.js";
import { MAX_VIDEO_SECONDS } from "./media.js";

/**
 * Das Format von catalog/gymtavo.json und seine Pruefung.
 *
 * Spec 2026-10-06-gymtavo-katalog-offener-zugang-design.md, Abschnitt 9.1.
 * Die Datei ist die gepflegte Quelle des Gymtavo-Katalogs; geschrieben wird
 * nur, was hier durchgeht. Alle Fehler kommen auf einmal, sonst wird eine
 * Datei mit 162 Uebungen in Dutzenden Laeufen repariert. Jede Meldung nennt
 * Index und Schluessel, weil eine Zeilennummer in einer 6000-Zeilen-Datei
 * niemandem hilft.
 *
 * Objekte sind strict: ein vertippter Feldname soll auffallen, statt still
 * ignoriert zu werden und als fehlender Wert zu enden.
 */

/** Feste id aus Migration 0047. */
export const GYMTAVO_STUDIO_ID = "00000000-0000-4000-8000-000000000001";

export const GRIFFE = [
  "neutral",
  "pronated",
  "supinated",
  "semi_pronated",
  "semi_supinated",
  "rotating",
  "front_rack",
  "none",
] as const;

const schluessel = z.string().regex(/^[a-z0-9_]+$/, "darf nur a-z, 0-9 und _ enthalten");
const text = z.string().trim().min(1, "darf nicht leer sein");
const positiv = z.number().positive("muss groesser als 0 sein");
const nichtNegativ = z.number().nonnegative("darf nicht negativ sein");
const ganzPositiv = z.number().int("muss eine ganze Zahl sein").positive("muss groesser als 0 sein");

// Ein Medienpfad, der aus dem Katalogordner hinausfuehrt, wuerde beliebige
// Dateien des Rechners hochladen, auf dem das Skript laeuft.
const medienPfad = z
  .string()
  .trim()
  .min(1, "darf nicht leer sein")
  .refine(
    (pfad) => !pfad.startsWith("/") && !pfad.split("/").includes(".."),
    "muss relativ zur Datei sein und darf nicht mit .. hinausfuehren",
  );

const einstellungSchema = z.discriminatedUnion("kind", [
  z
    .object({
      key: schluessel,
      label: text,
      kind: z.literal("number"),
      min: z.number().nullable(),
      max: z.number().nullable(),
      step: positiv.nullable(),
      unit: text.nullable(),
    })
    .strict(),
  z
    .object({
      key: schluessel,
      label: text,
      kind: z.literal("enum"),
      allowed_values: z.array(text).min(2, "braucht mindestens zwei Werte"),
    })
    .strict(),
]);

const geraetetypSchema = z
  .object({
    key: schluessel,
    name: text,
    category: z.enum(CATEGORIES),
    manufacturer: text.nullable(),
    photo: medienPfad.nullable(),
    load_unit: z.enum(LOAD_UNITS),
    load_step: positiv,
    load_min: nichtNegativ,
    load_max: nichtNegativ.nullable(),
    // Alle vier oder keiner: so verlangt es equipment_models_secondary_all_or_none (0046).
    secondary: z
      .object({ unit: z.enum(LOAD_UNITS), step: positiv, min: nichtNegativ, max: nichtNegativ })
      .strict()
      .nullable(),
    settings: z.array(einstellungSchema),
    exercises: z.array(schluessel),
  })
  .strict();

const uebungSchema = z
  .object({
    key: schluessel,
    name: text,
    description: text.nullable(),
    volume_kind: z.enum(VOLUME_KINDS),
    target_min: ganzPositiv,
    target_max: ganzPositiv,
    video: z
      .object({
        file: medienPfad,
        duration_s: z
          .number()
          .int("muss eine ganze Zahl sein")
          .min(1, "muss mindestens 1 sein")
          .max(MAX_VIDEO_SECONDS, `darf hoechstens ${MAX_VIDEO_SECONDS} sein`),
      })
      .strict()
      .nullable(),
    grip: z.enum(GRIFFE).nullable(),
    muscles: z.array(z.object({ muscle: schluessel, role: z.enum(["primary", "secondary"]) }).strict()),
    review: z.enum(["draft", "reviewed"]),
    sources: z.array(schluessel),
  })
  .strict();

const katalogSchema = z
  .object({
    format: z.literal(1),
    muscles: z.array(z.object({ key: schluessel, name: text }).strict()),
    sources: z.array(
      z
        .object({
          key: schluessel,
          title: text,
          url: z.string().regex(/^https:\/\/\S+$/, "muss eine https-Adresse sein"),
          accessed_at: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "muss ein Datum JJJJ-MM-TT sein"),
        })
        .strict(),
    ),
    equipment: z.array(geraetetypSchema),
    exercises: z.array(uebungSchema),
  })
  .strict();

export type KatalogDatei = z.infer<typeof katalogSchema>;
export type Geraetetyp = KatalogDatei["equipment"][number];
export type Uebung = KatalogDatei["exercises"][number];
export type Einstellung = Geraetetyp["settings"][number];

export type Pruefung<T> = { ok: true; wert: T } | { ok: false; fehler: string[] };

const TYPEN: Record<string, string> = {
  string: "Text",
  number: "Zahl",
  integer: "ganze Zahl",
  boolean: "Wahrheitswert",
  object: "Objekt",
  array: "Liste",
  null: "null",
};

function meldung(issue: z.ZodIssue): string {
  switch (issue.code) {
    case z.ZodIssueCode.invalid_type:
      return issue.received === "undefined"
        ? "fehlt"
        : `muss ${TYPEN[issue.expected] ?? issue.expected} sein, ist ${TYPEN[issue.received] ?? issue.received}`;
    case z.ZodIssueCode.invalid_literal:
      return `muss ${JSON.stringify(issue.expected)} sein`;
    case z.ZodIssueCode.invalid_enum_value:
      return `ist ${JSON.stringify(issue.received)}, erlaubt: ${issue.options.join(", ")}`;
    case z.ZodIssueCode.invalid_union_discriminator:
      return `muss ${issue.options.map(String).join(" oder ")} sein`;
    case z.ZodIssueCode.unrecognized_keys:
      return `unbekanntes Feld ${issue.keys.map((k) => `"${k}"`).join(", ")}`;
    default:
      return issue.message;
  }
}

function istObjekt(wert: unknown): wert is Record<string | number, unknown> {
  return typeof wert === "object" && wert !== null;
}

/** 'equipment[2] "laufband" secondary.max' -- Index und Schluessel, damit man den Eintrag findet. */
export function ort(roh: unknown, pfad: ReadonlyArray<string | number>): string {
  let text = "";
  let knoten: unknown = roh;
  for (const teil of pfad) {
    knoten = istObjekt(knoten) ? knoten[teil] : undefined;
    if (typeof teil === "number") {
      text += `[${teil}]`;
      if (istObjekt(knoten) && typeof knoten.key === "string") text += ` "${knoten.key}"`;
    } else {
      text += text === "" ? teil : text.endsWith('"') ? ` ${teil}` : `.${teil}`;
    }
  }
  return text === "" ? "Datei" : text;
}

function doppelte(werte: readonly string[]): string[] {
  const gesehen = new Set<string>();
  const doppelt = new Set<string>();
  for (const wert of werte) {
    if (gesehen.has(wert)) doppelt.add(wert);
    gesehen.add(wert);
  }
  return [...doppelt];
}

/** Was zod nicht sieht: Verweise zwischen Listen, Doppelte, Grenzen untereinander. */
function querPruefen(k: KatalogDatei): string[] {
  const fehler: string[] = [];
  const eindeutig = (wo: string, schluessel: string[]) => {
    for (const d of doppelte(schluessel)) fehler.push(`${wo}: Schluessel "${d}" kommt mehrfach vor`);
  };
  eindeutig("muscles", k.muscles.map((m) => m.key));
  eindeutig("sources", k.sources.map((q) => q.key));
  eindeutig("equipment", k.equipment.map((g) => g.key));
  eindeutig("exercises", k.exercises.map((u) => u.key));

  const uebungen = new Set(k.exercises.map((u) => u.key));
  const muskeln = new Set(k.muscles.map((m) => m.key));
  const quellen = new Set(k.sources.map((q) => q.key));
  const zugeordnet = new Set<string>();

  k.equipment.forEach((g, i) => {
    const wo = `equipment[${i}] "${g.key}"`;
    if (g.load_max !== null && g.load_max < g.load_min) fehler.push(`${wo}: load_max ist kleiner als load_min`);
    if (g.secondary !== null && g.secondary.max < g.secondary.min) {
      fehler.push(`${wo}: secondary.max ist kleiner als secondary.min`);
    }
    eindeutig(`${wo} settings`, g.settings.map((e) => e.key));
    g.settings.forEach((e, j) => {
      const woE = `${wo} settings[${j}] "${e.key}"`;
      if (e.kind === "number" && e.min !== null && e.max !== null && e.max < e.min) {
        fehler.push(`${woE}: max ist kleiner als min`);
      }
      if (e.kind === "enum") {
        for (const d of doppelte(e.allowed_values)) fehler.push(`${woE}: allowed_values enthaelt "${d}" mehrfach`);
      }
    });
    eindeutig(`${wo} exercises`, g.exercises);
    for (const u of g.exercises) {
      if (!uebungen.has(u)) fehler.push(`${wo} exercises: Uebung "${u}" gibt es in exercises nicht`);
      zugeordnet.add(u);
    }
  });

  k.exercises.forEach((u, i) => {
    const wo = `exercises[${i}] "${u.key}"`;
    if (u.target_max < u.target_min) fehler.push(`${wo}: target_max ist kleiner als target_min`);
    if (u.target_max > MAX_VOLUME[u.volume_kind]) {
      fehler.push(`${wo}: target_max ist groesser als ${MAX_VOLUME[u.volume_kind]} (Obergrenze fuer ${u.volume_kind})`);
    }
    // Eine Uebung ohne Geraetetyp waere in der App unerreichbar.
    if (!zugeordnet.has(u.key)) fehler.push(`${wo}: haengt an keinem Geraetetyp`);
    if (!u.muscles.some((m) => m.role === "primary")) {
      fehler.push(`${wo}: braucht mindestens einen Muskel mit role "primary"`);
    }
    for (const d of doppelte(u.muscles.map((m) => m.muscle))) fehler.push(`${wo} muscles: Muskel "${d}" kommt mehrfach vor`);
    for (const m of u.muscles) {
      if (!muskeln.has(m.muscle)) fehler.push(`${wo} muscles: Muskel "${m.muscle}" gibt es in muscles nicht`);
    }
    for (const q of u.sources) {
      if (!quellen.has(q)) fehler.push(`${wo} sources: Quelle "${q}" gibt es in sources nicht`);
    }
  });
  return fehler;
}

export function pruefeKatalog(roh: unknown): Pruefung<KatalogDatei> {
  const ergebnis = katalogSchema.safeParse(roh);
  if (!ergebnis.success) {
    return { ok: false, fehler: ergebnis.error.issues.map((issue) => `${ort(roh, issue.path)}: ${meldung(issue)}`) };
  }
  const fehler = querPruefen(ergebnis.data);
  return fehler.length > 0 ? { ok: false, fehler } : { ok: true, wert: ergebnis.data };
}
```

- [ ] **Step 5: Tests laufen lassen, sie müssen bestehen**

Run: `pnpm --filter @fitretro/domain exec vitest run src/katalog-datei.test.ts && pnpm --filter @fitretro/domain typecheck`
Expected: PASS, Typecheck ohne Fehler. Weicht ein erwarteter Meldungstext ab, weil zod die Issue anders schneidet (etwa Pfad oder Code beim `discriminatedUnion`), dann den Test nur dann anpassen, wenn die neue Meldung Ort und Ursache weiterhin klar nennt.

- [ ] **Step 6: Commit**

```bash
git add packages/domain/src/katalog-datei.ts packages/domain/src/katalog-datei.test.ts packages/domain/src/katalog-testdaten.ts packages/domain/package.json
git commit -m "feat(katalog): Format und Pruefung der Katalogdatei

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log -1 --format=%B
```

---

### Task 3: Medien prüfen und Datei laden

**Files:**
- Create: `packages/domain/src/katalog-medien.ts`
- Create: `packages/domain/src/katalog-laden.ts`
- Modify: `docs/superpowers/specs/2026-10-06-gymtavo-katalog-offener-zugang-design.md` (Abschnitt 9.1, Video-Regel)
- Test: `packages/domain/src/katalog-medien.test.ts`, `packages/domain/src/katalog-laden.test.ts`

**Interfaces:**
- Consumes: `KatalogDatei`, `Pruefung<T>`, `GYMTAVO_STUDIO_ID`, `pruefeKatalog` (Task 2); `sniffMediaType`, `readVideoDurationSeconds`, `PHOTO_BUCKET`, `VIDEO_BUCKET`, `MAX_PHOTO_BYTES`, `MAX_VIDEO_BYTES` aus `media.ts`.
- Produces:
  - `type Medium = { datei: string; bucket: "equipment-photos" | "instruction-videos"; storagePath: string; contentType: "image/png" | "image/jpeg" | "video/mp4"; bytes: Uint8Array }`
  - `type Medien = { fotos: Map<string, Medium>; videos: Map<string, Medium> }`: Schlüssel ist der `key` von Gerätetyp bzw. Übung.
  - `fotoPraefix(key: string): string`, `videoPraefix(key: string): string`
  - `pruefeMedien(k: KatalogDatei, lies: (datei: string) => Uint8Array | null): Pruefung<Medien>`
  - `type GeladenerKatalog = { katalog: KatalogDatei; medien: Medien }`, `ladeKatalog(datei: string): Pruefung<GeladenerKatalog>`

Eine Ergänzung zur Spec: Lässt sich die Dauer aus dem MP4 lesen (mvhd), muss sie mit `duration_s` übereinstimmen. `readVideoDurationSeconds` gibt es schon, eine ffprobe-Abhängigkeit kommt nicht dazu. Eine falsche Dauer würde in der App sonst eine falsche Länge anzeigen.

- [ ] **Step 1: Die fehlschlagenden Tests schreiben**

`packages/domain/src/katalog-medien.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { GYMTAVO_STUDIO_ID, pruefeKatalog, type KatalogDatei } from "./katalog-datei.js";
import { pruefeMedien } from "./katalog-medien.js";
import { beispielKatalog, jpegBytes, mp4Bytes } from "./katalog-testdaten.js";

function katalog(roh: unknown): KatalogDatei {
  const pruefung = pruefeKatalog(roh);
  if (!pruefung.ok) throw new Error(pruefung.fehler.join("\n"));
  return pruefung.wert;
}

describe("pruefeMedien", () => {
  it("bildet Storage-Pfade aus Schluessel und Hash", () => {
    const { roh, dateien } = beispielKatalog();
    const pruefung = pruefeMedien(katalog(roh), (d) => dateien.get(d) ?? null);
    if (!pruefung.ok) throw new Error(pruefung.fehler.join("\n"));

    const foto = pruefung.wert.fotos.get("brustpresse");
    expect(foto?.bucket).toBe("equipment-photos");
    expect(foto?.contentType).toBe("image/png");
    expect(foto?.storagePath).toMatch(new RegExp(`^${GYMTAVO_STUDIO_ID}/catalog/photos/brustpresse-[0-9a-f]{8}\\.png$`));
    expect([...pruefung.wert.videos.keys()]).toEqual(["brustpresse_neutral", "trizeps_druecken"]);
    expect(pruefung.wert.videos.get("trizeps_druecken")?.storagePath).toMatch(
      new RegExp(`^${GYMTAVO_STUDIO_ID}/catalog/videos/trizeps_druecken-[0-9a-f]{8}\\.mp4$`),
    );
  });

  it("aendert den Pfad genau dann, wenn sich die Datei aendert", () => {
    const { roh, dateien } = beispielKatalog();
    const k = katalog(roh);
    const pfad = () => {
      const p = pruefeMedien(k, (d) => dateien.get(d) ?? null);
      if (!p.ok) throw new Error(p.fehler.join("\n"));
      return p.wert.videos.get("trizeps_druecken")?.storagePath;
    };
    const erster = pfad();
    expect(pfad()).toBe(erster);
    dateien.set("media/videos/trizeps.mp4", mp4Bytes(5, 99));
    expect(pfad()).not.toBe(erster);
  });

  it("nimmt JPEG als .jpg", () => {
    const { roh, dateien } = beispielKatalog();
    dateien.set("media/photos/brustpresse.png", jpegBytes(1));
    const p = pruefeMedien(katalog(roh), (d) => dateien.get(d) ?? null);
    expect(p.ok && p.wert.fotos.get("brustpresse")?.storagePath.endsWith(".jpg")).toBe(true);
  });

  it("meldet fehlende, falsche und zu lange Dateien gesammelt", () => {
    const { roh, dateien } = beispielKatalog();
    dateien.delete("media/photos/brustpresse.png");
    dateien.set("media/videos/brustpresse_neutral.mp4", jpegBytes());
    dateien.set("media/videos/trizeps.mp4", mp4Bytes(7));
    const p = pruefeMedien(katalog(roh), (d) => dateien.get(d) ?? null);
    expect(p.ok ? [] : p.fehler).toEqual([
      'equipment[0] "brustpresse" photo "media/photos/brustpresse.png": Datei fehlt',
      'exercises[0] "brustpresse_neutral" video "media/videos/brustpresse_neutral.mp4": ist kein MP4',
      'exercises[1] "trizeps_druecken" video "media/videos/trizeps.mp4": dauert 7 s, angegeben sind 5 s',
    ]);
  });

  it("nimmt ein MP4 hin, dessen Dauer sich nicht lesen laesst", () => {
    const { roh, dateien } = beispielKatalog();
    dateien.set("media/videos/trizeps.mp4", mp4Bytes(null));
    expect(pruefeMedien(katalog(roh), (d) => dateien.get(d) ?? null).ok).toBe(true);
  });
});
```

`packages/domain/src/katalog-laden.test.ts`:

```ts
import { mkdirSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { ladeKatalog } from "./katalog-laden.js";
import { beispielKatalog } from "./katalog-testdaten.js";

function ordnerMitKatalog(): string {
  const ordner = mkdtempSync(join(tmpdir(), "katalog-"));
  const { roh, dateien } = beispielKatalog();
  writeFileSync(join(ordner, "gymtavo.json"), JSON.stringify(roh));
  for (const [pfad, bytes] of dateien) {
    mkdirSync(join(ordner, pfad, ".."), { recursive: true });
    writeFileSync(join(ordner, pfad), bytes);
  }
  return ordner;
}

describe("ladeKatalog", () => {
  it("liest Medien relativ zur Datei, nicht zum Arbeitsverzeichnis", () => {
    const ergebnis = ladeKatalog(join(ordnerMitKatalog(), "gymtavo.json"));
    if (!ergebnis.ok) throw new Error(ergebnis.fehler.join("\n"));
    expect(ergebnis.wert.medien.videos.size).toBe(2);
  });

  it("meldet kaputtes JSON", () => {
    const ordner = mkdtempSync(join(tmpdir(), "katalog-"));
    writeFileSync(join(ordner, "gymtavo.json"), "{ format: 1");
    const ergebnis = ladeKatalog(join(ordner, "gymtavo.json"));
    expect(ergebnis.ok ? "" : ergebnis.fehler[0]).toContain("kein gueltiges JSON");
  });

  it("meldet eine fehlende Datei", () => {
    const ergebnis = ladeKatalog(join(tmpdir(), "gibt-es-nicht.json"));
    expect(ergebnis.ok ? "" : ergebnis.fehler[0]).toContain("Datei nicht lesbar");
  });
});
```

- [ ] **Step 2: Tests laufen lassen, sie müssen scheitern**

Run: `pnpm --filter @fitretro/domain exec vitest run src/katalog-medien.test.ts src/katalog-laden.test.ts`
Expected: FAIL. `./katalog-medien.js` und `./katalog-laden.js` lassen sich nicht auflösen.

- [ ] **Step 3: Umsetzung schreiben**

`packages/domain/src/katalog-medien.ts`:

```ts
import { createHash } from "node:crypto";
import { GYMTAVO_STUDIO_ID, type KatalogDatei, type Pruefung } from "./katalog-datei.js";
import {
  MAX_PHOTO_BYTES,
  MAX_VIDEO_BYTES,
  PHOTO_BUCKET,
  VIDEO_BUCKET,
  readVideoDurationSeconds,
  sniffMediaType,
} from "./media.js";

/**
 * Fotos und Videos der Katalogdatei: lesen, am Inhalt pruefen, Storage-Pfad
 * bestimmen.
 *
 * Der Pfad enthaelt einen Hash des Inhalts. Eine geaenderte Datei bekommt so
 * einen neuen Pfad, statt eine alte zu ueberschreiben -- der Import loescht
 * und ueberschreibt nie, und eine App mit zwischengespeicherter URL bekommt
 * nie still den neuen Inhalt unter dem alten Namen.
 */

export type Medium = {
  datei: string;
  bucket: typeof PHOTO_BUCKET | typeof VIDEO_BUCKET;
  storagePath: string;
  contentType: "image/png" | "image/jpeg" | "video/mp4";
  bytes: Uint8Array;
};

export type Medien = { fotos: Map<string, Medium>; videos: Map<string, Medium> };

// "-" trennt Schluessel und Hash und kommt in Schluesseln nicht vor
// (^[a-z0-9_]+$). Damit ist kein Praefix der Anfang eines anderen: "bank-"
// trifft nie "bank_schraeg-...". Daran erkennt der Import seine eigenen
// Objekte und laesst im Portal hochgeladene in Ruhe.
export function fotoPraefix(key: string): string {
  return `${GYMTAVO_STUDIO_ID}/catalog/photos/${key}-`;
}

export function videoPraefix(key: string): string {
  return `${GYMTAVO_STUDIO_ID}/catalog/videos/${key}-`;
}

function kurzHash(bytes: Uint8Array): string {
  return createHash("sha256").update(bytes).digest("hex").slice(0, 8);
}

export function pruefeMedien(
  k: KatalogDatei,
  lies: (datei: string) => Uint8Array | null,
): Pruefung<Medien> {
  const fehler: string[] = [];
  const fotos = new Map<string, Medium>();
  const videos = new Map<string, Medium>();

  k.equipment.forEach((g, i) => {
    if (g.photo === null) return;
    const wo = `equipment[${i}] "${g.key}" photo "${g.photo}"`;
    const bytes = lies(g.photo);
    if (bytes === null) return void fehler.push(`${wo}: Datei fehlt`);
    const typ = sniffMediaType(bytes);
    if (typ !== "image/png" && typ !== "image/jpeg") return void fehler.push(`${wo}: ist kein PNG oder JPEG`);
    if (bytes.length > MAX_PHOTO_BYTES) return void fehler.push(`${wo}: ist groesser als 10 MiB`);
    const endung = typ === "image/png" ? "png" : "jpg";
    fotos.set(g.key, {
      datei: g.photo,
      bucket: PHOTO_BUCKET,
      storagePath: `${fotoPraefix(g.key)}${kurzHash(bytes)}.${endung}`,
      contentType: typ,
      bytes,
    });
  });

  k.exercises.forEach((u, i) => {
    if (u.video === null) return;
    const wo = `exercises[${i}] "${u.key}" video "${u.video.file}"`;
    const bytes = lies(u.video.file);
    if (bytes === null) return void fehler.push(`${wo}: Datei fehlt`);
    if (sniffMediaType(bytes) !== "video/mp4") return void fehler.push(`${wo}: ist kein MP4`);
    if (bytes.length > MAX_VIDEO_BYTES) return void fehler.push(`${wo}: ist groesser als 50 MiB`);
    // Die App zeigt die Laenge aus duration_s. Wo die Datei sie selbst
    // verraet, darf die Angabe nicht abweichen.
    const dauer = readVideoDurationSeconds(bytes);
    if (dauer !== null && dauer !== u.video.duration_s) {
      return void fehler.push(`${wo}: dauert ${dauer} s, angegeben sind ${u.video.duration_s} s`);
    }
    videos.set(u.key, {
      datei: u.video.file,
      bucket: VIDEO_BUCKET,
      storagePath: `${videoPraefix(u.key)}${kurzHash(bytes)}.mp4`,
      contentType: "video/mp4",
      bytes,
    });
  });

  return fehler.length > 0 ? { ok: false, fehler } : { ok: true, wert: { fotos, videos } };
}
```

`packages/domain/src/katalog-laden.ts`:

```ts
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { pruefeKatalog, type KatalogDatei, type Pruefung } from "./katalog-datei.js";
import { pruefeMedien, type Medien } from "./katalog-medien.js";

export type GeladenerKatalog = { katalog: KatalogDatei; medien: Medien };

/**
 * Liest die Katalogdatei von der Platte. Medienpfade gelten relativ zur
 * Datei, nicht zum Arbeitsverzeichnis -- sonst haengt das Ergebnis davon ab,
 * aus welchem Ordner jemand das Skript startet.
 */
export function ladeKatalog(datei: string): Pruefung<GeladenerKatalog> {
  let inhalt: string;
  try {
    inhalt = readFileSync(datei, "utf8");
  } catch {
    return { ok: false, fehler: [`${datei}: Datei nicht lesbar`] };
  }

  let roh: unknown;
  try {
    roh = JSON.parse(inhalt);
  } catch (fehler) {
    return { ok: false, fehler: [`${datei}: kein gueltiges JSON (${(fehler as Error).message})`] };
  }

  const pruefung = pruefeKatalog(roh);
  if (!pruefung.ok) return pruefung;

  const basis = dirname(resolve(datei));
  const medien = pruefeMedien(pruefung.wert, (pfad) => {
    try {
      return new Uint8Array(readFileSync(resolve(basis, pfad)));
    } catch {
      return null;
    }
  });
  if (!medien.ok) return medien;
  return { ok: true, wert: { katalog: pruefung.wert, medien: medien.wert } };
}
```

In Abschnitt 9.1 der Spec den Satz `Die Dauer wird nicht nachgemessen.` ersetzen durch: `Lässt sich die Dauer aus dem MP4 lesen, muss sie übereinstimmen.`

- [ ] **Step 4: Tests laufen lassen, sie müssen bestehen**

Run: `pnpm --filter @fitretro/domain exec vitest run src/katalog-medien.test.ts src/katalog-laden.test.ts && pnpm --filter @fitretro/domain typecheck`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/domain/src/katalog-medien.ts packages/domain/src/katalog-medien.test.ts packages/domain/src/katalog-laden.ts packages/domain/src/katalog-laden.test.ts docs/superpowers/specs/2026-10-06-gymtavo-katalog-offener-zugang-design.md
git commit -m "feat(katalog): Medien der Katalogdatei pruefen und Datei laden

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log -1 --format=%B
```

---

### Task 4: Plan aus Datei und Ist-Stand

**Files:**
- Create: `packages/domain/src/katalog-plan.ts`
- Test: `packages/domain/src/katalog-plan.test.ts`

**Interfaces:**
- Consumes: `KatalogDatei`, `Medien`, `Medium`, `fotoPraefix`, `videoPraefix`, `PHOTO_BUCKET`, `VIDEO_BUCKET`.
- Produces (in Task 5 und 6 genutzt):

```ts
export type GeraetetypZeile = { catalog_key: string; name: string; category: string; manufacturer: string | null; photo_path: string | null; load_unit: string; load_step: number; load_min: number; load_max: number | null; secondary_unit: string | null; secondary_step: number | null; secondary_min: number | null; secondary_max: number | null };
export type EinstellungZeile = { key: string; label: string; kind: string; min_value: number | null; max_value: number | null; step_value: number | null; unit: string | null; allowed_values: string[] | null; sort_order: number };
export type UebungZeile = { catalog_key: string; name: string; description: string | null; volume_kind: string; target_min: number; target_max: number };
export type IstGeraetetyp = Omit<GeraetetypZeile, "catalog_key"> & { id: string; catalog_key: string | null };
export type IstEinstellung = EinstellungZeile & { id: string; equipment_model_id: string };
export type IstUebung = Omit<UebungZeile, "catalog_key"> & { id: string; catalog_key: string | null };
export type IstVerknuepfung = { id: string; equipment_model_id: string; exercise_id: string; sort_order: number };
export type IstVideo = { id: string; equipment_model_exercise_id: string; storage_path: string; duration_s: number };
export type IstStand = { geraetetypen: IstGeraetetyp[]; einstellungen: IstEinstellung[]; uebungen: IstUebung[]; verknuepfungen: IstVerknuepfung[]; videos: IstVideo[]; objekte: ReadonlySet<string> }; // objekte: "<bucket>/<pfad>"
export type Art = "neu" | "geaendert" | "unveraendert";
export type Posten<Z> = { schluessel: string; art: Art; felder: string[]; id: string | null; zeile: Z };
export type ImportPlan = {
  geraetetypen: Posten<GeraetetypZeile>[];
  einstellungen: Posten<EinstellungZeile & { geraetetyp: string }>[];  // schluessel "<typ>.<key>"
  uebungen: Posten<UebungZeile>[];
  verknuepfungen: Posten<{ geraetetyp: string; uebung: string; sort_order: number }>[];  // schluessel "<typ> > <uebung>"
  videos: Posten<{ geraetetyp: string; uebung: string; storage_path: string; duration_s: number }>[];  // schluessel wie Verknuepfung
  uploads: Medium[];
  gemeldet: { geraetetypen: string[]; uebungen: string[]; einstellungen: string[]; verknuepfungen: string[]; videos: string[]; ersetzteMedien: string[]; ohneSchluessel: string[] };
};
export function planeImport(k: KatalogDatei, medien: Medien, ist: IstStand): ImportPlan;
```

- [ ] **Step 1: Die fehlschlagenden Tests schreiben**

`packages/domain/src/katalog-plan.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { GYMTAVO_STUDIO_ID, pruefeKatalog } from "./katalog-datei.js";
import { pruefeMedien } from "./katalog-medien.js";
import { planeImport, type ImportPlan, type IstStand } from "./katalog-plan.js";
import { beispielKatalog, mp4Bytes, pngBytes } from "./katalog-testdaten.js";

const LEER: IstStand = { geraetetypen: [], einstellungen: [], uebungen: [], verknuepfungen: [], videos: [], objekte: new Set() };

function plane(beispiel: ReturnType<typeof beispielKatalog>, ist: IstStand): ImportPlan {
  const k = pruefeKatalog(beispiel.roh);
  if (!k.ok) throw new Error(k.fehler.join("\n"));
  const m = pruefeMedien(k.wert, (d) => beispiel.dateien.get(d) ?? null);
  if (!m.ok) throw new Error(m.fehler.join("\n"));
  return planeImport(k.wert, m.wert, ist);
}

/** Ein Ist-Stand, der genau dem Plan entspricht -- als waere er schon importiert. */
function istAus(plan: ImportPlan): IstStand {
  const typId = (k: string) => `typ-${k}`;
  const uebId = (k: string) => `ueb-${k}`;
  const linkId = (s: string) => `link-${s}`;
  return {
    geraetetypen: plan.geraetetypen.map((p) => ({ id: typId(p.schluessel), ...p.zeile })),
    einstellungen: plan.einstellungen.map((p) => {
      const { geraetetyp, ...zeile } = p.zeile;
      return { id: `e-${p.schluessel}`, equipment_model_id: typId(geraetetyp), ...zeile };
    }),
    uebungen: plan.uebungen.map((p) => ({ id: uebId(p.schluessel), ...p.zeile })),
    verknuepfungen: plan.verknuepfungen.map((p) => ({
      id: linkId(p.schluessel),
      equipment_model_id: typId(p.zeile.geraetetyp),
      exercise_id: uebId(p.zeile.uebung),
      sort_order: p.zeile.sort_order,
    })),
    videos: plan.videos.map((p) => ({
      id: `v-${p.schluessel}`,
      equipment_model_exercise_id: linkId(p.schluessel),
      storage_path: p.zeile.storage_path,
      duration_s: p.zeile.duration_s,
    })),
    objekte: new Set(plan.uploads.map((m) => `${m.bucket}/${m.storagePath}`)),
  };
}

const arten = (liste: { art: string }[]) => liste.map((p) => p.art);

describe("planeImport", () => {
  it("legt bei leerem Katalog alles neu an", () => {
    const plan = plane(beispielKatalog(), LEER);
    expect(arten(plan.geraetetypen)).toEqual(["neu", "neu", "neu"]);
    expect(plan.einstellungen.map((p) => p.schluessel)).toEqual(["brustpresse.sitzhoehe", "brustpresse.griff"]);
    expect(plan.einstellungen.map((p) => p.zeile.sort_order)).toEqual([1, 2]);
    expect(plan.verknuepfungen.map((p) => p.schluessel)).toEqual([
      "brustpresse > brustpresse_neutral",
      "brustpresse > trizeps_druecken",
      "trizepsmaschine > trizeps_druecken",
      "laufband > gehen",
    ]);
    // trizeps_druecken haengt an zwei Typen: das Video an beiden Verknuepfungen.
    expect(plan.videos.map((p) => p.schluessel)).toEqual([
      "brustpresse > brustpresse_neutral",
      "brustpresse > trizeps_druecken",
      "trizepsmaschine > trizeps_druecken",
    ]);
    expect(plan.uploads).toHaveLength(3);
    expect(plan.geraetetypen[2]?.zeile).toMatchObject({ load_step: 0.1, secondary_unit: "pct", secondary_max: 15 });
    expect(plan.geraetetypen[0]?.zeile.photo_path).toMatch(new RegExp(`^${GYMTAVO_STUDIO_ID}/catalog/photos/brustpresse-`));
  });

  it("meldet beim zweiten Lauf alles unveraendert und laedt nichts hoch", () => {
    const beispiel = beispielKatalog();
    const zweiter = plane(beispiel, istAus(plane(beispiel, LEER)));
    for (const liste of [zweiter.geraetetypen, zweiter.einstellungen, zweiter.uebungen, zweiter.verknuepfungen, zweiter.videos]) {
      expect(arten(liste).every((a) => a === "unveraendert")).toBe(true);
    }
    expect(zweiter.uploads).toEqual([]);
  });

  it("haelt Zahlen aus der Datenbank, die als Text kommen, fuer gleich", () => {
    const beispiel = beispielKatalog();
    const ist = istAus(plane(beispiel, LEER));
    const laufband = ist.geraetetypen.find((g) => g.catalog_key === "laufband")!;
    (laufband as Record<string, unknown>).load_step = "0.1";
    (laufband as Record<string, unknown>).secondary_step = "0.50";
    expect(plane(beispiel, ist).geraetetypen[2]?.art).toBe("unveraendert");
  });

  it("nennt geaenderte Felder", () => {
    const beispiel = beispielKatalog();
    const ist = istAus(plane(beispiel, LEER));
    beispiel.roh.equipment[0]!.name = "Brustpresse neu";
    beispiel.roh.equipment[0]!.exercises.reverse();
    const plan = plane(beispiel, ist);
    expect(plan.geraetetypen[0]).toMatchObject({ art: "geaendert", felder: ["name"], id: "typ-brustpresse" });
    expect(plan.verknuepfungen.filter((p) => p.art === "geaendert").map((p) => p.felder)).toEqual([["sort_order"], ["sort_order"]]);
  });

  it("meldet ersetzte eigene Medien, aber keine fremden", () => {
    const beispiel = beispielKatalog();
    const ist = istAus(plane(beispiel, LEER));
    const altesVideo = ist.videos[1]!.storage_path;
    beispiel.dateien.set("media/videos/trizeps.mp4", mp4Bytes(5, 77));
    beispiel.dateien.set("media/photos/brustpresse.png", pngBytes(77));
    // Das Foto der Brustpresse stammt aus dem Portal, nicht vom Import.
    ist.geraetetypen[0]!.photo_path = `${GYMTAVO_STUDIO_ID}/portal-foto.png`;

    const plan = plane(beispiel, ist);
    expect(plan.videos.filter((p) => p.art === "geaendert").map((p) => p.felder)).toEqual([["storage_path"], ["storage_path"]]);
    expect(plan.gemeldet.ersetzteMedien).toEqual([`instruction-videos/${altesVideo}`]);
    expect(plan.uploads.map((m) => m.datei).sort()).toEqual(["media/photos/brustpresse.png", "media/videos/trizeps.mp4"]);
  });

  it("meldet, was nur noch in der Datenbank steht, und plant kein Loeschen", () => {
    const beispiel = beispielKatalog();
    const ist = istAus(plane(beispiel, LEER));
    beispiel.roh.equipment[0]!.settings.pop();
    beispiel.roh.equipment[0]!.exercises = [`brustpresse_neutral`];
    beispiel.roh.equipment.splice(2, 1);
    beispiel.roh.exercises.splice(2, 1);
    beispiel.roh.exercises[0]!.video = null;

    const plan = plane(beispiel, ist);
    expect(plan.gemeldet).toMatchObject({
      geraetetypen: ["laufband"],
      uebungen: ["gehen"],
      einstellungen: ["brustpresse.griff"],
      verknuepfungen: ["brustpresse > trizeps_druecken"],
      videos: ["brustpresse > brustpresse_neutral"],
    });
  });

  it("laesst fremde Videos und Zeilen ohne Schluessel in Ruhe", () => {
    const beispiel = beispielKatalog();
    const ist = istAus(plane(beispiel, LEER));
    ist.videos[0]!.storage_path = `${GYMTAVO_STUDIO_ID}/portal/eigenes.mp4`;
    ist.geraetetypen.push({ ...ist.geraetetypen[0]!, id: "hand", catalog_key: null, name: "Von Hand" });
    ist.uebungen.push({ ...ist.uebungen[0]!, id: "hand-u", catalog_key: null, name: "Von Hand Uebung" });

    const plan = plane(beispiel, ist);
    // Das fremde Video zaehlt nicht als eigenes: der Import legt seines daneben an.
    expect(plan.videos[0]).toMatchObject({ art: "neu", id: null });
    expect(plan.gemeldet.ersetzteMedien).toEqual([]);
    expect(plan.gemeldet.ohneSchluessel).toEqual(['Geraetetyp "Von Hand"', 'Uebung "Von Hand Uebung"']);
  });
});
```

- [ ] **Step 2: Tests laufen lassen, sie müssen scheitern**

Run: `pnpm --filter @fitretro/domain exec vitest run src/katalog-plan.test.ts`
Expected: FAIL mit `Failed to resolve import "./katalog-plan.js"`.

- [ ] **Step 3: Umsetzung schreiben**

`packages/domain/src/katalog-plan.ts`:

```ts
import type { KatalogDatei } from "./katalog-datei.js";
import { fotoPraefix, videoPraefix, type Medien, type Medium } from "./katalog-medien.js";
import { PHOTO_BUCKET, VIDEO_BUCKET } from "./media.js";

/**
 * Vergleicht die Katalogdatei mit dem Ist-Stand des Gymtavo-Studios und
 * entscheidet je Zeile: neu, geaendert, unveraendert. Rein und ohne Netz --
 * der Trockenlauf zeigt genau diesen Plan, der echte Lauf fuehrt ihn aus.
 *
 * Geloescht wird nie (Spec 9.1): Saetze und Studio-Zuordnungen zeigen auf
 * Katalogzeilen. Was nur noch in der Datenbank steht, landet in `gemeldet`.
 */

export type GeraetetypZeile = {
  catalog_key: string;
  name: string;
  category: string;
  manufacturer: string | null;
  photo_path: string | null;
  load_unit: string;
  load_step: number;
  load_min: number;
  load_max: number | null;
  secondary_unit: string | null;
  secondary_step: number | null;
  secondary_min: number | null;
  secondary_max: number | null;
};

export type EinstellungZeile = {
  key: string;
  label: string;
  kind: string;
  min_value: number | null;
  max_value: number | null;
  step_value: number | null;
  unit: string | null;
  allowed_values: string[] | null;
  sort_order: number;
};

export type UebungZeile = {
  catalog_key: string;
  name: string;
  description: string | null;
  volume_kind: string;
  target_min: number;
  target_max: number;
};

export type IstGeraetetyp = Omit<GeraetetypZeile, "catalog_key"> & { id: string; catalog_key: string | null };
export type IstEinstellung = EinstellungZeile & { id: string; equipment_model_id: string };
export type IstUebung = Omit<UebungZeile, "catalog_key"> & { id: string; catalog_key: string | null };
export type IstVerknuepfung = { id: string; equipment_model_id: string; exercise_id: string; sort_order: number };
export type IstVideo = { id: string; equipment_model_exercise_id: string; storage_path: string; duration_s: number };

export type IstStand = {
  geraetetypen: IstGeraetetyp[];
  einstellungen: IstEinstellung[];
  uebungen: IstUebung[];
  verknuepfungen: IstVerknuepfung[];
  videos: IstVideo[];
  /** "<bucket>/<pfad>" aller Objekte unter <Gymtavo-ID>/catalog/. */
  objekte: ReadonlySet<string>;
};

export type Art = "neu" | "geaendert" | "unveraendert";
export type Posten<Z> = { schluessel: string; art: Art; felder: string[]; id: string | null; zeile: Z };

export type ImportPlan = {
  geraetetypen: Posten<GeraetetypZeile>[];
  einstellungen: Posten<EinstellungZeile & { geraetetyp: string }>[];
  uebungen: Posten<UebungZeile>[];
  verknuepfungen: Posten<{ geraetetyp: string; uebung: string; sort_order: number }>[];
  videos: Posten<{ geraetetyp: string; uebung: string; storage_path: string; duration_s: number }>[];
  uploads: Medium[];
  gemeldet: {
    geraetetypen: string[];
    uebungen: string[];
    einstellungen: string[];
    verknuepfungen: string[];
    videos: string[];
    ersetzteMedien: string[];
    ohneSchluessel: string[];
  };
};

const GERAETETYP_FELDER = [
  "name", "category", "manufacturer", "photo_path", "load_unit", "load_step", "load_min", "load_max",
  "secondary_unit", "secondary_step", "secondary_min", "secondary_max",
] as const;
const EINSTELLUNG_FELDER = [
  "label", "kind", "min_value", "max_value", "step_value", "unit", "allowed_values", "sort_order",
] as const;
const UEBUNG_FELDER = ["name", "description", "volume_kind", "target_min", "target_max"] as const;

// PostgREST liefert numeric je nach Groesse als Zahl oder als Text. Ohne
// diesen Vergleich meldete jeder zweite Lauf das Laufband (0.1) als geaendert.
function gleich(a: unknown, b: unknown): boolean {
  if (a === null || a === undefined || b === null || b === undefined) return (a ?? null) === (b ?? null);
  if (typeof a === "number" || typeof b === "number") return Number(a) === Number(b);
  if (Array.isArray(a) || Array.isArray(b)) return JSON.stringify(a) === JSON.stringify(b);
  return a === b;
}

function vergleiche<Z extends Record<string, unknown>>(
  schluessel: string,
  zeile: Z,
  ist: (Record<string, unknown> & { id: string }) | undefined,
  felder: readonly (keyof Z & string)[],
): Posten<Z> {
  if (ist === undefined) return { schluessel, art: "neu", felder: [], id: null, zeile };
  const anders = felder.filter((f) => !gleich(zeile[f], ist[f]));
  return { schluessel, art: anders.length > 0 ? "geaendert" : "unveraendert", felder: anders, id: ist.id, zeile };
}

export function planeImport(k: KatalogDatei, medien: Medien, ist: IstStand): ImportPlan {
  const gemeldet: ImportPlan["gemeldet"] = {
    geraetetypen: [], uebungen: [], einstellungen: [], verknuepfungen: [], videos: [], ersetzteMedien: [], ohneSchluessel: [],
  };
  const ersetzt = new Set<string>();
  const typNachKey = new Map(ist.geraetetypen.flatMap((g) => (g.catalog_key === null ? [] : [[g.catalog_key, g] as const])));
  const uebungNachKey = new Map(ist.uebungen.flatMap((u) => (u.catalog_key === null ? [] : [[u.catalog_key, u] as const])));
  const uebungNameNachId = new Map(ist.uebungen.map((u) => [u.id, u.catalog_key ?? u.name]));
  const uebungDatei = new Map(k.exercises.map((u) => [u.key, u]));

  const geraetetypen = k.equipment.map((g) => {
    const zeile: GeraetetypZeile = {
      catalog_key: g.key,
      name: g.name,
      category: g.category,
      manufacturer: g.manufacturer,
      photo_path: medien.fotos.get(g.key)?.storagePath ?? null,
      load_unit: g.load_unit,
      load_step: g.load_step,
      load_min: g.load_min,
      load_max: g.load_max,
      secondary_unit: g.secondary?.unit ?? null,
      secondary_step: g.secondary?.step ?? null,
      secondary_min: g.secondary?.min ?? null,
      secondary_max: g.secondary?.max ?? null,
    };
    const istTyp = typNachKey.get(g.key);
    const posten = vergleiche(g.key, zeile, istTyp, GERAETETYP_FELDER);
    const altesFoto = istTyp?.photo_path;
    if (posten.felder.includes("photo_path") && altesFoto?.startsWith(fotoPraefix(g.key))) {
      ersetzt.add(`${PHOTO_BUCKET}/${altesFoto}`);
    }
    return posten;
  });

  const einstellungen = k.equipment.flatMap((g) => {
    const istTyp = typNachKey.get(g.key);
    const istListe = istTyp === undefined ? [] : ist.einstellungen.filter((e) => e.equipment_model_id === istTyp.id);
    const dateiKeys = new Set(g.settings.map((e) => e.key));
    for (const e of istListe) if (!dateiKeys.has(e.key)) gemeldet.einstellungen.push(`${g.key}.${e.key}`);
    return g.settings.map((e, j) => {
      const zeile = {
        geraetetyp: g.key,
        key: e.key,
        label: e.label,
        kind: e.kind,
        min_value: e.kind === "number" ? e.min : null,
        max_value: e.kind === "number" ? e.max : null,
        step_value: e.kind === "number" ? e.step : null,
        unit: e.kind === "number" ? e.unit : null,
        allowed_values: e.kind === "enum" ? e.allowed_values : null,
        sort_order: j + 1,
      };
      return vergleiche(`${g.key}.${e.key}`, zeile, istListe.find((x) => x.key === e.key), EINSTELLUNG_FELDER);
    });
  });

  const uebungen = k.exercises.map((u) =>
    vergleiche(
      u.key,
      { catalog_key: u.key, name: u.name, description: u.description, volume_kind: u.volume_kind, target_min: u.target_min, target_max: u.target_max },
      uebungNachKey.get(u.key),
      UEBUNG_FELDER,
    ),
  );

  const verknuepfungen: ImportPlan["verknuepfungen"] = [];
  const videos: ImportPlan["videos"] = [];
  for (const g of k.equipment) {
    const istTyp = typNachKey.get(g.key);
    const sollIds = new Set<string>();
    g.exercises.forEach((uKey, j) => {
      const istU = uebungNachKey.get(uKey);
      if (istU) sollIds.add(istU.id);
      const istV =
        istTyp && istU
          ? ist.verknuepfungen.find((v) => v.equipment_model_id === istTyp.id && v.exercise_id === istU.id)
          : undefined;
      const schluessel = `${g.key} > ${uKey}`;
      verknuepfungen.push(vergleiche(schluessel, { geraetetyp: g.key, uebung: uKey, sort_order: j + 1 }, istV, ["sort_order"]));

      // Nur Videos unter dem eigenen Praefix gehoeren dem Import; ein im
      // Portal ergaenztes Video an derselben Verknuepfung bleibt unberuehrt.
      const eigene = istV
        ? ist.videos.filter((x) => x.equipment_model_exercise_id === istV.id && x.storage_path.startsWith(videoPraefix(uKey)))
        : [];
      const medium = medien.videos.get(uKey);
      const video = uebungDatei.get(uKey)?.video ?? null;
      if (medium === undefined || video === null) {
        if (eigene.length > 0) gemeldet.videos.push(schluessel);
        return;
      }
      const posten = vergleiche(
        schluessel,
        { geraetetyp: g.key, uebung: uKey, storage_path: medium.storagePath, duration_s: video.duration_s },
        eigene[0],
        ["storage_path", "duration_s"],
      );
      if (posten.felder.includes("storage_path") && eigene[0]) ersetzt.add(`${VIDEO_BUCKET}/${eigene[0].storage_path}`);
      videos.push(posten);
    });
    if (istTyp) {
      for (const v of ist.verknuepfungen) {
        if (v.equipment_model_id === istTyp.id && !sollIds.has(v.exercise_id)) {
          gemeldet.verknuepfungen.push(`${g.key} > ${uebungNameNachId.get(v.exercise_id) ?? v.exercise_id}`);
        }
      }
    }
  }

  const typKeys = new Set(k.equipment.map((g) => g.key));
  const uebungKeys = new Set(k.exercises.map((u) => u.key));
  for (const g of ist.geraetetypen) {
    if (g.catalog_key === null) gemeldet.ohneSchluessel.push(`Geraetetyp "${g.name}"`);
    else if (!typKeys.has(g.catalog_key)) gemeldet.geraetetypen.push(g.catalog_key);
  }
  for (const u of ist.uebungen) {
    if (u.catalog_key === null) gemeldet.ohneSchluessel.push(`Uebung "${u.name}"`);
    else if (!uebungKeys.has(u.catalog_key)) gemeldet.uebungen.push(u.catalog_key);
  }
  gemeldet.ersetzteMedien = [...ersetzt];

  const uploads = [...medien.fotos.values(), ...medien.videos.values()].filter(
    (m) => !ist.objekte.has(`${m.bucket}/${m.storagePath}`),
  );

  return { geraetetypen, einstellungen, uebungen, verknuepfungen, videos, uploads, gemeldet };
}
```

- [ ] **Step 4: Tests laufen lassen, sie müssen bestehen**

Run: `pnpm --filter @fitretro/domain exec vitest run src/katalog-plan.test.ts && pnpm --filter @fitretro/domain typecheck`
Expected: PASS. Meckert der Typecheck, dass `IstGeraetetyp` nicht zu `Record<string, unknown>` passt, dann bekommt `vergleiche` als `ist`-Parameter den Typ `{ id: string } | undefined` und liest die Felder mit `(ist as Record<string, unknown>)[f]`.

- [ ] **Step 5: Commit**

```bash
git add packages/domain/src/katalog-plan.ts packages/domain/src/katalog-plan.test.ts
git commit -m "feat(katalog): Importplan aus Katalogdatei und Ist-Stand

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log -1 --format=%B
```

---

### Task 5: Bericht

**Files:**
- Modify: `packages/domain/src/katalog-plan.ts` (Funktion `berichtText` ergänzen)
- Test: `packages/domain/src/katalog-plan.test.ts` (neuer `describe`)

**Interfaces:**
- Produces: `berichtText(plan: ImportPlan): string`

- [ ] **Step 1: Den fehlschlagenden Test schreiben**

An `katalog-plan.test.ts` anhängen (Import um `berichtText` ergänzen):

```ts
describe("berichtText", () => {
  it("zaehlt je Tabelle, nennt Aenderungen und Gemeldetes", () => {
    const beispiel = beispielKatalog();
    const ist = istAus(plane(beispiel, LEER));
    ist.geraetetypen.push({ ...ist.geraetetypen[0]!, id: "alt", catalog_key: "alte_bank" });
    beispiel.roh.equipment[0]!.name = "Brustpresse neu";

    const text = berichtText(plane(beispiel, ist));
    expect(text).toContain("Geraetetypen: 0 neu, 1 geaendert, 2 unveraendert");
    expect(text).toContain("  ~ brustpresse (name)");
    expect(text).toContain("Uploads: 0 Dateien (0.0 MB)");
    expect(text).toContain("Nur in der Datenbank, nicht geloescht -- Geraetetypen: 1");
    expect(text).toContain("  - alte_bank");
  });

  it("kuerzt lange Listen auf 20 Eintraege", () => {
    const beispiel = beispielKatalog();
    const ist = istAus(plane(beispiel, LEER));
    for (let i = 0; i < 25; i += 1) ist.uebungen.push({ ...ist.uebungen[0]!, id: `h${i}`, catalog_key: null, name: `Hand ${i}` });
    const text = berichtText(plane(beispiel, ist));
    expect(text).toContain("Katalogzeilen ohne Schluessel, nicht verwaltet: 25");
    expect(text).toContain("  ... und 5 weitere");
  });
});
```

- [ ] **Step 2: Test laufen lassen, er muss scheitern**

Run: `pnpm --filter @fitretro/domain exec vitest run src/katalog-plan.test.ts`
Expected: FAIL. `berichtText` wird nicht exportiert.

- [ ] **Step 3: Umsetzung schreiben**

An `katalog-plan.ts` anhängen:

```ts
const HOECHSTENS = 20;

/** Der Text fuer Trockenlauf und echten Lauf -- derselbe, damit man vergleichen kann. */
export function berichtText(plan: ImportPlan): string {
  const zeilen: string[] = [];
  const liste = (eintraege: string[]) => {
    for (const e of eintraege.slice(0, HOECHSTENS)) zeilen.push(`  ${e}`);
    if (eintraege.length > HOECHSTENS) zeilen.push(`  ... und ${eintraege.length - HOECHSTENS} weitere`);
  };
  const tabelle = (titel: string, posten: Posten<unknown>[]) => {
    const zahl = (art: Art) => posten.filter((p) => p.art === art).length;
    zeilen.push(`${titel}: ${zahl("neu")} neu, ${zahl("geaendert")} geaendert, ${zahl("unveraendert")} unveraendert`);
    liste(
      posten.flatMap((p) =>
        p.art === "neu" ? [`+ ${p.schluessel}`] : p.art === "geaendert" ? [`~ ${p.schluessel} (${p.felder.join(", ")})`] : [],
      ),
    );
  };
  const melden = (titel: string, eintraege: string[]) => {
    if (eintraege.length === 0) return;
    zeilen.push(`${titel}: ${eintraege.length}`);
    liste(eintraege.map((e) => `- ${e}`));
  };

  tabelle("Geraetetypen", plan.geraetetypen);
  tabelle("Einstellungen", plan.einstellungen);
  tabelle("Uebungen", plan.uebungen);
  tabelle("Verknuepfungen", plan.verknuepfungen);
  tabelle("Videos", plan.videos);
  const bytes = plan.uploads.reduce((summe, m) => summe + m.bytes.length, 0);
  zeilen.push(`Uploads: ${plan.uploads.length} Dateien (${(bytes / 1024 / 1024).toFixed(1)} MB)`);

  melden("Nur in der Datenbank, nicht geloescht -- Geraetetypen", plan.gemeldet.geraetetypen);
  melden("Nur in der Datenbank, nicht geloescht -- Uebungen", plan.gemeldet.uebungen);
  melden("Nur in der Datenbank, nicht geloescht -- Einstellungen", plan.gemeldet.einstellungen);
  melden("Nur in der Datenbank, nicht geloescht -- Verknuepfungen", plan.gemeldet.verknuepfungen);
  melden("Video in der Datei entfernt, in der Datenbank behalten", plan.gemeldet.videos);
  melden("Ersetzte Medienobjekte, nicht geloescht", plan.gemeldet.ersetzteMedien);
  melden("Katalogzeilen ohne Schluessel, nicht verwaltet", plan.gemeldet.ohneSchluessel);
  return zeilen.join("\n");
}
```

- [ ] **Step 4: Tests laufen lassen, sie müssen bestehen**

Run: `pnpm --filter @fitretro/domain exec vitest run src/katalog-plan.test.ts && pnpm --filter @fitretro/domain typecheck`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/domain/src/katalog-plan.ts packages/domain/src/katalog-plan.test.ts
git commit -m "feat(katalog): Bericht fuer Trockenlauf und Import

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log -1 --format=%B
```

---

### Task 6: Ist-Stand lesen und Plan ausführen

**Files:**
- Create: `packages/domain/src/katalog-import.ts`
- Modify: `packages/domain/package.json` (exports: `"./katalog-import": "./src/katalog-import.ts"`)
- Test: `tests/integration/katalog-import.test.ts`

**Interfaces:**
- Consumes: alles aus Task 2–5, `DomainError`.
- Produces (aus `@fitretro/domain/katalog-import`):
  - `leseIstStand(admin: SupabaseClient): Promise<IstStand>`
  - `type Geschrieben = { uploads: number; geraetetypen: number; einstellungen: number; uebungen: number; verknuepfungen: number; videos: number }`
  - `fuehreAus(admin: SupabaseClient, plan: ImportPlan): Promise<Geschrieben>`
  - `importiereKatalog(admin: SupabaseClient, katalog: KatalogDatei, medien: Medien, optionen: { trocken: boolean }): Promise<{ plan: ImportPlan; geschrieben: Geschrieben | null }>`
  - Re-Exporte: `GYMTAVO_STUDIO_ID`, `pruefeKatalog`, `pruefeMedien`, `ladeKatalog`, `planeImport`, `berichtText` sowie die Typen `KatalogDatei`, `Medien`, `Medium`, `ImportPlan`, `IstStand`, `Posten`.

- [ ] **Step 1: Den fehlschlagenden Test schreiben**

`tests/integration/katalog-import.test.ts`:

```ts
import { afterAll, describe, expect, it } from "vitest";
import { serviceClient } from "./helpers/clients.js";
import {
  GYMTAVO_STUDIO_ID,
  fuehreAus,
  importiereKatalog,
  leseIstStand,
  planeImport,
  pruefeKatalog,
  pruefeMedien,
  type Posten,
} from "@fitretro/domain/katalog-import";
import { beispielKatalog, mp4Bytes, pngBytes } from "@fitretro/domain/katalog-testdaten";

// Spec 2026-10-06-gymtavo-katalog-offener-zugang-design.md, Abschnitt 9.1.
// Die lokale Datenbank teilen sich mehrere Sitzungen: jeder Block arbeitet
// mit eigenem Praefix und raeumt nur seine eigenen Zeilen und Objekte ab.
const admin = serviceClient();
const praefixe: string[] = [];
const objekte = new Set<string>();

function neuerPraefix(): string {
  const p = `t_${crypto.randomUUID().slice(0, 8)}_`;
  praefixe.push(p);
  return p;
}

function geladen(beispiel: ReturnType<typeof beispielKatalog>) {
  const k = pruefeKatalog(beispiel.roh);
  if (!k.ok) throw new Error(k.fehler.join("\n"));
  const m = pruefeMedien(k.wert, (d) => beispiel.dateien.get(d) ?? null);
  if (!m.ok) throw new Error(m.fehler.join("\n"));
  return { katalog: k.wert, medien: m.wert };
}

async function importiere(beispiel: ReturnType<typeof beispielKatalog>, trocken = false) {
  const { katalog, medien } = geladen(beispiel);
  const ergebnis = await importiereKatalog(admin, katalog, medien, { trocken });
  if (!trocken) for (const m of ergebnis.plan.uploads) objekte.add(`${m.bucket}/${m.storagePath}`);
  return ergebnis;
}

function eigene<Z>(liste: Posten<Z>[], p: string): Posten<Z>[] {
  return liste.filter((x) => x.schluessel.startsWith(p));
}

async function modell(key: string) {
  const { data, error } = await admin.from("equipment_models").select("*").eq("studio_id", GYMTAVO_STUDIO_ID).eq("catalog_key", key).single();
  if (error) throw error;
  return data;
}

async function uebungId(key: string): Promise<string> {
  const { data, error } = await admin.from("exercises").select("id").eq("studio_id", GYMTAVO_STUDIO_ID).eq("catalog_key", key).single();
  if (error) throw error;
  return data.id;
}

async function verknuepfung(typKey: string, uebungKey: string) {
  const typ = await modell(typKey);
  const { data, error } = await admin
    .from("equipment_model_exercises")
    .select("id, sort_order, instruction_assets(id, storage_path, duration_s)")
    .eq("equipment_model_id", typ.id)
    .eq("exercise_id", await uebungId(uebungKey))
    .maybeSingle();
  if (error) throw error;
  return data;
}

async function objektDa(bucketUndPfad: string): Promise<boolean> {
  const [bucket, ...rest] = bucketUndPfad.split("/");
  const { error } = await admin.storage.from(bucket!).download(rest.join("/"));
  return error === null;
}

afterAll(async () => {
  for (const p of praefixe) {
    const muster = `${p.replaceAll("_", "\\_")}%`;
    // Einstellungen, Verknuepfungen und Videos haengen per Kaskade daran.
    await admin.from("equipment_models").delete().eq("studio_id", GYMTAVO_STUDIO_ID).like("catalog_key", muster);
    await admin.from("exercises").delete().eq("studio_id", GYMTAVO_STUDIO_ID).like("catalog_key", muster);
  }
  const nachBucket = new Map<string, string[]>();
  for (const o of objekte) {
    const [bucket, ...rest] = o.split("/");
    nachBucket.set(bucket!, [...(nachBucket.get(bucket!) ?? []), rest.join("/")]);
  }
  for (const [bucket, pfade] of nachBucket) await admin.storage.from(bucket).remove(pfade);
});

describe("Katalogimport", () => {
  const p = neuerPraefix();
  const beispiel = beispielKatalog(p);
  let erstesTrizepsVideo = "";

  it("legt beim ersten Lauf alles an", async () => {
    const { plan, geschrieben } = await importiere(beispiel);

    expect(eigene(plan.geraetetypen, p).map((x) => x.art)).toEqual(["neu", "neu", "neu"]);
    expect(geschrieben).toEqual({ uploads: 3, geraetetypen: 3, einstellungen: 2, uebungen: 3, verknuepfungen: 4, videos: 3 });

    const laufband = await modell(`${p}laufband`);
    expect(laufband).toMatchObject({ category: "cardio", load_unit: "kmh", manufacturer: "Precor", secondary_unit: "pct" });
    expect(Number(laufband.load_step)).toBe(0.1);

    const brustpresse = await modell(`${p}brustpresse`);
    expect(await objektDa(`equipment-photos/${brustpresse.photo_path}`)).toBe(true);

    const a = await verknuepfung(`${p}brustpresse`, `${p}trizeps_druecken`);
    const b = await verknuepfung(`${p}trizepsmaschine`, `${p}trizeps_druecken`);
    expect(a?.sort_order).toBe(2);
    expect(a?.instruction_assets).toHaveLength(1);
    expect(b?.instruction_assets).toEqual(a?.instruction_assets.map((v) => ({ ...v, id: expect.any(String) })));
    erstesTrizepsVideo = a!.instruction_assets[0]!.storage_path;
  });

  it("aendert beim zweiten Lauf nichts", async () => {
    const vorher = await modell(`${p}laufband`);
    const { plan, geschrieben } = await importiere(beispiel);

    for (const liste of [plan.geraetetypen, plan.einstellungen, plan.uebungen, plan.verknuepfungen, plan.videos]) {
      expect(eigene<unknown>(liste, p).every((x) => x.art === "unveraendert")).toBe(true);
    }
    expect(geschrieben).toEqual({ uploads: 0, geraetetypen: 0, einstellungen: 0, uebungen: 0, verknuepfungen: 0, videos: 0 });
    expect((await modell(`${p}laufband`)).updated_at).toBe(vorher.updated_at);
  });

  it("uebernimmt Aenderungen und meldet das ersetzte Video", async () => {
    beispiel.roh.equipment[0]!.name = "Brustpresse neu";
    beispiel.roh.equipment[2]!.load_step = 0.5;
    beispiel.dateien.set("media/videos/trizeps.mp4", mp4Bytes(5, 99));

    const { plan } = await importiere(beispiel);

    expect(eigene(plan.geraetetypen, p).map((x) => x.felder)).toEqual([["name"], [], ["load_step"]]);
    expect(plan.gemeldet.ersetzteMedien).toContain(`instruction-videos/${erstesTrizepsVideo}`);
    const a = await verknuepfung(`${p}brustpresse`, `${p}trizeps_druecken`);
    const b = await verknuepfung(`${p}trizepsmaschine`, `${p}trizeps_druecken`);
    expect(a?.instruction_assets[0]?.storage_path).not.toBe(erstesTrizepsVideo);
    expect(b?.instruction_assets[0]?.storage_path).toBe(a?.instruction_assets[0]?.storage_path);
    expect(await objektDa(`instruction-videos/${erstesTrizepsVideo}`)).toBe(true);
  });

  it("meldet Entferntes nur und loescht nichts", async () => {
    beispiel.roh.equipment[0]!.settings.pop();
    beispiel.roh.equipment[2]!.exercises = [];
    beispiel.roh.exercises.splice(2, 1);

    const { plan } = await importiere(beispiel);

    expect(plan.gemeldet.einstellungen).toContain(`${p}brustpresse.griff`);
    expect(plan.gemeldet.uebungen).toContain(`${p}gehen`);
    expect(plan.gemeldet.verknuepfungen).toContain(`${p}laufband > ${p}gehen`);
    expect(await verknuepfung(`${p}laufband`, `${p}gehen`)).not.toBeNull();
    const { data } = await admin.from("equipment_setting_definitions").select("key").eq("equipment_model_id", (await modell(`${p}brustpresse`)).id);
    expect(data?.map((e) => e.key).sort()).toEqual(["griff", "sitzhoehe"]);
  });
});

describe("Trockenlauf", () => {
  it("laedt nichts hoch und schreibt nichts", async () => {
    const p = neuerPraefix();
    const { plan, geschrieben } = await importiere(beispielKatalog(p), true);

    expect(geschrieben).toBeNull();
    expect(eigene(plan.geraetetypen, p).map((x) => x.art)).toEqual(["neu", "neu", "neu"]);
    const { data } = await admin.from("equipment_models").select("id").like("catalog_key", `${p.replaceAll("_", "\\_")}%`);
    expect(data).toEqual([]);
    for (const m of plan.uploads.filter((u) => u.storagePath.includes(p))) {
      expect(await objektDa(`${m.bucket}/${m.storagePath}`)).toBe(false);
    }
  });
});

describe("Fremdes, Abbrueche und vorhandene Objekte", () => {
  const p = neuerPraefix();
  const beispiel = beispielKatalog(p);

  it("laesst ein im Portal hochgeladenes Video unberuehrt", async () => {
    await importiere(beispiel);
    const link = await verknuepfung(`${p}brustpresse`, `${p}brustpresse_neutral`);
    const fremd = await admin
      .from("instruction_assets")
      .insert({ equipment_model_exercise_id: link!.id, kind: "video", storage_path: `${GYMTAVO_STUDIO_ID}/portal/${p}eigen.mp4`, duration_s: 10 })
      .select("id")
      .single();
    if (fremd.error) throw fremd.error;
    beispiel.dateien.set("media/videos/brustpresse_neutral.mp4", mp4Bytes(6, 55));

    await importiere(beispiel);

    const nachher = await verknuepfung(`${p}brustpresse`, `${p}brustpresse_neutral`);
    expect(nachher?.instruction_assets).toHaveLength(2);
    expect(nachher?.instruction_assets.find((v) => v.id === fremd.data.id)).toMatchObject({ duration_s: 10, storage_path: `${GYMTAVO_STUDIO_ID}/portal/${p}eigen.mp4` });
  });

  it("setzt nach einem Abbruch fort", async () => {
    const link = await verknuepfung(`${p}trizepsmaschine`, `${p}trizeps_druecken`);
    await admin.from("equipment_model_exercises").delete().eq("id", link!.id);

    const { plan } = await importiere(beispiel);

    expect(eigene(plan.verknuepfungen, p).filter((x) => x.art === "neu").map((x) => x.schluessel)).toEqual([`${p}trizepsmaschine > ${p}trizeps_druecken`]);
    expect(eigene(plan.videos, p).filter((x) => x.art === "neu").map((x) => x.schluessel)).toEqual([`${p}trizepsmaschine > ${p}trizeps_druecken`]);
    expect((await verknuepfung(`${p}trizepsmaschine`, `${p}trizeps_druecken`))?.instruction_assets).toHaveLength(1);
  });

  it("nimmt ein schon hochgeladenes Objekt hin", async () => {
    beispiel.dateien.set("media/photos/brustpresse.png", pngBytes(4242));
    const { katalog, medien } = geladen(beispiel);
    const plan = planeImport(katalog, medien, await leseIstStand(admin));
    const foto = plan.uploads.find((m) => m.bucket === "equipment-photos")!;
    objekte.add(`${foto.bucket}/${foto.storagePath}`);
    const vorab = await admin.storage.from(foto.bucket).upload(foto.storagePath, foto.bytes, { contentType: foto.contentType });
    expect(vorab.error).toBeNull();

    await fuehreAus(admin, plan);

    expect((await modell(`${p}brustpresse`)).photo_path).toBe(foto.storagePath);
  });
});
```

- [ ] **Step 2: Test laufen lassen, er muss scheitern**

Run: `pnpm vitest run --config vitest.config.ts tests/integration/katalog-import.test.ts`
Expected: FAIL, `@fitretro/domain/katalog-import` lässt sich nicht auflösen.

- [ ] **Step 3: Umsetzung schreiben**

In `packages/domain/package.json` unter `exports` ergänzen: `"./katalog-import": "./src/katalog-import.ts"`.

`packages/domain/src/katalog-import.ts`:

```ts
import type { SupabaseClient } from "@supabase/supabase-js";
import { DomainError } from "./errors.js";
import { GYMTAVO_STUDIO_ID, type KatalogDatei } from "./katalog-datei.js";
import type { Medien, Medium } from "./katalog-medien.js";
import {
  planeImport,
  type ImportPlan,
  type IstEinstellung,
  type IstGeraetetyp,
  type IstStand,
  type IstUebung,
  type IstVerknuepfung,
  type IstVideo,
  type Posten,
} from "./katalog-plan.js";
import { PHOTO_BUCKET, VIDEO_BUCKET } from "./media.js";

/**
 * Der Katalogimport gegen eine echte Datenbank: Ist-Stand lesen, Plan
 * ausfuehren. Nur mit einem Service-Client sinnvoll -- deshalb wie
 * "@fitretro/domain/chargen" ein eigener Unterpfad, nicht der Hauptexport.
 *
 * Eine Transaktion ueber alles gibt es nicht (Spec 9.1, Weg 1). Das ist
 * vertretbar, weil jeder Schritt ein Upsert ist und nie geloescht wird: ein
 * abgebrochener Lauf hinterlaesst "noch nicht alles aktualisiert", und der
 * naechste Lauf setzt dort fort.
 */

export { GYMTAVO_STUDIO_ID, pruefeKatalog, type KatalogDatei } from "./katalog-datei.js";
export { pruefeMedien, type Medien, type Medium } from "./katalog-medien.js";
export { ladeKatalog } from "./katalog-laden.js";
export { berichtText, planeImport, type ImportPlan, type IstStand, type Posten } from "./katalog-plan.js";

/** PostgREST liefert hoechstens max_rows Zeilen (1000, supabase/config.toml). */
const BLOCK = 500;

type Antwort<T> = { data: T[] | null; error: { message: string } | null };

async function alleZeilen<T>(seite: (von: number, bis: number) => PromiseLike<Antwort<T>>): Promise<T[]> {
  const zeilen: T[] = [];
  for (let von = 0; ; von += BLOCK) {
    const { data, error } = await seite(von, von + BLOCK - 1);
    if (error) throw new DomainError("internal", error.message);
    zeilen.push(...(data ?? []));
    if ((data ?? []).length < BLOCK) return zeilen;
  }
}

async function objekteUnter(admin: SupabaseClient, bucket: string, ordner: string): Promise<string[]> {
  const pfade: string[] = [];
  for (let offset = 0; ; offset += BLOCK) {
    const { data, error } = await admin.storage
      .from(bucket)
      .list(ordner, { limit: BLOCK, offset, sortBy: { column: "name", order: "asc" } });
    if (error) throw new DomainError("internal", error.message);
    pfade.push(...data.map((o) => `${bucket}/${ordner}/${o.name}`));
    if (data.length < BLOCK) return pfade;
  }
}

export async function leseIstStand(admin: SupabaseClient): Promise<IstStand> {
  const studio = await admin.from("studios").select("id").eq("id", GYMTAVO_STUDIO_ID).eq("is_catalog", true).maybeSingle();
  if (studio.error) throw new DomainError("internal", studio.error.message);
  if (studio.data === null) {
    throw new DomainError("not_found", "Das Gymtavo-Studio fehlt. Zuerst die Migrationen bis 0048 anwenden.");
  }

  const geraetetypen = await alleZeilen<IstGeraetetyp>((von, bis) =>
    admin
      .from("equipment_models")
      .select("id, catalog_key, name, category, manufacturer, photo_path, load_unit, load_step, load_min, load_max, secondary_unit, secondary_step, secondary_min, secondary_max")
      .eq("studio_id", GYMTAVO_STUDIO_ID)
      .order("id")
      .range(von, bis),
  );
  // Gefiltert ueber das eingebettete Modell statt ueber eine id-Liste: eine
  // Liste von Hunderten UUIDs sprengte die URL-Laenge von PostgREST.
  const einstellungen = await alleZeilen<IstEinstellung>((von, bis) =>
    admin
      .from("equipment_setting_definitions")
      .select("id, equipment_model_id, key, label, kind, min_value, max_value, step_value, unit, allowed_values, sort_order, equipment_models!inner(studio_id)")
      .eq("equipment_models.studio_id", GYMTAVO_STUDIO_ID)
      .order("id")
      .range(von, bis),
  );
  const uebungen = await alleZeilen<IstUebung>((von, bis) =>
    admin
      .from("exercises")
      .select("id, catalog_key, name, description, volume_kind, target_min, target_max")
      .eq("studio_id", GYMTAVO_STUDIO_ID)
      .order("id")
      .range(von, bis),
  );
  const verknuepfungen = await alleZeilen<IstVerknuepfung>((von, bis) =>
    admin
      .from("equipment_model_exercises")
      .select("id, equipment_model_id, exercise_id, sort_order, equipment_models!inner(studio_id)")
      .eq("equipment_models.studio_id", GYMTAVO_STUDIO_ID)
      .order("id")
      .range(von, bis),
  );
  const videos = await alleZeilen<IstVideo>((von, bis) =>
    admin
      .from("instruction_assets")
      .select("id, equipment_model_exercise_id, storage_path, duration_s, equipment_model_exercises!inner(equipment_models!inner(studio_id))")
      .eq("equipment_model_exercises.equipment_models.studio_id", GYMTAVO_STUDIO_ID)
      .order("id")
      .range(von, bis),
  );
  const objekte = new Set([
    ...(await objekteUnter(admin, PHOTO_BUCKET, `${GYMTAVO_STUDIO_ID}/catalog/photos`)),
    ...(await objekteUnter(admin, VIDEO_BUCKET, `${GYMTAVO_STUDIO_ID}/catalog/videos`)),
  ]);
  return { geraetetypen, einstellungen, uebungen, verknuepfungen, videos, objekte };
}

export type Geschrieben = {
  uploads: number;
  geraetetypen: number;
  einstellungen: number;
  uebungen: number;
  verknuepfungen: number;
  videos: number;
};

function zuSchreiben<Z>(liste: Posten<Z>[]): Posten<Z>[] {
  return liste.filter((p) => p.art !== "unveraendert");
}

function bloecke<T>(liste: T[]): T[][] {
  const ergebnis: T[][] = [];
  for (let i = 0; i < liste.length; i += BLOCK) ergebnis.push(liste.slice(i, i + BLOCK));
  return ergebnis;
}

function idVon(ids: ReadonlyMap<string, string>, schluessel: string): string {
  const id = ids.get(schluessel);
  if (id === undefined) throw new DomainError("internal", `Keine id fuer "${schluessel}".`);
  return id;
}

async function hochladen(admin: SupabaseClient, m: Medium): Promise<void> {
  const { error } = await admin.storage.from(m.bucket).upload(m.storagePath, m.bytes, { contentType: m.contentType, upsert: false });
  if (error === null) return;
  // Ein abgebrochener Lauf hat das Objekt vielleicht schon hochgeladen. Der
  // Pfad enthaelt den Inhaltshash, also liegt dort dieselbe Datei.
  const status = (error as { statusCode?: string }).statusCode;
  if (status === "409" || /exists|duplicate/i.test(error.message)) return;
  throw new DomainError("internal", `${m.datei}: Upload fehlgeschlagen (${error.message})`);
}

export async function fuehreAus(admin: SupabaseClient, plan: ImportPlan): Promise<Geschrieben> {
  // Medien zuerst: so zeigt nie ein Datensatz auf eine noch fehlende Datei.
  for (const m of plan.uploads) await hochladen(admin, m);

  const typIds = new Map(plan.geraetetypen.flatMap((p) => (p.id ? [[p.schluessel, p.id] as const] : [])));
  const type = zuSchreiben(plan.geraetetypen);
  for (const block of bloecke(type)) {
    const { data, error } = await admin
      .from("equipment_models")
      .upsert(block.map((p) => ({ studio_id: GYMTAVO_STUDIO_ID, ...p.zeile })), { onConflict: "studio_id,catalog_key" })
      .select("id, catalog_key");
    if (error) throw new DomainError("internal", `Geraetetypen: ${error.message}`);
    for (const z of data) typIds.set(z.catalog_key, z.id);
  }

  const einstellungen = zuSchreiben(plan.einstellungen);
  for (const block of bloecke(einstellungen)) {
    const zeilen = block.map((p) => {
      const { geraetetyp, ...zeile } = p.zeile;
      return { equipment_model_id: idVon(typIds, geraetetyp), ...zeile };
    });
    const { error } = await admin.from("equipment_setting_definitions").upsert(zeilen, { onConflict: "equipment_model_id,key" });
    if (error) throw new DomainError("internal", `Einstellungen: ${error.message}`);
  }

  const uebungIds = new Map(plan.uebungen.flatMap((p) => (p.id ? [[p.schluessel, p.id] as const] : [])));
  const uebungen = zuSchreiben(plan.uebungen);
  for (const block of bloecke(uebungen)) {
    const { data, error } = await admin
      .from("exercises")
      .upsert(block.map((p) => ({ studio_id: GYMTAVO_STUDIO_ID, ...p.zeile })), { onConflict: "studio_id,catalog_key" })
      .select("id, catalog_key");
    if (error) throw new DomainError("internal", `Uebungen: ${error.message}`);
    for (const z of data) uebungIds.set(z.catalog_key, z.id);
  }

  const linkIds = new Map(plan.verknuepfungen.flatMap((p) => (p.id ? [[p.schluessel, p.id] as const] : [])));
  const verknuepfungen = zuSchreiben(plan.verknuepfungen);
  for (const block of bloecke(verknuepfungen)) {
    const nachIds = new Map(
      block.map((p) => [`${idVon(typIds, p.zeile.geraetetyp)}|${idVon(uebungIds, p.zeile.uebung)}`, p.schluessel]),
    );
    const { data, error } = await admin
      .from("equipment_model_exercises")
      .upsert(
        block.map((p) => ({
          equipment_model_id: idVon(typIds, p.zeile.geraetetyp),
          exercise_id: idVon(uebungIds, p.zeile.uebung),
          sort_order: p.zeile.sort_order,
        })),
        { onConflict: "equipment_model_id,exercise_id" },
      )
      .select("id, equipment_model_id, exercise_id");
    if (error) throw new DomainError("internal", `Verknuepfungen: ${error.message}`);
    for (const z of data) linkIds.set(idVon(nachIds, `${z.equipment_model_id}|${z.exercise_id}`), z.id);
  }

  const videos = zuSchreiben(plan.videos);
  for (const p of videos) {
    const werte = { storage_path: p.zeile.storage_path, duration_s: p.zeile.duration_s };
    const { error } =
      p.id === null
        ? await admin.from("instruction_assets").insert({ equipment_model_exercise_id: idVon(linkIds, p.schluessel), kind: "video", ...werte })
        : await admin.from("instruction_assets").update(werte).eq("id", p.id);
    if (error) throw new DomainError("internal", `Video ${p.schluessel}: ${error.message}`);
  }

  return {
    uploads: plan.uploads.length,
    geraetetypen: type.length,
    einstellungen: einstellungen.length,
    uebungen: uebungen.length,
    verknuepfungen: verknuepfungen.length,
    videos: videos.length,
  };
}

export async function importiereKatalog(
  admin: SupabaseClient,
  katalog: KatalogDatei,
  medien: Medien,
  optionen: { trocken: boolean },
): Promise<{ plan: ImportPlan; geschrieben: Geschrieben | null }> {
  const plan = planeImport(katalog, medien, await leseIstStand(admin));
  if (optionen.trocken) return { plan, geschrieben: null };
  return { plan, geschrieben: await fuehreAus(admin, plan) };
}
```

- [ ] **Step 4: Test laufen lassen, er muss bestehen**

Run: `pnpm vitest run --config vitest.config.ts tests/integration/katalog-import.test.ts && pnpm typecheck`
Expected: PASS (8 Tests). Scheitert ein Test mit PGRST204 zu einer Spalte, die es auf dem Branch gar nicht gibt, ist die geteilte Datenbank einer anderen Sitzung voraus (siehe Memory „Lokale Testumgebung: Fallen“). Dann vor jeder Fehlersuche `select max(version) from supabase_migrations.schema_migrations` prüfen.

- [ ] **Step 5: Commit**

```bash
git add packages/domain/src/katalog-import.ts packages/domain/package.json tests/integration/katalog-import.test.ts
git commit -m "feat(katalog): Ist-Stand lesen und Importplan ausfuehren

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log -1 --format=%B
```

---

### Task 7: Kommandozeile `pnpm catalog:import`

**Files:**
- Create: `scripts/catalog-import.ts`
- Modify: `package.json` (Skript `"catalog:import": "tsx scripts/catalog-import.ts"`)

**Interfaces:**
- Consumes: `ladeKatalog`, `importiereKatalog`, `berichtText` aus `@fitretro/domain/katalog-import`, `DomainError` aus `@fitretro/domain`.

- [ ] **Step 1: Skript schreiben**

`scripts/catalog-import.ts`:

```ts
#!/usr/bin/env tsx
import { parseArgs } from "node:util";
import { createClient } from "@supabase/supabase-js";
import "dotenv/config";
import { DomainError } from "@fitretro/domain";
import { berichtText, importiereKatalog, ladeKatalog } from "@fitretro/domain/katalog-import";

/**
 * Gleicht den Gymtavo-Katalog mit catalog/gymtavo.json ab (Spec 9.1). Schreibt
 * mit dem Service-Role-Schluessel und laeuft irgendwann gegen Produktion --
 * deshalb nennt es sein Ziel und verlangt ausserhalb von 127.0.0.1 ein --ja,
 * wie pnpm tags. Der Trockenlauf schreibt nichts und braucht es nicht.
 */

const HILFE = `Aufruf: pnpm catalog:import [datei] [--dry-run] [--ja]

  datei      Katalogdatei, Vorgabe catalog/gymtavo.json
  --dry-run  zeigt den Plan; laedt nichts hoch und schreibt nichts
  --ja       bestaetigt das Schreiben gegen ein nicht-lokales Ziel
`;

function umgebung(name: string): string {
  const wert = process.env[name];
  if (!wert) throw new DomainError("validation_failed", `Umgebungsvariable ${name} fehlt.`);
  return wert;
}

async function main(): Promise<void> {
  const { values, positionals } = parseArgs({
    allowPositionals: true,
    options: {
      "dry-run": { type: "boolean", default: false },
      ja: { type: "boolean", default: false },
      hilfe: { type: "boolean", short: "h", default: false },
    },
  });
  if (values.hilfe === true || positionals.length > 1) {
    console.log(HILFE);
    return;
  }

  const datei = positionals[0] ?? "catalog/gymtavo.json";
  const geladen = ladeKatalog(datei);
  if (!geladen.ok) {
    console.error(`${geladen.fehler.length} Fehler in ${datei}, nichts geschrieben:`);
    for (const fehler of geladen.fehler) console.error(`  ${fehler}`);
    process.exit(1);
  }

  const url = umgebung("SUPABASE_URL");
  const trocken = values["dry-run"] === true;
  console.log(`Ziel: ${url}${trocken ? " (Trockenlauf)" : ""}`);
  const lokal = url.includes("127.0.0.1") || url.includes("localhost");
  if (!lokal && !trocken && values.ja !== true) {
    throw new DomainError(
      "validation_failed",
      "Das ist kein lokales Ziel. Wiederhole den Aufruf mit --ja, wenn du das willst.",
    );
  }

  const admin = createClient(url, umgebung("SUPABASE_SERVICE_ROLE_KEY"), {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { plan, geschrieben } = await importiereKatalog(admin, geladen.wert.katalog, geladen.wert.medien, { trocken });
  console.log(berichtText(plan));
  console.log(
    geschrieben === null
      ? "Trockenlauf: nichts hochgeladen, nichts geschrieben."
      : `Geschrieben: ${geschrieben.uploads} Uploads, ${geschrieben.geraetetypen} Geraetetypen, ${geschrieben.einstellungen} Einstellungen, ${geschrieben.uebungen} Uebungen, ${geschrieben.verknuepfungen} Verknuepfungen, ${geschrieben.videos} Videos.`,
  );
}

main().catch((fehler: unknown) => {
  if (fehler instanceof DomainError) {
    console.error(`${fehler.code}: ${fehler.message}`);
    process.exit(1);
  }
  console.error(fehler);
  process.exit(1);
});
```

In der Wurzel-`package.json` unter `scripts` nach `"tags"` ergänzen: `"catalog:import": "tsx scripts/catalog-import.ts"`.

- [ ] **Step 2: Fehlerfall von Hand prüfen**

```bash
D=/private/tmp/claude-501/-Users-timbuttner-Documents-fitness-app/f6409ea4-c1d0-4491-b2be-0d5f24836fc0/scratchpad/kaputt
mkdir -p "$D" && echo '{"format":2,"muscles":[],"sources":[],"equipment":[{"key":"Bank"}],"exercises":[]}' > "$D/k.json"
pnpm catalog:import "$D/k.json"; echo "Exit: $?"
pnpm catalog:import --hilfe
```
Expected: `… Fehler in …, nichts geschrieben:`, darunter Zeilen wie `format: muss 1 sein` und `equipment[0] "Bank" key: darf nur a-z, 0-9 und _ enthalten`, danach `Exit: 1`. `--hilfe` gibt den Hilfetext aus.

- [ ] **Step 3: Commit**

```bash
git add scripts/catalog-import.ts package.json
git commit -m "feat(katalog): pnpm catalog:import mit Trockenlauf und Zielschutz

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log -1 --format=%B
```

---

### Task 8: Bestand aus dem GYMTAVO-Paket konvertieren und lokal importieren

**Files:**
- Create (außerhalb des Repos): `<scratchpad>/konverter/gymtavo_konverter.py`
- Create: `catalog/gymtavo.json`, `catalog/media/photos/*.png`, `catalog/media/videos/*.mp4`

Das Paket gilt als nicht vertrauenswürdige Datenquelle. Das Python-Skript liegt deshalb in einem eigenen Ordner im Scratchpad, läuft mit `python3 -I` und bekommt die Paketpfade als Argumente. Keines der Skripte aus dem Paket wird ausgeführt.

- [ ] **Step 1: Konverter schreiben**

`/private/tmp/claude-501/-Users-timbuttner-Documents-fitness-app/f6409ea4-c1d0-4491-b2be-0d5f24836fc0/scratchpad/konverter/gymtavo_konverter.py`:

```python
"""Einmaliger Konverter: GYMTAVO-Paket -> catalog/gymtavo.json + catalog/media.

Aufruf: python3 -I gymtavo_konverter.py <paketordner> <repo>/catalog
Liest nur JSON und kopiert Medien. Fuehrt nichts aus dem Paket aus.
"""
import json
import shutil
import sys
from pathlib import Path

paket = Path(sys.argv[1]).resolve()
ziel = Path(sys.argv[2]).resolve()


def lade(pfad):
    return json.loads((paket / pfad).read_text(encoding="utf-8"))


orig = lade("katalog-162.json")
modelle = lade("import/equipment_models.json")
einstellungen = lade("import/equipment_setting_definitions.json")
uebungen = lade("import/exercises.json")
links = lade("import/equipment_model_exercises.json")
assets = lade("import/instruction_assets.json")
idmap = lade("import/id-map.json")
manifest = lade("import/storage-manifest.json")

key_von = {e["id"]: e["source_id"] for e in idmap}
orig_uebung = {e["id"]: e for e in orig["exercises"]}
foto_quelle = {m["storage_path"]: m["local_path"] for m in manifest}
video_von_link = {a["equipment_model_exercise_id"]: a for a in assets}

(ziel / "media/photos").mkdir(parents=True, exist_ok=True)
(ziel / "media/videos").mkdir(parents=True, exist_ok=True)


def ohne_muskelgruppen(text):
    # Spec 9.1: Muskeln stehen strukturiert in der Datei, nicht mehr im Text.
    return "\n\n".join(t for t in text.split("\n\n") if not t.startswith("Muskelgruppen:\n"))


def sicher_in_paket(relativ):
    pfad = (paket / relativ).resolve()
    if paket not in pfad.parents:
        raise SystemExit(f"Pfad ausserhalb des Pakets: {relativ}")
    return pfad


equipment = []
for m in modelle:
    key = key_von[m["id"]]
    foto = None
    if m["photo_path"]:
        quelle = sicher_in_paket(foto_quelle[m["photo_path"]])
        foto = f"media/photos/{key}{quelle.suffix}"
        shutil.copyfile(quelle, ziel / foto)
    settings = []
    for e in sorted((e for e in einstellungen if e["equipment_model_id"] == m["id"]), key=lambda e: e["sort_order"]):
        if e["kind"] == "enum":
            settings.append({"key": e["key"], "label": e["label"], "kind": "enum", "allowed_values": e["allowed_values"]})
        else:
            settings.append({"key": e["key"], "label": e["label"], "kind": "number",
                             "min": e["min_value"], "max": e["max_value"], "step": e["step_value"], "unit": e["unit"]})
    secondary = None
    if m["secondary_unit"]:
        secondary = {"unit": m["secondary_unit"], "step": m["secondary_step"],
                     "min": m["secondary_min"], "max": m["secondary_max"]}
    eigene_links = sorted((l for l in links if l["equipment_model_id"] == m["id"]), key=lambda l: l["sort_order"])
    equipment.append({
        "key": key, "name": m["name"], "category": m["category"], "manufacturer": m["manufacturer"], "photo": foto,
        "load_unit": m["load_unit"], "load_step": m["load_step"], "load_min": m["load_min"], "load_max": m["load_max"],
        "secondary": secondary, "settings": settings,
        "exercises": [key_von[l["exercise_id"]] for l in eigene_links],
    })

exercises = []
for u in uebungen:
    key = key_von[u["id"]]
    o = orig_uebung[key]
    video = None
    for link in (l for l in links if l["exercise_id"] == u["id"]):
        asset = video_von_link.get(link["id"])
        if asset:
            quelle = sicher_in_paket(Path("media/videos") / Path(asset["storage_path"]).name)
            video = {"file": f"media/videos/{key}.mp4", "duration_s": asset["duration_s"]}
            shutil.copyfile(quelle, ziel / video["file"])
            break
    exercises.append({
        "key": key, "name": u["name"], "description": ohne_muskelgruppen(u["description"]),
        "volume_kind": u["volume_kind"], "target_min": u["target_min"], "target_max": u["target_max"],
        "video": video, "grip": o.get("grip"),
        "muscles": [{"muscle": mu["muscle_id"], "role": mu["role"]} for mu in o["muscles"]],
        "review": "reviewed" if o["review"]["status"] == "reviewed" else "draft",
        "sources": o["provenance"]["source_ids"],
    })

katalog = {
    "format": 1,
    "muscles": [{"key": m["id"], "name": m["name_de"]} for m in orig["muscles"]],
    "sources": [{"key": s["id"], "title": s["title"], "url": s["url"], "accessed_at": s["accessed_at"]} for s in orig["sources"]],
    "equipment": equipment,
    "exercises": exercises,
}
(ziel / "gymtavo.json").write_text(json.dumps(katalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"{len(equipment)} Geraetetypen, {len(exercises)} Uebungen, "
      f"{sum(1 for e in exercises if e['video'])} Videos, {sum(1 for e in equipment if e['photo'])} Fotos")
```

- [ ] **Step 2: Konverter laufen lassen**

```bash
python3 -I /private/tmp/claude-501/-Users-timbuttner-Documents-fitness-app/f6409ea4-c1d0-4491-b2be-0d5f24836fc0/scratchpad/konverter/gymtavo_konverter.py /Users/timbuttner/Downloads/GYMTAVO-Uebungsdatenbank "$PWD/catalog"
du -sh catalog/media; ls catalog/media/photos | wc -l; ls catalog/media/videos | wc -l
```
Expected: `55 Geraetetypen, 162 Uebungen, 162 Videos, 55 Fotos`, Medien zusammen etwa 7 MB, 55 Fotos, 162 Videos.

- [ ] **Step 3: Datei mit dem Trockenlauf prüfen**

Run: `pnpm catalog:import --dry-run`
Expected:
- Keine Prüffehler.
- `Geraetetypen: 55 neu, 0 geaendert, 0 unveraendert`, `Uebungen: 162 neu`, `Verknuepfungen: 162 neu`, `Videos: 162 neu`, `Uploads: 217 Dateien`.
- Dazu „Katalogzeilen ohne Schluessel, nicht verwaltet“ für die Testreste in der lokalen Datenbank.

Meldet die Prüfung Fehler, liegt das an den Paketdaten (etwa eine abweichende Videodauer). Den Fehler dann im Konverter oder in der Datei beheben, nicht in der Prüfung, und ihn im Ergebnis nennen.

- [ ] **Step 4: Zielschutz gegenprüfen**

Run: `SUPABASE_URL=https://beispiel.invalid pnpm catalog:import; echo "Exit: $?"`
Expected: `Ziel: https://beispiel.invalid`, dann `validation_failed: Das ist kein lokales Ziel. …`, `Exit: 1`. Kein Netzwerkzugriff, weil der Schutz vor dem Client greift.

- [ ] **Step 5: Lokal importieren, zweimal**

```bash
pnpm catalog:import
pnpm catalog:import
```
Expected:
- Erster Lauf: `Geschrieben: 217 Uploads, 55 Geraetetypen, 89 Einstellungen, 162 Uebungen, 162 Verknuepfungen, 162 Videos.`
- Zweiter Lauf: alles `unveraendert` und `Geschrieben: 0 Uploads, 0 …`.

Der Bestand bleibt in der geteilten lokalen Datenbank. Das ist unschädlich, weil die Katalogtests anderer Sitzungen nach eigenen IDs filtern.

- [ ] **Step 6: Sichtprobe der Daten**

```bash
docker exec supabase_db_m0-fundament psql -U postgres -tAc "select catalog_key, name, load_unit, load_step from equipment_models where catalog_key in ('chest_press','treadmill') order by 1; select count(*) from exercises where catalog_key is not null and studio_id='00000000-0000-4000-8000-000000000001';"
```
Expected: Brustpresse mit `kg|1`, Laufband mit `kmh|0.1`, 162 Übungen.

- [ ] **Step 7: Commit**

```bash
git add catalog
git commit -m "feat(katalog): Gymtavo-Bestand mit 55 Geraetetypen und 162 Uebungen als Katalogdatei

Konvertiert aus dem GYMTAVO-Paket (Originalkatalog Schema 0.11.0). Werte
sind die technischen Platzhalter des Pakets und vor produktivem Training zu
pruefen.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log -1 --format=%B
```

---

### Task 9: Gesamtprüfung und Ergebnis

**Files:**
- Modify: `docs/superpowers/plans/2026-10-10-gymtavo-katalog-etappe2-import.md` (Häkchen, Abschnitt „Ergebnis“)

- [ ] **Step 1: Alles laufen lassen**

```bash
pnpm typecheck
pnpm test
pnpm test:integration
```
Expected: alles grün. Rote Integrationstests vor der Fehlersuche gegen die bekannten Umgebungsfallen prüfen (geteilte Datenbank voraus, Docker-Uhr, `completeSession`-Flakes auf master) und im Ergebnis benennen. iOS ist nicht berührt, `xcodebuild test` entfällt.

- [ ] **Step 2: Ergebnis eintragen und Häkchen setzen**

Am Ende dieses Plans einen Abschnitt `## Ergebnis (<Datum>)` anlegen:
- Testzahlen.
- Ausgabe des zweiten lokalen Laufs (alles unverändert).
- Größe von `catalog/media`.
- Abweichungen vom Plan.
- Was Tim vor dem Produktionsimport tun muss: Migration 0048 nach dem Merge auf sein Wort, danach `pnpm catalog:import --dry-run` gegen Produktion, dann mit `--ja`.

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/plans/2026-10-10-gymtavo-katalog-etappe2-import.md
git commit -m "docs(plan): Etappe 2 umgesetzt und abgehakt

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log -1 --format=%B
```

Nicht pushen. Auf Tims Ansage folgen Push, PR, CI, Merge und danach die Produktion.
