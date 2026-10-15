# Cardio-Werte (E2) – Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cardio-Geräte erfassen je Satz bis zu acht optionale Werte (Zeit, Strecke, Stufe, km/h, Steigung, Watt, Frequenz, kcal), welche der Katalog-Typ festlegt, eingegeben über Knöpfe mit Zahleneingabe statt Rädern.

**Architecture:**
- **Server:** `equipment_models.cardio_werte` sagt, ob ein Gerät Cardio ist und welche Werte es hat, vererbt vom Katalog-Typ. `workout_sets` bekommt acht typisierte Spalten. Bei Cardio-Sätzen sind `load` und `volume` leer.
- **Alte Apps:** `recordSet` wandelt `load`/`volume` an einem Cardio-Gerät um.
- **Lesewege:** Alle liefern ein Objekt `cardio`.
- **App:** Am Cardio-Gerät ein Raster aus Wertknöpfen statt der Räder, eine Zeile „8:30 · 2,0 km · …“ in allen Anzeigen.
- **Migrationen:** Zwei Migrationen in getrennten Auslieferungsschritten.

**Tech Stack:**
- Postgres/Supabase-Migrationen.
- TypeScript-Domain (`packages/domain`, Zod, Vitest).
- Next.js-Portal (`apps/web`).
- SwiftUI-App (`apps/ios-member`, Swift Testing).

**Spec:** `docs/superpowers/specs/2026-10-15-cardio-werte-design.md`

## Global Constraints

- **Schlüssel und Reihenfolge, überall gleich:** `zeit, strecke, stufe, kmh, steigung, watt, frequenz, kcal`.
- **Spalten:** `dauer_s` int 1–86 400 · `strecke_m` int 1–200 000 · `stufe` int 0–100 · `kmh` numeric(4,1) 0–50 · `steigung_pct` numeric(4,1) −10–40 · `watt` int 0–3 000 · `kcal` int 0–10 000 · `frequenz` int 0–300.
- **JSON-Schlüssel** (API, App): `zeit, strecke, stufe, kmh, steigung, watt, kcal, frequenz`, immer im Objekt `cardio`.
- **Cardio-Gerät** heißt: Die vererbte Liste `cardio_werte` ist nicht leer. `category`/`equipment_group` bleiben Anzeige.
- **Fehlertexte (422 `validation_failed`):**
  - „Dieser Wert gehört nicht zu diesem Gerät.“
  - „Mindestens ein Wert fehlt.“
  - „Ein Cardio-Gerät hat keine Belastung.“
  - „Dieses Gerät hat keine Cardio-Werte.“
