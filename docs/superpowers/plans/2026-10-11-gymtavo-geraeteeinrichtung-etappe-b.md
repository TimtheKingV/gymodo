# Geräteeinrichtung Etappe B: Herstellermodelle – Umsetzungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ein Studio wählt nach dem Gymtavo-Typ den Hersteller und dessen konkretes Modell. Name, Hersteller, gegebenenfalls Belastung und Foto kommen von dort, ohne Abtippen. Grundlage sind 114 Herstellermodelle aus dem GYMTAVO-Paket, die über `catalog/gymtavo.json` importiert werden.

**Architecture:**
- **Datenbank:** Neue Tabellen `catalog_products` und `catalog_product_types` (m:n zu den Gymtavo-Typen), dazu die Herkunftsspalte `equipment_models.catalog_product_id` (Migration 0050).
- **Import:** Der bestehende Import (`katalog-datei` → `katalog-medien` → `katalog-plan` → `katalog-import`) bekommt `products[]` als weitere Liste mit demselben Muster: prüfen, planen, upserten, nie löschen. Einzige Ausnahme ist der Rechteentzug beim Foto.
- **Domain:**
  - `listCatalogTypes` liefert je Typ seine Produkte.
  - `createEquipmentModel` nimmt `catalogProductId` und prüft, dass Produkt und Typ zusammengehören.
  - `copyTypeDefaults` heißt künftig `copyCatalogDefaults` und nimmt das Produktfoto vor der Typillustration.
- **Portal:** `ModellVorlageFelder` aus Etappe A wird zum Ablauf Typ → Hersteller → Modell. Eine reine Hilfsdatei bildet Herstellerliste, Namen und Startwerte.

**Tech Stack:** Postgres-Migration (Supabase), TypeScript, Zod, Supabase JS, Next.js Server Actions, React 19, Vitest (+ jsdom, Testing Library), Playwright. Für den einmaligen Konverter kommt Python 3 außerhalb des Repos dazu.

**Spec:** `docs/superpowers/specs/2026-10-10-gymtavo-katalog-geraeteeinrichtung-design.md`, Abschnitte 3 (G2–G5), 6 und 7.

## Global Constraints

- **Arbeitsort und Push:** Arbeit nur im Worktree `.claude/worktrees/katalog-produkte`, Branch `claude/gymtavo-katalog-etappe-b` (Basis `master` @ `fa7c475`). Nicht pushen, bis Tim es sagt.
- **Migrationsnummer:** **0050**. Die Nummer 0049 ist mit `0049_satz_herkunft.sql` in `master` und in der lokalen DB schon vergeben. Die Spec sagt 0049 und wird in Task 1 korrigiert.
- **Geteiltes lokales Supabase:** Nie `supabase db reset`. Migrationen nur mit `pnpm exec supabase migration up`. Nie fremde Zeilen anfassen. Eigene Schlüssel tragen einen Präfix `t_<8 Zeichen>_`. Prüfungen gehen auf Enthaltensein, nie auf die ganze Liste. Eigene Zeilen und Storage-Objekte werden am Ende entfernt, Produkte vor Typen (Restrict).
- **Produktion:** Migration 0050 und `pnpm catalog:import` gegen Produktion nur nach dem Merge und auf Tims ausdrückliches Wort.
- **IDs und Pfade:**
  - Gymtavo-Studio-ID: `00000000-0000-4000-8000-000000000001`.
  - Produktfotos im Bucket `equipment-photos` unter `<Gymtavo-ID>/catalog/products/<key>-<sha256, 8 Zeichen>.<ext>`.
- **Clients:** Domain-Code nutzt den nutzergebundenen Client. Nur der Import (`@fitretro/domain/katalog-import`) nutzt die Service-Rolle.
- **Commits:** deutsch mit ae/oe/ue, ein Commit je Task, Form `feat(katalog): …`, `test(katalog): …` oder `docs(plan): …`, Trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Nach jedem Commit `git log -1 --format=%B` prüfen.
- **Texte:** Kommentare im Code in ASCII (ae/oe/ue), mit Begründung statt Nacherzählung. Sichtbare Texte im Portal mit echten Umlauten.
- **Sichtbare Texte, wörtlich:**
  - `Anderer Hersteller`
  - `Herstellername`
  - `Mein Modell ist nicht dabei`
  - `Symbolbild`
  - `Vorlage: {Hersteller} {Serie} {Name} {Code}` (ohne leere Teile)
  - Herstelleroption `{Hersteller} ({Anzahl})`
  - Fehlermeldung `Dieses Herstellermodell passt nicht zum Gymtavo-Typ.`
- **Produktname im Formular:** `{Serie} {Name} {Code}` ohne leere Teile, z. B. `Pure Kraft Brustpresse 4345`.
- **Testsatz:** Vor dem Abschluss läuft der volle Testsatz: `pnpm typecheck`, `pnpm test`, `pnpm test:integration`, `pnpm test:e2e` gegen den Produktionsbau (siehe Memory „Lokale Testumgebung“). iOS ist nicht betroffen.

## Entscheidungen dieses Plans (über die Spec hinaus)

- **P1:** `createEquipmentModel` prüft über `catalog_product_types`, dass `catalogProductId` zum gewählten `catalogModelId` gehört. Ein unbekanntes Produkt, ein Produkt ohne Typ und ein Produkt eines anderen Typs ergeben alle `validation_failed`.
  - Grund: Sonst käme bei einem veralteten Formular das Foto eines fremden Geräts ins Modell. Der Trigger prüft das weiterhin nicht (Spec 6.1), weil ein späterer Typwechsel erlaubt bleibt.
- **P2:** `products` ist in der Datei optional, Vorgabe `[]`.
  - Grund: Alte Katalogdateien und die Testdaten aus Etappe 2 bleiben gültig.
- **P3:** Die Funktion heißt `copyCatalogDefaults` (Spec 6.4), die Datei bleibt `typ-vorlage.ts`.
  - Grund: Ein Umzug der Datei bringt nichts außer Diff.
- **P4:** Die Hallen-Fotopflicht entfällt auch, wenn das gewählte Produkt ein geklärtes Foto hat.
  - Grund: Das ist dieselbe Regel wie beim Typ (Spec 5.2) und folgt aus G5.

## Review Focus

1. **Typwechsel nach gewähltem Produkt:** Erwartet ist, dass Hersteller und Modell zurückgesetzt werden, das versteckte `catalogProductId` verschwindet, das Rad die Werte des neuen Typs zeigt und ein vom Produkt vorgeschlagener Name durch den neuen Typnamen ersetzt wird. Test in Task 8.
2. **Rechteentzug:** Ein Produkt hat in der DB ein Foto, steht in der Datei aber auf `pending`. Erwartet: `photo_path` wird `null`, das Objekt bleibt liegen und erscheint im Bericht. Tests in Task 4 (Plan) und Task 5 (gegen die DB).
3. **Produkt passt nicht zum Typ** (veraltetes Formular, manipulierte Anfrage): Erwartet ist `validation_failed`, und es wird kein Modell angelegt. Test in Task 6.
4. **Gymtavo-Typ mit Produkten soll gelöscht werden** (Testaufräumen, späteres Ausmisten): Erwartet ist, dass Restrict das Löschen verhindert. Testcode räumt deshalb erst Produkte ab. Test in Task 1.
5. **Katalogdatei ohne `products`:** Erwartet ist, dass Prüfung und Import wie bisher durchgehen und der Bericht `Produkte: 0 neu, …` zeigt. Tests in Task 2 und Task 4.

---

## Dateien

| Datei | Aufgabe |
|---|---|
| `supabase/migrations/0050_catalog_products.sql` (neu) | Tabellen, Checks, Trigger, RLS, Herkunftsspalte |
| `tests/integration/katalog-produkte-db.test.ts` (neu) | Datenbankregeln |
| `packages/domain/src/katalog-datei.ts` | `products[]`, Prüfregeln |
| `packages/domain/src/katalog-testdaten.ts` | `mitProdukten()` |
| `packages/domain/src/katalog-medien.ts` | Produktfotos, `produktFotoPraefix` |
| `packages/domain/src/katalog-plan.ts` | Produkte und Verknüpfungen planen, Bericht |
| `packages/domain/src/katalog-import.ts` | Ist-Stand lesen, Produkte schreiben |
| `scripts/catalog-import.ts` | Ausgabe um Produkte ergänzen |
| `packages/domain/src/catalog.ts` | `CatalogProduct`, `listCatalogTypes`, `createEquipmentModel`, `getStudioCatalog` |
| `packages/domain/src/typ-vorlage.ts` | `copyCatalogDefaults` |
| `tests/integration/domain-katalog-produkte.test.ts` (neu) | Domain gegen die DB |
| `apps/web/app/portal/bausteine/typVorlage.ts` | `ProduktVorlage`, `fotoUrl`, `produkte` |
| `apps/web/app/portal/bausteine/herstellerWahl.ts` (neu) | rein: Herstelleroptionen, Produktliste, Namen, Startwerte |
| `apps/web/app/portal/bausteine/ModellVorlageFelder.tsx` | Ablauf Typ → Hersteller → Modell |
| `apps/web/app/portal/bausteine/ModellVorlageFelder.module.css` (neu) | Modellkarten |
| `apps/web/app/portal/[studioId]/catalog.ts` | `ladeTypVorlagen` mit signierten Bild-URLs |
| Schreibtisch: `geraete/neu/page.tsx`, `portal/actions.ts`, `[modelId]/page.tsx`, `StammdatenFormular.tsx` | Verdrahtung, Zeile „Vorlage:“ |
| Halle: `einrichten/modell/neu/page.tsx`, `ModellNeuFormular.tsx`, `einrichten/actions.ts` | Verdrahtung, Fotopflicht |
| `e2e/helpers/gymtavo.ts`, `e2e/gymtavo.spec.ts`, `e2e/einrichten.spec.ts` | Abnahme |
| `catalog/gymtavo.json` | 114 Produkte |

---

### Task 1: Migration 0050 `catalog_products`

**Files:**
- Create: `supabase/migrations/0050_catalog_products.sql`
- Create: `tests/integration/katalog-produkte-db.test.ts`
- Modify: `docs/superpowers/specs/2026-10-10-gymtavo-katalog-geraeteeinrichtung-design.md` (0049 → 0050)

**Interfaces:**
- Produces:
  - Tabelle `catalog_products` mit den Spalten `id, catalog_key, manufacturer, series, name, model_code, product_url, note, photo_path, photo_rights, load_unit, load_step, load_min, load_max, secondary_unit, secondary_step, secondary_min, secondary_max, created_at, updated_at`. Der Unique-Constraint auf `catalog_key` dient dem Upsert.
  - Tabelle `catalog_product_types(product_id, equipment_model_id)`.
  - Spalte `equipment_models.catalog_product_id`, FK-Name `equipment_models_catalog_product_id_fkey`.
  - Fehlertexte `gymtavo_produkttyp_ungueltig` und `gymtavo_herkunft_ungueltig`.

- [ ] **Step 1: Failing test schreiben**

`tests/integration/katalog-produkte-db.test.ts`:

```ts
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { createTestUser, serviceClient, uniqueEmail, userClient } from "./helpers/clients.js";

// Spec 2026-10-10-gymtavo-katalog-geraeteeinrichtung-design.md, 6.1.
// Geteilte lokale Datenbank: eigene Schluessel mit Praefix, am Ende werden
// nur eigene Zeilen entfernt -- Produkte vor Typen, weil die Verknuepfung
// den Typ mit restrict haelt.
const GYMTAVO = "00000000-0000-4000-8000-000000000001";
const p = `t_${crypto.randomUUID().slice(0, 8)}_`;
const admin = serviceClient();

let typId: string;
let studioId: string;
let studioModellId: string;
let trainer: string;

async function produkt(werte: Record<string, unknown> = {}) {
  return admin
    .from("catalog_products")
    .insert({ catalog_key: `${p}${crypto.randomUUID().slice(0, 6)}`, manufacturer: "gym80", name: "Brustpresse", ...werte })
    .select("id")
    .single();
}

beforeAll(async () => {
  const typ = await admin
    .from("equipment_models")
    .insert({ studio_id: GYMTAVO, name: `${p}Brustpresse`, load_step: 2.5 })
    .select("id")
    .single();
  if (typ.error) throw typ.error;
  typId = typ.data.id;

  const studio = await admin.from("studios").insert({ name: `Produkte ${p}` }).select("id").single();
  if (studio.error) throw studio.error;
  studioId = studio.data.id;
  trainer = uniqueEmail("produkte-trainer");
  const rolle = await admin
    .from("studio_memberships")
    .insert({ studio_id: studioId, user_id: await createTestUser(trainer), role: "trainer" });
  if (rolle.error) throw rolle.error;
  const modell = await admin
    .from("equipment_models")
    .insert({ studio_id: studioId, name: "Brustpresse", load_step: 5 })
    .select("id")
    .single();
  if (modell.error) throw modell.error;
  studioModellId = modell.data.id;
});

afterAll(async () => {
  // Herkunft zeigt mit restrict auf das Produkt: erst das Studio-Modell.
  await admin.from("equipment_models").delete().eq("studio_id", studioId);
  await admin.from("catalog_products").delete().like("catalog_key", `${p.replaceAll("_", "\\_")}%`);
  await admin.from("equipment_models").delete().eq("id", typId);
});

describe("catalog_products", () => {
  it("nimmt ein Produkt mit Verknuepfung zum Gymtavo-Typ an", async () => {
    const { data, error } = await produkt({ series: "Pure Kraft", model_code: "4345", product_url: "https://gym80.de/4345" });
    expect(error).toBeNull();
    const link = await admin.from("catalog_product_types").insert({ product_id: data!.id, equipment_model_id: typId });
    expect(link.error).toBeNull();
  });

  it("verbietet ein Foto ohne geklaerte Rechte", async () => {
    const offen = await produkt({ photo_path: `${GYMTAVO}/catalog/products/x-1.png` });
    expect(offen.error?.message).toContain("catalog_products_foto_nur_geklaert");
    const geklaert = await produkt({ photo_path: `${GYMTAVO}/catalog/products/x-2.png`, photo_rights: "cleared" });
    expect(geklaert.error).toBeNull();
  });

  it("verlangt die Belastung ganz oder gar nicht", async () => {
    const halb = await produkt({ load_unit: "kg", load_step: 5 });
    expect(halb.error?.message).toContain("catalog_products_load_all_or_none");
    const ganz = await produkt({ load_unit: "kg", load_step: 5, load_min: 5, load_max: 100 });
    expect(ganz.error).toBeNull();
  });

  it("verbietet leere Texte und eine Adresse ohne https", async () => {
    expect((await produkt({ manufacturer: " " })).error).not.toBeNull();
    expect((await produkt({ series: "" })).error).not.toBeNull();
    expect((await produkt({ product_url: "http://gym80.de" })).error).not.toBeNull();
    expect((await produkt({ catalog_key: "Gross-Buchstaben" })).error).not.toBeNull();
  });

  it("verknuepft nur mit Typen des Gymtavo-Studios", async () => {
    const { data } = await produkt();
    const link = await admin.from("catalog_product_types").insert({ product_id: data!.id, equipment_model_id: studioModellId });
    expect(link.error?.message).toContain("gymtavo_produkttyp_ungueltig");
  });

  it("haelt einen verknuepften Typ fest", async () => {
    const typ = await admin.from("equipment_models").insert({ studio_id: GYMTAVO, name: `${p}Fest`, load_step: 2.5 }).select("id").single();
    const { data } = await produkt();
    await admin.from("catalog_product_types").insert({ product_id: data!.id, equipment_model_id: typ.data!.id });
    const loeschen = await admin.from("equipment_models").delete().eq("id", typ.data!.id);
    expect(loeschen.error?.message).toContain("catalog_product_types");
    await admin.from("catalog_products").delete().eq("id", data!.id);
    expect((await admin.from("equipment_models").delete().eq("id", typ.data!.id)).error).toBeNull();
  });
});

describe("equipment_models.catalog_product_id", () => {
  it("merkt sich am Studio-Modell die Herkunft", async () => {
    const { data } = await produkt();
    const { error } = await admin.from("equipment_models").update({ catalog_product_id: data!.id }).eq("id", studioModellId);
    expect(error).toBeNull();
  });

  it("verbietet eine Herkunft im Gymtavo-Studio", async () => {
    const { data } = await produkt();
    const { error } = await admin.from("equipment_models").update({ catalog_product_id: data!.id }).eq("id", typId);
    expect(error?.message).toContain("gymtavo_herkunft_ungueltig");
  });
});

describe("RLS", () => {
  it("Angemeldete lesen Produkte und Verknuepfungen, schreiben aber nicht", async () => {
    const { data } = await produkt();
    await admin.from("catalog_product_types").insert({ product_id: data!.id, equipment_model_id: typId });
    const client = await userClient(trainer);

    const gelesen = await client.from("catalog_products").select("id, catalog_product_types(equipment_model_id)").eq("id", data!.id).single();
    expect(gelesen.data?.catalog_product_types).toEqual([{ equipment_model_id: typId }]);

    const neu = await client.from("catalog_products").insert({ catalog_key: `${p}fremd`, manufacturer: "x", name: "y" });
    expect(neu.error).not.toBeNull();
    const geaendert = await client.from("catalog_products").update({ name: "Gekapert" }).eq("id", data!.id).select("id");
    expect(geaendert.data ?? []).toEqual([]);
    const link = await client.from("catalog_product_types").delete().eq("product_id", data!.id).select("product_id");
    expect(link.data ?? []).toEqual([]);
    const danach = await admin.from("catalog_products").select("name").eq("id", data!.id).single();
    expect(danach.data?.name).toBe("Brustpresse");
  });
});
```

- [ ] **Step 2: Test laufen lassen, er muss scheitern**

Run: `pnpm test:integration -- katalog-produkte-db`
Expected: FAIL. Alle Fälle scheitern mit `relation "public.catalog_products" does not exist` bzw. `Could not find the table 'public.catalog_products'`.

- [ ] **Step 3: Migration schreiben**

`supabase/migrations/0050_catalog_products.sql`:

```sql
-- Herstellermodelle im Gymtavo-Katalog, Spec
-- 2026-10-10-gymtavo-katalog-geraeteeinrichtung-design.md, Abschnitt 6.1.
--
-- Eigene Tabelle statt equipment_models im Gymtavo-Studio (G2): dort waere
-- jedes Herstellermodell fuer jeden heutigen Leser ein Geraetetyp
-- (Bootstrap, Freies Training, Typsuche) und braeuchte ueberall einen Filter.
-- Geschrieben wird nur vom Import mit der Service-Rolle; Pflege im Portal
-- kommt mit Etappe 6 der Katalog-Spec.

create table public.catalog_products (
  id             uuid primary key default gen_random_uuid(),
  catalog_key    text not null
    constraint catalog_products_catalog_key_format check (catalog_key ~ '^[a-z0-9_]+$')
    -- Ein Constraint statt eines Index: PostgREST-Upserts (on_conflict)
    -- brauchen ihn, wie bei 0048.
    constraint catalog_products_catalog_key_unique unique,
  manufacturer   text not null check (length(trim(manufacturer)) > 0),
  series         text check (series is null or length(trim(series)) > 0),
  name           text not null check (length(trim(name)) > 0),
  model_code     text check (model_code is null or length(trim(model_code)) > 0),
  product_url    text check (product_url is null or product_url like 'https://%'),
  note           text check (note is null or length(trim(note)) > 0),
  photo_path     text,
  photo_rights   text not null default 'pending'
    constraint catalog_products_photo_rights_check check (photo_rights in ('pending', 'cleared')),
  load_unit      text check (load_unit is null or load_unit in ('kg', 'watt', 'level', 'kmh', 'pct', 'rpm')),
  load_step      numeric check (load_step is null or load_step > 0),
  load_min       numeric check (load_min is null or load_min >= 0),
  load_max       numeric,
  secondary_unit text check (secondary_unit is null or secondary_unit in ('kg', 'watt', 'level', 'kmh', 'pct', 'rpm')),
  secondary_step numeric check (secondary_step is null or secondary_step > 0),
  secondary_min  numeric check (secondary_min is null or secondary_min >= 0),
  secondary_max  numeric,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),

  -- G3: ein ungeklaertes Foto kann nie angezeigt werden, auch nicht durch
  -- einen Fehler im Code -- es hat schlicht keinen Pfad.
  constraint catalog_products_foto_nur_geklaert
    check (photo_path is null or photo_rights = 'cleared'),
  -- G4: alles oder nichts. Ein Schritt ohne Einheit haette kein Rad, eine
  -- Einheit ohne Grenzen waere nur halb ein Raster.
  constraint catalog_products_load_all_or_none
    check ((load_unit is null) = (load_step is null)
       and (load_unit is null) = (load_min is null)
       and (load_unit is null) = (load_max is null)),
  constraint catalog_products_load_range
    check (load_max is null or load_max >= load_min),
  constraint catalog_products_secondary_all_or_none
    check ((secondary_unit is null) = (secondary_step is null)
       and (secondary_unit is null) = (secondary_min is null)
       and (secondary_unit is null) = (secondary_max is null)),
  constraint catalog_products_secondary_range
    check (secondary_max is null or secondary_max >= secondary_min)
);

create trigger set_updated_at before update on public.catalog_products
  for each row execute function public.set_updated_at();

-- Ein Produkt passt oft zu mehreren Typen (15 von 114 im Erstbestand).
-- restrict am Typ: ein Typ mit Produkten verschwindet nicht still mitsamt
-- ihrer Zuordnung.
create table public.catalog_product_types (
  product_id         uuid not null references public.catalog_products (id) on delete cascade,
  equipment_model_id uuid not null references public.equipment_models (id) on delete restrict,
  primary key (product_id, equipment_model_id)
);

create index on public.catalog_product_types (equipment_model_id);

-- SECURITY DEFINER wie equipment_models_zuordnung_pruefen (0047): das Ziel
-- liegt in einem Studio, das der Aufrufer nicht lesen muss.
create or replace function public.catalog_product_types_typ_pruefen()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not exists (
    select 1 from public.equipment_models typ
    where typ.id = new.equipment_model_id
      and public.is_catalog_studio(typ.studio_id)
  ) then
    raise exception 'gymtavo_produkttyp_ungueltig';
  end if;
  return new;
end;
$$;

revoke all on function public.catalog_product_types_typ_pruefen() from public, anon, authenticated;

create trigger catalog_product_types_typ_pruefen
  before insert or update on public.catalog_product_types
  for each row execute function public.catalog_product_types_typ_pruefen();

-- Nur Herkunft: die Werte sind kopiert (G1). Ob das Produkt zum
-- zugeordneten Typ passt, prueft der Trigger bewusst nicht -- sonst
-- scheiterte ein spaeterer Typwechsel im StammdatenFormular, und die
-- Spalte wirkt nicht aufs Training. Die Pruefung beim Anlegen macht
-- createEquipmentModel.
alter table public.equipment_models
  add column catalog_product_id uuid
    constraint equipment_models_catalog_product_id_fkey
    references public.catalog_products (id) on delete restrict;

create index on public.equipment_models (catalog_product_id);

create or replace function public.equipment_models_herkunft_pruefen()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.catalog_product_id is not null and public.is_catalog_studio(new.studio_id) then
    raise exception 'gymtavo_herkunft_ungueltig';
  end if;
  return new;
end;
$$;

revoke all on function public.equipment_models_herkunft_pruefen() from public, anon, authenticated;

create trigger equipment_models_herkunft_pruefen
  before insert or update of catalog_product_id, studio_id on public.equipment_models
  for each row execute function public.equipment_models_herkunft_pruefen();

-- Lesen fuer alle Angemeldeten, wie der uebrige Katalog. Keine
-- Schreib-Policies: es schreibt nur die Service-Rolle. Die Grants zum
-- Schreiben fallen zusaetzlich weg, weil RLS ein TRUNCATE nicht aufhaelt.
alter table public.catalog_products enable row level security;
alter table public.catalog_product_types enable row level security;

create policy catalog_products_select on public.catalog_products
  for select to authenticated using (true);
create policy catalog_product_types_select on public.catalog_product_types
  for select to authenticated using (true);

revoke insert, update, delete, truncate on public.catalog_products from anon, authenticated;
revoke insert, update, delete, truncate on public.catalog_product_types from anon, authenticated;
revoke all on public.catalog_products from anon;
revoke all on public.catalog_product_types from anon;

-- Produktfotos liegen unter <Gymtavo-ID>/catalog/products/; media_select
-- aus 0047 (is_catalog_studio) deckt den Pfad schon ab.
```

- [ ] **Step 4: Migration lokal anwenden**

Run: `pnpm exec supabase migration up --local`
Expected: `Applying migration 0050_catalog_products.sql...`, danach `Local database is up to date.` Kein `db reset`.

- [ ] **Step 5: Test laufen lassen, er muss grün sein**

Run: `pnpm test:integration -- katalog-produkte-db`
Expected: PASS, 9 Tests.

- [ ] **Step 6: Spec auf 0050 korrigieren**

In `docs/superpowers/specs/2026-10-10-gymtavo-katalog-geraeteeinrichtung-design.md` jedes `0049` durch `0050` ersetzen (Überschrift 6.1 und Abschnitt 7). Unter die Überschrift 6.1 kommt die Zeile:

```markdown
> Nummer 0050 statt 0049: 0049 ist mit `0049_satz_herkunft.sql` (Sensor B) vergeben.
```

Run: `grep -n "0049\|0050" docs/superpowers/specs/2026-10-10-gymtavo-katalog-geraeteeinrichtung-design.md`
Expected: `0049` taucht nur noch im Hinweis auf.

- [ ] **Step 7: Commit**

```bash
git add supabase/migrations/0050_catalog_products.sql tests/integration/katalog-produkte-db.test.ts docs/superpowers/specs/2026-10-10-gymtavo-katalog-geraeteeinrichtung-design.md
git commit -m "feat(katalog): Herstellermodelle mit Typzuordnung und Herkunft am Studio-Modell (Migration 0050)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log -1 --format=%B
```

---

### Task 2: `products[]` in der Katalogdatei prüfen

**Files:**
- Modify: `packages/domain/src/katalog-datei.ts`
- Modify: `packages/domain/src/katalog-testdaten.ts`
- Test: `packages/domain/src/katalog-datei.test.ts`

**Interfaces:**
- Produces:
  - `KatalogDatei["products"]`: Array von `Produkt` mit den Feldern `key, manufacturer, series, name, model_code, product_url, types: string[], note, photo, photo_rights: "pending" | "cleared", load_unit, load_step, load_min, load_max, secondary`.
  - `export type Produkt`.
  - In `katalog-testdaten.ts`: `mitProdukten(beispiel, p)` liefert `{ roh, dateien }` mit zwei Produkten:
    - `${p}gym80_pure_kraft_4345`: pending, ohne Foto, ohne Belastung, Typen `${p}brustpresse` und `${p}trizepsmaschine`.
    - `${p}precor_trm_885`: cleared, Foto `media/products/precor_trm_885.jpg`, Belastung kmh, Typ `${p}laufband`.

- [ ] **Step 1: Failing tests schreiben**

Am Ende von `packages/domain/src/katalog-datei.test.ts` anfügen (Import oben um `mitProdukten` ergänzen: `import { beispielKatalog, mitProdukten } from "./katalog-testdaten.js";`):

```ts
function produktFehler(aendern: (roh: ReturnType<typeof mitProdukten>["roh"]) => void): string[] {
  const { roh } = mitProdukten(beispielKatalog());
  aendern(roh);
  const pruefung = pruefeKatalog(roh);
  if (pruefung.ok) throw new Error("Pruefung haette scheitern muessen");
  return pruefung.fehler;
}

describe("pruefeKatalog products", () => {
  it("nimmt eine Datei ohne products als leere Liste", () => {
    const pruefung = pruefeKatalog(beispielKatalog().roh);
    expect(pruefung.ok && pruefung.wert.products).toEqual([]);
  });

  it("laesst Produkte mit und ohne Belastung durch", () => {
    const pruefung = pruefeKatalog(mitProdukten(beispielKatalog()).roh);
    if (!pruefung.ok) throw new Error(pruefung.fehler.join("\n"));
    expect(pruefung.wert.products.map((x) => x.key)).toEqual(["gym80_pure_kraft_4345", "precor_trm_885"]);
  });

  it("meldet Formfehler mit Ort", () => {
    expect(
      produktFehler((roh) => {
        roh.products[0]!.product_url = "http://gym80.de";
        roh.products[0]!.photo_rights = "unklar";
        roh.products[1]!.types = [];
        roh.products[1]!.series = " ";
      }),
    ).toEqual([
      'products[0] "gym80_pure_kraft_4345" product_url: muss eine https-Adresse sein',
      'products[0] "gym80_pure_kraft_4345" photo_rights: ist "unklar", erlaubt: pending, cleared',
      'products[1] "precor_trm_885" series: darf nicht leer sein',
      'products[1] "precor_trm_885" types: braucht mindestens einen Geraetetyp',
    ]);
  });

  it("meldet Verweise, Doppelte und halbe Belastung", () => {
    expect(
      produktFehler((roh) => {
        roh.products[0]!.types = ["brustpresse", "brustpresse", "rudergeraet"];
        roh.products[0]!.load_unit = "kg";
        roh.products[1]!.load_max = 0.5;
        roh.products.push({ ...roh.products[1]!, load_max: 25 });
      }),
    ).toEqual([
      'products: Schluessel "precor_trm_885" kommt mehrfach vor',
      'products[0] "gym80_pure_kraft_4345" types: Geraetetyp "brustpresse" kommt mehrfach vor',
      'products[0] "gym80_pure_kraft_4345" types: Geraetetyp "rudergeraet" gibt es in equipment nicht',
      'products[0] "gym80_pure_kraft_4345": load_unit, load_step, load_min und load_max nur alle zusammen oder keins',
      'products[1] "precor_trm_885": load_max ist kleiner als load_min',
    ]);
  });
});
```

Die Reihenfolge der zod-Meldungen folgt der Feldreihenfolge im Schema (Step 3). Weicht sie ab, ist das Schema in der falschen Reihenfolge und wird angepasst, nicht der Test.

- [ ] **Step 2: Tests laufen lassen, sie müssen scheitern**

Run: `pnpm --filter @fitretro/domain test -- katalog-datei`
Expected: FAIL. `mitProdukten` ist nicht exportiert (`SyntaxError`/`is not a function`).

- [ ] **Step 3: Testdaten ergänzen**

Am Ende von `packages/domain/src/katalog-testdaten.ts`:

```ts
export type ProduktRoh = {
  key: string;
  manufacturer: string;
  series: string | null;
  name: string;
  model_code: string | null;
  product_url: string | null;
  types: string[];
  note: string | null;
  photo: string | null;
  photo_rights: string;
  load_unit: string | null;
  load_step: number | null;
  load_min: number | null;
  load_max: number | null;
  secondary: { unit: string; step: number; min: number; max: number } | null;
};

/**
 * Der Beispielkatalog mit zwei Herstellermodellen (Spec 2026-10-10 ...,
 * 6.2): eines an zwei Typen, ohne Foto und ohne Belastung -- so sieht der
 * Erstbestand aus --, eines mit geklaertem Foto und vollem Raster.
 * Getrennt von beispielKatalog, damit dessen Zaehlungen in den
 * Bestandstests gleich bleiben.
 */
export function mitProdukten(beispiel: ReturnType<typeof beispielKatalog>, p = "") {
  const products: ProduktRoh[] = [
    {
      key: `${p}gym80_pure_kraft_4345`,
      manufacturer: "gym80",
      series: "Pure Kraft",
      name: "Brustpresse",
      model_code: "4345",
      product_url: "https://example.org/gym80/4345",
      types: [`${p}brustpresse`, `${p}trizepsmaschine`],
      note: "Scheibenbeladen, eigenes Lastprofil.",
      photo: null,
      photo_rights: "pending",
      load_unit: null,
      load_step: null,
      load_min: null,
      load_max: null,
      secondary: null,
    },
    {
      key: `${p}precor_trm_885`,
      manufacturer: "Precor",
      series: null,
      name: "Laufband",
      model_code: "TRM 885",
      product_url: null,
      types: [`${p}laufband`],
      note: null,
      photo: "media/products/precor_trm_885.jpg",
      photo_rights: "cleared",
      load_unit: "kmh",
      load_step: 0.1,
      load_min: 0.8,
      load_max: 25,
      secondary: { unit: "pct", step: 0.5, min: 0, max: 15 },
    },
  ];
  const dateien = new Map(beispiel.dateien);
  dateien.set("media/products/precor_trm_885.jpg", jpegBytes(4));
  return { roh: { ...beispiel.roh, products }, dateien };
}
```

- [ ] **Step 4: Schema und Querprüfung ergänzen**

In `packages/domain/src/katalog-datei.ts`:

(a) Vor `geraetetypSchema` die Nebenbelastung herausziehen, damit Typ und Produkt dieselbe Regel nutzen:

```ts
// Alle vier oder keiner: so verlangt es equipment_models_secondary_all_or_none (0046).
const nebenbelastungSchema = z
  .object({ unit: z.enum(LOAD_UNITS), step: positiv, min: nichtNegativ, max: nichtNegativ })
  .strict();
```

In `geraetetypSchema` das bisherige `secondary: z.object({...}).strict().nullable(),` samt Kommentar ersetzen durch:

```ts
    secondary: nebenbelastungSchema.nullable(),
```

(b) Nach `uebungSchema`:

```ts
const httpsAdresse = z.string().regex(/^https:\/\/\S+$/, "muss eine https-Adresse sein");

// Spec 2026-10-10-gymtavo-katalog-geraeteeinrichtung-design.md, 6.2.
// Die Belastung ist hier nullable und wird in querPruefen als Ganzes
// geprueft -- zod kennt "alle vier oder keins" ueber Geschwisterfelder nicht.
const produktSchema = z
  .object({
    key: schluessel,
    manufacturer: text,
    series: text.nullable(),
    name: text,
    model_code: text.nullable(),
    product_url: httpsAdresse.nullable(),
    types: z.array(schluessel).min(1, "braucht mindestens einen Geraetetyp"),
    note: text.nullable(),
    photo: medienPfad.nullable(),
    photo_rights: z.enum(["pending", "cleared"]),
    load_unit: z.enum(LOAD_UNITS).nullable(),
    load_step: positiv.nullable(),
    load_min: nichtNegativ.nullable(),
    load_max: nichtNegativ.nullable(),
    secondary: nebenbelastungSchema.nullable(),
  })
  .strict();
```

(c) In `katalogSchema` bei `sources` die URL-Regel durch `url: httpsAdresse,` ersetzen und nach `exercises: z.array(uebungSchema),` ergänzen:

```ts
    // Optional (Plan-Entscheidung P2): Dateien von vor Etappe B bleiben gueltig.
    products: z.array(produktSchema).default([]),
```

(d) Nach `export type Einstellung = …`:

```ts
export type Produkt = KatalogDatei["products"][number];
```

(e) In `querPruefen` nach `eindeutig("exercises", …)`:

```ts
  eindeutig("products", k.products.map((p) => p.key));
```

und vor `return fehler;`:

```ts
  const typen = new Set(k.equipment.map((g) => g.key));
  k.products.forEach((p, i) => {
    const wo = `products[${i}] "${p.key}"`;
    for (const d of doppelte(p.types)) fehler.push(`${wo} types: Geraetetyp "${d}" kommt mehrfach vor`);
    for (const t of p.types) {
      if (!typen.has(t)) fehler.push(`${wo} types: Geraetetyp "${t}" gibt es in equipment nicht`);
    }
    // Wie catalog_products_load_all_or_none (0050): ein halbes Raster ist keins.
    const gesetzt = [p.load_unit, p.load_step, p.load_min, p.load_max].filter((w) => w !== null).length;
    if (gesetzt !== 0 && gesetzt !== 4) {
      fehler.push(`${wo}: load_unit, load_step, load_min und load_max nur alle zusammen oder keins`);
    }
    if (p.load_min !== null && p.load_max !== null && p.load_max < p.load_min) {
      fehler.push(`${wo}: load_max ist kleiner als load_min`);
    }
    if (p.secondary !== null && p.secondary.max < p.secondary.min) {
      fehler.push(`${wo}: secondary.max ist kleiner als secondary.min`);
    }
  });
```

- [ ] **Step 5: Tests laufen lassen, sie müssen grün sein**

Run: `pnpm --filter @fitretro/domain test -- katalog-datei`
Expected: PASS. Die bisherigen Tests bleiben grün, 4 neue kommen dazu.

- [ ] **Step 6: Commit**

```bash
git add packages/domain/src/katalog-datei.ts packages/domain/src/katalog-datei.test.ts packages/domain/src/katalog-testdaten.ts
git commit -m "feat(katalog): Katalogdatei kennt Herstellermodelle und prueft sie mit Ort

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log -1 --format=%B
```

---

### Task 3: Produktfotos lesen und prüfen

**Files:**
- Modify: `packages/domain/src/katalog-medien.ts`
- Test: `packages/domain/src/katalog-medien.test.ts`

**Interfaces:**
- Consumes: `KatalogDatei["products"]` (Task 2).
- Produces:
  - `Medien` = `{ fotos; videos; produktFotos: Map<string, Medium> }`. `produktFotos` enthält auch Fotos mit `pending`, denn geprüft wird jedes. Was davon hochgeladen wird, entscheidet der Plan.
  - `produktFotoPraefix(key: string): string` liefert `${GYMTAVO_STUDIO_ID}/catalog/products/${key}-`.

- [ ] **Step 1: Failing tests schreiben**

In `packages/domain/src/katalog-medien.test.ts` den Import um `produktFotoPraefix` und `mitProdukten` ergänzen und anfügen:

```ts
describe("pruefeMedien Produktfotos", () => {
  function medienVon(beispiel: ReturnType<typeof mitProdukten>) {
    const k = pruefeKatalog(beispiel.roh);
    if (!k.ok) throw new Error(k.fehler.join("\n"));
    return pruefeMedien(k.wert, (d) => beispiel.dateien.get(d) ?? null);
  }

  it("legt das Produktfoto unter den eigenen Praefix mit Inhaltshash", () => {
    const m = medienVon(mitProdukten(beispielKatalog()));
    if (!m.ok) throw new Error(m.fehler.join("\n"));
    const foto = m.wert.produktFotos.get("precor_trm_885");
    expect(foto?.storagePath).toMatch(new RegExp(`^${produktFotoPraefix("precor_trm_885")}[0-9a-f]{8}\\.jpg$`));
    expect(foto?.contentType).toBe("image/jpeg");
    expect(m.wert.produktFotos.has("gym80_pure_kraft_4345")).toBe(false);
  });

  it("prueft auch ein Foto ohne geklaerte Rechte", () => {
    const beispiel = mitProdukten(beispielKatalog());
    beispiel.roh.products[0]!.photo = "media/products/fehlt.png";
    const m = medienVon(beispiel);
    expect(m.ok ? [] : m.fehler).toEqual([
      'products[0] "gym80_pure_kraft_4345" photo "media/products/fehlt.png": Datei fehlt',
    ]);
  });

  it("verlangt PNG oder JPEG", () => {
    const beispiel = mitProdukten(beispielKatalog());
    beispiel.dateien.set("media/products/precor_trm_885.jpg", mp4Bytes(3));
    const m = medienVon(beispiel);
    expect(m.ok ? [] : m.fehler).toEqual([
      'products[1] "precor_trm_885" photo "media/products/precor_trm_885.jpg": ist kein PNG oder JPEG',
    ]);
  });
});
```

Benötigte Importe oben in der Datei: `pruefeKatalog` aus `./katalog-datei.js`; `pruefeMedien` und `produktFotoPraefix` aus `./katalog-medien.js`; `beispielKatalog`, `mitProdukten` und `mp4Bytes` aus `./katalog-testdaten.js`. Was schon importiert ist, nicht doppeln.

- [ ] **Step 2: Tests laufen lassen, sie müssen scheitern**

Run: `pnpm --filter @fitretro/domain test -- katalog-medien`
Expected: FAIL. `produktFotoPraefix is not a function` bzw. `produktFotos` ist `undefined`.

- [ ] **Step 3: Implementieren**

In `packages/domain/src/katalog-medien.ts`:

(a) Typ und Präfix:

```ts
export type Medien = { fotos: Map<string, Medium>; videos: Map<string, Medium>; produktFotos: Map<string, Medium> };
```

nach `videoPraefix`:

```ts
/** Eigener Ordner: Produkt- und Typschluessel teilen keinen Namensraum. */
export function produktFotoPraefix(key: string): string {
  return `${GYMTAVO_STUDIO_ID}/catalog/products/${key}-`;
}
```

(b) In `pruefeMedien` den Block `k.equipment.forEach((g, i) => { … });` ersetzen durch einen gemeinsamen Helfer und zwei Aufrufe:

```ts
  const produktFotos = new Map<string, Medium>();

  function foto(wo: string, datei: string, praefix: string): Medium | null {
    const bytes = lies(datei);
    if (bytes === null) {
      fehler.push(`${wo}: Datei fehlt`);
      return null;
    }
    const typ = sniffMediaType(bytes);
    if (typ !== "image/png" && typ !== "image/jpeg") {
      fehler.push(`${wo}: ist kein PNG oder JPEG`);
      return null;
    }
    if (bytes.length > MAX_PHOTO_BYTES) {
      fehler.push(`${wo}: ist groesser als 10 MiB`);
      return null;
    }
    const endung = typ === "image/png" ? "png" : "jpg";
    return { datei, bucket: PHOTO_BUCKET, storagePath: `${praefix}${kurzHash(bytes)}.${endung}`, contentType: typ, bytes };
  }

  k.equipment.forEach((g, i) => {
    if (g.photo === null) return;
    const medium = foto(`equipment[${i}] "${g.key}" photo "${g.photo}"`, g.photo, fotoPraefix(g.key));
    if (medium) fotos.set(g.key, medium);
  });

  // Auch ein Foto ohne geklaerte Rechte wird geprueft (Spec 6.2): sonst
  // faellt eine kaputte Datei erst auf, wenn die Rechte da sind.
  k.products.forEach((p, i) => {
    if (p.photo === null) return;
    const medium = foto(`products[${i}] "${p.key}" photo "${p.photo}"`, p.photo, produktFotoPraefix(p.key));
    if (medium) produktFotos.set(p.key, medium);
  });
```

und das Ergebnis:

```ts
  return fehler.length > 0 ? { ok: false, fehler } : { ok: true, wert: { fotos, videos, produktFotos } };
```

- [ ] **Step 4: Tests laufen lassen, sie müssen grün sein**

Run: `pnpm --filter @fitretro/domain test -- katalog-medien katalog-laden`
Expected: PASS, auch die bestehenden Fälle.

- [ ] **Step 5: Commit**

```bash
git add packages/domain/src/katalog-medien.ts packages/domain/src/katalog-medien.test.ts
git commit -m "feat(katalog): Produktfotos der Katalogdatei pruefen und eigenem Ordner zuweisen

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log -1 --format=%B
```

---

### Task 4: Produkte und Verknüpfungen planen

**Files:**
- Modify: `packages/domain/src/katalog-plan.ts`
- Test: `packages/domain/src/katalog-plan.test.ts`

**Interfaces:**
- Consumes: `Medien.produktFotos` (Task 3), `KatalogDatei["products"]` (Task 2).
- Produces:
  - `ProduktZeile` mit den Feldern `catalog_key, manufacturer, series, name, model_code, product_url, note, photo_path, photo_rights, load_unit, load_step, load_min, load_max, secondary_unit, secondary_step, secondary_min, secondary_max`.
  - `IstStand` bekommt zusätzlich `produkte: (ProduktZeile & { id: string })[]` und `produktTypen: { product_id: string; equipment_model_id: string }[]`.
  - `ImportPlan` bekommt zusätzlich `produkte: Posten<ProduktZeile>[]` und `produktTypen: Posten<{ produkt: string; geraetetyp: string }>[]`.
  - `gemeldet` bekommt zusätzlich `produkte: string[]`, `produktTypen: string[]`, `zurueckgehalteneFotos: string[]` und `entzogeneFotos: string[]`.
  - Der Schlüssel einer Verknüpfung lautet `"<produkt> > <typ>"`.

- [ ] **Step 1: Failing tests schreiben**

In `packages/domain/src/katalog-plan.test.ts`:

(a) `LEER` erweitern:

```ts
const LEER: IstStand = {
  geraetetypen: [], einstellungen: [], uebungen: [], verknuepfungen: [], videos: [], produkte: [], produktTypen: [], objekte: new Set(),
};
```

(b) In `istAus` vor `objekte:` ergänzen:

```ts
    produkte: plan.produkte.map((p) => ({ id: `prod-${p.schluessel}`, ...p.zeile })),
    produktTypen: plan.produktTypen.map((p) => ({ product_id: `prod-${p.zeile.produkt}`, equipment_model_id: typId(p.zeile.geraetetyp) })),
```

(c) `mitProdukten` importieren und anfügen:

```ts
describe("planeImport Produkte", () => {
  it("legt Produkte und ihre Typzuordnungen neu an", () => {
    const plan = plane(mitProdukten(beispielKatalog()), LEER);
    expect(plan.produkte.map((p) => [p.schluessel, p.art])).toEqual([
      ["gym80_pure_kraft_4345", "neu"],
      ["precor_trm_885", "neu"],
    ]);
    expect(plan.produktTypen.map((p) => p.schluessel)).toEqual([
      "gym80_pure_kraft_4345 > brustpresse",
      "gym80_pure_kraft_4345 > trizepsmaschine",
      "precor_trm_885 > laufband",
    ]);
    const precor = plan.produkte[1]!.zeile;
    expect(precor).toMatchObject({ photo_rights: "cleared", load_unit: "kmh", load_min: 0.8, secondary_unit: "pct", secondary_max: 15 });
    expect(precor.photo_path).toMatch(/\/catalog\/products\/precor_trm_885-[0-9a-f]{8}\.jpg$/);
    expect(plan.uploads.map((m) => m.datei)).toContain("media/products/precor_trm_885.jpg");
  });

  it("aendert beim zweiten Lauf nichts", () => {
    const beispiel = mitProdukten(beispielKatalog());
    const plan = plane(beispiel, istAus(plane(beispiel, LEER)));
    expect(arten(plan.produkte)).toEqual(["unveraendert", "unveraendert"]);
    expect(arten(plan.produktTypen)).toEqual(["unveraendert", "unveraendert", "unveraendert"]);
    expect(plan.uploads).toEqual([]);
  });

  it("haelt ein Foto ohne geklaerte Rechte zurueck und meldet es", () => {
    const beispiel = mitProdukten(beispielKatalog());
    beispiel.roh.products[1]!.photo_rights = "pending";
    const plan = plane(beispiel, LEER);
    expect(plan.produkte[1]!.zeile.photo_path).toBeNull();
    expect(plan.uploads.map((m) => m.datei)).not.toContain("media/products/precor_trm_885.jpg");
    expect(plan.gemeldet.zurueckgehalteneFotos).toEqual(["precor_trm_885"]);
  });

  it("nimmt bei Rechteentzug das Foto weg und meldet das Objekt", () => {
    const beispiel = mitProdukten(beispielKatalog());
    const vorher = plane(beispiel, LEER);
    const altesFoto = vorher.produkte[1]!.zeile.photo_path;
    beispiel.roh.products[1]!.photo_rights = "pending";
    const plan = plane(beispiel, istAus(vorher));
    expect(plan.produkte[1]).toMatchObject({ art: "geaendert", felder: ["photo_path", "photo_rights"] });
    expect(plan.produkte[1]!.zeile.photo_path).toBeNull();
    expect(plan.gemeldet.entzogeneFotos).toEqual([`precor_trm_885: equipment-photos/${altesFoto}`]);
    expect(plan.gemeldet.ersetzteMedien).toEqual([]);
  });

  it("meldet Produkte und Zuordnungen, die nur in der Datenbank stehen", () => {
    const beispiel = mitProdukten(beispielKatalog());
    const ist = istAus(plane(beispiel, LEER));
    beispiel.roh.products[0]!.types = ["brustpresse"];
    beispiel.roh.products.pop();
    const plan = plane(beispiel, ist);
    expect(plan.gemeldet.produkte).toEqual(["precor_trm_885"]);
    expect(plan.gemeldet.produktTypen).toEqual(["gym80_pure_kraft_4345 > trizepsmaschine"]);
  });

  it("zeigt Produkte im Bericht, auch ohne products in der Datei", () => {
    expect(berichtText(plane(beispielKatalog(), LEER))).toContain("Produkte: 0 neu, 0 geaendert, 0 unveraendert");
    const text = berichtText(plane(mitProdukten(beispielKatalog()), LEER));
    expect(text).toContain("Produkte: 2 neu, 0 geaendert, 0 unveraendert");
    expect(text).toContain("Produkt-Typen: 3 neu, 0 geaendert, 0 unveraendert");
  });
});
```

- [ ] **Step 2: Tests laufen lassen, sie müssen scheitern**

Run: `pnpm --filter @fitretro/domain test -- katalog-plan`
Expected: FAIL. `plan.produkte` ist `undefined`; die Typprüfung von `LEER` meckert erst bei `pnpm typecheck`.

- [ ] **Step 3: Implementieren**

In `packages/domain/src/katalog-plan.ts`:

(a) Typen nach `UebungZeile`:

```ts
export type ProduktZeile = {
  catalog_key: string;
  manufacturer: string;
  series: string | null;
  name: string;
  model_code: string | null;
  product_url: string | null;
  note: string | null;
  photo_path: string | null;
  photo_rights: "pending" | "cleared";
  load_unit: string | null;
  load_step: number | null;
  load_min: number | null;
  load_max: number | null;
  secondary_unit: string | null;
  secondary_step: number | null;
  secondary_min: number | null;
  secondary_max: number | null;
};

export type IstProdukt = ProduktZeile & { id: string };
export type IstProduktTyp = { product_id: string; equipment_model_id: string };
```

`IstStand` vor `objekte` um

```ts
  produkte: IstProdukt[];
  produktTypen: IstProduktTyp[];
```

erweitern und den Kommentar an `objekte` zu `/** "<bucket>/<pfad>" aller Objekte unter <Gymtavo-ID>/catalog/ (photos, videos, products). */` ändern.

`ImportPlan` nach `videos`:

```ts
  produkte: Posten<ProduktZeile>[];
  produktTypen: Posten<{ produkt: string; geraetetyp: string }>[];
```

`gemeldet` am Ende:

```ts
    produkte: string[];
    produktTypen: string[];
    /** Produktfotos in der Datei, deren Rechte offen sind -- nicht hochgeladen. */
    zurueckgehalteneFotos: string[];
    /** "<key>: <bucket>/<pfad>" -- Rechte entzogen, photo_path geleert, Objekt bleibt. */
    entzogeneFotos: string[];
```

(b) Feldliste nach `UEBUNG_FELDER`:

```ts
const PRODUKT_FELDER = [
  "manufacturer", "series", "name", "model_code", "product_url", "note", "photo_path", "photo_rights",
  "load_unit", "load_step", "load_min", "load_max", "secondary_unit", "secondary_step", "secondary_min", "secondary_max",
] as const;
```

(c) In `planeImport`: die Initialisierung von `gemeldet` um `produkte: [], produktTypen: [], zurueckgehalteneFotos: [], entzogeneFotos: []` erweitern. Vor `const typKeys = …` einfügen:

```ts
  // Produkte (Spec 2026-10-10 ..., 6.2). Ein Foto kommt nur mit geklaerten
  // Rechten in die Zeile und in den Upload; ein ungeklaertes bleibt in der
  // Datei und wird gemeldet (G3).
  const produktNachKey = new Map(ist.produkte.map((x) => [x.catalog_key, x]));
  const typKeyNachId = new Map(ist.geraetetypen.flatMap((g) => (g.catalog_key === null ? [] : [[g.id, g.catalog_key] as const])));
  const produktFotos: Medium[] = [];
  const produkte = k.products.map((p) => {
    const medium = medien.produktFotos.get(p.key);
    const geklaert = p.photo_rights === "cleared";
    if (medium && geklaert) produktFotos.push(medium);
    if (medium && !geklaert) gemeldet.zurueckgehalteneFotos.push(p.key);
    const zeile: ProduktZeile = {
      catalog_key: p.key,
      manufacturer: p.manufacturer,
      series: p.series,
      name: p.name,
      model_code: p.model_code,
      product_url: p.product_url,
      note: p.note,
      photo_path: geklaert ? (medium?.storagePath ?? null) : null,
      photo_rights: p.photo_rights,
      load_unit: p.load_unit,
      load_step: p.load_step,
      load_min: p.load_min,
      load_max: p.load_max,
      secondary_unit: p.secondary?.unit ?? null,
      secondary_step: p.secondary?.step ?? null,
      secondary_min: p.secondary?.min ?? null,
      secondary_max: p.secondary?.max ?? null,
    };
    const istP = produktNachKey.get(p.key);
    const posten = vergleiche(p.key, zeile, istP, PRODUKT_FELDER);
    if (istP?.photo_path && posten.felder.includes("photo_path")) {
      // Die einzige Stelle, an der der Import etwas wegnimmt (Spec 6.2):
      // ein Rechteentzug muss sofort wirken. Das Objekt bleibt liegen.
      if (!geklaert) gemeldet.entzogeneFotos.push(`${p.key}: ${PHOTO_BUCKET}/${istP.photo_path}`);
      else ersetzt.add(`${PHOTO_BUCKET}/${istP.photo_path}`);
    }
    return posten;
  });

  const produktTypen = k.products.flatMap((p) => {
    const istP = produktNachKey.get(p.key);
    const soll = new Set(p.types);
    if (istP) {
      for (const l of ist.produktTypen) {
        const typKey = typKeyNachId.get(l.equipment_model_id) ?? l.equipment_model_id;
        if (l.product_id === istP.id && !soll.has(typKey)) gemeldet.produktTypen.push(`${p.key} > ${typKey}`);
      }
    }
    return p.types.map((t) => {
      const istTyp = typNachKey.get(t);
      const istL =
        istP && istTyp
          ? ist.produktTypen.find((l) => l.product_id === istP.id && l.equipment_model_id === istTyp.id)
          : undefined;
      // Die Verknuepfung hat keine eigenen Felder: neu oder unveraendert.
      return vergleiche(
        `${p.key} > ${t}`,
        { produkt: p.key, geraetetyp: t },
        istL ? { ...istL, id: `${istL.product_id}|${istL.equipment_model_id}` } : undefined,
        [],
      );
    });
  });

  const produktKeys = new Set(k.products.map((p) => p.key));
  for (const x of ist.produkte) if (!produktKeys.has(x.catalog_key)) gemeldet.produkte.push(x.catalog_key);
```

Die Uploads am Ende ersetzen durch:

```ts
  const uploads = [...fotos, ...medien.videos.values(), ...produktFotos].filter(
    (m) => !ist.objekte.has(`${m.bucket}/${m.storagePath}`),
  );

  return { geraetetypen, einstellungen, uebungen, verknuepfungen, videos, produkte, produktTypen, uploads, gemeldet };
```

(d) In `berichtText` nach `tabelle("Videos", plan.videos);`:

```ts
  tabelle("Produkte", plan.produkte);
  tabelle("Produkt-Typen", plan.produktTypen);
```

und nach dem letzten `melden(…)`:

```ts
  melden("Nur in der Datenbank, nicht geloescht -- Produkte", plan.gemeldet.produkte);
  melden("Nur in der Datenbank, nicht geloescht -- Produkt-Typen", plan.gemeldet.produktTypen);
  melden("Produktfoto ohne geklaerte Rechte, nicht hochgeladen", plan.gemeldet.zurueckgehalteneFotos);
  melden("Produktfoto nach Rechteentzug entfernt, Objekt bleibt liegen", plan.gemeldet.entzogeneFotos);
```

- [ ] **Step 4: Tests und Typprüfung laufen lassen**

Run: `pnpm --filter @fitretro/domain test -- katalog-plan && pnpm --filter @fitretro/domain typecheck`
Expected: PASS. Meldet `typecheck` `katalog-import.ts` (fehlende `produkte` im `IstStand`), wird das in Task 5 behoben. Dann reicht hier der Unit-Lauf. Die Meldung steht im Ledger als erwartete Lücke bis Task 5.

- [ ] **Step 5: Commit**

```bash
git add packages/domain/src/katalog-plan.ts packages/domain/src/katalog-plan.test.ts
git commit -m "feat(katalog): Importplan fuer Herstellermodelle, Rechteentzug nimmt das Foto weg

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log -1 --format=%B
```

---

### Task 5: Produkte importieren

**Files:**
- Modify: `packages/domain/src/katalog-import.ts`
- Modify: `scripts/catalog-import.ts`
- Test: `tests/integration/katalog-import.test.ts`

**Interfaces:**
- Consumes: `ImportPlan.produkte`, `ImportPlan.produktTypen`, `IstStand.produkte` und `IstStand.produktTypen` (Task 4).
- Produces: `Geschrieben` bekommt zusätzlich `produkte: number` und `produktTypen: number`.

- [ ] **Step 1: Failing tests schreiben**

In `tests/integration/katalog-import.test.ts`:

(a) Import um `mitProdukten` ergänzen: `import { beispielKatalog, mitProdukten, mp4Bytes, pngBytes } from "@fitretro/domain/katalog-testdaten";`

(b) Die zwei bestehenden `toEqual({ uploads: …` (Zeilen 109 und 133) um `, produkte: 0, produktTypen: 0` vor der schließenden Klammer ergänzen.

(c) In `afterAll` als erste Zeile in der `for (const p of praefixe)`-Schleife, direkt nach `const muster = …`:

```ts
    // Produkte zuerst: ihre Typzuordnung haelt den Typ mit restrict.
    await admin.from("catalog_products").delete().like("catalog_key", muster);
```

(d) Neuer Block am Ende:

```ts
describe("Katalogimport Produkte", () => {
  const p = neuerPraefix();
  const beispiel = mitProdukten(beispielKatalog(p), p);

  async function produkt(key: string) {
    const { data, error } = await admin
      .from("catalog_products")
      .select("*, catalog_product_types(equipment_models(catalog_key))")
      .eq("catalog_key", key)
      .single();
    if (error) throw error;
    return data;
  }

  it("legt Produkte mit Typzuordnung an und laedt nur geklaerte Fotos hoch", async () => {
    const { plan, geschrieben } = await importiere(beispiel);
    expect(eigene(plan.produkte, p).map((x) => x.art)).toEqual(["neu", "neu"]);
    expect(geschrieben).toMatchObject({ produkte: 2, produktTypen: 3 });

    const gym80 = await produkt(`${p}gym80_pure_kraft_4345`);
    expect(gym80).toMatchObject({ manufacturer: "gym80", series: "Pure Kraft", model_code: "4345", photo_path: null, photo_rights: "pending", load_unit: null });
    expect(gym80.catalog_product_types.map((l: { equipment_models: { catalog_key: string } }) => l.equipment_models.catalog_key).sort()).toEqual(
      [`${p}brustpresse`, `${p}trizepsmaschine`],
    );

    const precor = await produkt(`${p}precor_trm_885`);
    expect(precor.photo_rights).toBe("cleared");
    expect(Number(precor.load_min)).toBe(0.8);
    expect(await objektDa(`equipment-photos/${precor.photo_path}`)).toBe(true);
  });

  it("aendert beim zweiten Lauf nichts", async () => {
    const { plan, geschrieben } = await importiere(beispiel);
    expect(eigene(plan.produkte, p).map((x) => x.art)).toEqual(["unveraendert", "unveraendert"]);
    expect(eigene(plan.produktTypen, p).every((x) => x.art === "unveraendert")).toBe(true);
    expect(geschrieben).toMatchObject({ uploads: 0, produkte: 0, produktTypen: 0 });
  });

  it("nimmt bei Rechteentzug das Foto weg, das Objekt bleibt", async () => {
    const altesFoto = (await produkt(`${p}precor_trm_885`)).photo_path as string;
    const entzogen = mitProdukten(beispielKatalog(p), p);
    entzogen.roh.products[1]!.photo_rights = "pending";

    const { plan } = await importiere(entzogen);
    expect(plan.gemeldet.entzogeneFotos).toContain(`${p}precor_trm_885: equipment-photos/${altesFoto}`);
    expect((await produkt(`${p}precor_trm_885`)).photo_path).toBeNull();
    expect(await objektDa(`equipment-photos/${altesFoto}`)).toBe(true);
    objekte.add(`equipment-photos/${altesFoto}`);
  });

  it("schreibt im Trockenlauf keine Produkte", async () => {
    const q = neuerPraefix();
    const { plan, geschrieben } = await importiere(mitProdukten(beispielKatalog(q), q), true);
    expect(geschrieben).toBeNull();
    expect(eigene(plan.produkte, q)).toHaveLength(2);
    const { data } = await admin.from("catalog_products").select("id").like("catalog_key", `${q.replaceAll("_", "\\_")}%`);
    expect(data).toEqual([]);
  });
});
```

- [ ] **Step 2: Tests laufen lassen, sie müssen scheitern**

Run: `pnpm test:integration -- katalog-import`
Expected: FAIL. Die alten Fälle scheitern an den fehlenden `produkte`/`produktTypen` in `geschrieben`, die neuen an `geschrieben.produkte` `undefined`.

- [ ] **Step 3: Implementieren**

In `packages/domain/src/katalog-import.ts`:

(a) Importe aus `./katalog-plan.js` um `type IstProdukt, type IstProduktTyp` ergänzen. Den Re-Export `export { pruefeMedien, … } from "./katalog-medien.js";` um `produktFotoPraefix` erweitern.

(b) In `leseIstStand` vor `const objekte = …`:

```ts
  const produkte = await alleZeilen<IstProdukt>((von, bis) =>
    admin
      .from("catalog_products")
      .select("id, catalog_key, manufacturer, series, name, model_code, product_url, note, photo_path, photo_rights, load_unit, load_step, load_min, load_max, secondary_unit, secondary_step, secondary_min, secondary_max")
      .order("id")
      .range(von, bis),
  );
  const produktTypen = await alleZeilen<IstProduktTyp>((von, bis) =>
    admin
      .from("catalog_product_types")
      .select("product_id, equipment_model_id")
      .order("product_id")
      .order("equipment_model_id")
      .range(von, bis),
  );
```

In `objekte` die dritte Quelle ergänzen:

```ts
    ...(await objekteUnter(admin, PHOTO_BUCKET, `${GYMTAVO_STUDIO_ID}/catalog/products`)),
```

und das Ergebnis: `return { geraetetypen, einstellungen, uebungen, verknuepfungen, videos, produkte, produktTypen, objekte };`

Die Fehlermeldung zum fehlenden Studio auf `"Das Gymtavo-Studio fehlt. Zuerst die Migrationen bis 0050 anwenden."` ändern.

(c) `Geschrieben` um `produkte: number; produktTypen: number;` erweitern.

(d) In `fuehreAus` vor `return {`:

```ts
  // Produkte nach den Typen: ihre Zuordnung braucht die Typ-ids.
  const produktIds = new Map(plan.produkte.flatMap((p) => (p.id ? [[p.schluessel, p.id] as const] : [])));
  const produkte = zuSchreiben(plan.produkte);
  for (const block of bloecke(produkte)) {
    const { data, error } = await admin
      .from("catalog_products")
      .upsert(block.map((p) => p.zeile), { onConflict: "catalog_key" })
      .select("id, catalog_key");
    if (error) throw new DomainError("internal", `Produkte: ${error.message}`);
    for (const z of data) produktIds.set(z.catalog_key, z.id);
  }

  const produktTypen = zuSchreiben(plan.produktTypen);
  for (const block of bloecke(produktTypen)) {
    const { error } = await admin.from("catalog_product_types").upsert(
      block.map((p) => ({ product_id: idVon(produktIds, p.zeile.produkt), equipment_model_id: idVon(typIds, p.zeile.geraetetyp) })),
      { onConflict: "product_id,equipment_model_id", ignoreDuplicates: true },
    );
    if (error) throw new DomainError("internal", `Produkt-Typen: ${error.message}`);
  }
```

und im Rückgabeobjekt `produkte: produkte.length, produktTypen: produktTypen.length,` ergänzen.

(e) `scripts/catalog-import.ts`: die Ausgabezeile ergänzen um `, ${geschrieben.produkte} Produkte, ${geschrieben.produktTypen} Produkt-Typen` vor dem abschließenden Punkt.

- [ ] **Step 4: Tests und Typprüfung laufen lassen**

Run: `pnpm --filter @fitretro/domain typecheck && pnpm test:integration -- katalog-import katalog-key`
Expected: PASS. Bestehende und neue Fälle sind grün.

- [ ] **Step 5: Commit**

```bash
git add packages/domain/src/katalog-import.ts scripts/catalog-import.ts tests/integration/katalog-import.test.ts
git commit -m "feat(katalog): Import schreibt Herstellermodelle und ihre Typzuordnung

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log -1 --format=%B
```

---

### Task 6: Domain – Produkte lesen, Herkunft setzen, Foto vom Produkt

**Files:**
- Modify: `packages/domain/src/catalog.ts`
- Modify: `packages/domain/src/typ-vorlage.ts`
- Modify: `packages/domain/src/index.ts`
- Modify: `tests/integration/domain-typ-vorlage.test.ts` (Umbenennung)
- Modify: `apps/web/app/portal/actions.ts`, `apps/web/app/portal/[studioId]/einrichten/actions.ts`, `apps/web/app/portal/[studioId]/einrichten/modell/neu/ModellNeuFormular.tsx` (nur Umbenennung)
- Modify: Testfixtures mit `CatalogType` oder `CatalogModel` (siehe Step 6)
- Create: `tests/integration/domain-katalog-produkte.test.ts`

**Interfaces:**
- Consumes: Tabellen aus Task 1.
- Produces:
  - `export type CatalogProduct = { id: string; key: string; manufacturer: string; series: string | null; name: string; modelCode: string | null; note: string | null; load: { unit: LoadUnit; step: number; min: number; max: number } | null; secondary: { unit: LoadUnit; step: number; min: number; max: number } | null; photoPath: string | null }`.
  - `CatalogType.products: CatalogProduct[]`, sortiert nach Hersteller, Serie und Name.
  - `CatalogModel.catalogProduct: { manufacturer: string; series: string | null; name: string; modelCode: string | null } | null`.
  - `EquipmentModelInput.catalogProductId?: string | null`.
  - `copyCatalogDefaults(client, equipmentModelId): Promise<{ settingsCopied: number; photoCopied: boolean }>` ersetzt `copyTypeDefaults`.

- [ ] **Step 1: Failing test schreiben**

`tests/integration/domain-katalog-produkte.test.ts`:

```ts
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import {
  DomainError,
  PHOTO_BUCKET,
  copyCatalogDefaults,
  createEquipmentModel,
  getStudioCatalog,
  listCatalogTypes,
} from "@fitretro/domain";
import { createTestUser, serviceClient, uniqueEmail, userClient } from "./helpers/clients.js";

// Spec 2026-10-10-gymtavo-katalog-geraeteeinrichtung-design.md, 6.4.
// Geteilte lokale Datenbank: eigene Typen und Produkte mit Praefix, am Ende
// nur eigene Zeilen und Objekte weg -- Studio-Modelle vor Produkten, Produkte
// vor Typen (restrict).
const GYMTAVO = "00000000-0000-4000-8000-000000000001";
const p = `t_${crypto.randomUUID().slice(0, 8)}_`;
const admin = serviceClient();

/** 1x1 PNG, gueltig fuer sniffMediaType und stripPngMetadata. */
const PNG_1X1 = Uint8Array.from(
  Buffer.from("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==", "base64"),
);

const typFoto = `${GYMTAVO}/catalog/photos/${p}typ.png`;
const produktFoto = `${GYMTAVO}/catalog/products/${p}geklaert-00000000.png`;
const eigeneObjekte = [typFoto, produktFoto];

let studioId: string;
let trainer: string;
let typA: string;
let typB: string;
let typOhneFotoDatei: string;
let geklaert: string;
let offen: string;
let fremd: string;

beforeAll(async () => {
  for (const pfad of [typFoto, produktFoto]) {
    const { error } = await admin.storage.from(PHOTO_BUCKET).upload(pfad, new Blob([PNG_1X1], { type: "image/png" }), { contentType: "image/png" });
    if (error) throw error;
  }

  const typen = await admin
    .from("equipment_models")
    .insert([
      { studio_id: GYMTAVO, name: `${p}Brustpresse`, load_step: 1, photo_path: typFoto },
      { studio_id: GYMTAVO, name: `${p}Butterfly`, load_step: 1 },
      // Foto zeigt ins Leere: kopiert copyCatalogDefaults trotzdem ein Foto,
      // kann es nur vom Produkt kommen.
      { studio_id: GYMTAVO, name: `${p}Ruderzug`, load_step: 1, photo_path: `${GYMTAVO}/catalog/photos/${p}gibt_es_nicht.png` },
    ])
    .select("id");
  if (typen.error) throw typen.error;
  [typA, typB, typOhneFotoDatei] = typen.data.map((t) => t.id) as [string, string, string];
  const einstellung = await admin
    .from("equipment_setting_definitions")
    .insert({ equipment_model_id: typA, key: "seat_height", label: "Sitzhöhe", kind: "number", sort_order: 0 });
  if (einstellung.error) throw einstellung.error;

  const produkte = await admin
    .from("catalog_products")
    .insert([
      {
        catalog_key: `${p}geklaert`, manufacturer: "gym80", series: "Pure Kraft", name: "Brustpresse", model_code: "4345",
        note: "Scheibenbeladen.", photo_path: produktFoto, photo_rights: "cleared",
        load_unit: "kg", load_step: 2.5, load_min: 5, load_max: 150,
      },
      { catalog_key: `${p}offen`, manufacturer: "Technogym", name: "Chest Press", photo_rights: "pending" },
      { catalog_key: `${p}fremd`, manufacturer: "gym80", name: "Butterfly" },
    ])
    .select("id");
  if (produkte.error) throw produkte.error;
  [geklaert, offen, fremd] = produkte.data.map((x) => x.id) as [string, string, string];
  const links = await admin.from("catalog_product_types").insert([
    { product_id: geklaert, equipment_model_id: typA },
    { product_id: geklaert, equipment_model_id: typOhneFotoDatei },
    { product_id: offen, equipment_model_id: typA },
    { product_id: offen, equipment_model_id: typB },
    { product_id: fremd, equipment_model_id: typB },
  ]);
  if (links.error) throw links.error;

  const studio = await admin.from("studios").insert({ name: `Produkte ${p}` }).select("id").single();
  if (studio.error) throw studio.error;
  studioId = studio.data.id;
  trainer = uniqueEmail("katalog-produkte");
  const rolle = await admin.from("studio_memberships").insert({ studio_id: studioId, user_id: await createTestUser(trainer), role: "trainer" });
  if (rolle.error) throw rolle.error;
});

afterAll(async () => {
  const modelle = await admin.from("equipment_models").select("photo_path").eq("studio_id", studioId);
  const studioFotos = (modelle.data ?? []).flatMap((m) => (m.photo_path ? [m.photo_path as string] : []));
  await admin.from("equipment_models").delete().eq("studio_id", studioId);
  await admin.from("catalog_products").delete().like("catalog_key", `${p.replaceAll("_", "\\_")}%`);
  await admin.from("equipment_models").delete().in("id", [typA, typB, typOhneFotoDatei]);
  await admin.storage.from(PHOTO_BUCKET).remove([...eigeneObjekte, ...studioFotos]);
});

async function anlegen(werte: { typ: string; produkt?: string; name?: string }) {
  return createEquipmentModel(await userClient(trainer), {
    studioId, name: werte.name ?? "Brustpresse", loadStep: 2.5, catalogModelId: werte.typ, catalogProductId: werte.produkt,
  });
}

describe("listCatalogTypes Produkte", () => {
  it("liefert je Typ seine Produkte, ein Produkt an zwei Typen bei beiden", async () => {
    const typen = await listCatalogTypes(await userClient(trainer));
    const a = typen.find((t) => t.id === typA)!;
    const b = typen.find((t) => t.id === typB)!;
    expect(a.products.map((x) => x.id)).toEqual([geklaert, offen]);
    expect(b.products.map((x) => x.id)).toEqual([fremd, offen]);
    expect(a.products[0]).toEqual({
      id: geklaert, key: `${p}geklaert`, manufacturer: "gym80", series: "Pure Kraft", name: "Brustpresse", modelCode: "4345",
      note: "Scheibenbeladen.", load: { unit: "kg", step: 2.5, min: 5, max: 150 }, secondary: null, photoPath: produktFoto,
    });
    expect(a.products[1]).toMatchObject({ manufacturer: "Technogym", series: null, modelCode: null, load: null, photoPath: null });
  });
});

describe("createEquipmentModel mit Produkt", () => {
  it("merkt sich die Herkunft, der Katalog zeigt sie", async () => {
    const { id } = await anlegen({ typ: typA, produkt: geklaert, name: "Pure Kraft Brustpresse 4345" });
    const katalog = await getStudioCatalog(await userClient(trainer), studioId);
    expect(katalog.models.find((m) => m.id === id)?.catalogProduct).toEqual({
      manufacturer: "gym80", series: "Pure Kraft", name: "Brustpresse", modelCode: "4345",
    });
  });

  it("lehnt ein Produkt ab, das nicht zum Typ passt, unbekannt ist oder ohne Typ kommt", async () => {
    for (const werte of [
      { typ: typA, produkt: fremd },
      { typ: typA, produkt: crypto.randomUUID() },
    ]) {
      await expect(anlegen(werte)).rejects.toMatchObject({ code: "validation_failed", message: "Dieses Herstellermodell passt nicht zum Gymtavo-Typ." });
    }
    const ohneTyp = createEquipmentModel(await userClient(trainer), { studioId, name: "X", loadStep: 2.5, catalogProductId: geklaert });
    await expect(ohneTyp).rejects.toBeInstanceOf(DomainError);
    const { count } = await admin.from("equipment_models").select("id", { count: "exact", head: true }).eq("studio_id", studioId).eq("catalog_product_id", fremd);
    expect(count).toBe(0);
  });
});

describe("copyCatalogDefaults", () => {
  async function fotoPfad(id: string): Promise<string | null> {
    const { data } = await admin.from("equipment_models").select("photo_path").eq("id", id).single();
    return data?.photo_path ?? null;
  }

  it("nimmt das geklaerte Produktfoto vor der Typillustration, als Kopie im Studioordner", async () => {
    const { id } = await anlegen({ typ: typOhneFotoDatei, produkt: geklaert });
    // Das Typfoto fehlt im Bucket -- ein Erfolg kann nur vom Produkt kommen.
    expect(await copyCatalogDefaults(await userClient(trainer), id)).toEqual({ settingsCopied: 0, photoCopied: true });
    expect(await fotoPfad(id)).toMatch(new RegExp(`^${studioId}/`));
  });

  it("nimmt bei offenem Produktfoto die Typillustration, Einstellungen immer vom Typ", async () => {
    const { id } = await anlegen({ typ: typA, produkt: offen });
    expect(await copyCatalogDefaults(await userClient(trainer), id)).toEqual({ settingsCopied: 1, photoCopied: true });
    expect(await fotoPfad(id)).toMatch(new RegExp(`^${studioId}/`));
  });
});
```

- [ ] **Step 2: Test laufen lassen, er muss scheitern**

Run: `pnpm test:integration -- domain-katalog-produkte`
Expected: FAIL. `copyCatalogDefaults` ist kein Export (`is not a function`), und `products` ist `undefined`.

- [ ] **Step 3: `catalog.ts` erweitern**

(a) In `equipmentModelInputSchema` nach `catalogModelId`:

```ts
    /** Herstellermodell (Spec 2026-10-10 ..., 6.4); nur mit passendem Typ. */
    catalogProductId: uuid.nullish(),
```

(b) `zuordnungsFehler` um die Herkunft ergänzen:

```ts
  if (error?.message?.includes("gymtavo_herkunft_ungueltig")) {
    return new DomainError("validation_failed", "Ein Gymtavo-Typ hat kein Herstellermodell als Vorlage.");
  }
```

(c) In `createEquipmentModel` nach `await requireStudioStaff(…)`:

```ts
  if (werte.catalogProductId) {
    await produktPasstZumTyp(client, werte.catalogProductId, werte.catalogModelId ?? null);
  }
```

und im Insert nach `catalog_model_id`: `catalog_product_id: werte.catalogProductId ?? null,`

Vor `createEquipmentModel`:

```ts
const PRODUKT_PASST_NICHT = "Dieses Herstellermodell passt nicht zum Gymtavo-Typ.";

/**
 * Plan-Entscheidung P1: das Produkt muss am gewaehlten Typ haengen. Sonst
 * kaeme bei einem veralteten Formular das Foto eines fremden Geraets ins
 * Modell. Der Trigger aus 0050 prueft das bewusst nicht (spaeterer
 * Typwechsel), deshalb hier und nur beim Anlegen. Ein unbekanntes Produkt
 * hat keine Zuordnung und faellt damit ebenfalls hierher.
 */
async function produktPasstZumTyp(client: SupabaseClient, produktId: string, typId: string | null): Promise<void> {
  if (!typId) throw new DomainError("validation_failed", PRODUKT_PASST_NICHT);
  const { data, error } = await client
    .from("catalog_product_types")
    .select("product_id")
    .eq("product_id", produktId)
    .eq("equipment_model_id", typId)
    .maybeSingle();
  if (error) throw new DomainError("internal", error.message);
  if (!data) throw new DomainError("validation_failed", PRODUKT_PASST_NICHT);
}
```

(d) `CatalogModel` nach `catalogModelId`:

```ts
  /** Herstellermodell, aus dem das Modell entstand -- nur Herkunft (G1). */
  catalogProduct: { manufacturer: string; series: string | null; name: string; modelCode: string | null } | null;
```

In `getStudioCatalog` an die Spaltenliste von `equipment_models` nach `catalog_model_id` anhängen:

```
, catalog_products!equipment_models_catalog_product_id_fkey (manufacturer, series, name, model_code)
```

Den expliziten FK-Namen braucht es, weil `equipment_models` jetzt auf zwei Wegen an `catalog_products` hängt (Herkunft und `catalog_product_types`). `ModelRow` um `catalog_products: { manufacturer: string; series: string | null; name: string; model_code: string | null } | null;` erweitern und im Mapping nach `catalogModelId` ergänzen:

```ts
    catalogProduct: row.catalog_products
      ? {
          manufacturer: row.catalog_products.manufacturer,
          series: row.catalog_products.series,
          name: row.catalog_products.name,
          modelCode: row.catalog_products.model_code,
        }
      : null,
```

(e) Vor `CatalogType`:

```ts
export type CatalogProduct = {
  id: string;
  key: string;
  manufacturer: string;
  series: string | null;
  name: string;
  modelCode: string | null;
  note: string | null;
  /** Ganz oder gar nicht (0050); null heisst: die Werte des Typs gelten. */
  load: { unit: LoadUnit; step: number; min: number; max: number } | null;
  secondary: { unit: LoadUnit; step: number; min: number; max: number } | null;
  /** Nur bei geklaerten Rechten (G3). */
  photoPath: string | null;
};
```

und in `CatalogType` nach `photoPath`: `products: CatalogProduct[];`

(f) In `listCatalogTypes` die Auswahl um

```
,
       catalog_product_types (catalog_products (id, catalog_key, manufacturer, series, name, model_code, note, photo_path, photo_rights, load_unit, load_step, load_min, load_max, secondary_unit, secondary_step, secondary_min, secondary_max))
```

erweitern, nach `instruction_assets (…))`. `Row` bekommt:

```ts
    catalog_product_types: Array<{ catalog_products: ProduktRow }>;
```

mit, auf Modulebene vor `listCatalogTypes`:

```ts
type ProduktRow = {
  id: string;
  catalog_key: string;
  manufacturer: string;
  series: string | null;
  name: string;
  model_code: string | null;
  note: string | null;
  photo_path: string | null;
  photo_rights: "pending" | "cleared";
  load_unit: LoadUnit | null;
  load_step: number | string | null;
  load_min: number | string | null;
  load_max: number | string | null;
  secondary_unit: LoadUnit | null;
  secondary_step: number | string | null;
  secondary_min: number | string | null;
  secondary_max: number | string | null;
};

function raster(
  unit: LoadUnit | null,
  step: number | string | null,
  min: number | string | null,
  max: number | string | null,
): CatalogProduct["load"] {
  return unit === null || step === null || min === null || max === null
    ? null
    : { unit, step: Number(step), min: Number(min), max: Number(max) };
}

function produktAus(row: ProduktRow): CatalogProduct {
  return {
    id: row.id,
    key: row.catalog_key,
    manufacturer: row.manufacturer,
    series: row.series,
    name: row.name,
    modelCode: row.model_code,
    note: row.note,
    load: raster(row.load_unit, row.load_step, row.load_min, row.load_max),
    secondary: raster(row.secondary_unit, row.secondary_step, row.secondary_min, row.secondary_max),
    // Doppelt gesichert: der Check aus 0050 laesst ohnehin kein
    // ungeklaertes Foto mit Pfad zu.
    photoPath: row.photo_rights === "cleared" ? row.photo_path : null,
  };
}

function produktReihenfolge(a: CatalogProduct, b: CatalogProduct): number {
  return (
    a.manufacturer.localeCompare(b.manufacturer, "de") ||
    (a.series ?? "").localeCompare(b.series ?? "", "de") ||
    a.name.localeCompare(b.name, "de")
  );
}
```

Im Mapping nach `photoPath: row.photo_path,`:

```ts
    products: row.catalog_product_types.map((link) => produktAus(link.catalog_products)).sort(produktReihenfolge),
```

- [ ] **Step 4: `copyCatalogDefaults`**

In `packages/domain/src/typ-vorlage.ts`:
- Die Funktion `copyTypeDefaults` in `copyCatalogDefaults` umbenennen.
- Im Kopfkommentar ergänzen: „Das Foto kommt vom Herstellermodell, wenn es eines mit geklärten Rechten gibt, sonst vom Typ (Spec 6.4, G5).“
- Die Modellabfrage auf `.select("studio_id, photo_path, catalog_model_id, catalog_product_id")` mit passendem Typparameter erweitern.

Den Fotoschritt ersetzen durch:

```ts
  const photoCopied = modell.photo_path
    ? false
    : await fotoKopieren(client, await vorlageFoto(client, modell.catalog_model_id, modell.catalog_product_id), equipmentModelId);
```

`fotoKopieren` nimmt statt `typId` den fertigen Pfad:

```ts
/** Produktfoto vor Typillustration (G5). Ein offenes Produktfoto hat keinen Pfad (0050). */
async function vorlageFoto(client: SupabaseClient, typId: string, produktId: string | null): Promise<string | null> {
  if (produktId) {
    const { data: produkt } = await client
      .from("catalog_products")
      .select("photo_path, photo_rights")
      .eq("id", produktId)
      .maybeSingle<{ photo_path: string | null; photo_rights: string }>();
    if (produkt?.photo_path && produkt.photo_rights === "cleared") return produkt.photo_path;
  }
  const { data: typ } = await client
    .from("equipment_models")
    .select("photo_path")
    .eq("id", typId)
    .maybeSingle<{ photo_path: string | null }>();
  return typ?.photo_path ?? null;
}

async function fotoKopieren(client: SupabaseClient, pfad: string | null, modelId: string): Promise<boolean> {
  if (!pfad) return false;
  const { data: datei, error } = await client.storage.from(PHOTO_BUCKET).download(pfad);
  if (error || !datei) {
    throw new DomainError("internal", "Das Vorlagefoto aus dem Gymtavo-Katalog liess sich nicht laden.");
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

- [ ] **Step 5: Umbenennung nachziehen**

Run:

```bash
grep -rl "copyTypeDefaults" packages/domain/src tests apps/web/app | xargs sed -i '' 's/copyTypeDefaults/copyCatalogDefaults/g'
grep -rn "copyTypeDefaults" packages tests apps/web/app e2e
```

Expected: keine Treffer mehr. `index.ts` exportiert `copyCatalogDefaults`. Zusätzlich `export type CatalogProduct` in `index.ts` ergänzen, wo `CatalogType` exportiert wird.

- [ ] **Step 6: Fixtures nachziehen und Typprüfung**

Run: `pnpm typecheck`
Expected: Fehler nur in Testfixtures, denen `products` (bei `CatalogType`) oder `catalogProduct` (bei `CatalogModel`) fehlt. Bekannte Kandidaten:
- `apps/web/app/portal/[studioId]/(schreibtisch)/geraete/[modelId]/uebungen/gymtavo.test.ts`
- `apps/web/app/portal/[studioId]/offen.test.ts`
- `apps/web/app/portal/gymtavoTyp.test.ts`

Jedem gemeldeten Objekt `products: []` bzw. `catalogProduct: null` hinzufügen und neu prüfen, bis `pnpm typecheck` grün ist.

- [ ] **Step 7: Tests laufen lassen**

Run: `pnpm test:integration -- domain-katalog-produkte domain-typ-vorlage domain-catalog && pnpm test`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add packages/domain/src tests/integration/domain-katalog-produkte.test.ts tests/integration/domain-typ-vorlage.test.ts apps/web/app
git commit -m "feat(katalog): Typliste mit Herstellermodellen, Anlegen mit Herkunft, Foto vom Produkt vor Typ

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log -1 --format=%B
```

---

### Task 7: Portal-Hilfen für Hersteller und Modell (rein)

**Files:**
- Modify: `apps/web/app/portal/bausteine/typVorlage.ts`
- Create: `apps/web/app/portal/bausteine/herstellerWahl.ts`
- Test: `apps/web/app/portal/bausteine/typVorlage.test.ts`, `apps/web/app/portal/bausteine/herstellerWahl.test.ts` (neu)

**Interfaces:**
- Consumes: `CatalogType.products`, `CatalogProduct` (Task 6).
- Produces:
  - `ProduktVorlage = Pick<CatalogProduct, "id" | "manufacturer" | "series" | "name" | "modelCode" | "note" | "load" | "secondary"> & { fotoUrl: string | null }`.
  - `TypVorlage` bekommt zusätzlich `fotoUrl: string | null` und `produkte: ProduktVorlage[]`.
  - `typVorlagen(typen, kategorie?, fotoUrls: Record<string, string> = {})`.
  - In `herstellerWahl.ts`:
    - `ANDERER_HERSTELLER = "__anderer"`
    - `herstellerOptionen(typ): AuswahlOption[]`
    - `produkteVon(typ, hersteller): ProduktVorlage[]`
    - `produktName(p): string`
    - `vorlageText(p): string`
    - `vorlageStart(typ, produkt | null): ModellBelastungStart`
    - `nameNachVorschlag(aktuell, voriger: string | null, neuer: string | null): string`
  - `nameNachTypwahl` entfällt und wird durch `nameNachVorschlag` ersetzt.

- [ ] **Step 1: Failing tests schreiben**