- **Keine Progression für Cardio.** Kein Vorschlag, keine Historie in der Regel.
- **Kommentare** verweisen auf „(Testnotiz 14.10., 18:45 #7)“. Bezeichner sind deutsch wie im Umfeld.
- **Auslieferung:**
  1. 0054 + `catalog:import`
  2. Web
  3. App
  4. 0055

  Kein Schritt vor dem vorigen, und jeder nur auf Freigabe.

## Review Focus

1. **Alter Cardio-Satz aus einer Warteschlange** (`load` + `volume`, kein `cardio`) trifft nach 0054 auf ein Cardio-Gerät. Erwartet: Er wird umgewandelt und gespeichert, nicht verworfen. → Integrationstest in Task 2.
2. **Studio-Modell mit leerer eigener Liste und Katalog-Typ:** erbt die Liste in `recordSet`, Bootstrap und Gerätekontext. → Tests in Task 2 und Task 3.
3. **„Weiterer Satz“ am Cardio-Gerät:** Das Raster ist mit den eben gesicherten Werten vorbelegt, nicht mit denen vom letzten Training. → Test in Task 8.
4. **Komma-Eingabe** („10,5“), ein Wert außerhalb des Bereichs, leeres Feld. → Tests in Task 7.
5. **Alter Verlauf-Cache und Antworten mit `load: null`:** dekodieren ohne Fehler, kein Totalausfall von Bootstrap oder Verlauf. → Tests in Task 6.

## Dateiübersicht

**Server**
- Neu: `packages/domain/src/cardio.ts` (Konstanten, Schema, Umwandlung, Prüfung, Zeilen-Mapping) und `packages/domain/src/cardio.test.ts`.
- `packages/domain/src/workout.ts`: Schema und `recordSet`. Dazu `stationAufloesen`, das die Liste mitliefert.
- `packages/domain/src/bootstrap.ts`, `sessions.ts`, `machine-context.ts`, `progress.ts`, `abschluss.ts`, `progression.ts` (Aufrufer): Lesewege, Cardio aus der Progression.
- `packages/domain/src/katalog-datei.ts`, `katalog-plan.ts`, `katalog-import.ts`; `catalog/gymtavo.json`.
- `packages/domain/src/catalog.ts`: `cardioWerte` in Modell-Eingabe und -Patch.
- `packages/domain/src/index.ts`: Exporte.
- `supabase/migrations/0054_cardio_werte.sql`, `0055_cardio_altdaten.sql`.
- Tests: `tests/integration/domain-cardio-werte.test.ts` (neu), `tests/integration/migration-cardio-altdaten.test.ts` (neu).

**Portal**
- `apps/web/app/portal/formfelder.ts` und `formfelder.test.ts`.
- `apps/web/app/portal/bausteine/ModellBelastungRad.tsx`.

**App** (`apps/ios-member`)
- Neu: `FitnessMember/Workout/Cardio.swift` (`CardioWert`, `CardioWerte`, `CardioEingabe`).
- `Networking/DTOs/WorkoutSet.swift`, `SessionSummary.swift`, `BootstrapResponse.swift`, `TagContextResponse.swift`.
- `Workout/LokaleSession.swift`, `Workout/WorkoutSessionStore.swift`, `Workout/Station.swift`.
- `DesignSystem/Zahlformat.swift`.
- `Screens/Geraet/GeraetModel.swift` und `GeraetView.swift`; neu `Screens/Geraet/CardioRaster.swift`.
- Anzeigen: `Screens/Home/SessionDetailView.swift`, `Screens/Training/TrainingAbschlussView.swift`, `Workout/Trainingszusammenfassung.swift`, `Screens/Home/UebungsfortschrittView.swift`, `Workout/GeraeteAuswahl.swift`.
- Tests (neu): `FitnessMemberTests/CardioTests.swift`, `CardioGeraetModelTests.swift`.

## Befehle

- **Vitest (Domain):** `cd packages/domain && npx vitest run <datei>`.
- **Vitest (Portal):** `cd apps/web && npx vitest run app/portal/formfelder.test.ts`.
- **Integration:** `pnpm test:integration tests/integration/<datei>`.
  - Lokale DB ohne Reset aktualisieren: `npx supabase migration up --local`.
  - Lokales Supabase muss laufen.
- **Swift:**
  ```bash
  cd apps/ios-member && xcodebuild test -project FitnessMember.xcodeproj -scheme FitnessMember \
    -destination 'platform=iOS Simulator,id=A2FB7461-E303-4CFE-AA08-9AC1B8C41707' [-only-testing:FitnessMemberTests/<Suite>] 2>&1 \
    | grep -E "error:|✘|TEST (SUCCEEDED|FAILED)|Test run with"
  ```
  - Neue Swift-Dateien brauchen vorher `xcodegen generate`.
  - „Early unexpected exit“, „mkstemp“ oder „failed to launch“ ist Infrastruktur: einmal wiederholen.

---

### Task 1: Domain-Grundlage `cardio.ts`

**Files:**
- Create: `packages/domain/src/cardio.ts`, `packages/domain/src/cardio.test.ts`
- Modify: `packages/domain/src/index.ts` (Export)

**Interfaces:**
- Produces:
  - `CARDIO_WERTE` (readonly tuple), `type CardioWert`
  - `cardioWerteSchema` (Zod-Objekt, alle optional), `type CardioWerte`
  - `cardioListeSchema` (Array ohne Dubletten)
  - `CARDIO_SPALTEN: Record<CardioWert, string>`
  - `CARDIO_SELECT: string` (Spaltenliste für Selects)
  - `cardioAusZeile(row): CardioWerte | null`
  - `cardioZuSpalten(w: CardioWerte): Record<string, number | null>`
  - `cardioListeDesModells({ eigene, katalog }): CardioWert[]`
  - `cardioPruefen(w, liste): string | null`
  - `altEingabeUmwandeln({ load, secondaryLoad, volume, loadUnit, secondaryUnit, volumeKind }, liste): CardioWerte`

- [ ] **Step 1: Failing test** `packages/domain/src/cardio.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import {
  CARDIO_WERTE,
  altEingabeUmwandeln,
  cardioAusZeile,
  cardioListeDesModells,
  cardioPruefen,
  cardioWerteSchema,
  cardioZuSpalten,
} from "./cardio.js";

describe("CARDIO_WERTE", () => {
  it("hat die feste Reihenfolge der Spec", () => {
    expect(CARDIO_WERTE).toEqual(["zeit", "strecke", "stufe", "kmh", "steigung", "watt", "frequenz", "kcal"]);
  });
});

describe("cardioWerteSchema", () => {
  it("nimmt gueltige Werte, auch einzeln", () => {
    expect(cardioWerteSchema.parse({ zeit: 510, strecke: 2000 })).toEqual({ zeit: 510, strecke: 2000 });
    expect(cardioWerteSchema.parse({ kmh: 10.5, steigung: -2.5 })).toEqual({ kmh: 10.5, steigung: -2.5 });
  });

  it("weist Werte ausserhalb der Grenzen und gebrochene Ganzzahlen ab", () => {
    expect(cardioWerteSchema.safeParse({ zeit: 0 }).success).toBe(false);
    expect(cardioWerteSchema.safeParse({ kmh: 50.1 }).success).toBe(false);
    expect(cardioWerteSchema.safeParse({ steigung: -10.5 }).success).toBe(false);
    expect(cardioWerteSchema.safeParse({ watt: 142.5 }).success).toBe(false);
    expect(cardioWerteSchema.safeParse({ puls: 120 }).success).toBe(false);
  });
});

describe("cardioPruefen", () => {
  const ruderer = ["zeit", "strecke", "watt", "frequenz", "kcal"] as const;

  it("laesst Werte aus der Liste des Geraets durch", () => {
    expect(cardioPruefen({ zeit: 510, strecke: 2000 }, [...ruderer])).toBeNull();
  });

  it("lehnt einen Wert ab, den das Geraet nicht hat", () => {
    expect(cardioPruefen({ stufe: 5 }, [...ruderer])).toBe("Dieser Wert gehört nicht zu diesem Gerät.");
  });

  it("verlangt mindestens einen Wert", () => {
    expect(cardioPruefen({}, [...ruderer])).toBe("Mindestens ein Wert fehlt.");
  });
});

describe("cardioListeDesModells", () => {
  it("nimmt die eigene Liste, sonst die des Katalog-Typs", () => {
    expect(cardioListeDesModells({ eigene: ["zeit"], katalog: ["zeit", "kmh"] })).toEqual(["zeit"]);
    expect(cardioListeDesModells({ eigene: [], katalog: ["zeit", "kmh"] })).toEqual(["zeit", "kmh"]);
    expect(cardioListeDesModells({ eigene: [], katalog: null })).toEqual([]);
  });

  it("ordnet nach der festen Reihenfolge", () => {
    expect(cardioListeDesModells({ eigene: ["kcal", "zeit", "strecke"], katalog: null })).toEqual(["zeit", "strecke", "kcal"]);
  });
});

describe("altEingabeUmwandeln", () => {
  const rad = ["zeit", "strecke", "stufe", "watt", "frequenz", "kcal"] as const;

  it("macht aus Sekunden Zeit und aus der Stufe stufe", () => {
    expect(
      altEingabeUmwandeln(
        { load: 5, secondaryLoad: null, volume: 1200, loadUnit: "level", secondaryUnit: null, volumeKind: "seconds" },
        [...rad],
      ),
    ).toEqual({ zeit: 1200, stufe: 5 });
  });

  it("macht aus Metern Strecke und verwirft, was das Geraet nicht hat", () => {
    expect(
      altEingabeUmwandeln(
        { load: 8.5, secondaryLoad: 2, volume: 3000, loadUnit: "kmh", secondaryUnit: "pct", volumeKind: "meters" },
        ["zeit", "strecke", "kmh"],
      ),
    ).toEqual({ strecke: 3000, kmh: 8.5 });
  });

  it("laesst kg und Wiederholungen weg", () => {
    expect(
      altEingabeUmwandeln(
        { load: 80, secondaryLoad: null, volume: 10, loadUnit: "kg", secondaryUnit: null, volumeKind: "reps" },
        [...rad],
      ),
    ).toEqual({});
  });
});

describe("Zeilen-Mapping", () => {
  it("liest nur gesetzte Spalten und schreibt alle acht", () => {
    expect(cardioAusZeile({ dauer_s: 510, strecke_m: null, stufe: null, kmh: "10.5", steigung_pct: null, watt: null, kcal: null, frequenz: null }))
      .toEqual({ zeit: 510, kmh: 10.5 });
    expect(cardioAusZeile({ dauer_s: null, strecke_m: null, stufe: null, kmh: null, steigung_pct: null, watt: null, kcal: null, frequenz: null }))
      .toBeNull();
    expect(cardioZuSpalten({ zeit: 510 })).toEqual({
      dauer_s: 510, strecke_m: null, stufe: null, kmh: null, steigung_pct: null, watt: null, kcal: null, frequenz: null,
    });
  });
});
```

- [ ] **Step 2: Run, expect FAIL** (Modul fehlt): `cd packages/domain && npx vitest run src/cardio.test.ts`

- [ ] **Step 3: Implementation** `packages/domain/src/cardio.ts`:

```ts
import { z } from "zod";
import type { LoadUnit, VolumeKind } from "./belastung.js";

/**
 * Die Werte eines Cardio-Satzes (Testnotiz 14.10., 18:45 #7; Spec
 * 2026-10-15-cardio-werte-design). Die Reihenfolge ist die der Knoepfe und
 * der Satzzeile -- in der App steht dieselbe Liste (CardioWert.swift).
 */
export const CARDIO_WERTE = ["zeit", "strecke", "stufe", "kmh", "steigung", "watt", "frequenz", "kcal"] as const;
export type CardioWert = (typeof CARDIO_WERTE)[number];
export const cardioWertSchema = z.enum(CARDIO_WERTE);

const ganz = (min: number, max: number) => z.number().int().min(min).max(max).optional();
const zehntel = (min: number, max: number) =>
  z.number().min(min).max(max).refine((x) => Math.abs(x * 10 - Math.round(x * 10)) < 1e-9, "Höchstens eine Nachkommastelle.").optional();

export const cardioWerteSchema = z
  .object({
    zeit: ganz(1, 86_400),
    strecke: ganz(1, 200_000),
    stufe: ganz(0, 100),
    kmh: zehntel(0, 50),
    steigung: zehntel(-10, 40),
    watt: ganz(0, 3_000),
    frequenz: ganz(0, 300),
    kcal: ganz(0, 10_000),
  })
  .strict();
export type CardioWerte = z.infer<typeof cardioWerteSchema>;

export const cardioListeSchema = z
  .array(cardioWertSchema)
  .refine((liste) => new Set(liste).size === liste.length, "Ein Wert steht doppelt in der Liste.");

/** Spalte in workout_sets je Wert. */
export const CARDIO_SPALTEN: Record<CardioWert, string> = {
  zeit: "dauer_s",
  strecke: "strecke_m",
  stufe: "stufe",
  kmh: "kmh",
  steigung: "steigung_pct",
  watt: "watt",
  frequenz: "frequenz",
  kcal: "kcal",
};

export const CARDIO_SELECT = CARDIO_WERTE.map((w) => CARDIO_SPALTEN[w]).join(", ");

export type CardioZeile = Record<"dauer_s" | "strecke_m" | "stufe" | "kmh" | "steigung_pct" | "watt" | "kcal" | "frequenz", number | string | null>;

/** null, wenn kein Wert gesetzt ist -- dann ist es ein Kraftsatz. numeric kommt als Zeichenkette. */
export function cardioAusZeile(row: CardioZeile): CardioWerte | null {
  const werte: CardioWerte = {};
  for (const wert of CARDIO_WERTE) {
    const roh = row[CARDIO_SPALTEN[wert] as keyof CardioZeile];
    if (roh !== null && roh !== undefined) werte[wert] = Number(roh);
  }
  return Object.keys(werte).length === 0 ? null : werte;
}

export function cardioZuSpalten(werte: CardioWerte): Record<string, number | null> {
  return Object.fromEntries(CARDIO_WERTE.map((w) => [CARDIO_SPALTEN[w], werte[w] ?? null]));
}

/** Eigene Liste vor der des Katalog-Typs, geordnet nach CARDIO_WERTE (Spec 2.1). */
export function cardioListeDesModells(m: { eigene: readonly string[]; katalog: readonly string[] | null }): CardioWert[] {
  const quelle = m.eigene.length > 0 ? m.eigene : m.katalog ?? [];
  return CARDIO_WERTE.filter((w) => quelle.includes(w));
}

export function cardioPruefen(werte: CardioWerte, liste: readonly CardioWert[]): string | null {
  const gesetzt = CARDIO_WERTE.filter((w) => werte[w] !== undefined);
  if (gesetzt.length === 0) return "Mindestens ein Wert fehlt.";
  if (gesetzt.some((w) => !liste.includes(w))) return "Dieser Wert gehört nicht zu diesem Gerät.";
  return null;
}

const WERT_JE_EINHEIT: Partial<Record<LoadUnit, CardioWert>> = {
  level: "stufe",
  kmh: "kmh",
  watt: "watt",
  pct: "steigung",
  rpm: "frequenz",
};

/**
 * Ein Satz einer App von vor E2 an einem Cardio-Geraet: load/volume statt
 * cardio (Spec 3.1). Was das Geraet nicht anbietet, faellt weg, statt den
 * Satz abzulehnen -- er liegt vielleicht seit Tagen in einer Warteschlange.
 */
export function altEingabeUmwandeln(
  e: {
    load: number | null | undefined;
    secondaryLoad: number | null | undefined;
    volume: number | null | undefined;
    loadUnit: LoadUnit;
    secondaryUnit: LoadUnit | null;
    volumeKind: VolumeKind;
  },
  liste: readonly CardioWert[],
): CardioWerte {
  const werte: Partial<Record<CardioWert, number>> = {};
  const setze = (wert: CardioWert | undefined, zahl: number | null | undefined) => {
    if (wert && zahl !== null && zahl !== undefined && liste.includes(wert)) werte[wert] = zahl;
  };
  setze(e.volumeKind === "seconds" ? "zeit" : e.volumeKind === "meters" ? "strecke" : undefined, e.volume);
  setze(WERT_JE_EINHEIT[e.loadUnit], e.load);
  setze(e.secondaryUnit ? WERT_JE_EINHEIT[e.secondaryUnit] : undefined, e.secondaryLoad);
  // Ganzzahlige Spalten runden: eine alte Stufe 5.0 bleibt 5.
  for (const w of ["zeit", "strecke", "stufe", "watt", "frequenz", "kcal"] as const) {
    if (werte[w] !== undefined) werte[w] = Math.round(werte[w]!);
  }
  return werte as CardioWerte;
}
```

In `packages/domain/src/index.ts` ergänzen:

```ts
export {
  CARDIO_WERTE,
  cardioListeSchema,
  cardioWerteSchema,
} from "./cardio.js";
export type { CardioWert, CardioWerte } from "./cardio.js";
```

- [ ] **Step 4: Run, expect PASS.** Danach `npx tsc --noEmit -p .` ohne neue Fehler.
- [ ] **Step 5: Commit** `feat(cardio): Werte, Grenzen und Umwandlung in der Domain`

---

### Task 2: Migration 0054 und `recordSet`

**Files:**
- Create: `supabase/migrations/0054_cardio_werte.sql`, `tests/integration/domain-cardio-werte.test.ts`
- Modify: `packages/domain/src/workout.ts` (Schema ~77, `stationAufloesen` ~196, `recordSet` ~271–400, `RecordedSet`/`SetRow`/`toRecordedSet` ~126–176)

**Interfaces:**
- Consumes: alles aus Task 1.
- Produces:
  - `recordSetInputSchema` mit `load?`, `volume?`, `cardio?`.
  - `RecordedSet.load: number | null`, `volume: number | null`, `cardio: CardioWerte | null`.
  - `stationAufloesen(...).modell` trägt zusätzlich `load_unit`, `cardio_werte` (bereits vererbt aufgelöst, als `CardioWert[]`).

- [ ] **Step 1: Migration** `supabase/migrations/0054_cardio_werte.sql`:

```sql
-- Testnotiz 14.10., 18:45 #7: Cardio-Werte (Spec 2026-10-15-cardio-werte-design).
--
-- Ein Cardio-Satz traegt bis zu acht beobachtete Werte statt Belastung und
-- Umfang. Welche, sagt das Geraet (cardio_werte, vom Katalog-Typ geerbt);
-- eine nicht-leere Liste macht ein Geraet zum Cardio-Geraet. Altdaten
-- bleiben hier unberuehrt -- 0055 schreibt sie um, erst nach der App.

create function public.ohne_dubletten(liste text[]) returns boolean
  language sql immutable
  as $$ select cardinality(liste) = (select count(distinct x) from unnest(liste) as x) $$;

alter table public.equipment_models
  add column cardio_werte text[] not null default '{}'
    constraint equipment_models_cardio_werte_bekannt
    check (cardio_werte <@ array['zeit','strecke','stufe','kmh','steigung','watt','frequenz','kcal']::text[])
    constraint equipment_models_cardio_werte_einmalig
    check (public.ohne_dubletten(cardio_werte));

alter table public.workout_sets
  alter column load drop not null,
  alter column volume drop not null,
  add column dauer_s int constraint workout_sets_dauer_s_check check (dauer_s between 1 and 86400),
  add column strecke_m int constraint workout_sets_strecke_m_check check (strecke_m between 1 and 200000),
  add column stufe int constraint workout_sets_stufe_check check (stufe between 0 and 100),
  add column kmh numeric(4, 1) constraint workout_sets_kmh_check check (kmh between 0 and 50),
  add column steigung_pct numeric(4, 1) constraint workout_sets_steigung_pct_check check (steigung_pct between -10 and 40),
  add column watt int constraint workout_sets_watt_check check (watt between 0 and 3000),
  add column kcal int constraint workout_sets_kcal_check check (kcal between 0 and 10000),
  add column frequenz int constraint workout_sets_frequenz_check check (frequenz between 0 and 300),
  -- Kraft ODER Cardio, nie gemischt, nie leer.
  add constraint workout_sets_art check (
    (load is not null and volume is not null
      and dauer_s is null and strecke_m is null and stufe is null and kmh is null
      and steigung_pct is null and watt is null and kcal is null and frequenz is null)
    or (load is null and volume is null and secondary_load is null
      and num_nonnulls(dauer_s, strecke_m, stufe, kmh, steigung_pct, watt, kcal, frequenz) >= 1));

-- 0049 verglich volume_counted mit volume; ein leeres volume machte den
-- Vergleich NULL, und ein CHECK laesst NULL durch.
alter table public.workout_sets drop constraint workout_sets_herkunft_consistent;
alter table public.workout_sets add constraint workout_sets_herkunft_consistent check (
  (volume_source = 'eingegeben' and volume_counted is null and rep_events is null)
  or (volume_source = 'gemessen' and volume is not null and volume_counted is not null
      and volume_counted = volume and rep_events is not null)
  or (volume_source = 'korrigiert' and volume is not null and volume_counted is not null
      and volume_counted <> volume and rep_events is not null));

-- Die Katalog-Typen (Spec 6). catalog:import haelt die Datei danach gleich.
update public.equipment_models set cardio_werte = array['zeit','strecke','kmh','steigung','kcal'] where catalog_key = 'treadmill';
update public.equipment_models set cardio_werte = array['zeit','strecke','stufe','watt','frequenz','kcal']
  where catalog_key in ('upright_bike', 'recumbent_bike', 'indoor_bike');
update public.equipment_models set cardio_werte = array['zeit','strecke','watt','kcal'] where catalog_key in ('airbike', 'ski_ergometer');
update public.equipment_models set cardio_werte = array['zeit','strecke','stufe','frequenz','kcal'] where catalog_key = 'elliptical';
update public.equipment_models set cardio_werte = array['zeit','strecke','watt','frequenz','kcal'] where catalog_key = 'rowing_ergometer';
update public.equipment_models set cardio_werte = array['zeit','stufe','kcal'] where catalog_key = 'stair_climber';

-- Eigene Cardio-Modelle ohne Typ (Spec 9): Zeit plus der Wert ihrer Einheit.
update public.equipment_models
  set cardio_werte = array['zeit'] || case load_unit
    when 'level' then array['stufe'] when 'kmh' then array['kmh'] when 'watt' then array['watt']
    when 'pct' then array['steigung'] when 'rpm' then array['frequenz'] else array[]::text[] end
  where category = 'cardio' and catalog_model_id is null and catalog_key is null;
```

Vorher prüfen: `grep -o '"key": "[a-z_]*"' catalog/gymtavo.json` gegen die Schlüssel oben (Treppe: `stair_climber`, Crosstrainer: `elliptical`). Weicht ein Schlüssel ab, die Migration an die Datei anpassen.

- [ ] **Step 2: Failing integration test** `tests/integration/domain-cardio-werte.test.ts`. Den `beforeAll`-Aufbau aus `tests/integration/domain-record-set-typ.test.ts` übernehmen (Studio, Mitglied, Katalog-Studio `00000000-0000-4000-8000-000000000001`). Anlegen:
  - einen Katalog-Typ `cardio_werte: ['zeit','strecke','watt']`, `category 'cardio'`, `load_unit 'level'`, mit einer Übung `volume_kind 'seconds'`;
  - ein Studio-Modell mit `catalog_model_id` = Typ und leerer eigener Liste, dazu eine Maschine;
  - ein Kraftmodell (kg, Übung reps) mit Maschine.

```ts
describe("recordSet -- Cardio (Testnotiz 14.10., 18:45 #7)", () => {
  const basis = () => ({ sessionId: crypto.randomUUID(), setId: crypto.randomUUID(), setIndex: 1 });

  it("speichert Cardio-Werte an der Maschine, Liste vom Typ geerbt", async () => {
    const client = await userClient(mitgliedEmail);
    const satz = await recordSet(client, { ...basis(), machineId: cardioMaschine, exerciseId: cardioUebung, cardio: { zeit: 510, strecke: 2000 } });
    expect(satz).toMatchObject({ load: null, volume: null, cardio: { zeit: 510, strecke: 2000 } });
  });

  it("lehnt einen Wert ab, den das Geraet nicht hat", async () => {
    const client = await userClient(mitgliedEmail);
    await expect(recordSet(client, { ...basis(), machineId: cardioMaschine, exerciseId: cardioUebung, cardio: { stufe: 5 } }))
      .rejects.toMatchObject({ code: "validation_failed", message: "Dieser Wert gehört nicht zu diesem Gerät." });
  });

  it("lehnt einen leeren Cardio-Satz ab", async () => {
    const client = await userClient(mitgliedEmail);
    await expect(recordSet(client, { ...basis(), machineId: cardioMaschine, exerciseId: cardioUebung, cardio: {} }))
      .rejects.toMatchObject({ message: "Mindestens ein Wert fehlt." });
  });

  // Review Focus 1: Satz einer alten App, vielleicht aus der Warteschlange.
  it("wandelt load/volume einer alten App um", async () => {
    const client = await userClient(mitgliedEmail);
    const satz = await recordSet(client, { ...basis(), machineId: cardioMaschine, exerciseId: cardioUebung, load: 5, volume: 1200 });
    // level -> stufe steht nicht in der Liste und faellt weg, Sekunden -> zeit.
    expect(satz).toMatchObject({ load: null, volume: null, cardio: { zeit: 1200 } });
  });

  it("lehnt cardio an einem Kraftgeraet ab", async () => {
    const client = await userClient(mitgliedEmail);
    await expect(recordSet(client, { ...basis(), machineId: kraftMaschine, exerciseId: kraftUebung, load: 40, volume: 10, cardio: { zeit: 60 } }))
      .rejects.toMatchObject({ message: "Dieses Gerät hat keine Cardio-Werte." });
  });

  it("lehnt Belastung neben Cardio-Werten ab", async () => {
    const client = await userClient(mitgliedEmail);
    await expect(recordSet(client, { ...basis(), machineId: cardioMaschine, exerciseId: cardioUebung, load: 5, volume: 60, cardio: { zeit: 60 } }))
      .rejects.toMatchObject({ message: "Ein Cardio-Gerät hat keine Belastung." });
  });

  it("Kraft bleibt wie bisher", async () => {
    const client = await userClient(mitgliedEmail);
    const satz = await recordSet(client, { ...basis(), machineId: kraftMaschine, exerciseId: kraftUebung, load: 40, volume: 10 });
    expect(satz).toMatchObject({ load: 40, volume: 10, cardio: null });
  });

  it("die Datenbank lehnt gemischte Saetze selbst ab", async () => {
    const { error } = await serviceClient().from("workout_sets").insert({
      id: crypto.randomUUID(), studio_id: studio, user_id: mitgliedId, session_id: vorhandeneSession,
      equipment_model_id: kraftModell, exercise_id: kraftUebung, set_index: 9, load: 40, volume: 10, dauer_s: 60,
    });
    expect(error?.message).toMatch(/workout_sets_art/);
  });
});
```

`vorhandeneSession` legt der `beforeAll` per Service-Client an (`workout_sessions` insert).

Run: `npx supabase migration up --local && pnpm test:integration tests/integration/domain-cardio-werte.test.ts`
Expected: FAIL. `cardio` ist im Schema unbekannt, Zod lehnt ab (`.strict` gibt es dort nicht, also wird `cardio` verworfen und `load` fehlt → validation_failed).

- [ ] **Step 3: Schema** in `workout.ts`. Im Objekt von `recordSetInputSchema`:
  - `load: z.number().min(0).max(9999).optional(),`
  - `volume: z.number().int().min(1).max(100000).optional(),`
  - neu `cardio: cardioWerteSchema.optional(),`
  - Ein weiteres `.refine` vor `.superRefine`:

```ts
  .refine((v) => v.cardio !== undefined || (v.load !== undefined && v.volume !== undefined), {
    path: ["load"],
    message: "Ein Satz braucht Belastung und Umfang oder Cardio-Werte.",
  })
```

`herkunftPruefen(value)` liest `volume`. Prüfen, dass es mit `undefined` umgehen kann (`herkunft.ts:53,71-74`), sonst dort `value.volume ?? 0` vergleichen. `volumeSource` ist bei Cardio `eingegeben`, der Vergleich greift dann nicht.

- [ ] **Step 4: `stationAufloesen` liefert die Liste.**
  - `NEBEN_SPALTEN` wird zu `"secondary_unit, secondary_step, secondary_min, secondary_max, load_unit, cardio_werte, catalog_model_id"`.
  - Der Typ `Nebenbelastung` bekommt `load_unit: LoadUnit; cardio_werte: string[]; catalog_model_id: string | null`.
  - Vor jedem `return` in `stationAufloesen` die Liste vererbt auflösen:

```ts
async function cardioListe(client: SupabaseClient, modell: Nebenbelastung): Promise<CardioWert[]> {
  if (modell.cardio_werte.length > 0 || !modell.catalog_model_id) {
    return cardioListeDesModells({ eigene: modell.cardio_werte, katalog: null });
  }
  const { data } = await client
    .from("equipment_models")
    .select("cardio_werte")
    .eq("id", modell.catalog_model_id)
    .maybeSingle<{ cardio_werte: string[] }>();
  return cardioListeDesModells({ eigene: [], katalog: data?.cardio_werte ?? [] });
}
```

  - Rückgabetyp von `stationAufloesen`: zusätzlich `cardioWerte: CardioWert[]`. Ergänze in beiden `return`s `cardioWerte: await cardioListe(client, <modell>)`.

- [ ] **Step 5: `recordSet`.** Nach der Übungsprüfung (`exercise` geladen) die bisherigen Prüfungen von Umfang, Herkunft und Nebenbelastung in einen Kraft-Zweig legen und einen Cardio-Zweig davorsetzen:

```ts
  // Cardio (Testnotiz 14.10., 18:45 #7): eine nicht-leere Liste am Geraet.
  let cardio: CardioWerte | null = null;
  if (station.cardioWerte.length > 0) {
    if (input.cardio !== undefined) {
      if (input.load !== undefined || input.volume !== undefined || (input.secondaryLoad ?? null) !== null) {
        throw new DomainError("validation_failed", "Ein Cardio-Gerät hat keine Belastung.");
      }
      cardio = input.cardio;
    } else {
      // Eine App von vor E2 (Spec 3.1).
      cardio = altEingabeUmwandeln(
        {
          load: input.load, secondaryLoad: input.secondaryLoad, volume: input.volume,
          loadUnit: modell.load_unit, secondaryUnit: modell.secondary_unit, volumeKind: exercise.volume_kind,
        },
        station.cardioWerte,
      );
    }
    const fehler = cardioPruefen(cardio, station.cardioWerte);
    if (fehler) throw new DomainError("validation_failed", fehler);
  } else if (input.cardio !== undefined) {
    throw new DomainError("validation_failed", "Dieses Gerät hat keine Cardio-Werte.");
  }
```

  - Die bestehenden Blöcke laufen nur noch, wenn `cardio === null`: Umfangsgrenze, Herkunft und Nebenbelastung. Dort kommen `input.load!`/`input.volume!`; das Schema-Refine garantiert beide.
  - Im Upsert:
    - `load: cardio ? null : input.load`
    - `volume: cardio ? null : input.volume`
    - `secondary_load: cardio ? null : secondaryLoad`
    - `...cardioZuSpalten(cardio ?? {})`
    - `volume_source: cardio ? "eingegeben" : input.volumeSource`
  - Im `.select(...)` `CARDIO_SELECT` anhängen.
  - `SetRow` erweitert um `CardioZeile` und `load`/`volume` nullable.
  - `RecordedSet`: `load: number | null; volume: number | null; cardio: CardioWerte | null`.
  - `toRecordedSet`:
    - `load: row.load === null ? null : Number(row.load)`
    - `volume: row.volume`
    - `cardio: cardioAusZeile(row)`

- [ ] **Step 6: Run, expect PASS**:
  - `pnpm test:integration tests/integration/domain-cardio-werte.test.ts tests/integration/domain-record-set.test.ts tests/integration/domain-record-set-typ.test.ts tests/integration/api-workout-sets.test.ts`
  - `cd packages/domain && npx vitest run`
  - `npx tsc --noEmit -p .`

  Weitere Leser von `RecordedSet.load` meldet tsc; sie bekommen `?? 0` nur dort, wo es Anzeige ist. Sonst nach Task 3 richten.

- [ ] **Step 7: Commit** `feat(cardio): Cardio-Werte am Satz, Liste am Geraet, alte Apps werden umgewandelt`

---

### Task 3: Lesewege und Progression

**Files:**
- Modify:
  - `packages/domain/src/bootstrap.ts` (`MODELL_SPALTEN` ~175, `ModellZeile` ~178, `Geraetemodell` ~117, `zuModell` ~510, `SatzZeile`/`letzteSaetze` ~262, `lastSets`/`lastTypeSets`-Typen ~80, Satz-Select ~381)
  - `packages/domain/src/sessions.ts` (`SessionBlock.sets` ~155, `SetRow` ~200, Select ~317, Mapping ~369)
  - `packages/domain/src/machine-context.ts` (Modell-Spalten ~197, `history` ~81/450, `SetRow` ~93, Select ~376, `suggestion`)
  - `packages/domain/src/progress.ts` (~89–155)
  - `packages/domain/src/abschluss.ts` (~441, Blockpaare), Progression-Aufrufer
- Test: `tests/integration/domain-cardio-werte.test.ts` (erweitern), `packages/domain/src/bootstrap.test.ts` (`letzteSaetze`)

**Interfaces:**
- Consumes: `cardioAusZeile`, `CARDIO_SELECT`, `cardioListeDesModells` (Task 1).
- Produces (API, von der App in Task 6 gelesen):
  - `Geraetemodell.cardioWerte: CardioWert[]` (vererbt)
  - `lastSets[]` / `lastTypeSets[]`: `load: number | null`, `volume: number | null`, `cardio: CardioWerte | null`
  - `SessionBlock.sets[]`: dieselben drei Felder
  - `MachineContext.equipmentModel.cardioWerte`
  - `history[]`: `load: number | null`, `volume: number[]` (ohne null), `cardio: CardioWerte | null`
  - `suggestion` bei Cardio wie „kein Vorschlag“

- [ ] **Step 1: Failing tests.**
  - In `bootstrap.test.ts` (Unit, `letzteSaetze`): Eine `SatzZeile` mit `load: null, volume: null, dauer_s: 510, strecke_m: 2000` und den übrigen Cardio-Spalten `null` ergibt in `lastSets[0]` `{ load: null, volume: null, cardio: { zeit: 510, strecke: 2000 } }`. Eine Kraftzeile ergibt `cardio: null`.
  - In `domain-cardio-werte.test.ts`:

```ts
describe("Lesewege -- Cardio", () => {
  it("Bootstrap: Liste am Studio-Modell vom Typ geerbt, letzter Satz mit cardio", async () => {
    const client = await userClient(mitgliedEmail);
    await recordSet(client, { sessionId: crypto.randomUUID(), setId: crypto.randomUUID(), setIndex: 1,
      machineId: cardioMaschine, exerciseId: cardioUebung, cardio: { zeit: 600, watt: 150 } });
    const b = await getBootstrap(client);
    const m = b.machines.find((x) => x.id === cardioMaschine)!;
    expect(m.equipmentModel.cardioWerte).toEqual(["zeit", "strecke", "watt"]);
    expect(b.lastSets.find((s) => s.machineId === cardioMaschine)).toMatchObject({ load: null, cardio: { zeit: 600, watt: 150 } });
  });

  it("Sessions liefern cardio am Satz", async () => {
    const client = await userClient(mitgliedEmail);
    const { sessions } = await getSessions(client);
    const satz = sessions.flatMap((s) => s.blocks).find((b) => b.machineId === cardioMaschine)?.sets[0];
    expect(satz?.cardio).toBeTruthy();
    expect(satz?.load).toBeNull();
  });

  it("Geraetekontext: Liste, Historie mit cardio, kein Vorschlag", async () => {
    const client = await userClient(mitgliedEmail);
    const k = await getMachineContext(client, { machineId: cardioMaschine, exerciseId: cardioUebung });
    expect(k.equipmentModel.cardioWerte).toEqual(["zeit", "strecke", "watt"]);
    expect(k.history[0]).toMatchObject({ load: null, volume: [], cardio: expect.any(Object) });
    expect(k.suggestion).toMatchObject({ resultLoad: null });
  });

  it("Fortschritt laesst Cardio aus dem Bestlast-Diagramm", async () => {
    const client = await userClient(mitgliedEmail);
    const p = await getProgress(client);
    expect(p.find((x) => x.exerciseId === cardioUebung)?.points ?? []).toEqual([]);
  });
});
```

Die Namen `getMachineContext`/`getProgress` und die Form ihrer Rückgabe mit `grep -n "export async function" packages/domain/src/machine-context.ts packages/domain/src/progress.ts` prüfen und die Aufrufe anpassen. Ebenso die Form von „kein Vorschlag“ in `progression.ts` (z. B. `resultLoad: null` mit `reasonCode`); die Erwartung im Test danach richten.

Run: `pnpm test:integration tests/integration/domain-cardio-werte.test.ts`. Expected: FAIL (`cardioWerte` undefined).

- [ ] **Step 2: Bootstrap.**
  - `MODELL_SPALTEN` += `, cardio_werte`.
  - `ModellZeile.cardio_werte: string[]`.
  - `Geraetemodell.cardioWerte: CardioWert[]` mit Doc-Kommentar „Welche Cardio-Werte das Gerät anbietet; leer bei Kraft. Am Studio-Modell vom Typ geerbt (Testnotiz 14.10., 18:45 #7).“
  - Neben `katalogGruppen` eine `katalogCardio`-Map aus `katalogModellRows` (`row.id → row.cardio_werte`).
  - In `zuModell`: `cardioWerte: cardioListeDesModells({ eigene: row.cardio_werte, katalog: row.catalog_model_id ? katalogCardio.get(row.catalog_model_id) ?? null : null })`.
  - Satz-Select (~381) += `, ${CARDIO_SELECT}`.
  - `SatzZeile`: `load`/`volume` nullable, `& CardioZeile`.
  - In `letzteSaetze.werte`:
    - `load: row.load === null ? null : Number(row.load)`
    - `volume: row.volume`
    - `cardio: cardioAusZeile(row)`
  - Typen in `Bootstrap.lastSets`/`lastTypeSets` entsprechend.

- [ ] **Step 3: Sessions.** Select += `, ${CARDIO_SELECT}`. `SetRow` nullable plus `CardioZeile`. Mapping wie in Step 2. `SessionBlock.sets[]`-Typ entsprechend.

- [ ] **Step 4: Gerätekontext.**
  - Modell-Spalten (~197) += `, cardio_werte`.
  - Das Katalogmodell lädt die Funktion schon für die Übungen (`modellIds`). Seine `cardio_werte` mitlesen und `cardioWerte` am zurückgegebenen `equipmentModel` vererbt setzen, wie in Step 2.
  - History-Select (~376) += `, ${CARDIO_SELECT}`.
  - In `history`:
    - `load: block.sets[0]?.load ?? null`
    - `volume: block.sets.flatMap((s) => (s.volume === null ? [] : [s.volume]))`
    - `cardio: block.sets[0]?.cardio ?? null`
  - Die Mappingstelle der Sätze in Blöcke (`Number(row.load)`) wie in Step 2.
  - `suggestion`: Ist die Liste nicht leer, den Weg nehmen, den der Code für „keine Historie“ schon hat. Die Progression bekommt keine Cardio-Sätze.

- [ ] **Step 5: Progression und Abschluss.**
  - In `abschluss.ts` die Historie für die Regel (~441) auf `.not("load", "is", null)` filtern.
  - Bei den Blockpaaren des Abschlusses (`vorschlaegeFuerAbschluss`) Paare überspringen, deren Sätze alle `load === null` sind (Cardio). Für sie entsteht keine `progression_suggestions`-Zeile.
  - Ein Unit-Test in `abschluss.test.ts`: Ein Blockpaar nur mit Cardio-Sätzen ergibt keinen Vorschlag. Die Hilfsfunktion, die die Paare bildet, gegebenenfalls um diesen Filter ergänzen und ihn dort testen.

- [ ] **Step 6: Fortschritt.** `progress.ts` (~89) liest Sätze für `topLoad`. Select-Filter `.not("load", "is", null)`, damit kein `Number(null) = 0` ins Diagramm kommt.

- [ ] **Step 7: Run, expect PASS:**
  - `pnpm test:integration tests/integration/domain-cardio-werte.test.ts tests/integration/domain-bootstrap*.test.ts tests/integration/domain-sessions.test.ts tests/integration/domain-tag-context.test.ts tests/integration/domain-progress.test.ts`
  - `cd packages/domain && npx vitest run && npx tsc --noEmit -p .`
  - `cd apps/web && npx tsc --noEmit 2>&1 | grep -v ReihenfolgeDialog`

- [ ] **Step 8: Commit** `feat(cardio): Lesewege liefern Cardio-Werte, keine Progression fuer Cardio`

---

### Task 4: Katalog

**Files:**
- Modify: `catalog/gymtavo.json` (neun Cardio-Typen), `packages/domain/src/katalog-datei.ts` (~77–101, ~290–300), `packages/domain/src/katalog-plan.ts` (~18–26, ~128, ~170–190), `packages/domain/src/katalog-import.ts` (~73 Select)
- Test: `packages/domain/src/katalog-datei.test.ts`, `packages/domain/src/katalog-plan.test.ts` (vorhandene Dateien; Namen per `ls packages/domain/src | grep katalog` prüfen)

- [ ] **Step 1: Failing tests.**
  - In `katalog-datei.test.ts` die vorhandene Hilfsfunktion für einen Minimal-Katalog nutzen und prüfen:
    - Ein Cardio-Typ ohne `cardio_values` ergibt den Fehler `"<wo>: category \"cardio\" verlangt cardio_values"`.
    - Ein Kraft-Typ mit `cardio_values: ["zeit"]` ergibt `"<wo>: cardio_values nur bei category \"cardio\""`.
    - `cardio_values: ["puls"]` scheitert am Schema.
  - In `katalog-plan.test.ts`: Ein Typ mit `cardio_values: ["zeit","strecke"]` ergibt eine Zeile `cardio_werte: ["zeit","strecke"]`. Ein Unterschied nur in `cardio_werte` gilt als Änderung.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implementation.**
  - `geraetetypSchema` += `cardio_values: z.array(cardioWertSchema).default([]),` (Import aus `./cardio.js`).
  - Kreuzprüfung nach der Gruppen-Regel:

```ts
    if (g.category === "cardio" && g.cardio_values.length === 0) {
      fehler.push(`${wo}: category "cardio" verlangt cardio_values`);
    }
    if (g.category !== "cardio" && g.cardio_values.length > 0) {
      fehler.push(`${wo}: cardio_values nur bei category "cardio"`);
    }
    for (const d of doppelte(g.cardio_values)) fehler.push(`${wo}: cardio_values enthaelt "${d}" mehrfach`);
```

  - `GeraetetypZeile` += `cardio_werte: string[]`.
  - `GERAETETYP_FELDER` += `"cardio_werte"`.
  - In der Zeile: `cardio_werte: g.cardio_values`.
  - Der Diff vergleicht Felder vermutlich mit `!==`. Für das Array einen Vergleich über `JSON.stringify` einsetzen (die vorhandene Vergleichsfunktion suchen und erweitern).
  - In `katalog-import.ts` die Select-Liste der Typen += `cardio_werte`.
  - `gymtavo.json`: In jedem der neun Cardio-Typen nach `"secondary": null,` die Liste aus Spec §6 einfügen, z. B. beim Laufband `"cardio_values": ["zeit", "strecke", "kmh", "steigung", "kcal"],`.
- [ ] **Step 4: Run, expect PASS**:
  - `cd packages/domain && npx vitest run`
  - `pnpm catalog:import --dry-run` gegen lokal. Ob es einen Trockenlauf gibt, steht in `scripts/catalog-import.ts`; sonst ohne Option lokal laufen lassen.
  - Erwartet: keine Änderung an `cardio_werte`, denn 0054 hat lokal schon dieselben Listen gesetzt.
- [ ] **Step 5: Commit** `feat(katalog): Cardio-Werte je Geraetetyp`

---

### Task 5: Portal

**Files:**
- Modify: `packages/domain/src/catalog.ts` (`equipmentModelInputSchema` ~92, Insert ~182, `equipmentModelPatchSchema` ~205, Patch ~233, Lesewege des Portals ~983/1085 für den Startwert)
- Modify: `apps/web/app/portal/formfelder.ts` und `formfelder.test.ts`, `apps/web/app/portal/bausteine/ModellBelastungRad.tsx`
- Die Seiten, die `ModellBelastungRad` mit `start` versorgen (`StammdatenFormular.tsx:61`, `ModellVorlageFelder.tsx:172`), reichen `cardioWerte` und `typCardioWerte` mit durch.

- [ ] **Step 1: Failing test** in `formfelder.test.ts`:

```ts
describe("cardioAusFormular", () => {
  it("liest die angekreuzten Werte in fester Reihenfolge", () => {
    const f = new FormData();
    f.append("cardioWert", "kcal");
    f.append("cardioWert", "zeit");
    f.append("cardioWert", "puls");
    expect(cardioAusFormular(f, "cardio")).toEqual({ cardioWerte: ["zeit", "kcal"] });
  });

  it("leer heisst erben", () => {
    expect(cardioAusFormular(new FormData(), "cardio")).toEqual({ cardioWerte: [] });
  });

  it("Kraft hat nie Cardio-Werte", () => {
    const f = new FormData();
    f.append("cardioWert", "zeit");
    expect(cardioAusFormular(f, "kraft")).toEqual({ cardioWerte: [] });
  });
});
```

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implementation.**
  - `formfelder.ts`:

```ts
export function cardioAusFormular(formData: FormData, kategorie: Category): { cardioWerte: CardioWert[] } {
  if (kategorie !== "cardio") return { cardioWerte: [] };
  const gewaehlt = formData.getAll("cardioWert").map(String);
  return { cardioWerte: CARDIO_WERTE.filter((w) => gewaehlt.includes(w)) };
}
```

  - In `actions.ts` bei beiden Aufrufen von `belastungAusFormular`: `...cardioAusFormular(formData, belastungAusFormular(formData).category)` daneben.
  - `catalog.ts`:
    - Beide Schemas bekommen `cardioWerte: cardioListeSchema.optional()` (Patch) bzw. `.default([])` (Input).
    - Der Insert schreibt `cardio_werte: werte.cardioWerte`, der Patch `if (werte.cardioWerte !== undefined) zeile.cardio_werte = werte.cardioWerte`.
    - Ein eigenes Cardio-Modell ohne Typ (`catalogModelId` leer) und ohne Werte wird mit `validation_failed` abgelehnt, Text: „Ein Cardio-Gerät ohne Typ braucht mindestens einen Wert.“
  - `ModellBelastungRad.tsx`:
    - Neue optionale Props `cardioWerte?: CardioWert[]` und `typCardioWerte?: CardioWert[]`.
    - Ist `category === "cardio"`, statt der Belastungsfelder eine `fieldset` mit acht Checkboxen `name="cardioWert"` zeigen. Beschriftungen:
      - Zeit
      - Strecke
      - Stufe
      - Geschwindigkeit (km/h)
      - Steigung (%)
      - Watt
      - Trittfrequenz / Schlagzahl
      - Kalorien
    - Vorbelegung: `cardioWerte`, wenn nicht leer, sonst `typCardioWerte`.
    - Darunter der Hinweis „Nichts angekreuzt: wie der Gerätetyp.“, wenn `typCardioWerte` gesetzt ist.
    - Die versteckten Felder der Belastung (`loadUnit`, `loadStep`, `loadMin`) bleiben mit ihren alten Werten im Formular (`type="hidden"`). Sonst bricht `belastungAusFormular`, und die DB-Spalten bleiben unverändert.
  - Die beiden Aufrufer laden `cardio_werte` des Modells und des Typs mit. Die Portal-Lesewege in `catalog.ts` (~983, ~1302) sind dafür um `cardio_werte` zu erweitern und als `cardioWerte` zurückzugeben.
- [ ] **Step 4: Run, expect PASS**:
  - `cd apps/web && npx vitest run app/portal/formfelder.test.ts && npx tsc --noEmit 2>&1 | grep -v ReihenfolgeDialog`
  - `cd packages/domain && npx vitest run`
- [ ] **Step 5: Manuell:** `pnpm --filter web dev`, ein Laufband-Modell im Portal öffnen. Prüfen: Checkboxen sichtbar, vorbelegt vom Typ; Speichern ändert `cardio_werte`. Mit Claude-in-Chrome oder per Hand.
- [ ] **Step 6: Commit** `feat(portal): Cardio-Werte je Geraetemodell ankreuzen`

---

### Task 6: App – Modelle und DTOs

**Files:**
- Create: `apps/ios-member/FitnessMember/Workout/Cardio.swift`, `apps/ios-member/FitnessMemberTests/CardioTests.swift`
- Modify:
  - `Networking/DTOs/WorkoutSet.swift` (SetWrite, RecordedSet)
  - `Networking/DTOs/SessionSummary.swift` (Block.Set)
  - `Networking/DTOs/BootstrapResponse.swift` (EquipmentModel, Catalog.EquipmentType, LastSet, LastTypeSet)
  - `Networking/DTOs/TagContextResponse.swift` (EquipmentModel, HistoryEntry)
  - `Workout/LokaleSession.swift` (LokalerSatz)
  - `Workout/Station.swift:53-66`
  - Alle Aufrufer, die der Compiler danach meldet

**Interfaces:**
- Produces:
  - `enum CardioWert: String, CaseIterable, Codable` (Reihenfolge = TS)
  - `struct CardioWerte: Codable, Hashable` mit `subscript(_: CardioWert) -> Double?` (get/set), `var istLeer: Bool`
  - `LokalerSatz.load: Double?`, `volume: Int?`, `cardio: CardioWerte?`
  - `SetWrite.load: Double?`, `volume: Int?`, `cardio: CardioWerte?`
  - `BootstrapResponse.EquipmentModel.cardioWerte: [CardioWert]` (`var … = []`)
  - `LastSet`/`LastTypeSet`/`SessionSummary.Block.Set`/`HistoryEntry`: `load: Double?`, `volume`/`volume: Int?`, `cardio: CardioWerte?`

- [ ] **Step 1: Failing tests** `CardioTests.swift`:

```swift
import Foundation
import Testing
@testable import FitnessMember

/// Testnotiz 14.10., 18:45 #7: Cardio-Werte in der App.
struct CardioTests {
    @Test func dieReihenfolgeIstDieDesServers() {
        #expect(CardioWert.allCases.map(\.rawValue) == ["zeit", "strecke", "stufe", "kmh", "steigung", "watt", "frequenz", "kcal"])
    }

    @Test func werteLassenSichJeSchluesselSetzen() {
        var w = CardioWerte()
        w[.zeit] = 510
        w[.kmh] = 10.5
        #expect(w.zeit == 510)
        #expect(w.kmh == 10.5)
        #expect(!w.istLeer)
        w[.zeit] = nil
        w[.kmh] = nil
        #expect(w.istLeer)
    }

    /// Review Focus 5: ein Satz ohne load (Cardio) bricht weder Bootstrap noch Verlauf.
    @Test func lastSetMitLoadNullDekodiert() throws {
        let json = #"{"machineId":"m","exerciseId":"e","load":null,"secondaryLoad":null,"volume":null,"rir":null,"performedAt":"2026-10-15T10:00:00Z","cardio":{"zeit":510,"strecke":2000}}"#
        let s = try JSONDecoder().decode(BootstrapResponse.LastSet.self, from: Data(json.utf8))
        #expect(s.load == nil)
        #expect(s.cardio?.strecke == 2000)
    }

    @Test func alterVerlaufOhneCardioDekodiert() throws {
        let json = #"{"setIndex":1,"load":40,"secondaryLoad":null,"volume":10,"rir":null,"problemFlag":false,"problemReason":null,"performedAt":"2026-09-01T10:00:00Z"}"#
        let s = try JSONDecoder().decode(SessionSummary.Block.Set.self, from: Data(json.utf8))
        #expect(s.load == 40)
        #expect(s.cardio == nil)
    }

    @Test func modellOhneCardioWerteIstKraft() throws {
        // Ein Server von vor E2 schickt das Feld nicht.
        #expect(Station.testGeraet("m").equipmentModel.cardioWerte.isEmpty)
    }

    @Test func setWriteSchicktCardioOhneLoad() throws {
        let body = SetWrite(machineId: "m", exerciseId: "e", setIndex: 1, load: nil, volume: nil,
                            cardio: CardioWerte(zeit: 510))
        let json = String(decoding: try JSONEncoder().encode(body), as: UTF8.self)
        #expect(json.contains(#""cardio":{"zeit":510}"#))
        #expect(!json.contains(#""load""#))
    }

    @Test func alteWarteschlangeMitLoadDekodiert() throws {
        let json = #"{"machineId":"m","exerciseId":"e","setIndex":1,"load":5,"volume":1200,"problemFlag":false,"volumeSource":"eingegeben"}"#
        let body = try JSONDecoder().decode(SetWrite.self, from: Data(json.utf8))
        #expect(body.load == 5)
        #expect(body.cardio == nil)
    }
}
```

Danach `cd apps/ios-member && xcodegen generate`.

- [ ] **Step 2: Run, expect FAIL** (Compiler): `-only-testing:FitnessMemberTests/CardioTests`

- [ ] **Step 3: `Cardio.swift`:**

```swift
import Foundation

/// Die Werte eines Cardio-Satzes (Testnotiz 14.10., 18:45 #7). Reihenfolge
/// und Schluessel wie CARDIO_WERTE in packages/domain/src/cardio.ts.
enum CardioWert: String, CaseIterable, Codable, Hashable, Sendable {
    case zeit, strecke, stufe, kmh, steigung, watt, frequenz, kcal

    var name: String {
        switch self {
        case .zeit: "Zeit"
        case .strecke: "Strecke"
        case .stufe: "Stufe"
        case .kmh: "Tempo"
        case .steigung: "Steigung"
        case .watt: "Watt"
        case .frequenz: "Frequenz"
        case .kcal: "Kalorien"
        }
    }

    /// Ganzzahlig in der Datenbank -- alle ausser km/h und Steigung.
    var ganzzahlig: Bool { self != .kmh && self != .steigung }

    /// Grenzen wie die Checks aus Migration 0054.
    var bereich: ClosedRange<Double> {
        switch self {
        case .zeit: 1...86_400
        case .strecke: 1...200_000
        case .stufe: 0...100
        case .kmh: 0...50
        case .steigung: -10...40
        case .watt: 0...3_000
        case .frequenz: 0...300
        case .kcal: 0...10_000
        }
    }
}

/// Was an einem Cardio-Satz gesetzt ist. Jeder Wert optional; ein Satz
/// braucht mindestens einen.
struct CardioWerte: Codable, Hashable, Sendable {
    var zeit: Int? = nil
    var strecke: Int? = nil
    var stufe: Int? = nil
    var kmh: Double? = nil
    var steigung: Double? = nil
    var watt: Int? = nil
    var frequenz: Int? = nil
    var kcal: Int? = nil

    var istLeer: Bool { CardioWert.allCases.allSatisfy { self[$0] == nil } }

    subscript(_ wert: CardioWert) -> Double? {
        get {
            switch wert {
            case .zeit: zeit.map(Double.init)
            case .strecke: strecke.map(Double.init)
            case .stufe: stufe.map(Double.init)
            case .kmh: kmh
            case .steigung: steigung
            case .watt: watt.map(Double.init)
            case .frequenz: frequenz.map(Double.init)
            case .kcal: kcal.map(Double.init)
            }
        }
        set {
            let ganz = newValue.map { Int($0.rounded()) }
            switch wert {
            case .zeit: zeit = ganz
            case .strecke: strecke = ganz
            case .stufe: stufe = ganz
            case .kmh: kmh = newValue
            case .steigung: steigung = newValue
            case .watt: watt = ganz
            case .frequenz: frequenz = ganz
            case .kcal: kcal = ganz
            }
        }
    }

    /// Nur, was das Geraet anbietet -- eine Vorbelegung von einem Geraet
    /// mit anderer Liste darf keinen Wert mitbringen, den der Server ablehnt.
    func nur(_ liste: [CardioWert]) -> CardioWerte {
        var ergebnis = CardioWerte()
        for wert in liste { ergebnis[wert] = self[wert] }
        return ergebnis
    }
}
```

Synthetisiertes Codable lässt `nil` beim Kodieren weg und dekodiert Optionals mit `decodeIfPresent`. Das ist gewollt.

- [ ] **Step 4: DTOs und `LokalerSatz`.** In jedem genannten Typ:
  - `let load: Double` wird `let load: Double?`, `let volume: Int` wird `let volume: Int?`, dazu `var cardio: CardioWerte? = nil`.
  - **`HistoryEntry`:** `load: Double?`, `volume` bleibt `[Int]`, `var cardio: CardioWerte? = nil`.
  - **`SetWrite`:**
    - `var load: Double?`, `var volume: Int?`, `var cardio: CardioWerte? = nil`.
    - `CodingKeys` += `cardio`.
    - Im eigenen Dekoder:
      - `load = try c.decodeIfPresent(Double.self, forKey: .load) ?? alt.decodeIfPresent(Double.self, forKey: .weightKg)`
      - `volume` analog mit `reps`
      - `cardio = try c.decodeIfPresent(CardioWerte.self, forKey: .cardio)`
    - Gibt es einen eigenen `encode(to:)`, dort `encodeIfPresent` für die drei.
  - **`LokalerSatz`:** dasselbe Muster. `CodingKeys` += `cardio`, Rückfall auf `weightKg`/`reps` mit `decodeIfPresent`.
  - **`BootstrapResponse.EquipmentModel` und `Catalog.EquipmentType`:**
    - `var cardioWerte: [CardioWert] = []`, mit eigenem `decodeIfPresent`, falls die Typen eigene Dekoder haben; sonst ändert der synthetisierte Dekoder bei `var` mit Vorgabe nichts. Synthetisiertes `Decodable` verlangt den Schlüssel auch bei `var` mit Vorgabe!
    - Deshalb: `private var cardioWerteRoh: [CardioWert]?` mit `CodingKey` `cardioWerte` und `var cardioWerte: [CardioWert] { cardioWerteRoh ?? [] }`.
    - Unbekannte Werte vom Server (künftige Schlüssel) dürfen nicht brechen. Daher `[String]?` dekodieren und `compactMap(CardioWert.init(rawValue:))`.
  - **`Station.init(typ:)`:** `cardioWerteRoh` per Memberwise-Init durchreichen. Weil das ein privates Feld ist, einen `init` mit `cardioWerte:` an `EquipmentModel` ergänzen oder das Rohfeld `fileprivate` statt `private` machen. Der einfachste Weg, den der Compiler erlaubt.
  - **`Station.testGeraet`** (Test-Hilfe, `grep -rn "static func testGeraet" FitnessMemberTests FitnessMember`): `cardioWerte` leer lassen. Zusätzlich `static func testCardio(_ id: String, werte: [CardioWert]) -> Station` im selben Test-Hilfsfile, das ein Modell mit `category: .cardio`, `loadUnit: .level` und der Liste baut.

- [ ] **Step 5: Compiler-Fallout.** `load`/`volume` optional bricht Aufrufer. Regeln:
  - **Kraftpfade** (Räder, Progression, Satzvergleich, Tonnage, Bestlast): nur mit Sätzen, die beides haben. `guard let load, let volume` oder `compactMap`; Cardio-Sätze fallen heraus.
  - **Anzeige:** Ist `cardio` gesetzt, `Zahlformat.cardio(...)` (Task 7, bis dahin `""`), sonst die bisherige Formatierung mit entpackten Werten.
  - **`WorkoutSessionStore.satzSichern(...)`:** Signatur `load: Double?, volume: Int?, cardio: CardioWerte? = nil`. Body: `SetWrite(... load: load, volume: volume, cardio: cardio ...)`, `LokalerSatz(... cardio: cardio)`.
  - **`Trainingszusammenfassung`:** `belastungen = Set(block.saetze.compactMap(\.load))`. `satzAnzahl` zählt weiter alle.

  Bei jedem Fix im Code einen Satz Kommentar nur dort, wo die Regel nicht offensichtlich ist.

- [ ] **Step 6: Run, expect PASS:** volle Swift-Suite.
- [ ] **Step 7: Commit** `feat(cardio): App kennt Cardio-Werte und optionale Belastung`

---

### Task 7: App – Formatierung und Eingabelogik

**Files:**
- Modify: `apps/ios-member/FitnessMember/DesignSystem/Zahlformat.swift`, `apps/ios-member/FitnessMember/Workout/Cardio.swift`
- Test: `apps/ios-member/FitnessMemberTests/CardioTests.swift`

**Interfaces:**
- Produces:
  - `Zahlformat.cardio(_ w: CardioWerte) -> String`
  - `Zahlformat.cardioWert(_ wert: CardioWert, _ zahl: Double) -> String`
  - `Zahlformat.cardioGesprochen(_ w: CardioWerte) -> String`
  - `enum CardioEingabe`:
    - `static func zahl(_ text: String, fuer: CardioWert) -> Result<Double, CardioEingabe.Fehler>`
    - `static func zeit(stunden: Int, minuten: Int, sekunden: Int) -> Result<Double, CardioEingabe.Fehler>`
    - `static func zeitTeile(_ sekunden: Int) -> (h: Int, m: Int, s: Int)`
  - `CardioEingabe.Fehler: Equatable { case leer, keineZahl, ausserhalb(String) }`

- [ ] **Step 1: Failing tests** (an `CardioTests` anhängen):

```swift
    @Test func dieZeileFolgtDerFestenReihenfolge() {
        let w = CardioWerte(zeit: 510, strecke: 2000, stufe: 5, watt: 142)
        #expect(Zahlformat.cardio(w) == "8:30 · 2,0 km · Stufe 5 · 142 W")
    }

    @Test func einzelneWerte() {
        #expect(Zahlformat.cardioWert(.zeit, 3900) == "1:05:00")
        #expect(Zahlformat.cardioWert(.strecke, 850) == "850 m")
        #expect(Zahlformat.cardioWert(.strecke, 12_340) == "12,3 km")
        #expect(Zahlformat.cardioWert(.kmh, 10.5) == "10,5 km/h")
        #expect(Zahlformat.cardioWert(.steigung, -2) == "−2,0 %")
        #expect(Zahlformat.cardioWert(.frequenz, 85) == "85 /min")
        #expect(Zahlformat.cardioWert(.kcal, 310) == "310 kcal")
    }

    /// Review Focus 4.
    @Test func eingabeMitKommaPunktUndGrenzen() {
        #expect(CardioEingabe.zahl("10,5", fuer: .kmh) == .success(10.5))
        #expect(CardioEingabe.zahl("10.5", fuer: .kmh) == .success(10.5))
        #expect(CardioEingabe.zahl("", fuer: .kmh) == .failure(.leer))
        #expect(CardioEingabe.zahl("abc", fuer: .watt) == .failure(.keineZahl))
        #expect(CardioEingabe.zahl("51", fuer: .kmh) == .failure(.ausserhalb("Höchstens 50 km/h.")))
        #expect(CardioEingabe.zahl("142,5", fuer: .watt) == .failure(.keineZahl))
    }

    @Test func zeitHinUndZurueck() {
        #expect(CardioEingabe.zeit(stunden: 0, minuten: 8, sekunden: 30) == .success(510))
        #expect(CardioEingabe.zeit(stunden: 0, minuten: 0, sekunden: 0) == .failure(.ausserhalb("Mindestens 1 Sekunde.")))
        #expect(CardioEingabe.zeit(stunden: 0, minuten: 8, sekunden: 60) == .failure(.keineZahl))
        #expect(CardioEingabe.zeitTeile(3900) == (h: 1, m: 5, s: 0))
    }
```

`Result` mit Tupel ist nicht `Equatable`; für `zeitTeile` die drei Komponenten einzeln vergleichen, falls `==` auf dem Tupel nicht kompiliert.

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implementation.**
  - In `Zahlformat` die vorhandenen Formatter für Dezimalzahlen nutzen (`grep -n "static func\|NumberFormatter\|formatted" DesignSystem/Zahlformat.swift`), deutsches Komma, „−“ (U+2212) für negative Zahlen wie im Umfeld.
  - **Zeit:** `m:ss`, ab 3 600 s `h:mm:ss`.
  - **Strecke:** unter 1 000 `"\(Int) m"`, sonst km mit einer Nachkommastelle.
  - `kmh`/`steigung` mit einer Nachkommastelle, `stufe` als `"Stufe \(n)"`, `watt` als `"\(n) W"`, `frequenz` als `"\(n) /min"`, `kcal` als `"\(n) kcal"`.
  - `cardio(_:)` verbindet die gesetzten Werte in `CardioWert.allCases`-Reihenfolge mit `" · "`.
  - `cardioGesprochen`: ausgeschrieben („8 Minuten 30 Sekunden, 2,0 Kilometer, Stufe 5, 142 Watt“).
  - **`CardioEingabe.zahl`:**
    - trimmen, `,` durch `.` ersetzen, `Double(...)`.
    - Ganzzahlige Werte verlangen `rounded() == wert`, sonst `.keineZahl`.
    - Außerhalb von `bereich`: `.ausserhalb(text)`, Text: „Höchstens X.“ bzw. „Mindestens X.“ mit `Zahlformat.cardioWert(wert, grenze)`. Für die Zeit „Mindestens 1 Sekunde.“
  - **`CardioEingabe.zeit`:** Minuten und Sekunden 0–59, sonst `.keineZahl`. Summe gegen `CardioWert.zeit.bereich`.
- [ ] **Step 4: Run, expect PASS.**
- [ ] **Step 5: Commit** `feat(cardio): Satzzeile und Zahleneingabe`

---

### Task 8: App – Eingabe am Gerät

**Files:**
- Modify: `apps/ios-member/FitnessMember/Screens/Geraet/GeraetModel.swift`, `apps/ios-member/FitnessMember/Screens/Geraet/GeraetView.swift` (`inhalt` ~199)
- Create: `apps/ios-member/FitnessMember/Screens/Geraet/CardioRaster.swift`, `apps/ios-member/FitnessMemberTests/CardioGeraetModelTests.swift`

**Interfaces:**
- Consumes: `Station.equipmentModel.cardioWerte`, `CardioWerte`, `CardioEingabe`, `WorkoutSessionStore.satzSichern(... cardio:)`.
- Produces:
  - `GeraetModel.istCardio: Bool`
  - `GeraetModel.cardioListe: [CardioWert]`
  - `GeraetModel.cardio: CardioWerte`
  - `GeraetModel.cardioSetzen(_ wert: CardioWert, _ zahl: Double?)`
  - `GeraetModel.kannSichern: Bool`

- [ ] **Step 1: Failing tests** `CardioGeraetModelTests.swift`. Den Aufbau eines `GeraetModel` aus `GeraetModelTests.swift` übernehmen (`grep -n "private func modell(" FitnessMemberTests/GeraetModelTests.swift`). Fake-Loader, temporärer `WorkoutSessionStore`, `enqueue` sammelt in ein Array. Station `Station.testCardio("m1", werte: [.zeit, .strecke, .watt])`, Bootstrap mit einem `LastSet` mit `cardio: CardioWerte(zeit: 600, strecke: 2100, stufe: 7)`.

```swift
@MainActor
struct CardioGeraetModelTests {
    @Test func vorbelegtMitDemLetztenMalNurMitWertenDesGeraets() {
        let modell = cardioModell()
        #expect(modell.istCardio)
        #expect(modell.cardioListe == [.zeit, .strecke, .watt])
        #expect(modell.cardio == CardioWerte(zeit: 600, strecke: 2100))   // stufe faellt weg
    }

    @Test func sichernSchicktCardioOhneLoad() async {
        var gesendet: [PendingSetWrite] = []
        let modell = cardioModell(enqueue: { gesendet.append($0) })
        modell.cardioSetzen(.watt, 150)
        await modell.satzSichern(problemFlag: false, problemReason: nil)
        #expect(gesendet.first?.body.cardio == CardioWerte(zeit: 600, strecke: 2100, watt: 150))
        #expect(gesendet.first?.body.load == nil)
        #expect(gesendet.first?.body.volume == nil)
        #expect(modell.phase == .abschluss)
    }

    /// Review Focus 3.
    @Test func weitererSatzBehaeltDieEbenGesichertenWerte() async {
        let modell = cardioModell()
        modell.cardioSetzen(.zeit, 900)
        await modell.satzSichern(problemFlag: false, problemReason: nil)
        modell.weitererSatz()
        #expect(modell.cardio.zeit == 900)
    }

    @Test func ohneWertKeinSichern() {
        let modell = cardioModell()
        for wert in modell.cardioListe { modell.cardioSetzen(wert, nil) }
        #expect(!modell.kannSichern)
    }

    @Test func kraftBleibtBeiDenRaedern() {
        let modell = kraftModell()
        #expect(!modell.istCardio)
        #expect(modell.kannSichern)
    }
}
```

Ist `Phase` nicht `Equatable`, mit `if case .abschluss = modell.phase` prüfen.

Danach `xcodegen generate`.

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: `GeraetModel`.**
  - Neben `belastung`/`umfang`:

```swift
    /// Am Cardio-Geraet statt der Raeder (Testnotiz 14.10., 18:45 #7): was
    /// gerade in den Knoepfen steht. Vorbelegt vom letzten Mal, nach einem
    /// Satz mit dessen Werten.
    private(set) var cardio = CardioWerte()

    var cardioListe: [CardioWert] { station.equipmentModel.cardioWerte }
    var istCardio: Bool { !cardioListe.isEmpty }
    var kannSichern: Bool { !istCardio || !cardio.istLeer }

    func cardioSetzen(_ wert: CardioWert, _ zahl: Double?) {
        cardio[wert] = zahl
    }
```

  - `LetzterSatz` bekommt `let cardio: CardioWerte?`. `load`/`volume` werden optional; beide `map`-Stellen in `letzterSatz(an:...)` reichen `$0.cardio` durch.
  - In `init` nach der Vorbelegung von `nebenbelastung`:
    `cardio = letzter?.cardio?.nur(station.equipmentModel.cardioWerte) ?? CardioWerte()`
  - In `init` und `uebungWechseln` stehen `letzter?.load ?? …` und `letzter?.volume ?? …`. Diese bleiben, denn `nil` fällt auf Startwert bzw. `targetMin`. In `uebungWechseln` zusätzlich `cardio = letzter?.cardio?.nur(cardioListe) ?? CardioWerte()`.
  - In `satzSichern` der Aufruf von `sessions.satzSichern`:

```swift
        var geschrieben = sessions.satzSichern(
            station: station, exerciseId: uebungId,
            einheiten: einheiten,
            load: istCardio ? nil : belastung,
            secondaryLoad: istCardio ? nil : nebenbelastung,
            volume: istCardio ? nil : umfang,
            cardio: istCardio ? cardio : nil,
            problemFlag: problemFlag, problemReason: problemReason
        )
```

    `herkunft` bei Cardio ist `.eingegeben`, weil der `volumeKind`-Zweig schon `ergebnis = nil` liefert, sofern die Übung Sekunden oder Meter hat. Zusätzlich `if istCardio { ergebnis = nil }` absichern, falls eine Studio-Cardio-Übung `reps` hätte. `cardio` bleibt nach dem Sichern stehen; das ist die Vorbelegung für „Weiterer Satz“.
  - Der Mitschnitt (`mitschnitt?.satzGesichert`) bekommt bei Cardio `weightKg: nil, reps: nil`. Das ergibt sich schon aus `loadUnit`/`volumeKind`; prüfen.
- [ ] **Step 4: `CardioRaster.swift`:**

```swift
import SwiftUI

/// Die Knoepfe am Cardio-Geraet statt der Raeder (Testnotiz 14.10., 18:45
/// #7): je Wert des Geraets einer, vorbelegt, ein Tipp oeffnet die
/// Zahleneingabe. Kein Wert ist Pflicht, einer muss gesetzt sein.
struct CardioRaster: View {
    @Bindable var modell: GeraetModel
    @State private var offen: CardioWert?

    private let spalten = [GridItem(.flexible(), spacing: DesignSystem.Spacing.s12),
                           GridItem(.flexible(), spacing: DesignSystem.Spacing.s12)]

    var body: some View {
        LazyVGrid(columns: spalten, spacing: DesignSystem.Spacing.s12) {
            ForEach(modell.cardioListe, id: \.self) { wert in
                Button { offen = wert } label: {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                        Text(wert.name.uppercased())
                            .font(DesignSystem.Typography.label)
                            .tracking(1.5)
                            .foregroundStyle(DesignSystem.Color.textFaint)
                        Text(modell.cardio[wert].map { Zahlformat.cardioWert(wert, $0) } ?? "–")
                            .font(.system(size: 28, weight: .black).monospacedDigit())
                            .foregroundStyle(DesignSystem.Color.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                    .padding(DesignSystem.Spacing.s12)
                    .background(DesignSystem.Color.surface, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(wert.name): \(modell.cardio[wert].map { Zahlformat.cardioWert(wert, $0) } ?? "leer")")
                .testnotizElement("geraet.cardio.\(wert.rawValue)", typ: "Button")
            }
        }
        .sheet(item: $offen) { wert in
            CardioWertSheet(wert: wert, start: modell.cardio[wert]) { modell.cardioSetzen(wert, $0) }
                .presentationDetents([.height(320)])
        }
    }
}

extension CardioWert: Identifiable { var id: String { rawValue } }

/// Die Zahleneingabe zu einem Knopf. "Leeren" nimmt den Wert aus dem Satz.
struct CardioWertSheet: View {
    let wert: CardioWert
    let start: Double?
    let beiFertig: (Double?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var teile = (h: 0, m: 0, s: 0)
    @FocusState private var fokus: Bool

    private var ergebnis: Result<Double, CardioEingabe.Fehler> {
        wert == .zeit ? CardioEingabe.zeit(stunden: teile.h, minuten: teile.m, sekunden: teile.s)
                      : CardioEingabe.zahl(text, fuer: wert)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
            Text(wert.name).font(DesignSystem.Typography.titel)
            if wert == .zeit {
                ZeitFelder(teile: $teile)
            } else {
                TextField("–", text: $text)
                    .keyboardType(wert.ganzzahlig ? .numberPad : .decimalPad)
                    .font(.system(size: 40, weight: .black).monospacedDigit())
                    .focused($fokus)
            }
            if case .failure(.ausserhalb(let hinweis)) = ergebnis {
                Text(hinweis).foregroundStyle(DesignSystem.Color.danger)
            }
            HStack(spacing: DesignSystem.Spacing.s12) {
                SecondaryButton(title: "Leeren") { beiFertig(nil); dismiss() }
                PrimaryButton(title: "Übernehmen") {
                    if case .success(let zahl) = ergebnis { beiFertig(zahl); dismiss() }
                }
                .disabled({ if case .success = ergebnis { false } else { true } }())
            }
        }
        .padding(20)
        .onAppear {
            if let start {
                if wert == .zeit { teile = CardioEingabe.zeitTeile(Int(start)) }
                else { text = Zahlformat.cardioZahl(wert, start) }
            }
            fokus = true
        }
    }
}
```

`ZeitFelder` sind drei `TextField`s mit `.numberPad` (Stunden nur sichtbar, wenn `teile.h > 0` oder nach Tipp auf „+ Stunden“), getrennt durch „:“, gebunden an `teile`. `Zahlformat.cardioZahl(_:_:)` ist die Zahl ohne Einheit für das Eingabefeld („10,5“); sie in Task 7 mit anlegen, falls noch nicht da. Namen von `DesignSystem.Typography.titel`, `Color.surface`, `Color.danger`, `Spacing.s16` gegen `DesignSystem` prüfen (`grep -n "static let" DesignSystem/*.swift`) und die vorhandenen nehmen.

- [ ] **Step 5: `GeraetView`.**
  - Im Zweig `.eingabe` von `inhalt` (GeraetView.swift ~199–227) statt `WertZeile` bei `modell.istCardio` das `CardioRaster(modell: modell)` zeigen.
  - Der Hauptknopf „Satz sichern“ bekommt `.disabled(!modell.kannSichern)`. Die Stelle per `grep -n "Satz sichern" Screens/Geraet/GeraetView.swift` finden.
  - Der Belastungs-Knopf der Pause (`GewichtAendernSheet`) erscheint bei Cardio nicht. Die Pause entfällt dort ohnehin (Satzziel 1), also nichts zu tun außer prüfen.
- [ ] **Step 6: Run, expect PASS:** `-only-testing:FitnessMemberTests/CardioGeraetModelTests`, danach die volle Suite.
- [ ] **Step 7: Sichtprüfung im Simulator.** App im Simulator starten (`xcrun simctl` mit dem Build aus dem Testlauf). Bei laufendem lokalem Web (`pnpm --filter web dev`) und Login ein Cardio-Gerät öffnen: Raster, Sheet, Sichern. Zeigt der Simulator nicht genug, im Ergebnisabschnitt vermerken: „Sichtprüfung am Gerät offen“.
- [ ] **Step 8: Commit** `feat(geraet): Cardio-Werte per Knopf und Zahleneingabe statt Raedern`

---

### Task 9: App – Anzeigen

**Files:**
- Modify:
  - `Screens/Home/SessionDetailView.swift` (~250–272)
  - `Screens/Training/TrainingAbschlussView.swift` (~387–490)
  - `Workout/Trainingszusammenfassung.swift` (`Blockzeile`)
  - `Screens/Home/UebungsfortschrittView.swift` (~53–163)
  - `Workout/GeraeteAuswahl.swift` (~268–282)
- Test: `FitnessMemberTests/TrainingszusammenfassungTests.swift`, `FitnessMemberTests/GeraeteAuswahlTests.swift` (Namen per `ls FitnessMemberTests` prüfen)

**Interfaces:**
- Consumes: `Zahlformat.cardio`, `cardio` an `LokalerSatz`/`SessionSummary.Block.Set`/`LastSet`.
- Produces: `Blockzeile.cardio: CardioWerte?` (letzter Satz des Blocks, wenn Cardio).

- [ ] **Step 1: Failing tests.**
  - `TrainingszusammenfassungTests`: Ein Block mit einem `LokalerSatz(load: nil, volume: nil, cardio: CardioWerte(zeit: 510))` ergibt `Blockzeile.cardio == CardioWerte(zeit: 510)`, `belastung == nil`, `satzAnzahl == 1`.
  - Die Funktion, die in `GeraeteAuswahl` den Text „zuletzt“ bildet (~268–282), liefert für einen Cardio-`LastSet` `Zahlformat.cardio(...)`. Den Test an den vorhandenen Test für diese Funktion anhängen.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implementation.**
  - `Blockzeile` += `var cardio: CardioWerte? = nil` (Hashable bleibt). In `Trainingszusammenfassung.init?` gilt `cardio: block.saetze.last?.cardio`.
  - **`TrainingAbschlussView`:** Wo eine `Blockzeile` als „Belastung · n Sätze“ erscheint, bei `cardio != nil` `Zahlformat.cardio(cardio)` zeigen. Unter „Beim nächsten Mal“ Blöcke mit `cardio != nil` weglassen (Filter vor dem `ForEach`).
  - **`SessionDetailView`:** In der Satzliste je Satz `if let cardio = satz.cardio { Text(Zahlformat.cardio(cardio)) } else { bisher }`. `accessibilityLabel` mit `cardioGesprochen`.
  - **`UebungsfortschrittView`:**
    - Hat die Übung nur Cardio-Sätze (aus `verlauf.sessions` gesammelt, `sets.contains { $0.cardio != nil }`), statt des Diagramms eine Liste der letzten zehn Einheiten: Datum (wie im Umfeld formatiert) und `Zahlformat.cardio` des jeweils letzten Satzes.
    - Die Liste kommt aus dem Verlauf; ein eigener Server-Endpunkt ist dafür nicht nötig. Spec 3.3 erlaubt das: „liefert die letzten Einheiten“ ist hier über `sessions` erfüllt.
  - **`GeraeteAuswahl`:** Hat der letzte Satz `cardio`, zeigt „zuletzt“ `Zahlformat.cardio(cardio)`.
- [ ] **Step 4: Run, expect PASS:** volle Swift-Suite.
- [ ] **Step 5: Commit** `feat(cardio): Satzzeile in Verlauf, Abschluss, Fortschritt und Geraeteliste`

---

### Task 10: Migration 0055 – Altdaten

**Files:**
- Create: `supabase/migrations/0055_cardio_altdaten.sql`, `tests/integration/migration-cardio-altdaten.test.ts`

Die Migration läuft lokal in diesem Task, in Produktion aber erst **nach** der App (Auslieferungsschritt 4).

- [ ] **Step 1: Failing test.**
  - Die Umwandlung gibt es als SQL-Funktion `public.cardio_altdaten_umschreiben()`. Die Migration ruft sie einmal auf; der Test ruft sie erneut auf.
  - Seed per Service-Client:
    - ein Katalog-Typ mit `cardio_werte = {zeit, stufe}`, `load_unit 'level'`, Übung `seconds`;
    - ein alter Satz daran mit `load 5`, `volume 1200`;
    - ein Kraftsatz.

```ts
it("schreibt alte Cardio-Saetze um und laesst Kraft stehen", async () => {
  const admin = serviceClient();
  const { error } = await admin.rpc("cardio_altdaten_umschreiben");
  expect(error).toBeNull();
  const { data: cardio } = await admin.from("workout_sets").select("load, volume, dauer_s, stufe").eq("id", alterCardioSatz).single();
  expect(cardio).toEqual({ load: null, volume: null, dauer_s: 1200, stufe: 5 });
  const { data: kraft } = await admin.from("workout_sets").select("load, volume, dauer_s").eq("id", kraftSatz).single();
  expect(kraft).toEqual({ load: 40, volume: 10, dauer_s: null });
});

it("ist wiederholbar", async () => {
  const { error } = await serviceClient().rpc("cardio_altdaten_umschreiben");
  expect(error).toBeNull();
});
```

  Seed-Vorsicht: Nach 0054 verbietet der Check nichts an `load 5, volume 1200` an einem Cardio-Modell, denn der Check kennt das Modell nicht. Der Insert geht also.

Run, Expected: FAIL (Funktion fehlt).

- [ ] **Step 2: Migration** `supabase/migrations/0055_cardio_altdaten.sql`:

```sql
-- Testnotiz 14.10., 18:45 #7, Auslieferungsschritt 4 (Spec 8): alte
-- Cardio-Saetze tragen load/volume. Erst NACH der App mit Cardio-Werten
-- einspielen -- eine aeltere App liest load/volume als Pflichtfelder.
--
-- Regel wie altEingabeUmwandeln (cardio.ts): Sekunden -> dauer_s, Meter ->
-- strecke_m, die Belastung je Einheit in ihre Spalte. Werte ausserhalb der
-- vererbten Liste des Geraets fallen weg. Bleibt nichts, bleibt der Satz
-- unveraendert (er verletzte sonst workout_sets_art).

create function public.cardio_altdaten_umschreiben() returns void
  language sql
  as $$
  with liste as (
    select m.id,
           m.load_unit,
           m.secondary_unit,
           case when cardinality(m.cardio_werte) > 0 then m.cardio_werte else coalesce(k.cardio_werte, '{}') end as werte
    from public.equipment_models m
    left join public.equipment_models k on k.id = m.catalog_model_id
  ),
  neu as (
    select s.id,
      case when e.volume_kind = 'seconds' and 'zeit' = any(l.werte) then least(greatest(s.volume, 1), 86400) end as dauer_s,
      case when e.volume_kind = 'meters' and 'strecke' = any(l.werte) then least(greatest(s.volume, 1), 200000) end as strecke_m,
      case when l.load_unit = 'level' and 'stufe' = any(l.werte) then round(s.load)::int end as stufe,
      case when l.load_unit = 'kmh' and 'kmh' = any(l.werte) then round(s.load, 1) end as kmh,
      coalesce(
        case when l.load_unit = 'pct' and 'steigung' = any(l.werte) then round(s.load, 1) end,
        case when l.secondary_unit = 'pct' and 'steigung' = any(l.werte) then round(s.secondary_load, 1) end) as steigung_pct,
      case when l.load_unit = 'watt' and 'watt' = any(l.werte) then round(s.load)::int end as watt,
      coalesce(
        case when l.load_unit = 'rpm' and 'frequenz' = any(l.werte) then round(s.load)::int end,
        case when l.secondary_unit = 'rpm' and 'frequenz' = any(l.werte) then round(s.secondary_load)::int end) as frequenz
    from public.workout_sets s
    join liste l on l.id = s.equipment_model_id
    join public.exercises e on e.id = s.exercise_id
    where cardinality(l.werte) > 0 and s.load is not null
  )
  update public.workout_sets s
     set dauer_s = n.dauer_s, strecke_m = n.strecke_m, stufe = n.stufe, kmh = n.kmh,
         steigung_pct = n.steigung_pct, watt = n.watt, frequenz = n.frequenz,
         load = null, volume = null, secondary_load = null,
         volume_source = 'eingegeben', volume_counted = null, rep_events = null
    from neu n
   where s.id = n.id
     and num_nonnulls(n.dauer_s, n.strecke_m, n.stufe, n.kmh, n.steigung_pct, n.watt, n.frequenz) >= 1;
  $$;

revoke execute on function public.cardio_altdaten_umschreiben() from public, anon, authenticated;

select public.cardio_altdaten_umschreiben();
```

  Grenzwerte vor dem Schreiben prüfen: Eine alte `stufe` über 100 oder `kmh` über 50 würde den Check reißen. Die `case`-Ausdrücke dafür mit `least(...)` auf die Grenze kappen, wie bei `dauer_s`.

- [ ] **Step 3: Run, expect PASS:** `npx supabase migration up --local && pnpm test:integration tests/integration/migration-cardio-altdaten.test.ts`
- [ ] **Step 4: Commit** `feat(cardio): Migration schreibt alte Cardio-Saetze um`

---

### Task 11: Abschluss

- [ ] **Step 1:** Volle Suiten:
  - `cd packages/domain && npx vitest run`
  - `cd apps/web && npx vitest run`
  - `pnpm test:integration`
  - alle Swift-Tests

  Ergebnisse festhalten, bekannte Ausfälle benennen (`sticker.test.ts`).
- [ ] **Step 2:** Diesen Plan um „## Ergebnis“ ergänzen: Testzahlen, Abweichungen, offene Punkte, Auslieferungsreihenfolge.
- [ ] **Step 3:** Commit `docs(plan): Cardio-Werte umgesetzt`. Push, PR gegen `master`. **Kein Merge ohne Freigabe.**
- [ ] **Step 4: Auslieferung, nur auf Freigabe, jeder Schritt einzeln:**
  1. **Nur 0054 auf Prod.** `supabase db push --linked` spielt alle offenen Migrationen ein, also vorher prüfen, dass 0055 noch nicht im Branch liegt, oder `--include-all` meiden. Sicherer: 0055 erst nach Schritt 3 mergen, als eigener PR. Danach `pnpm smoke:migrations`, dann `pnpm catalog:import` gegen Prod.
  2. Merge (ohne 0055) → Vercel.
  3. App-Build aufs Gerät, Prüfung nach Spec „Auf dem Gerät“.
  4. PR mit 0055 mergen, `supabase db push --linked`, `pnpm smoke:migrations`.

  **Deshalb kommt Task 10 auf einen eigenen Branch** `claude/cardio-altdaten` (von diesem abgezweigt), mit eigenem PR.

## Ergebnis

Umgesetzt am 15.10. mit Subagenten (je Aufgabe ein Implementierer und ein Review, am Ende ein Review des ganzen Branches und eine Korrekturrunde).

**Tests (Stand nach der Korrekturrunde):**
- Domain-Vitest: 357 grün; `sticker.test.ts` lädt lokal nicht (fehlende Pakete), wie bisher.
- Portal-Vitest: 311 grün.
- Integration: 864 von 865 grün. Der eine Ausfall (`api-workout-sets` „beendet die eigene Session“) liegt an der Uhr der Docker-VM und tritt genauso auf `master` auf.
- Swift: 1187 grün.

**Abweichungen vom Plan und von der Spec:**
- **Spec §3.1 geändert:** Sätze einer alten App (ohne `cardio`) an Cardio-Geräten werden im alten Format gespeichert, nicht sofort umgewandelt. Sonst könnte eine alte App ihren Bootstrap nicht mehr lesen (Spec §8). Leser leiten `cardio` für solche Zeilen per `altEingabeUmwandeln` ab; der Ausschluss aus der Progression hängt an der Geräteliste. Migration 0055 schreibt die Zeilen später um.
- Portal: Entspricht die angekreuzte Liste der des Typs, wird `[]` gespeichert (erben), damit die Vererbung nicht beim ersten Speichern verloren geht.
- Eingabe: „1.000“ gilt bei ganzzahligen Werten als Tausenderpunkt; „−“ (U+2212) wird beim Einlesen akzeptiert.
- Am Cardio-Gerät startet „Weiterer Satz“ ohne Pause; ein leerer Cardio-Satz lässt sich auf keinem Weg sichern.
- „Noch nie“ in Geräteseite und Übungswechsel berücksichtigt Cardio-Sätze; „Beim nächsten Mal“ entfällt bei reinen Cardio-Einheiten.
- Migration 0055 liegt auf eigenem Branch `claude/cardio-altdaten`.

**Offen:**
- Vor dem 0055-PR: 0055 setzt Nebenbelastungen nur für Steigung und Frequenz um, `altEingabeUmwandeln` für alle Einheiten (Stufe, km/h, Watt als Nebenbelastung). Kein Katalog-Typ hat so eine Nebenbelastung, ein Studio-Modell könnte sie haben.
- Sichtprüfung auf dem Gerät (Raster, Eingabe-Sheet, Zeitfelder) und im Portal (Checkboxen).
- 0055 hat kein Versions-Gate: Eine nicht aktualisierte App mit Cardio-Verlauf startet danach nicht mehr. Deshalb 0055 erst ausliefern, wenn alle Apps aktualisiert sind.

**Auslieferung (jeder Schritt nur auf Freigabe):**
1. Migration 0054 auf Prod, `pnpm smoke:migrations`. Danach `pnpm catalog:import --dry-run` gegen Prod zeigen: lokal zeigt der Trockenlauf auch fremde offene Unterschiede (Startwerte bei 52 Typen, 69 Produkte).
2. PR `claude/cardio-werte` mergen → Vercel.
3. App-Build aufs Gerät.
4. Später: PR `claude/cardio-altdaten` (0055) mergen, `supabase db push --linked`, `pnpm smoke:migrations`.