`apps/web/app/portal/bausteine/herstellerWahl.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import {
  ANDERER_HERSTELLER,
  herstellerOptionen,
  nameNachVorschlag,
  produkteVon,
  produktName,
  vorlageStart,
  vorlageText,
} from "./herstellerWahl";
import type { ProduktVorlage, TypVorlage } from "./typVorlage";

function produkt(werte: Partial<ProduktVorlage> & Pick<ProduktVorlage, "id" | "manufacturer" | "name">): ProduktVorlage {
  return { series: null, modelCode: null, note: null, load: null, secondary: null, fotoUrl: null, ...werte };
}

const typ: TypVorlage = {
  id: "t1", name: "Brustpresse", manufacturer: null, category: "kraft",
  loadUnit: "kg", loadStep: 1.25, loadMin: 0, loadMax: null,
  secondaryUnit: null, secondaryStep: null, secondaryMin: null, secondaryMax: null,
  hatFoto: true, fotoUrl: "https://bild/typ",
  produkte: [
    produkt({ id: "p1", manufacturer: "gym80", series: "Pure Kraft", name: "Brustpresse", modelCode: "4345" }),
    produkt({ id: "p2", manufacturer: "gym80", series: "Sygnum", name: "Chest Press", load: { unit: "kg", step: 5, min: 5, max: 150 } }),
    produkt({ id: "p3", manufacturer: "Life Fitness", series: "Insignia", name: "Chest Press", modelCode: "SS-CP" }),
  ],
};

describe("herstellerOptionen", () => {
  it("nennt jeden Hersteller einmal mit Anzahl, dazu Anderer Hersteller", () => {
    expect(herstellerOptionen(typ)).toEqual([
      { wert: "gym80", anzeige: "gym80 (2)" },
      { wert: "Life Fitness", anzeige: "Life Fitness (1)" },
      { wert: ANDERER_HERSTELLER, anzeige: "Anderer Hersteller" },
    ]);
  });
});

describe("produkteVon", () => {
  it("liefert nur die Produkte des Herstellers", () => {
    expect(produkteVon(typ, "gym80").map((x) => x.id)).toEqual(["p1", "p2"]);
    expect(produkteVon(typ, ANDERER_HERSTELLER)).toEqual([]);
  });
});

describe("produktName und vorlageText", () => {
  it("setzt Serie, Name und Code ohne leere Teile zusammen", () => {
    expect(produktName(typ.produkte[0]!)).toBe("Pure Kraft Brustpresse 4345");
    expect(produktName(typ.produkte[1]!)).toBe("Sygnum Chest Press");
    expect(produktName(produkt({ id: "x", manufacturer: "Assault", name: "AirBike" }))).toBe("AirBike");
  });

  it("nennt die Vorlage mit Hersteller", () => {
    expect(vorlageText({ manufacturer: "gym80", series: "Pure Kraft", name: "Brustpresse", modelCode: "4345" })).toBe(
      "Vorlage: gym80 Pure Kraft Brustpresse 4345",
    );
    expect(vorlageText({ manufacturer: "Assault", series: null, name: "AirBike", modelCode: null })).toBe("Vorlage: Assault AirBike");
  });
});

describe("vorlageStart", () => {
  it("nimmt die Belastung vom Produkt, wenn bekannt, sonst vom Typ", () => {
    expect(vorlageStart(typ, typ.produkte[1]!)).toMatchObject({ category: "kraft", loadUnit: "kg", loadStep: 5, loadMin: 5, loadMax: 150 });
    expect(vorlageStart(typ, typ.produkte[0]!)).toMatchObject({ loadStep: 1.25, loadMin: 0, loadMax: null });
    expect(vorlageStart(typ, null)).toMatchObject({ loadStep: 1.25 });
  });

  it("nimmt die Nebenbelastung vom Produkt nur zusammen mit dessen Belastung", () => {
    const cardio = produkt({
      id: "c", manufacturer: "Precor", name: "Laufband",
      load: { unit: "kmh", step: 0.1, min: 0.8, max: 25 }, secondary: { unit: "pct", step: 0.5, min: 0, max: 15 },
    });
    expect(vorlageStart({ ...typ, category: "cardio" }, cardio)).toMatchObject({
      loadUnit: "kmh", loadMin: 0.8, secondaryUnit: "pct", secondaryStep: 0.5, secondaryMin: 0, secondaryMax: 15,
    });
  });
});

describe("nameNachVorschlag", () => {
  it("uebernimmt den Vorschlag bei leerem oder unveraendert vorgeschlagenem Namen", () => {
    expect(nameNachVorschlag("", null, "Brustpresse")).toBe("Brustpresse");
    expect(nameNachVorschlag("Brustpresse", "Brustpresse", "Pure Kraft Brustpresse 4345")).toBe("Pure Kraft Brustpresse 4345");
  });

  it("laesst einen selbst getippten Namen stehen", () => {
    expect(nameNachVorschlag("Presse links", "Brustpresse", "Pure Kraft Brustpresse 4345")).toBe("Presse links");
    expect(nameNachVorschlag("Presse links", null, null)).toBe("Presse links");
  });
});
```

In `typVorlage.test.ts`:
- Jeden Test zu `nameNachTypwahl` entfernen; `nameNachVorschlag` deckt ihn ab.
- Den Test zu `typVorlagen` erweitern. Der `CatalogType`-Fixture bekommt `products: [{ id: "p1", key: "k", manufacturer: "gym80", series: null, name: "Brustpresse", modelCode: null, note: null, load: null, secondary: null, photoPath: "gymtavo/p1.png" }]`, der Typ selbst `photoPath: "gymtavo/t1.png"`. Dazu kommt diese Prüfung:

```ts
  it("haengt signierte Bild-URLs an Typ und Produkt, ohne Pfade herauszugeben", () => {
    const [vorlage] = typVorlagen([typMitProdukt], undefined, { "gymtavo/t1.png": "https://bild/t1", "gymtavo/p1.png": "https://bild/p1" });
    expect(vorlage).toMatchObject({ hatFoto: true, fotoUrl: "https://bild/t1" });
    expect(vorlage!.produkte).toEqual([
      { id: "p1", manufacturer: "gym80", series: null, name: "Brustpresse", modelCode: null, note: null, load: null, secondary: null, fotoUrl: "https://bild/p1" },
    ]);
    expect(JSON.stringify(vorlage)).not.toContain("gymtavo/");
  });
```

`typMitProdukt` ist der so erweiterte Fixture. Gibt es in der Datei schon einen `CatalogType`-Fixture, wird dieser erweitert, statt einen zweiten anzulegen.

- [ ] **Step 2: Tests laufen lassen, sie müssen scheitern**

Run: `pnpm --filter @fitretro/web test -- herstellerWahl typVorlage`
Expected: FAIL. `./herstellerWahl` existiert nicht.

- [ ] **Step 3: `typVorlage.ts` erweitern**

- `nameNachTypwahl` samt Kommentar löschen.
- Den Import `import type { CatalogProduct, CatalogType } from "@fitretro/domain";` ergänzen.
- Vor `TypVorlage` einfügen:

```ts
/** Ein Herstellermodell, wie das Formular es braucht -- Bild als URL, nie als Pfad. */
export type ProduktVorlage = Pick<
  CatalogProduct,
  "id" | "manufacturer" | "series" | "name" | "modelCode" | "note" | "load" | "secondary"
> & { fotoUrl: string | null };
```

In `TypVorlage` nach `hatFoto` ergänzen:

```ts
  /** Signiert auf dem Server (ladeTypVorlagen); Symbolbild der Modellkarten. */
  fotoUrl: string | null;
  produkte: ProduktVorlage[];
```

`typVorlagen`:

```ts
export function typVorlagen(
  typen: CatalogType[],
  kategorie?: Category,
  fotoUrls: Record<string, string> = {},
): TypVorlage[] {
  const url = (pfad: string | null) => (pfad ? (fotoUrls[pfad] ?? null) : null);
  return typen
    .filter((typ) => kategorie === undefined || typ.category === kategorie)
    .map((typ) => ({
      // ... bisherige Felder unveraendert ...
      hatFoto: typ.photoPath !== null,
      fotoUrl: url(typ.photoPath),
      produkte: typ.products.map((p) => ({
        id: p.id,
        manufacturer: p.manufacturer,
        series: p.series,
        name: p.name,
        modelCode: p.modelCode,
        note: p.note,
        load: p.load,
        secondary: p.secondary,
        fotoUrl: url(p.photoPath),
      })),
    }));
}
```

(„bisherige Felder unveraendert“ heißt: `id` bis `secondaryMax` wie heute ausschreiben.)

- [ ] **Step 4: `herstellerWahl.ts` schreiben**

```ts
import type { AuswahlOption } from "./Auswahl";
import type { ModellBelastungStart } from "./ModellBelastungRad";
import { belastungStart, type ProduktVorlage, type TypVorlage } from "./typVorlage";

/**
 * Hersteller- und Modellwahl der Modellformulare (Spec
 * 2026-10-10-gymtavo-katalog-geraeteeinrichtung-design.md, 6.5) als reine
 * Funktionen -- ohne Browser pruefbar, die Komponente verdrahtet nur.
 */

/** Kein echter Herstellername: Hersteller kommen aus der Datei und beginnen nie mit "__". */
export const ANDERER_HERSTELLER = "__anderer";

export function herstellerOptionen(typ: TypVorlage): AuswahlOption[] {
  const anzahl = new Map<string, number>();
  for (const p of typ.produkte) anzahl.set(p.manufacturer, (anzahl.get(p.manufacturer) ?? 0) + 1);
  return [
    ...[...anzahl]
      .sort(([a], [b]) => a.localeCompare(b, "de"))
      .map(([name, n]) => ({ wert: name, anzeige: `${name} (${n})` })),
    { wert: ANDERER_HERSTELLER, anzeige: "Anderer Hersteller" },
  ];
}

/** Die Reihenfolge kommt sortiert aus listCatalogTypes. */
export function produkteVon(typ: TypVorlage, hersteller: string): ProduktVorlage[] {
  return typ.produkte.filter((p) => p.manufacturer === hersteller);
}

function teile(...werte: (string | null)[]): string {
  return werte.filter((w): w is string => w !== null && w.trim().length > 0).join(" ");
}

/** "Pure Kraft Brustpresse 4345" -- der Hersteller steht im eigenen Feld. */
export function produktName(p: Pick<ProduktVorlage, "series" | "name" | "modelCode">): string {
  return teile(p.series, p.name, p.modelCode);
}

export function vorlageText(p: { manufacturer: string; series: string | null; name: string; modelCode: string | null }): string {
  return `Vorlage: ${teile(p.manufacturer, p.series, p.name, p.modelCode)}`;
}

/**
 * Produkt vor Typ (G4), aber nur als Ganzes: ein Produkt ohne Raster laesst
 * die Typwerte stehen. Die Kategorie kommt immer vom Typ -- das Produkt hat
 * keine.
 */
export function vorlageStart(typ: TypVorlage, produkt: ProduktVorlage | null): ModellBelastungStart {
  const start = belastungStart(typ);
  if (!produkt?.load) return start;
  return {
    ...start,
    loadUnit: produkt.load.unit,
    loadStep: produkt.load.step,
    loadMin: produkt.load.min,
    loadMax: produkt.load.max,
    secondaryUnit: produkt.secondary?.unit ?? null,
    secondaryStep: produkt.secondary?.step ?? null,
    secondaryMin: produkt.secondary?.min ?? null,
    secondaryMax: produkt.secondary?.max ?? null,
  };
}

/**
 * Ein Vorschlag (Typname, Produktname) ersetzt nur, was selbst ein
 * Vorschlag war oder leer ist -- was der Trainer getippt hat, bleibt.
 */
export function nameNachVorschlag(aktuell: string, voriger: string | null, neuer: string | null): string {
  if (neuer === null) return aktuell;
  const leer = aktuell.trim().length === 0;
  return leer || aktuell === voriger ? neuer : aktuell;
}
```

- [ ] **Step 5: Tests laufen lassen, sie müssen grün sein**

Run: `pnpm --filter @fitretro/web test -- herstellerWahl typVorlage`
Expected: PASS. `pnpm typecheck` darf noch in `ModellVorlageFelder.tsx` (Import von `nameNachTypwahl`) und in den Fixtures von `ModellVorlageFelder.test.tsx` (fehlende `fotoUrl`/`produkte`) scheitern; das behebt Task 8.

- [ ] **Step 6: Commit**

```bash
git add apps/web/app/portal/bausteine/typVorlage.ts apps/web/app/portal/bausteine/typVorlage.test.ts apps/web/app/portal/bausteine/herstellerWahl.ts apps/web/app/portal/bausteine/herstellerWahl.test.ts
git commit -m "feat(katalog): Herstellerliste, Modellname und Startwerte aus dem Herstellermodell

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log -1 --format=%B
```

---

### Task 8: `ModellVorlageFelder` – Typ → Hersteller → Modell

**Files:**
- Modify: `apps/web/app/portal/bausteine/ModellVorlageFelder.tsx`
- Create: `apps/web/app/portal/bausteine/ModellVorlageFelder.module.css`
- Test: `apps/web/app/portal/bausteine/ModellVorlageFelder.test.tsx`

**Interfaces:**
- Consumes: alles aus Task 7.
- Produces:
  - `ModellVorlageFelder({ typen, gross?, kategorie?, onVorlage? })` mit `onVorlage?: (wahl: VorlageWahl) => void`. Das ersetzt `onTyp`.
  - `export type VorlageWahl = { typ: TypVorlage | null; produkt: ProduktVorlage | null }`.
  - Formularfelder: `name`, `manufacturer` (Textfeld oder verstecktes Feld), `catalogModelId` (aus `GymtavoTypFeld`), `catalogProductId` (versteckt, nur bei gewähltem Produkt) und die Felder des Belastungsrads.

- [ ] **Step 1: Failing tests schreiben**

In `ModellVorlageFelder.test.tsx`:

(a) Den Fixtures `brust` und `laufband` jeweils `fotoUrl: null, produkte: []` geben. `platzhalter` erbt das per Spread.

(b) Den Test „meldet den gewaehlten Typ nach aussen“ ersetzen durch die Prop `onVorlage` und `expect(onVorlage).toHaveBeenLastCalledWith({ typ: brust, produkt: null })`.

(c) Neue Fixtures und Tests:

```ts
const gym80: TypVorlage["produkte"][number] = {
  id: "p1", manufacturer: "gym80", series: "Pure Kraft", name: "Brustpresse", modelCode: "4345",
  note: "Scheibenbeladen, eigenes Lastprofil.", load: { unit: "kg", step: 2.5, min: 5, max: 150 }, secondary: null, fotoUrl: null,
};
const mitProdukten: TypVorlage = {
  ...brust, id: "t4", name: "Brustpresse Pro", fotoUrl: "https://bild/typ",
  produkte: [gym80, { ...gym80, id: "p2", manufacturer: "Technogym", series: null, name: "Chest Press", modelCode: null, note: null, load: null }],
};

async function herstellerWaehlen(anzeige: string) {
  fireEvent.click(screen.getByRole("button", { name: "Hersteller" }));
  fireEvent.click(await screen.findByRole("option", { name: anzeige }));
}

describe("ModellVorlageFelder Herstellermodelle", () => {
  it("ohne Produkte am Typ bleibt der Hersteller ein Textfeld", async () => {
    render(<ModellVorlageFelder typen={[brust]} kategorie="kraft" />);
    await typWaehlen("Brustpresse");
    expect(screen.getByLabelText("Hersteller").tagName).toBe("INPUT");
  });

  it("Modell gewaehlt: Name, Hersteller, Belastung, Hinweis und Herkunft kommen vom Produkt", async () => {
    render(<ModellVorlageFelder typen={[mitProdukten]} kategorie="kraft" />);
    await typWaehlen("Brustpresse Pro");
    await herstellerWaehlen("gym80 (1)");
    fireEvent.click(screen.getByRole("radio", { name: /Pure Kraft Brustpresse 4345/ }));

    expect(feldwert("name")).toBe("Pure Kraft Brustpresse 4345");
    expect(feldwert("manufacturer")).toBe("gym80");
    expect(feldwert("catalogProductId")).toBe("p1");
    expect(feldwert("loadStep")).toBe("2,5");
    expect(feldwert("loadMin")).toBe("5");
    expect(feldwert("loadMax")).toBe("150");
    expect(screen.getByText("Scheibenbeladen, eigenes Lastprofil.")).toBeTruthy();
    // Ohne eigenes Produktfoto zeigt die Karte die Typzeichnung als Symbolbild.
    expect(screen.getByRole("radio", { name: /Symbolbild/ })).toBeTruthy();
  });

  it("Mein Modell ist nicht dabei: Typwerte bleiben, Hersteller gesetzt, keine Herkunft", async () => {
    render(<ModellVorlageFelder typen={[mitProdukten]} kategorie="kraft" />);
    await typWaehlen("Brustpresse Pro");
    await herstellerWaehlen("gym80 (1)");
    fireEvent.click(screen.getByRole("radio", { name: /Pure Kraft Brustpresse 4345/ }));
    fireEvent.click(screen.getByRole("radio", { name: "Mein Modell ist nicht dabei" }));

    expect(feldwert("name")).toBe("Brustpresse Pro");
    expect(feldwert("manufacturer")).toBe("gym80");
    expect(feldwert("catalogProductId")).toBeNull();
    expect(feldwert("loadStep")).toBe("5");
  });

  it("Anderer Hersteller oeffnet das Textfeld", async () => {
    render(<ModellVorlageFelder typen={[mitProdukten]} kategorie="kraft" />);
    await typWaehlen("Brustpresse Pro");
    await herstellerWaehlen("Anderer Hersteller");
    fireEvent.change(screen.getByLabelText("Herstellername"), { target: { value: "Eigenbau" } });
    expect(feldwert("manufacturer")).toBe("Eigenbau");
    expect(screen.queryByRole("radio")).toBeNull();
  });

  it("Review Focus 1: ein Typwechsel setzt Hersteller und Modell zurueck", async () => {
    const onVorlage = vi.fn();
    render(<ModellVorlageFelder typen={[mitProdukten, brust]} kategorie="kraft" onVorlage={onVorlage} />);
    await typWaehlen("Brustpresse Pro");
    await herstellerWaehlen("gym80 (1)");
    fireEvent.click(screen.getByRole("radio", { name: /Pure Kraft Brustpresse 4345/ }));
    await typWaehlen("Brustpresse");

    expect(feldwert("catalogProductId")).toBeNull();
    expect(feldwert("name")).toBe("Brustpresse");
    expect(feldwert("loadStep")).toBe("5");
    expect(feldwert("loadMax")).toBe("100");
    expect(screen.getByLabelText("Hersteller").tagName).toBe("INPUT");
    expect(onVorlage).toHaveBeenLastCalledWith({ typ: brust, produkt: null });
  });
});
```

`feldwert` liest `input[name=…]`, also auch versteckte Felder. Bei zwei Feldern gleichen Namens nimmt `querySelector` das erste. Die Komponente rendert deshalb nie zwei `manufacturer`-Felder gleichzeitig.

- [ ] **Step 2: Tests laufen lassen, sie müssen scheitern**

Run: `pnpm --filter @fitretro/web test -- ModellVorlageFelder`
Expected: FAIL. Der Knopf „Hersteller“ fehlt, die Radios fehlen, `onVorlage` wird nicht aufgerufen.

- [ ] **Step 3: CSS schreiben**

`apps/web/app/portal/bausteine/ModellVorlageFelder.module.css`:

```css
/* Modellkarten der Herstellerwahl (Spec 2026-10-10 ..., 6.5): Bild oben,
   Name darunter, die ganze Karte ist die Klickflaeche des Radios. */
.karten {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
  gap: 12px;
  margin: 0;
  padding: 0;
  border: 0;
}

.karte {
  display: grid;
  gap: 6px;
  padding: 8px;
  border: 1px solid var(--line);
  border-radius: var(--r-card);
  cursor: pointer;
}

.karte:has(input:checked) {
  border-color: var(--accent);
  box-shadow: 0 0 0 1px var(--accent);
}

.karte input {
  position: absolute;
  opacity: 0;
  pointer-events: none;
}

.karte:has(input:focus-visible) {
  outline: 2px solid var(--accent);
  outline-offset: 2px;
}

.bild {
  width: 100%;
  aspect-ratio: 4 / 3;
  object-fit: contain;
  border-radius: var(--r-control);
  background: var(--well);
}

.symbol {
  font-size: 12px;
  color: var(--text-muted);
}

.titel {
  font-weight: 600;
}
```

Die Variablen (`--line`, `--accent`, `--well`, `--text-muted`, `--r-card`, `--r-control`) sind dieselben wie in `portal.module.css`.

- [ ] **Step 4: Komponente umbauen**

`apps/web/app/portal/bausteine/ModellVorlageFelder.tsx` vollständig:

```tsx
"use client";

import { useId, useState } from "react";
import type { Category } from "@fitretro/domain/belastung";
import { Feld } from "../Form";
import { Auswahl } from "./Auswahl";
import { GymtavoTypFeld } from "./GymtavoTypFeld";
import { ModellBelastungRad } from "./ModellBelastungRad";
import {
  ANDERER_HERSTELLER,
  herstellerOptionen,
  nameNachVorschlag,
  produkteVon,
  produktName,
  vorlageStart,
} from "./herstellerWahl";
import type { ProduktVorlage, TypVorlage } from "./typVorlage";
import styles from "../portal.module.css";
import wahl from "./ModellVorlageFelder.module.css";

export type VorlageWahl = { typ: TypVorlage | null; produkt: ProduktVorlage | null };

/**
 * Gymtavo-Typ, Hersteller, Herstellermodell, Name und Belastung beider
 * Modellformulare (Schreibtisch und Halle). Reihenfolge wie der Gedanke am
 * Geraet: was ist es, von wem, welches genau (Spec
 * 2026-10-10-gymtavo-katalog-geraeteeinrichtung-design.md, 5.2 und 6.5).
 *
 * Name und Belastung sind Vorschlaege: ein Typ- oder Produktwechsel ersetzt
 * nur, was selbst vorgeschlagen war (nameNachVorschlag). Das Rad bekommt
 * Typ und Produkt als `key` -- nur ein Neuaufbau laedt seine Startwerte neu
 * (Kopfkommentar ModellBelastungRad).
 *
 * Es gibt nie zwei Felder "manufacturer": React 19 schickt sonst beide,
 * und die Action liest das erste.
 */
export function ModellVorlageFelder({
  typen,
  gross = false,
  kategorie,
  onVorlage,
}: {
  typen: TypVorlage[];
  gross?: boolean;
  /** Vorher gefragt (geraete/neu); fehlt in der Halle. */
  kategorie?: Category;
  /** Die Halle macht davon die Fotopflicht abhaengig. */
  onVorlage?: (wahl: VorlageWahl) => void;
}) {
  const [typ, setTyp] = useState<TypVorlage | null>(null);
  const [hersteller, setHersteller] = useState("");
  const [produkt, setProdukt] = useState<ProduktVorlage | null>(null);
  const [nichtDabei, setNichtDabei] = useState(false);
  const [name, setName] = useState("");
  const [vorschlag, setVorschlag] = useState<string | null>(null);
  const herstellerId = useId();

  function vorschlagen(neu: string | null) {
    setName((aktuell) => nameNachVorschlag(aktuell, vorschlag, neu));
    setVorschlag(neu);
  }

  function typGewaehlt(typId: string) {
    const neu = typen.find((t) => t.id === typId) ?? null;
    setTyp(neu);
    setHersteller("");
    setProdukt(null);
    setNichtDabei(false);
    vorschlagen(neu?.name ?? null);
    onVorlage?.({ typ: neu, produkt: null });
  }

  function produktGewaehlt(neu: ProduktVorlage | null) {
    setProdukt(neu);
    setNichtDabei(neu === null);
    vorschlagen(neu ? produktName(neu) : (typ?.name ?? null));
    onVorlage?.({ typ, produkt: neu });
  }

  // Ein neuer Hersteller verwirft das Modell des alten, aber nicht den
  // Typ: Name und Rad fallen auf die Typwerte zurueck.
  function herstellerGewaehlt(wert: string) {
    setHersteller(wert);
    setNichtDabei(false);
    if (produkt) {
      setProdukt(null);
      vorschlagen(typ?.name ?? null);
      onVorlage?.({ typ, produkt: null });
    }
  }

  const mitAuswahl = typ !== null && typ.produkte.length > 0;
  const anderer = hersteller === ANDERER_HERSTELLER;
  const modelle = mitAuswahl && hersteller !== "" && !anderer ? produkteVon(typ, hersteller) : [];

  return (
    <>
      <GymtavoTypFeld gross={gross} typen={typen} start={null} onChange={typGewaehlt} />
      {typ ? (
        <p className={styles.hint} role="status">
          {`Werte vom Typ ${typ.name} übernommen – bitte ans Gerät anpassen.`}
        </p>
      ) : null}

      {mitAuswahl ? (
        <div className={styles.field}>
          <label className={styles.label} htmlFor={herstellerId}>
            Hersteller
          </label>
          <Auswahl
            id={herstellerId}
            value={hersteller}
            onChange={herstellerGewaehlt}
            optionen={herstellerOptionen(typ)}
            platzhalter="Hersteller wählen"
            suche="Hersteller suchen"
            gross={gross}
          />
          {hersteller !== "" && !anderer ? <input type="hidden" name="manufacturer" value={hersteller} /> : null}
        </div>
      ) : (
        <Feld gross={gross} name="manufacturer" label="Hersteller" placeholder="Technogym" />
      )}
      {mitAuswahl && anderer ? (
        <Feld gross={gross} name="manufacturer" label="Herstellername" placeholder="Eigenbau" />
      ) : null}

      {modelle.length > 0 ? (
        <fieldset className={wahl.karten}>
          <legend className={styles.label}>Modell</legend>
          {modelle.map((p) => (
            <label key={p.id} className={wahl.karte}>
              <input
                type="radio"
                name="produktWahl"
                value={p.id}
                checked={produkt?.id === p.id}
                onChange={() => produktGewaehlt(p)}
              />
              {p.fotoUrl ?? typ?.fotoUrl ? (
                // Dekorativ (alt=""): der Name steht darunter und benennt das Radio.
                <img className={wahl.bild} src={p.fotoUrl ?? typ?.fotoUrl ?? ""} alt="" />
              ) : null}
              <span className={wahl.titel}>{produktName(p)}</span>
              {!p.fotoUrl && typ?.fotoUrl ? <span className={wahl.symbol}>Symbolbild</span> : null}
            </label>
          ))}
          <label className={wahl.karte}>
            <input
              type="radio"
              name="produktWahl"
              value=""
              checked={nichtDabei}
              onChange={() => produktGewaehlt(null)}
            />
            <span className={wahl.titel}>Mein Modell ist nicht dabei</span>
          </label>
        </fieldset>
      ) : null}
      {produkt ? <input type="hidden" name="catalogProductId" value={produkt.id} /> : null}

      <Feld
        gross={gross}
        name="name"
        label="Name"
        required
        placeholder="Latzug"
        value={name}
        onChange={(e) => setName(e.target.value)}
      />
      {produkt?.note ? <p className={styles.hint}>{produkt.note}</p> : null}
      <ModellBelastungRad
        key={`${typ?.id ?? "ohne-typ"}:${produkt?.id ?? ""}`}
        gross={gross}
        {...(kategorie ? { kategorie } : {})}
        {...(typ ? { start: vorlageStart(typ, produkt) } : {})}
      />
    </>
  );
}
```

- [ ] **Step 5: Tests laufen lassen, sie müssen grün sein**

Run: `pnpm --filter @fitretro/web test -- ModellVorlageFelder herstellerWahl typVorlage`
Expected: PASS. Die Tests aus Etappe A bleiben grün: Vorbefüllen, Typwechsel, getippter Name, Halle mit Kategorie.

- [ ] **Step 6: Commit**

```bash
git add apps/web/app/portal/bausteine/ModellVorlageFelder.tsx apps/web/app/portal/bausteine/ModellVorlageFelder.module.css apps/web/app/portal/bausteine/ModellVorlageFelder.test.tsx
git commit -m "feat(katalog): Modellformular fragt nach dem Typ Hersteller und Herstellermodell

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log -1 --format=%B
```

---

### Task 9: Verdrahtung in Schreibtisch und Halle, Zeile „Vorlage“, Abnahme

**Files:**
- Modify: `apps/web/app/portal/[studioId]/catalog.ts`
- Modify: `apps/web/app/portal/[studioId]/(schreibtisch)/geraete/neu/page.tsx`
- Modify: `apps/web/app/portal/actions.ts` (`modellAnlegen`)
- Modify: `apps/web/app/portal/[studioId]/(schreibtisch)/geraete/[modelId]/StammdatenFormular.tsx`
- Modify: `apps/web/app/portal/[studioId]/einrichten/modell/neu/page.tsx`, `…/ModellNeuFormular.tsx`
- Modify: `apps/web/app/portal/[studioId]/einrichten/actions.ts` (`modellAnlegen`, `typHatFoto` → `vorlageHatFoto`)
- Modify: `e2e/helpers/gymtavo.ts`, `e2e/gymtavo.spec.ts`, `e2e/einrichten.spec.ts`

**Interfaces:**
- Consumes:
  - `ModellVorlageFelder` mit `onVorlage` und `VorlageWahl` (Task 8).
  - `typVorlagen(typen, kategorie, fotoUrls)` und `vorlageText` (Task 7).
  - `CatalogModel.catalogProduct` und `createEquipmentModel({ catalogProductId })` (Task 6).
- Produces:
  - `ladeTypVorlagen(kategorie?: Category): Promise<TypVorlage[]>` (React `cache`).
  - E2E-Helfer `herstellerProdukt(admin, typId, werte?)` liefert `{ produktId, key }`.

- [ ] **Step 1: Failing E2E-Tests schreiben**

(a) `e2e/helpers/gymtavo.ts` am Ende:

```ts
/**
 * Ein Herstellermodell an genau diesem Typ (Spec 2026-10-10 ..., 6.5). Der
 * Typ ist je Test eigen, also auch die Herstellerliste -- "gym80 (1)"
 * bleibt eindeutig, egal was der geteilte Katalog sonst traegt.
 */
export async function herstellerProdukt(
  admin: SupabaseClient,
  typId: string,
  werte: { manufacturer?: string; series?: string | null; name?: string; model_code?: string | null; note?: string | null; foto?: boolean } = {},
): Promise<{ produktId: string; key: string }> {
  const key = `e2e_${crypto.randomUUID().replaceAll("-", "").slice(0, 12)}`;
  let photo_path: string | null = null;
  if (werte.foto) {
    photo_path = `${GYMTAVO}/catalog/products/${key}-00000000.png`;
    const png = Buffer.from(
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==",
      "base64",
    );
    const { error } = await admin.storage.from("equipment-photos").upload(photo_path, png, { contentType: "image/png" });
    if (error) throw error;
  }
  const { data, error } = await admin
    .from("catalog_products")
    .insert({
      catalog_key: key,
      manufacturer: werte.manufacturer ?? "gym80",
      series: werte.series === undefined ? "Pure Kraft" : werte.series,
      name: werte.name ?? "Brustpresse",
      model_code: werte.model_code === undefined ? "4345" : werte.model_code,
      note: werte.note ?? null,
      photo_path,
      photo_rights: photo_path ? "cleared" : "pending",
    })
    .select("id")
    .single();
  if (error) throw error;
  const link = await admin.from("catalog_product_types").insert({ product_id: data.id, equipment_model_id: typId });
  if (link.error) throw link.error;
  return { produktId: data.id, key };
}

/** Hersteller ueber die Suche waehlen, wie typWaehlen. */
export async function herstellerWaehlen(page: Page, anzeige: string): Promise<void> {
  await page.getByRole("button", { name: "Hersteller", exact: true }).click();
  await page.getByRole("option", { name: anzeige, exact: true }).click();
}
```

(b) In `e2e/gymtavo.spec.ts` den Import um `herstellerProdukt, herstellerWaehlen` ergänzen und anfügen:

```ts
// Spec 2026-10-10-gymtavo-katalog-geraeteeinrichtung-design.md, 6.5 und 6.6.

test("Brustpresse, gym80, Modell: Name, Hersteller und Hinweis kommen vom Herstellermodell", async ({ page }) => {
  const { admin, studioId } = await studioMitTrainer(page, "gymtavo-produkt");
  const { typId, typName } = await gymtavoTyp(admin, "Brustpresse", [], {
    werte: { load_step: 5, load_min: 0, load_max: 100 },
    einstellungen: [{ key: "seat_height", label: "Sitzhöhe", kind: "number" }],
    foto: true,
  });
  const { produktId } = await herstellerProdukt(admin, typId, { note: "Scheibenbeladen, eigenes Lastprofil." });

  await page.goto(`/portal/${studioId}/geraete/neu?art=typ&kategorie=kraft`);
  await typWaehlen(page, typName);
  await herstellerWaehlen(page, "gym80 (1)");
  await page.getByRole("radio", { name: /Pure Kraft Brustpresse 4345/ }).check();
  await expect(page.getByLabel("Name")).toHaveValue("Pure Kraft Brustpresse 4345");
  await expect(page.getByText("Scheibenbeladen, eigenes Lastprofil.")).toBeVisible();
  await expect(page.getByText("Symbolbild")).toBeVisible();
  await page.getByRole("button", { name: "Weiter", exact: true }).click();
  await expect(page).toHaveURL(new RegExp(`/portal/${studioId}/geraete/[0-9a-f-]+/einstellungen`));

  const { data: modell } = await admin
    .from("equipment_models")
    .select("id, name, manufacturer, catalog_product_id, photo_path, equipment_setting_definitions(key)")
    .eq("studio_id", studioId)
    .single();
  expect(modell).toMatchObject({ name: "Pure Kraft Brustpresse 4345", manufacturer: "gym80", catalog_product_id: produktId });
  expect(modell?.photo_path).toMatch(new RegExp(`^${studioId}/`));
  expect(modell?.equipment_setting_definitions).toEqual([{ key: "seat_height" }]);

  await page.goto(`/portal/${studioId}/geraete/${modell!.id}`);
  await expect(page.getByText("Vorlage: gym80 Pure Kraft Brustpresse 4345")).toBeVisible();
});

test("Mein Modell ist nicht dabei: Typwerte bleiben, Hersteller ist gesetzt", async ({ page }) => {
  const { admin, studioId } = await studioMitTrainer(page, "gymtavo-nicht-dabei");
  const { typId, typName } = await gymtavoTyp(admin, "Brustpresse");
  await herstellerProdukt(admin, typId);

  await page.goto(`/portal/${studioId}/geraete/neu?art=typ&kategorie=kraft`);
  await typWaehlen(page, typName);
  await herstellerWaehlen(page, "gym80 (1)");
  await page.getByRole("radio", { name: "Mein Modell ist nicht dabei" }).check();
  await expect(page.getByLabel("Name")).toHaveValue(typName);
  await page.getByRole("button", { name: "Weiter", exact: true }).click();
  await expect(page).toHaveURL(new RegExp(`/portal/${studioId}/geraete/[0-9a-f-]+/einstellungen`));

  const { data } = await admin.from("equipment_models").select("name, manufacturer, catalog_product_id").eq("studio_id", studioId).single();
  expect(data).toEqual({ name: typName, manufacturer: "gym80", catalog_product_id: null });
});

test("Anderer Hersteller ergibt freien Text", async ({ page }) => {
  const { admin, studioId } = await studioMitTrainer(page, "gymtavo-anderer");
  const { typId, typName } = await gymtavoTyp(admin, "Brustpresse");
  await herstellerProdukt(admin, typId);

  await page.goto(`/portal/${studioId}/geraete/neu?art=typ&kategorie=kraft`);
  await typWaehlen(page, typName);
  await herstellerWaehlen(page, "Anderer Hersteller");
  await page.getByLabel("Herstellername").fill("Eigenbau");
  await page.getByRole("button", { name: "Weiter", exact: true }).click();
  await expect(page).toHaveURL(new RegExp(`/portal/${studioId}/geraete/[0-9a-f-]+/einstellungen`));

  const { data } = await admin.from("equipment_models").select("manufacturer, catalog_product_id").eq("studio_id", studioId).single();
  expect(data).toEqual({ manufacturer: "Eigenbau", catalog_product_id: null });
});
```

(c) In `e2e/einrichten.spec.ts` neben die drei Tests aus Etappe A einen vierten setzen. Seine Vorbereitung (`studioMitTrainer`, Pfad `/portal/${studioId}/einrichten/modell/neu`, Knopf „Weiter zu den Einstellungen“) wird aus dem dortigen Test „ohne Foto mit Zeichnung“ übernommen:

```ts
test("Halle: ein Herstellermodell mit geklaertem Foto ersetzt das eigene Foto", async ({ page }) => {
  const { admin, studioId } = await studioMitTrainer(page, "halle-produktfoto");
  const { typId, typName } = await gymtavoTyp(admin, "Brustpresse");
  const { produktId } = await herstellerProdukt(admin, typId, { foto: true });

  await page.goto(`/portal/${studioId}/einrichten/modell/neu`);
  await typWaehlen(page, typName);
  const weiter = page.getByRole("button", { name: "Weiter zu den Einstellungen" });
  await expect(weiter).toBeDisabled();
  await herstellerWaehlen(page, "gym80 (1)");
  await page.getByRole("radio", { name: /Pure Kraft Brustpresse 4345/ }).check();
  await expect(weiter).toBeEnabled();
  await weiter.click();
  await expect(page).toHaveURL(new RegExp(`/portal/${studioId}/einrichten/modell/[0-9a-f-]+/einstellungen`));

  const { data } = await admin.from("equipment_models").select("catalog_product_id, photo_path").eq("studio_id", studioId).single();
  expect(data?.catalog_product_id).toBe(produktId);
  expect(data?.photo_path).toMatch(new RegExp(`^${studioId}/`));
});
```

Heißen `studioMitTrainer` und die Imports in `einrichten.spec.ts` anders, werden sie von dort übernommen. Die Prüfungen bleiben, wie sie hier stehen.

- [ ] **Step 2: E2E laufen lassen, sie müssen scheitern**

Run: `pnpm test:e2e -- gymtavo.spec.ts einrichten.spec.ts`
Expected: FAIL. Die vier neuen Tests finden den Knopf „Hersteller“ nicht, weil die Seiten die Produkte noch nicht laden; die alten Tests bleiben grün. Bei einem Lauf gegen einen wiederverwendeten Dev-Server: erst die Fallen aus der Memory „Lokale Testumgebung“ prüfen.

- [ ] **Step 3: `ladeTypVorlagen`**

In `apps/web/app/portal/[studioId]/catalog.ts` die Importe ergänzen (`type Category` aus `@fitretro/domain/belastung`, `typVorlagen` und `type TypVorlage` aus `../bausteine/typVorlage`) und nach `ladeTypen` anfügen:

```ts
/**
 * Die Typliste fuer die Modellformulare, mit signierten URLs fuer Typ- und
 * Produktbilder (Modellkarten, Spec 2026-10-10 ..., 6.5). Gefiltert wird vor
 * dem Signieren: am Schreibtisch braucht nur eine Kategorie Bilder.
 */
export const ladeTypVorlagen = cache(async (kategorie?: Category): Promise<TypVorlage[]> => {
  const typen = (await ladeTypen()).filter((typ) => kategorie === undefined || typ.category === kategorie);
  const pfade = [
    ...new Set(
      typen.flatMap((typ) => [typ.photoPath, ...typ.products.map((p) => p.photoPath)]).filter((pfad): pfad is string => pfad !== null),
    ),
  ];
  const urls = await signMediaUrls(await createServerSupabaseClient(), PHOTO_BUCKET, pfade, MEDIA_URL_TTL_SECONDS);
  return typVorlagen(typen, undefined, Object.fromEntries(urls));
});
```

- [ ] **Step 4: Schreibtisch verdrahten**

- `geraete/neu/page.tsx`: Die Prop `typen={typVorlagen(await listCatalogTypes(...), …)}` wird zu `typen={katalog.isCatalog ? [] : await ladeTypVorlagen(kategorie === "cardio" ? "cardio" : "kraft")}`. `katalog` kommt aus `await ladeKatalog(studioId)` (cache, die Rail laedt ihn ohnehin). Im Gymtavo-Studio zeigt das Portal weder Typen noch Produkte (Spec 6.5); der Trigger aus 0047 verbietet dort eine Typzuordnung ohnehin, das Feld führte bisher nur in einen Fehler. Die nicht mehr gebrauchten Importe (`listCatalogTypes`, `typVorlagen`, gegebenenfalls `createServerSupabaseClient`) entfernen und `ladeTypVorlagen` aus `../../../catalog` importieren.
- `apps/web/app/portal/actions.ts`, `modellAnlegen`: im Aufruf von `createEquipmentModel` nach `catalogModelId: typ.catalogModelId,` ergänzen:

```ts
      catalogProductId: optionalerText(formData, "catalogProductId"),
```

- `StammdatenFormular.tsx`:
  - Den `modell`-Typ um `catalogProduct: { manufacturer: string; series: string | null; name: string; modelCode: string | null } | null;` erweitern.
  - `vorlageText` aus `../../../../bausteine/herstellerWahl` importieren.
  - Nach `<GymtavoTypFeld … />` einfügen:

```tsx
      {modell.catalogProduct ? (
        // Nur Herkunft (G1): die Werte sind beim Anlegen kopiert und hier
        // frei aenderbar; ein Produkt nachtraeglich zuweisen kommt spaeter.
        <p className={styles.hint}>{vorlageText(modell.catalogProduct)}</p>
      ) : null}
```

`[modelId]/page.tsx` reicht `modell` schon ganz durch, dort ändert sich nichts.

- [ ] **Step 5: Halle verdrahten**

- `einrichten/modell/neu/page.tsx`: `ladeTypen` und `typVorlagen` durch `ladeTypVorlagen` ersetzen: `const katalog = await ladeKatalog(studioId);`, `const typen = katalog.isCatalog ? [] : await ladeTypVorlagen();` und `typen={typen}`. Grund wie am Schreibtisch.
- `ModellNeuFormular.tsx`:
  - `onTyp={setTyp}` wird zu `onVorlage={setVorlage}`.
  - Neuer State: `const [vorlage, setVorlage] = useState<VorlageWahl>({ typ: null, produkt: null });` (Import `type VorlageWahl` aus `ModellVorlageFelder`). Der alte `typ`-State fällt weg.
  - Das bisherige `fotoNoetig` ersetzen durch:

```ts
  // Ohne eigenes Foto geht es weiter, wenn die Vorlage ein Bild mitbringt:
  // geklaertes Produktfoto oder Typzeichnung (Spec 5.2, Plan-Entscheidung P4).
  const produktFoto = vorlage.produkt?.fotoUrl != null;
  const fotoNoetig = !(produktFoto || vorlage.typ?.hatFoto);
```

  Der Hinweis am Fotofeld wird:

```tsx
          fotoNoetig
            ? "Das ganze Gerät ins Bild. Ein Foto je Modell, nicht je Gerät — zwei baugleiche Kabelzüge zeigen dasselbe Bild."
            : produktFoto
              ? "Ohne eigenes Foto zeigt das Gerät das Herstellerfoto. Ein echtes Foto hilft Mitgliedern, das Gerät zu erkennen."
              : "Ohne eigenes Foto zeigt das Gerät die Gymtavo-Zeichnung. Ein echtes Foto hilft Mitgliedern, das Gerät zu erkennen."
```

  Den Kopfkommentar um „oder das Herstellermodell ein geklärtes Foto hat“ ergänzen und `copyTypeDefaults` dort in `copyCatalogDefaults` ändern, falls Task 6 das nicht schon getan hat.

- `einrichten/actions.ts`, `modellAnlegen`:
  - Vor dem Fotocheck `const produktId = optionalerText(formData, "catalogProductId");` lesen.
  - Den Fotocheck ändern zu `if (!eigenesFoto && !(await vorlageHatFoto(client, typ.catalogModelId, produktId)))`.
  - Im Aufruf von `createEquipmentModel` ergänzen: `catalogProductId: produktId,`.
  - `typHatFoto` ersetzen durch:

```ts
/** Typzeichnung oder geklaertes Produktfoto (Spec 5.2, Plan-Entscheidung P4). */
async function vorlageHatFoto(
  client: Awaited<ReturnType<typeof createServerSupabaseClient>>,
  typId: string | undefined,
  produktId: string | null,
): Promise<boolean> {
  if (!typId) return false;
  const typ = (await listCatalogTypes(client)).find((t) => t.id === typId);
  if (!typ) return false;
  return typ.photoPath !== null || typ.products.some((p) => p.id === produktId && p.photoPath !== null);
}
```

  `vorlageHatFoto` liest das Produkt am Typ. Ein Produkt, das nicht zum Typ passt, bringt deshalb kein Foto mit, und `createEquipmentModel` lehnt es ohnehin ab (P1).

- [ ] **Step 6: Typprüfung und Unit-Tests**

Run: `pnpm typecheck && pnpm test`
Expected: PASS.

- [ ] **Step 7: E2E gegen den Produktionsbau**

Run, wie in der Memory „Lokale Testumgebung“ beschrieben:

```bash
pkill -f "next-server" ; rm -rf apps/web/.next
APPLE_TEAM_ID=ABCDE12345 APPLE_BUNDLE_ID=de.fitretro.member pnpm build
(set -a; . ./.env; set +a; pnpm --filter @fitretro/web start -p 3007 &)
pnpm test:e2e -- gymtavo.spec.ts einrichten.spec.ts
```

Expected: PASS, auch die Tests aus Etappe A. Danach den Server beenden (`pkill -f next-server`) und `apps/web/AGENTS.md` sowie `apps/web/CLAUDE.md` löschen, falls der Build sie angelegt hat.

- [ ] **Step 8: Commit**

```bash
git add apps/web/app e2e
git commit -m "feat(katalog): Schreibtisch und Halle legen Modelle aus Herstellermodellen an

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log -1 --format=%B
```

---

### Task 10: Erstbestand – 114 Herstellermodelle in die Katalogdatei

**Files:**
- Create (außerhalb des Repos): `<scratchpad>/konverter-produkte/produkte_konverter.py`
- Modify: `catalog/gymtavo.json`

Das Paket gilt als nicht vertrauenswürdige Datenquelle. Das Skript liegt in einem eigenen Ordner im Scratchpad, läuft mit `python3 -I` und bekommt die Pfade als Argumente. Nichts aus dem Paket wird ausgeführt. Die Herstellerfotos kommen nicht ins Repo (Spec 6.3).

- [ ] **Step 1: Konverter schreiben**

`<scratchpad>/konverter-produkte/produkte_konverter.py`:

```python
"""Einmaliger Konverter: GYMTAVO-Herstellermodelle -> products[] in catalog/gymtavo.json.

Aufruf: python3 -I produkte_konverter.py <herstellerbilder-kandidaten.json> <repo>/catalog/gymtavo.json
Spec 2026-10-10-gymtavo-katalog-geraeteeinrichtung-design.md, 6.3: nur Modelle,
deren Typen alle im Katalog stehen; keine Fotos, keine Belastung, keine
Paket-UUIDs. Liest nur JSON, fuehrt nichts aus dem Paket aus.
"""
import json
import sys


def leer_zu_none(wert):
    if wert is None:
        return None
    wert = str(wert).strip()
    return wert or None


def main(kandidaten_pfad, katalog_pfad):
    with open(kandidaten_pfad, encoding="utf-8") as f:
        kandidaten = json.load(f)["models"]
    with open(katalog_pfad, encoding="utf-8") as f:
        katalog = json.load(f)

    typen = {g["key"] for g in katalog["equipment"]}
    produkte, ausgelassen = [], []
    for m in kandidaten:
        # Reihenfolge behalten, Doppelte raus: die Datei verbietet sie.
        zuordnung = list(dict.fromkeys(m["equipment_type_candidates"]))
        fehlend = [t for t in zuordnung if t not in typen]
        if fehlend:
            ausgelassen.append((m["id"], fehlend))
            continue
        produkte.append({
            "key": m["id"],
            "manufacturer": m["manufacturer"].strip(),
            "series": leer_zu_none(m.get("series")),
            "name": m["model"].strip(),
            "model_code": leer_zu_none(m.get("model_code")),
            "product_url": leer_zu_none(m.get("product_url")),
            "types": zuordnung,
            "note": leer_zu_none(m.get("review_note_de")),
            "photo": None,
            "photo_rights": "pending",
            "load_unit": None,
            "load_step": None,
            "load_min": None,
            "load_max": None,
            "secondary": None,
        })

    produkte.sort(key=lambda p: (p["manufacturer"].lower(), p["series"] or "", p["name"], p["key"]))
    katalog["products"] = produkte
    with open(katalog_pfad, "w", encoding="utf-8") as f:
        json.dump(katalog, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print(f"{len(produkte)} Produkte geschrieben, {len(ausgelassen)} ausgelassen:")
    for key, fehlend in ausgelassen:
        print(f"  {key}: {', '.join(fehlend)}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
```

- [ ] **Step 2: Konverter ausführen**

Run:

```bash
python3 -I <scratchpad>/konverter-produkte/produkte_konverter.py ~/Downloads/GYMTAVO-Uebungsdatenbank/manufacturers/herstellerbilder-kandidaten.json catalog/gymtavo.json
git diff --stat catalog/gymtavo.json
```

Expected:
- `114 Produkte geschrieben, 5 ausgelassen:`. Die fünf Ausgelassenen zeigen auf `flat_bench`, `adjustable_bench`, `decline_bench`, `preacher_bench` oder `upright_bench`.
- `git diff` zeigt nur hinzugefügte Zeilen am Dateiende (`products`). Ändern sich andere Zeilen, stimmt die Formatierung nicht (Einrückung, `ensure_ascii`). Dann den Diff ansehen und den Konverter anpassen.

- [ ] **Step 3: Datei prüfen und lokal importieren**

Run:

```bash
pnpm catalog:import --dry-run 2>&1 | tee <scratchpad>/import-trocken.txt | head -20
```

Expected:
- `Ziel: http://127.0.0.1:54321 (Trockenlauf)`
- `Produkte: 114 neu, 0 geaendert, 0 unveraendert`
- `Produkt-Typen: 130 neu, 0 geaendert, 0 unveraendert`. 114 Modelle, davon 15 mit mehreren Typen; nachgezählt am 11.10. aus dem Paket.
- Geräte- und Übungszeilen `0 neu`. Steht dort etwas anderes, weil die geteilte DB von einem anderen Stand ist: nicht importieren, sondern Tim melden.

Bei passendem Plan:

```bash
pnpm catalog:import
pnpm catalog:import --dry-run | grep -E "^Produkt"
```

Expected: Der erste Lauf meldet `… 114 Produkte, 130 Produkt-Typen.` Der zweite Trockenlauf meldet `Produkte: 0 neu, 0 geaendert, 114 unveraendert`.

- [ ] **Step 4: Commit**

```bash
git add catalog/gymtavo.json
git commit -m "feat(katalog): 114 Herstellermodelle aus dem GYMTAVO-Paket als Erstbestand

Ohne Fotos (Rechte offen) und ohne Belastung; die Notiz aus dem Paket
steht als Hinweis am Modell.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log -1 --format=%B
```

---

### Task 11: Voller Testsatz, Sichtprobe, Ergebnis im Plan

**Files:**
- Modify: `docs/superpowers/plans/2026-10-11-gymtavo-geraeteeinrichtung-etappe-b.md` (Abschnitt „Ergebnis“, Häkchen)

- [ ] **Step 1: Voller Testsatz**

Run:

```bash
pnpm typecheck && pnpm test && pnpm test:integration > <scratchpad>/integration.txt 2>&1; tail -30 <scratchpad>/integration.txt
```

Danach `pnpm test:e2e` gegen den Produktionsbau wie in Task 9, Step 7.

Expected:
- `typecheck` und `test` grün.
- Integration grün bis auf bekannte Umgebungsfehler (`completeSession`, Uhrversatz). Jeder rote Test wird benannt und gegen `master` geprüft.
- E2E grün bis auf vorbestehende Timingfälle, die ebenfalls benannt werden.

- [ ] **Step 2: Sichtprobe im Browser**

Gegen den Produktionsbau mit dem echten lokalen Katalog:
- Schreibtisch, „Gerät hinzufügen“, Kraft, Typ „Brustpresse“ (`chest_press`): Herstellerliste mit Anzahlen, Modellkarten mit „Symbolbild“, Name nach Modellwahl, Notiz über dem Rad.
- Nach dem Speichern: Stammdaten zeigen die Zeile „Vorlage: …“.
- Halle: Typ ohne Zeichnung, aber Produkt mit Foto gibt es im Erstbestand nicht. Hier reicht der E2E-Test aus Task 9.

Screenshots in den Scratchpad, nicht ins Repo.

- [ ] **Step 3: Ergebnis eintragen und committen**

Am Planende einen Abschnitt `## Ergebnis` anlegen mit:
- Testzahlen und benannten Umgebungsfehlern.
- Entscheidungen beim Umsetzen (Ledger-`Ruling:`).
- Zurückgestellten Kleinigkeiten.
- Den Schritten für Produktion: Migration 0050, dann `pnpm catalog:import --dry-run` gegen Produktion mit der Erwartung `Produkte: 114 neu`, Rest unverändert, dann `--ja`. Alles erst nach dem Merge und auf Tims Wort.

Alle erledigten Schritte abhaken.

```bash
git add docs/superpowers/plans/2026-10-11-gymtavo-geraeteeinrichtung-etappe-b.md
git commit -m "docs(plan): Etappe B der Geraeteeinrichtung umgesetzt

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log -1 --format=%B
```
