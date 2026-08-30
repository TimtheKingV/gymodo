# Gerätekatalog — Datenmodell Implementierungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Das vollständige Datenmodell für den Gerätekatalog (Gerätemodelle, Einstellparameter, Übungen, Einweisungsvideos, Geräteinstanzen) existiert mit getesteter RLS, und der Web-Fallback nutzt keinen Service-Role-Key mehr für öffentliche Anfragen.

**Architecture:** Reine Datenbank- und RLS-Arbeit auf dem bestehenden Supabase-Schema aus M0 (`studios`, `profiles`, `studio_memberships`, `machine_tags`). Keine neue Web-Oberfläche in diesem Plan — Trainer-UI und Medien-Upload sind ein separater Folgeplan, der auf diesem Schema aufbaut. Dieser Plan führt zum ersten Mal rollenbasierte Schreibrechte ein (Trainer/Owner dürfen den Katalog pflegen, Mitglieder nicht), über eine neue `SECURITY DEFINER`-Funktion `is_studio_staff`, analog zu `is_studio_member` aus M0.

**Tech Stack:** identisch zu M0 — TypeScript strict, Supabase/PostgreSQL mit RLS, Vitest-Integrationstests gegen echtes lokales Postgres, Playwright-E2E.

**Spec:** `docs/superpowers/specs/2026-08-28-fitness-retrofit-m1-design.md`, Abschnitt 7 (Datenmodell) und Abschnitt 6.1 (Umsetzung Ruling — `resolve_tag_fallback`)

## Global Constraints

Diese Werte gelten in jedem Task, zusätzlich zu den in M0 etablierten Regeln (`studio_id` + `ENABLE`/`FORCE ROW LEVEL SECURITY` auf jeder Tabelle, Positiv-/Negativ-/Cross-Tenant-Test je Policy, Migrationen ausschließlich versioniert in `supabase/migrations/`, TypeScript `strict: true` ohne `any`/`@ts-ignore`, ein Commit je abgeschlossenem Schritt-Block).

- **Rollenbasierte Schreibrechte (neu in diesem Plan):** `equipment_models`, `equipment_setting_definitions`, `exercises`, `equipment_model_exercises`, `instruction_assets`, `machines` sind für alle Studiomitglieder lesbar (`is_studio_member`), aber nur für `trainer`/`owner` schreibbar (`is_studio_staff`, wird in Task 2 angelegt). Kein `for all`-Policy-Shortcut — je Aktion (`select`/`insert`/`update`/`delete`) eine eigene, explizite Policy, damit jede einzeln testbar und im Review nachvollziehbar ist.
- **Studio-Konsistenz bei Verknüpfungstabellen:** Wo eine Zeile auf zwei studio-gebundene Tabellen verweist (`equipment_model_exercises`, `machines`), erzwingt die INSERT/UPDATE-Policy per Join, dass beide Seiten demselben Studio angehören — nicht nur Anwendungscode. Diese Garantie wird **durch RLS erzwungen, nicht durch das Schema**: die einspaltigen Fremdschlüssel (`equipment_model_id`, `exercise_id`) verhindern die Verknüpfung selbst nicht — mit dem Service-Role-Client (der RLS umgeht) lässt sich eine studioübergreifende Zeile anlegen. Eine studioübergreifende Verknüpfung ist damit auf Datenbankebene *policy-seitig* ausgeschlossen, nicht durch das Schema selbst. **Konsequenz für den Folgeplan:** Die API muss für diese Tabellen einen nutzergebundenen Client verwenden, niemals den Service-Role-Client — sonst entfallen sämtliche Same-Studio-Garantien dieses Branches auf einen Schlag.
- **Kein Medien-Upload in diesem Plan.** `equipment_models.photo_path` und `instruction_assets.storage_path` sind reine Text-Spalten. Es wird in diesem Plan kein Storage-Bucket angelegt, keine Upload-Route gebaut. Das ist expliziter Scope eines Folgeplans (Trainer-Weboberfläche).
- **Video-Formatgrenze:** `instruction_assets.duration_s` ist auf maximal 45 Sekunden begrenzt (Spec Abschnitt 6.8) — als Check-Constraint, nicht nur als Konvention.
- **`machines.status`:** zweiwertiges Enum `active`/`inactive`. Feinere Wartungszustände (Spec-Erwähnung in Blueprint 5.2) sind YAGNI für M1 und kommen erst bei echtem Bedarf.
- **Löschverhalten:** `equipment_models` wird bei Löschversuch mit existierenden `machines` durch `on delete restrict` blockiert — ein Gerätemodell, das noch in Benutzung ist, verschwindet nicht stillschweigend mitsamt seinen Geräteinstanzen.
- **Bekannte, bewusst offene Lücke:** Spec Abschnitt 7.6 verlangt Trainer/Owner-Schreibrechte auch auf `machine_tags` (Anlegen, Zuweisen, Sperren). M0 hat dort ausschließlich eine Select-Policy angelegt, Schreiben lief bislang nur serverseitig mit Service-Role. Dieser Plan fügt `machine_tags` **keine** Insert/Update-Policy hinzu — das gehört zur Tag-Zuweisungs-Workflow-Logik (Sperren, Neuzuweisen, Rate-Limiting nach Spec 10.4) und damit in den Trainer-Weboberfläche-Folgeplan, nicht in reines Datenmodell. Nicht vergessen, dort nachzuholen.

---

## Dateistruktur

Nach diesem Plan zusätzlich zu M0 vorhanden:

```text
supabase/migrations/
  0003_resolve_tag_fallback.sql   # SECURITY DEFINER statt Service-Role im Web-Fallback
  0004_equipment_models.sql       # is_studio_staff() + equipment_models + equipment_setting_definitions
  0005_exercises.sql              # exercises + equipment_model_exercises
  0006_instruction_assets.sql     # instruction_assets
  0007_machines.sql               # machines
  0008_machine_tags_fk.sql        # FK + Check-Constraint auf machine_tags.machine_id (in M0 angekündigt)

apps/web/app/t/[token]/page.tsx   # modifiziert: anon-Client + RPC statt Service-Role-Client

tests/integration/
  resolve-tag-fallback.test.ts    # neu
  rls-equipment-models.test.ts    # neu
  rls-exercises.test.ts           # neu
  rls-instruction-assets.test.ts  # neu
  rls-machines.test.ts            # neu
  rls-machine-tags.test.ts        # modifiziert: Fixture braucht jetzt eine Geraeteinstanz

e2e/
  tag-fallback.spec.ts            # modifiziert: dritter Testfall braucht jetzt eine Geraeteinstanz,
                                   # neuer Testfall fuer den Status "unassigned"
```

**Verantwortlichkeiten:** Jede Migration fügt genau eine fachliche Einheit hinzu (ein bis zwei eng verwandte Tabellen plus deren RLS). `resolve_tag_fallback` steht bewusst als eigene, erste Migration, weil sie eine Sicherheitslücke aus dem M0-Abschlussreview schließt und mit keiner der neuen Tabellen zusammenhängt.

---

## Task 1: Sicherheits-Fix — `resolve_tag_fallback` ersetzt den Service-Role-Client

**Hintergrund:** Der finale Whole-Branch-Review des M0-Plans hat festgestellt, dass `apps/web/app/t/[token]/page.tsx` einen Service-Role-Key in einem öffentlichen, unauthentifizierten Request-Handler verwendet — das widerspricht der Spec (§16.6.4: „Service-Role-Keys niemals … in normalen Request-Handlern"). Die Ruling aus diesem Review: der Fix wird als erste Migration dieses Folgeplans nachgeholt, bevor die Fallback-Query um weitere Spalten (Gerätename, Foto) erweitert wird.

**Files:**
- Create: `supabase/migrations/0003_resolve_tag_fallback.sql`
- Modify: `apps/web/app/t/[token]/page.tsx`
- Test: `tests/integration/resolve-tag-fallback.test.ts`

**Interfaces:**
- Consumes: `hashTagToken`, `createTagToken`, `isValidTagToken` aus `@fitretro/domain`; `requiredEnv` aus `apps/web/lib/env.ts`; `machine_tags`-Tabelle aus M0
- Produces: SQL-Funktion `public.resolve_tag_fallback(p_token_hash text) returns table (machine_tag_id uuid)`, `grant execute … to anon`

- [ ] **Step 1: Den fehlschlagenden Integrationstest schreiben**

`tests/integration/resolve-tag-fallback.test.ts`:

```ts
import { beforeAll, describe, expect, it } from "vitest";
import { createClient } from "@supabase/supabase-js";
import { createTagToken, hashTagToken } from "@fitretro/domain";
import { serviceClient } from "./helpers/clients.js";

function anonClient() {
  const url = process.env.SUPABASE_URL;
  const anonKey = process.env.SUPABASE_ANON_KEY;
  if (!url || !anonKey) {
    throw new Error("SUPABASE_URL/SUPABASE_ANON_KEY fehlen");
  }
  return createClient(url, anonKey, { auth: { persistSession: false } });
}

let activeToken: string;
let revokedToken: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studio, error: studioError } = await admin
    .from("studios")
    .insert({ name: "Resolve-Fallback Studio" })
    .select("id")
    .single();
  if (studioError) throw studioError;

  activeToken = createTagToken();
  revokedToken = createTagToken();
  const { error: tagError } = await admin.from("machine_tags").insert([
    { studio_id: studio.id, token_hash: hashTagToken(activeToken), status: "active" },
    { studio_id: studio.id, token_hash: hashTagToken(revokedToken), status: "revoked" },
  ]);
  if (tagError) throw tagError;
});

describe("resolve_tag_fallback", () => {
  it("liefert eine Zeile fuer einen aktiven Tag", async () => {
    const client = anonClient();
    const { data, error } = await client.rpc("resolve_tag_fallback", {
      p_token_hash: hashTagToken(activeToken),
    });
    expect(error).toBeNull();
    expect(data).toHaveLength(1);
  });

  it("liefert keine Zeile fuer einen gesperrten Tag", async () => {
    const client = anonClient();
    const { data, error } = await client.rpc("resolve_tag_fallback", {
      p_token_hash: hashTagToken(revokedToken),
    });
    expect(error).toBeNull();
    expect(data).toEqual([]);
  });

  it("liefert keine Zeile fuer einen unbekannten Token-Hash", async () => {
    const client = anonClient();
    const { data, error } = await client.rpc("resolve_tag_fallback", {
      p_token_hash: hashTagToken(createTagToken()),
    });
    expect(error).toBeNull();
    expect(data).toEqual([]);
  });

  it("anonymer Client kann machine_tags nicht direkt lesen", async () => {
    const client = anonClient();
    const { data, error } = await client.from("machine_tags").select("id");
    // RLS verweigert: entweder ein Fehler oder eine leere Liste, niemals Daten.
    if (!error) {
      expect(data).toEqual([]);
    }
  });
});
```

- [ ] **Step 2: Test laufen lassen und Fehlschlag bestätigen**

```bash
pnpm test:integration
```

Erwartet: FAIL — `function public.resolve_tag_fallback(text) does not exist` (oder PostgREST-Äquivalent).

- [ ] **Step 3: Migration schreiben**

`supabase/migrations/0003_resolve_tag_fallback.sql`:

```sql
-- Loest den Service-Role-Key im oeffentlichen Web-Fallback ab (siehe M0-
-- Abschlussreview, Ruling zu Finding 2). Liefert ausschliesslich eine
-- machine_tag_id fuer aktive Tags -- niemals Personendaten, niemals mehr
-- Spalten als der aufrufende Client ohnehin schon kennen darf.
create or replace function public.resolve_tag_fallback(p_token_hash text)
returns table (machine_tag_id uuid)
language sql
security definer
set search_path = public, pg_temp
stable
as $$
  select id
  from public.machine_tags
  where token_hash = p_token_hash
    and status = 'active';
$$;

revoke all on function public.resolve_tag_fallback(text) from public;
grant execute on function public.resolve_tag_fallback(text) to anon;
```

- [ ] **Step 4: Migration anwenden und Test laufen lassen**

```bash
pnpm exec supabase db reset
pnpm test:integration
```

Erwartet: die vier neuen Tests bestehen (16 bestehende Tests aus M0 bleiben unverändert grün).

- [ ] **Step 5: Fallback-Seite auf die neue Funktion umstellen**

`apps/web/app/t/[token]/page.tsx` komplett ersetzen durch:

```tsx
import { createClient } from "@supabase/supabase-js";
import { hashTagToken, isValidTagToken } from "@fitretro/domain";
import { requiredEnv } from "@/lib/env";

export const dynamic = "force-dynamic";

/**
 * Web-Fallback fuer Geraete-Tags.
 *
 * Diese Seite ist oeffentlich und zeigt niemals persoenliche Daten.
 * Ein unbekannter, ungueltiger und ein gesperrter Token liefern bewusst
 * dieselbe Antwort, damit sich gueltige Tokens nicht durch Ausprobieren
 * unterscheiden lassen.
 */
export default async function TagFallbackPage({
  params,
}: {
  params: Promise<{ token: string }>;
}) {
  const { token } = await params;

  const unknown = (
    <main>
      <h1 data-testid="tag-unknown">Dieser Code ist nicht aktiv.</h1>
      <p>Bitte wende dich an dein Studio.</p>
    </main>
  );

  if (!isValidTagToken(token)) return unknown;

  // Oeffentlicher Endpunkt ohne Nutzersession: der anonyme Key berechtigt
  // zu nichts ausser dem Aufruf von resolve_tag_fallback (SECURITY DEFINER,
  // liefert ausschliesslich eine machine_tag_id fuer aktive Tags zurueck).
  const client = createClient(
    requiredEnv("SUPABASE_URL"),
    requiredEnv("SUPABASE_ANON_KEY"),
    { auth: { persistSession: false } },
  );

  const { data } = await client.rpc("resolve_tag_fallback", {
    p_token_hash: hashTagToken(token),
  });

  if (!data || data.length === 0) return unknown;

  return (
    <main>
      <h1>Gerät erkannt</h1>
      <p data-testid="install-hint">
        Installiere die App, um deine Einstellungen und deinen Verlauf zu
        speichern.
      </p>
    </main>
  );
}
```

- [ ] **Step 6: Bestehende E2E-Tests laufen lassen (Regressionscheck)**

```bash
pnpm test:e2e
```

Erwartet: alle 5 bestehenden E2E-Tests weiterhin grün — die Fallback-Seite verhält sich für den Browser identisch, nur die interne Implementierung hat sich geändert (keine Anpassung an `e2e/tag-fallback.spec.ts` in diesem Task nötig — die Fixture-Anpassung wegen der neuen `machine_tags`-Constraint kommt erst in Task 6).

- [ ] **Step 7: Alle Tests einmal komplett laufen lassen**

```bash
pnpm typecheck
pnpm test
pnpm test:integration
pnpm test:e2e
```

Erwartet: alles grün.

- [ ] **Step 8: Committen**

```bash
git add supabase/migrations/0003_resolve_tag_fallback.sql tests/integration/resolve-tag-fallback.test.ts apps/web/app/t/\[token\]/page.tsx
git commit -m "fix: Web-Fallback nutzt SECURITY DEFINER statt Service-Role-Key"
```

---

## Task 2: `equipment_models`, `equipment_setting_definitions` und rollenbasierte Schreibrechte

**Files:**
- Create: `supabase/migrations/0004_equipment_models.sql`
- Test: `tests/integration/rls-equipment-models.test.ts`

**Interfaces:**
- Consumes: `is_studio_member(uuid)` aus M0; `serviceClient`, `createTestUser`, `uniqueEmail`, `userClient` aus `tests/integration/helpers/clients.ts`
- Produces: SQL-Funktion `public.is_studio_staff(p_studio_id uuid) returns boolean`; Tabellen `equipment_models`, `equipment_setting_definitions`

- [ ] **Step 1: Den fehlschlagenden RLS-Test schreiben**

`tests/integration/rls-equipment-models.test.ts`:

```ts
import { beforeAll, describe, expect, it } from "vitest";
import {
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";

let studioA: string;
let studioB: string;
let memberAEmail: string;
let staffAEmail: string;
let memberBEmail: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioError } = await admin
    .from("studios")
    .insert([{ name: "Equipment Studio A" }, { name: "Equipment Studio B" }])
    .select("id");
  if (studioError) throw studioError;
  studioA = studios[0]!.id;
  studioB = studios[1]!.id;

  memberAEmail = uniqueEmail("eq-member-a");
  staffAEmail = uniqueEmail("eq-staff-a");
  memberBEmail = uniqueEmail("eq-member-b");

  const memberAId = await createTestUser(memberAEmail);
  const staffAId = await createTestUser(staffAEmail);
  const memberBId = await createTestUser(memberBEmail);

  const { error: membershipError } = await admin.from("studio_memberships").insert([
    { studio_id: studioA, user_id: memberAId, role: "member" },
    { studio_id: studioA, user_id: staffAId, role: "trainer" },
    { studio_id: studioB, user_id: memberBId, role: "member" },
  ]);
  if (membershipError) throw membershipError;
});

describe("RLS auf equipment_models", () => {
  it("positiv: Staff kann ein Geraetemodell anlegen", async () => {
    const client = await userClient(staffAEmail);
    const { data, error } = await client
      .from("equipment_models")
      .insert({ studio_id: studioA, name: "Beinpresse", weight_step_kg: 5 })
      .select("id")
      .single();
    expect(error).toBeNull();
    expect(data?.id).toBeDefined();
  });

  it("negativ: Mitglied kann kein Geraetemodell anlegen", async () => {
    const client = await userClient(memberAEmail);
    const { error } = await client
      .from("equipment_models")
      .insert({ studio_id: studioA, name: "Verboten", weight_step_kg: 5 });
    expect(error).not.toBeNull();
  });

  it("cross-tenant: Mitglied aus Studio B kann in Studio A nichts anlegen", async () => {
    const client = await userClient(memberBEmail);
    const { error } = await client
      .from("equipment_models")
      .insert({ studio_id: studioA, name: "Fremd", weight_step_kg: 5 });
    expect(error).not.toBeNull();
  });

  it("positiv: Mitglied sieht Geraetemodelle seines Studios", async () => {
    const client = await userClient(memberAEmail);
    const { data, error } = await client.from("equipment_models").select("id");
    expect(error).toBeNull();
    expect(data!.length).toBeGreaterThan(0);
  });

  it("cross-tenant: Mitglied aus Studio B sieht Studio-A-Geraete nicht", async () => {
    const client = await userClient(memberBEmail);
    const { data } = await client
      .from("equipment_models")
      .select("id")
      .eq("studio_id", studioA);
    expect(data).toEqual([]);
  });

  it("negativ: Staff kann kein Geraetemodell mit Gewichtsschritt <= 0 anlegen", async () => {
    const client = await userClient(staffAEmail);
    const { error } = await client
      .from("equipment_models")
      .insert({ studio_id: studioA, name: "Ungueltig", weight_step_kg: 0 });
    expect(error).not.toBeNull();
  });
});

describe("RLS auf equipment_setting_definitions", () => {
  let modelId: string;

  beforeAll(async () => {
    const admin = serviceClient();
    const { data, error } = await admin
      .from("equipment_models")
      .insert({ studio_id: studioA, name: "Latzug", weight_step_kg: 2.5 })
      .select("id")
      .single();
    if (error) throw error;
    modelId = data.id;
  });

  it("positiv: Staff kann eine Einstelldefinition anlegen", async () => {
    const client = await userClient(staffAEmail);
    const { error } = await client.from("equipment_setting_definitions").insert({
      equipment_model_id: modelId,
      key: "seat_position",
      label: "Sitzposition",
      kind: "number",
      min_value: 1,
      max_value: 8,
      step_value: 1,
    });
    expect(error).toBeNull();
  });

  it("negativ: Mitglied kann keine Einstelldefinition anlegen", async () => {
    const client = await userClient(memberAEmail);
    const { error } = await client.from("equipment_setting_definitions").insert({
      equipment_model_id: modelId,
      key: "verboten",
      label: "Verboten",
      kind: "number",
    });
    expect(error).not.toBeNull();
  });

  it("cross-tenant: Mitglied aus Studio B sieht die Einstelldefinition nicht", async () => {
    const client = await userClient(memberBEmail);
    const { data } = await client
      .from("equipment_setting_definitions")
      .select("id")
      .eq("equipment_model_id", modelId);
    expect(data).toEqual([]);
  });
});
```

- [ ] **Step 2: Test laufen lassen und Fehlschlag bestätigen**

```bash
pnpm test:integration
```

Erwartet: FAIL — `relation "public.equipment_models" does not exist`.

- [ ] **Step 3: Migration schreiben**

`supabase/migrations/0004_equipment_models.sql`:

```sql
-- Rollenpruefung fuer Schreibrechte: Trainer und Owner duerfen den
-- Geraetekatalog pflegen, einfache Mitglieder nicht. Analog zu
-- is_studio_member aus M0, aber mit Rollenfilter.
create or replace function public.is_studio_staff(p_studio_id uuid)
returns boolean
language sql
security definer
set search_path = public, pg_temp
stable
as $$
  select exists (
    select 1
    from public.studio_memberships m
    where m.studio_id = p_studio_id
      and m.user_id = auth.uid()
      and m.role in ('trainer', 'owner')
  );
$$;

revoke all on function public.is_studio_staff(uuid) from public;
grant execute on function public.is_studio_staff(uuid) to authenticated;

create table public.equipment_models (
  id             uuid primary key default gen_random_uuid(),
  studio_id      uuid not null references public.studios (id) on delete cascade,
  name           text not null check (length(trim(name)) > 0),
  manufacturer   text,
  photo_path     text,
  weight_step_kg numeric not null check (weight_step_kg > 0),
  min_weight_kg  numeric not null default 0 check (min_weight_kg >= 0),
  max_weight_kg  numeric check (max_weight_kg is null or max_weight_kg >= min_weight_kg),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create index on public.equipment_models (studio_id);

alter table public.equipment_models enable row level security;
alter table public.equipment_models force row level security;

create policy equipment_models_select on public.equipment_models
  for select to authenticated
  using (public.is_studio_member(studio_id));

create policy equipment_models_insert on public.equipment_models
  for insert to authenticated
  with check (public.is_studio_staff(studio_id));

create policy equipment_models_update on public.equipment_models
  for update to authenticated
  using (public.is_studio_staff(studio_id))
  with check (public.is_studio_staff(studio_id));

create policy equipment_models_delete on public.equipment_models
  for delete to authenticated
  using (public.is_studio_staff(studio_id));

create table public.equipment_setting_definitions (
  id                  uuid primary key default gen_random_uuid(),
  equipment_model_id  uuid not null references public.equipment_models (id) on delete cascade,
  key                 text not null check (length(trim(key)) > 0),
  label               text not null check (length(trim(label)) > 0),
  kind                text not null check (kind in ('number', 'enum')),
  min_value           numeric,
  max_value           numeric,
  step_value          numeric,
  unit                text,
  sort_order          integer not null default 0,
  created_at          timestamptz not null default now(),
  unique (equipment_model_id, key)
);

create index on public.equipment_setting_definitions (equipment_model_id);

alter table public.equipment_setting_definitions enable row level security;
alter table public.equipment_setting_definitions force row level security;

create policy equipment_setting_definitions_select on public.equipment_setting_definitions
  for select to authenticated
  using (
    exists (
      select 1 from public.equipment_models em
      where em.id = equipment_setting_definitions.equipment_model_id
        and public.is_studio_member(em.studio_id)
    )
  );

create policy equipment_setting_definitions_insert on public.equipment_setting_definitions
  for insert to authenticated
  with check (
    exists (
      select 1 from public.equipment_models em
      where em.id = equipment_setting_definitions.equipment_model_id
        and public.is_studio_staff(em.studio_id)
    )
  );

create policy equipment_setting_definitions_update on public.equipment_setting_definitions
  for update to authenticated
  using (
    exists (
      select 1 from public.equipment_models em
      where em.id = equipment_setting_definitions.equipment_model_id
        and public.is_studio_staff(em.studio_id)
    )
  )
  with check (
    exists (
      select 1 from public.equipment_models em
      where em.id = equipment_setting_definitions.equipment_model_id
        and public.is_studio_staff(em.studio_id)
    )
  );

create policy equipment_setting_definitions_delete on public.equipment_setting_definitions
  for delete to authenticated
  using (
    exists (
      select 1 from public.equipment_models em
      where em.id = equipment_setting_definitions.equipment_model_id
        and public.is_studio_staff(em.studio_id)
    )
  );
```

- [ ] **Step 4: Migration anwenden und Tests laufen lassen**

```bash
pnpm exec supabase db reset
pnpm test:integration
```

Erwartet: alle neuen Tests bestehen, alle bestehenden Tests bleiben grün.

- [ ] **Step 5: Committen**

```bash
git add supabase/migrations/0004_equipment_models.sql tests/integration/rls-equipment-models.test.ts
git commit -m "feat: equipment_models und equipment_setting_definitions mit rollenbasierter RLS"
```

---

## Task 3: `exercises` und `equipment_model_exercises`

**Files:**
- Create: `supabase/migrations/0005_exercises.sql`
- Test: `tests/integration/rls-exercises.test.ts`

**Interfaces:**
- Consumes: `is_studio_member`, `is_studio_staff` aus Task 2; `equipment_models` aus Task 2
- Produces: Tabellen `exercises`, `equipment_model_exercises`

- [ ] **Step 1: Den fehlschlagenden RLS-Test schreiben**

`tests/integration/rls-exercises.test.ts`:

```ts
import { beforeAll, describe, expect, it } from "vitest";
import {
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";

let studioA: string;
let studioB: string;
let memberAEmail: string;
let staffAEmail: string;
let memberBEmail: string;
let modelA: string;
let exerciseB: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioError } = await admin
    .from("studios")
    .insert([{ name: "Exercise Studio A" }, { name: "Exercise Studio B" }])
    .select("id");
  if (studioError) throw studioError;
  studioA = studios[0]!.id;
  studioB = studios[1]!.id;

  memberAEmail = uniqueEmail("ex-member-a");
  staffAEmail = uniqueEmail("ex-staff-a");
  memberBEmail = uniqueEmail("ex-member-b");

  const memberAId = await createTestUser(memberAEmail);
  const staffAId = await createTestUser(staffAEmail);
  const memberBId = await createTestUser(memberBEmail);

  const { error: membershipError } = await admin.from("studio_memberships").insert([
    { studio_id: studioA, user_id: memberAId, role: "member" },
    { studio_id: studioA, user_id: staffAId, role: "trainer" },
    { studio_id: studioB, user_id: memberBId, role: "member" },
  ]);
  if (membershipError) throw membershipError;

  const { data: model, error: modelError } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioA, name: "Kabelzug", weight_step_kg: 5 })
    .select("id")
    .single();
  if (modelError) throw modelError;
  modelA = model.id;

  const { data: exercise, error: exerciseError } = await admin
    .from("exercises")
    .insert({
      studio_id: studioB,
      name: "Fremde Uebung",
      target_reps_min: 8,
      target_reps_max: 12,
    })
    .select("id")
    .single();
  if (exerciseError) throw exerciseError;
  exerciseB = exercise.id;
});

describe("RLS auf exercises", () => {
  it("positiv: Staff kann eine Uebung anlegen", async () => {
    const client = await userClient(staffAEmail);
    const { error } = await client.from("exercises").insert({
      studio_id: studioA,
      name: "Breiter Griff",
      target_reps_min: 8,
      target_reps_max: 12,
    });
    expect(error).toBeNull();
  });

  it("negativ: Mitglied kann keine Uebung anlegen", async () => {
    const client = await userClient(memberAEmail);
    const { error } = await client.from("exercises").insert({
      studio_id: studioA,
      name: "Verboten",
      target_reps_min: 8,
      target_reps_max: 12,
    });
    expect(error).not.toBeNull();
  });

  it("cross-tenant: Mitglied aus Studio B sieht Uebungen von Studio A nicht", async () => {
    const client = await userClient(memberBEmail);
    const { data } = await client
      .from("exercises")
      .select("id")
      .eq("studio_id", studioA);
    expect(data).toEqual([]);
  });
});

describe("RLS auf equipment_model_exercises", () => {
  it("negativ: Studio-uebergreifende Verknuepfung wird abgelehnt, auch fuer Staff", async () => {
    const client = await userClient(staffAEmail);
    const { error } = await client.from("equipment_model_exercises").insert({
      equipment_model_id: modelA,
      exercise_id: exerciseB,
    });
    expect(error).not.toBeNull();
  });

  it("positiv: Staff kann Geraet und Uebung im selben Studio verknuepfen", async () => {
    const admin = serviceClient();
    const { data: ownExercise, error: exerciseError } = await admin
      .from("exercises")
      .insert({
        studio_id: studioA,
        name: "Eigene Uebung",
        target_reps_min: 8,
        target_reps_max: 12,
      })
      .select("id")
      .single();
    if (exerciseError) throw exerciseError;

    const client = await userClient(staffAEmail);
    const { error } = await client.from("equipment_model_exercises").insert({
      equipment_model_id: modelA,
      exercise_id: ownExercise.id,
    });
    expect(error).toBeNull();
  });
});
```

- [ ] **Step 2: Test laufen lassen und Fehlschlag bestätigen**

```bash
pnpm test:integration
```

Erwartet: FAIL — `relation "public.exercises" does not exist`.

- [ ] **Step 3: Migration schreiben**

`supabase/migrations/0005_exercises.sql`:

```sql
create table public.exercises (
  id               uuid primary key default gen_random_uuid(),
  studio_id        uuid not null references public.studios (id) on delete cascade,
  name             text not null check (length(trim(name)) > 0),
  description      text,
  target_reps_min  integer not null check (target_reps_min > 0),
  target_reps_max  integer not null check (target_reps_max >= target_reps_min),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create index on public.exercises (studio_id);

alter table public.exercises enable row level security;
alter table public.exercises force row level security;

create policy exercises_select on public.exercises
  for select to authenticated
  using (public.is_studio_member(studio_id));

create policy exercises_insert on public.exercises
  for insert to authenticated
  with check (public.is_studio_staff(studio_id));

create policy exercises_update on public.exercises
  for update to authenticated
  using (public.is_studio_staff(studio_id))
  with check (public.is_studio_staff(studio_id));

create policy exercises_delete on public.exercises
  for delete to authenticated
  using (public.is_studio_staff(studio_id));

create table public.equipment_model_exercises (
  id                  uuid primary key default gen_random_uuid(),
  equipment_model_id  uuid not null references public.equipment_models (id) on delete cascade,
  exercise_id         uuid not null references public.exercises (id) on delete cascade,
  sort_order          integer not null default 0,
  created_at          timestamptz not null default now(),
  unique (equipment_model_id, exercise_id)
);

create index on public.equipment_model_exercises (equipment_model_id);
create index on public.equipment_model_exercises (exercise_id);

alter table public.equipment_model_exercises enable row level security;
alter table public.equipment_model_exercises force row level security;

-- Verknuepfung ist nur gueltig, wenn Geraetemodell und Uebung demselben
-- Studio gehoeren -- der Join erzwingt das direkt in der Policy, nicht
-- nur per Anwendungscode.
create policy equipment_model_exercises_select on public.equipment_model_exercises
  for select to authenticated
  using (
    exists (
      select 1
      from public.equipment_models em
      join public.exercises e on e.studio_id = em.studio_id
      where em.id = equipment_model_exercises.equipment_model_id
        and e.id = equipment_model_exercises.exercise_id
        and public.is_studio_member(em.studio_id)
    )
  );

create policy equipment_model_exercises_insert on public.equipment_model_exercises
  for insert to authenticated
  with check (
    exists (
      select 1
      from public.equipment_models em
      join public.exercises e on e.studio_id = em.studio_id
      where em.id = equipment_model_exercises.equipment_model_id
        and e.id = equipment_model_exercises.exercise_id
        and public.is_studio_staff(em.studio_id)
    )
  );

create policy equipment_model_exercises_update on public.equipment_model_exercises
  for update to authenticated
  using (
    exists (
      select 1
      from public.equipment_models em
      join public.exercises e on e.studio_id = em.studio_id
      where em.id = equipment_model_exercises.equipment_model_id
        and e.id = equipment_model_exercises.exercise_id
        and public.is_studio_staff(em.studio_id)
    )
  )
  with check (
    exists (
      select 1
      from public.equipment_models em
      join public.exercises e on e.studio_id = em.studio_id
      where em.id = equipment_model_exercises.equipment_model_id
        and e.id = equipment_model_exercises.exercise_id
        and public.is_studio_staff(em.studio_id)
    )
  );

create policy equipment_model_exercises_delete on public.equipment_model_exercises
  for delete to authenticated
  using (
    exists (
      select 1
      from public.equipment_models em
      join public.exercises e on e.studio_id = em.studio_id
      where em.id = equipment_model_exercises.equipment_model_id
        and e.id = equipment_model_exercises.exercise_id
        and public.is_studio_staff(em.studio_id)
    )
  );
```

- [ ] **Step 4: Migration anwenden und Tests laufen lassen**

```bash
pnpm exec supabase db reset
pnpm test:integration
```

Erwartet: alle neuen Tests bestehen, alle bestehenden Tests bleiben grün.

- [ ] **Step 5: Committen**

```bash
git add supabase/migrations/0005_exercises.sql tests/integration/rls-exercises.test.ts
git commit -m "feat: exercises und equipment_model_exercises mit Studio-Konsistenzpruefung"
```

---

## Task 4: `instruction_assets`

**Files:**
- Create: `supabase/migrations/0006_instruction_assets.sql`
- Test: `tests/integration/rls-instruction-assets.test.ts`

**Interfaces:**
- Consumes: `is_studio_member`, `is_studio_staff` aus Task 2; `equipment_model_exercises` aus Task 3
- Produces: Tabelle `instruction_assets`

- [ ] **Step 1: Den fehlschlagenden RLS-Test schreiben**

`tests/integration/rls-instruction-assets.test.ts`:

```ts
import { beforeAll, describe, expect, it } from "vitest";
import {
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";

let staffAEmail: string;
let memberBEmail: string;
let linkId: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioError } = await admin
    .from("studios")
    .insert([{ name: "Assets Studio A" }, { name: "Assets Studio B" }])
    .select("id");
  if (studioError) throw studioError;
  const studioA = studios[0]!.id;
  const studioB = studios[1]!.id;

  staffAEmail = uniqueEmail("assets-staff-a");
  memberBEmail = uniqueEmail("assets-member-b");
  const staffAId = await createTestUser(staffAEmail);
  const memberBId = await createTestUser(memberBEmail);

  const { error: membershipError } = await admin.from("studio_memberships").insert([
    { studio_id: studioA, user_id: staffAId, role: "trainer" },
    { studio_id: studioB, user_id: memberBId, role: "member" },
  ]);
  if (membershipError) throw membershipError;

  const { data: model, error: modelError } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioA, name: "Beinstrecker", weight_step_kg: 5 })
    .select("id")
    .single();
  if (modelError) throw modelError;

  const { data: exercise, error: exerciseError } = await admin
    .from("exercises")
    .insert({
      studio_id: studioA,
      name: "Beinstrecken",
      target_reps_min: 8,
      target_reps_max: 12,
    })
    .select("id")
    .single();
  if (exerciseError) throw exerciseError;

  const { data: link, error: linkError } = await admin
    .from("equipment_model_exercises")
    .insert({ equipment_model_id: model.id, exercise_id: exercise.id })
    .select("id")
    .single();
  if (linkError) throw linkError;
  linkId = link.id;
});

describe("RLS auf instruction_assets", () => {
  it("positiv: Staff kann ein Einweisungsvideo anlegen", async () => {
    const client = await userClient(staffAEmail);
    const { error } = await client.from("instruction_assets").insert({
      equipment_model_exercise_id: linkId,
      kind: "video",
      storage_path: "instructions/beinstrecken.mp4",
      duration_s: 30,
    });
    expect(error).toBeNull();
  });

  it("negativ: Video ueber 45 Sekunden wird abgelehnt", async () => {
    const client = await userClient(staffAEmail);
    const { error } = await client.from("instruction_assets").insert({
      equipment_model_exercise_id: linkId,
      kind: "video",
      storage_path: "instructions/zu-lang.mp4",
      duration_s: 60,
    });
    expect(error).not.toBeNull();
  });

  it("cross-tenant: Mitglied aus Studio B sieht das Video nicht", async () => {
    const client = await userClient(memberBEmail);
    const { data } = await client
      .from("instruction_assets")
      .select("id")
      .eq("equipment_model_exercise_id", linkId);
    expect(data).toEqual([]);
  });
});
```

- [ ] **Step 2: Test laufen lassen und Fehlschlag bestätigen**

```bash
pnpm test:integration
```

Erwartet: FAIL — `relation "public.instruction_assets" does not exist`.

- [ ] **Step 3: Migration schreiben**

`supabase/migrations/0006_instruction_assets.sql`:

```sql
create table public.instruction_assets (
  id                           uuid primary key default gen_random_uuid(),
  equipment_model_exercise_id  uuid not null references public.equipment_model_exercises (id) on delete cascade,
  kind                         text not null check (kind = 'video'),
  storage_path                 text not null check (length(trim(storage_path)) > 0),
  duration_s                   integer check (duration_s is null or (duration_s > 0 and duration_s <= 45)),
  created_at                   timestamptz not null default now()
);

create index on public.instruction_assets (equipment_model_exercise_id);

alter table public.instruction_assets enable row level security;
alter table public.instruction_assets force row level security;

create policy instruction_assets_select on public.instruction_assets
  for select to authenticated
  using (
    exists (
      select 1
      from public.equipment_model_exercises eme
      join public.equipment_models em on em.id = eme.equipment_model_id
      where eme.id = instruction_assets.equipment_model_exercise_id
        and public.is_studio_member(em.studio_id)
    )
  );

create policy instruction_assets_insert on public.instruction_assets
  for insert to authenticated
  with check (
    exists (
      select 1
      from public.equipment_model_exercises eme
      join public.equipment_models em on em.id = eme.equipment_model_id
      where eme.id = instruction_assets.equipment_model_exercise_id
        and public.is_studio_staff(em.studio_id)
    )
  );

create policy instruction_assets_update on public.instruction_assets
  for update to authenticated
  using (
    exists (
      select 1
      from public.equipment_model_exercises eme
      join public.equipment_models em on em.id = eme.equipment_model_id
      where eme.id = instruction_assets.equipment_model_exercise_id
        and public.is_studio_staff(em.studio_id)
    )
  )
  with check (
    exists (
      select 1
      from public.equipment_model_exercises eme
      join public.equipment_models em on em.id = eme.equipment_model_id
      where eme.id = instruction_assets.equipment_model_exercise_id
        and public.is_studio_staff(em.studio_id)
    )
  );

create policy instruction_assets_delete on public.instruction_assets
  for delete to authenticated
  using (
    exists (
      select 1
      from public.equipment_model_exercises eme
      join public.equipment_models em on em.id = eme.equipment_model_id
      where eme.id = instruction_assets.equipment_model_exercise_id
        and public.is_studio_staff(em.studio_id)
    )
  );
```

- [ ] **Step 4: Migration anwenden und Tests laufen lassen**

```bash
pnpm exec supabase db reset
pnpm test:integration
```

Erwartet: alle neuen Tests bestehen, alle bestehenden Tests bleiben grün.

- [ ] **Step 5: Committen**

```bash
git add supabase/migrations/0006_instruction_assets.sql tests/integration/rls-instruction-assets.test.ts
git commit -m "feat: instruction_assets mit 45-Sekunden-Formatgrenze"
```

---

## Task 5: `machines`

**Files:**
- Create: `supabase/migrations/0007_machines.sql`
- Test: `tests/integration/rls-machines.test.ts`

**Interfaces:**
- Consumes: `is_studio_member`, `is_studio_staff` aus Task 2; `equipment_models` aus Task 2
- Produces: Tabelle `machines`, Enum `public.machine_status`

- [ ] **Step 1: Den fehlschlagenden RLS-Test schreiben**

`tests/integration/rls-machines.test.ts`:

```ts
import { beforeAll, describe, expect, it } from "vitest";
import {
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";

let studioA: string;
let studioB: string;
let staffAEmail: string;
let memberAEmail: string;
let memberBEmail: string;
let modelA: string;
let modelB: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioError } = await admin
    .from("studios")
    .insert([{ name: "Machines Studio A" }, { name: "Machines Studio B" }])
    .select("id");
  if (studioError) throw studioError;
  studioA = studios[0]!.id;
  studioB = studios[1]!.id;

  staffAEmail = uniqueEmail("machines-staff-a");
  memberAEmail = uniqueEmail("machines-member-a");
  memberBEmail = uniqueEmail("machines-member-b");
  const staffAId = await createTestUser(staffAEmail);
  const memberAId = await createTestUser(memberAEmail);
  const memberBId = await createTestUser(memberBEmail);

  const { error: membershipError } = await admin.from("studio_memberships").insert([
    { studio_id: studioA, user_id: staffAId, role: "trainer" },
    { studio_id: studioA, user_id: memberAId, role: "member" },
    { studio_id: studioB, user_id: memberBId, role: "member" },
  ]);
  if (membershipError) throw membershipError;

  const { data: models, error: modelError } = await admin
    .from("equipment_models")
    .insert([
      { studio_id: studioA, name: "Rudergeraet", weight_step_kg: 5 },
      { studio_id: studioB, name: "Fremdgeraet", weight_step_kg: 5 },
    ])
    .select("id");
  if (modelError) throw modelError;
  modelA = models[0]!.id;
  modelB = models[1]!.id;
});

describe("RLS auf machines", () => {
  it("positiv: Staff kann eine Geraeteinstanz anlegen", async () => {
    const client = await userClient(staffAEmail);
    const { error } = await client.from("machines").insert({
      studio_id: studioA,
      equipment_model_id: modelA,
      label: "Rudergeraet 1",
    });
    expect(error).toBeNull();
  });

  it("negativ: Mitglied kann keine Geraeteinstanz anlegen", async () => {
    const client = await userClient(memberAEmail);
    const { error } = await client.from("machines").insert({
      studio_id: studioA,
      equipment_model_id: modelA,
      label: "Verboten",
    });
    expect(error).not.toBeNull();
  });

  it("negativ: Studio-uebergreifende Geraeteinstanz wird abgelehnt", async () => {
    const client = await userClient(staffAEmail);
    const { error } = await client.from("machines").insert({
      studio_id: studioA,
      equipment_model_id: modelB,
      label: "Fremdes Modell",
    });
    expect(error).not.toBeNull();
  });

  it("cross-tenant: Mitglied aus Studio B sieht Studio-A-Geraete nicht", async () => {
    const client = await userClient(memberBEmail);
    const { data } = await client
      .from("machines")
      .select("id")
      .eq("studio_id", studioA);
    expect(data).toEqual([]);
  });
});
```

- [ ] **Step 2: Test laufen lassen und Fehlschlag bestätigen**

```bash
pnpm test:integration
```

Erwartet: FAIL — `relation "public.machines" does not exist`.

- [ ] **Step 3: Migration schreiben**

`supabase/migrations/0007_machines.sql`:

```sql
create type public.machine_status as enum ('active', 'inactive');

create table public.machines (
  id                  uuid primary key default gen_random_uuid(),
  studio_id           uuid not null references public.studios (id) on delete cascade,
  equipment_model_id  uuid not null references public.equipment_models (id) on delete restrict,
  label               text not null check (length(trim(label)) > 0),
  location_note       text,
  status              public.machine_status not null default 'active',
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

create index on public.machines (studio_id);
create index on public.machines (equipment_model_id);

alter table public.machines enable row level security;
alter table public.machines force row level security;

create policy machines_select on public.machines
  for select to authenticated
  using (public.is_studio_member(studio_id));

-- Wie equipment_model_exercises: die Policy erzwingt zugleich, dass das
-- referenzierte Geraetemodell demselben Studio gehoert wie die Instanz.
--
-- WICHTIG: Die Spalten der machines-Zeile MUESSEN hier mit dem Tabellennamen
-- qualifiziert werden (machines.studio_id, nicht studio_id). Unqualifiziert
-- loest PostgreSQL den Namen gegen die INNERE Tabelle der Unterabfrage auf --
-- equipment_models hat ebenfalls eine Spalte studio_id, sodass aus
-- "em.studio_id = studio_id" ein wirkungsloses "em.studio_id = em.studio_id"
-- wuerde und die Studio-Pruefung stillschweigend nichts pruefte.
create policy machines_insert on public.machines
  for insert to authenticated
  with check (
    public.is_studio_staff(machines.studio_id)
    and exists (
      select 1 from public.equipment_models em
      where em.id = machines.equipment_model_id
        and em.studio_id = machines.studio_id
    )
  );

create policy machines_update on public.machines
  for update to authenticated
  using (public.is_studio_staff(machines.studio_id))
  with check (
    public.is_studio_staff(machines.studio_id)
    and exists (
      select 1 from public.equipment_models em
      where em.id = machines.equipment_model_id
        and em.studio_id = machines.studio_id
    )
  );

create policy machines_delete on public.machines
  for delete to authenticated
  using (public.is_studio_staff(machines.studio_id));
```

- [ ] **Step 4: Migration anwenden und Tests laufen lassen**

```bash
pnpm exec supabase db reset
pnpm test:integration
```

Erwartet: alle neuen Tests bestehen, alle bestehenden Tests bleiben grün.

- [ ] **Step 5: Committen**

```bash
git add supabase/migrations/0007_machines.sql tests/integration/rls-machines.test.ts
git commit -m "feat: machines mit Studio-Konsistenzpruefung gegen equipment_models"
```

---

## Task 6: `machine_tags` bekommt seinen Fremdschlüssel — und zwei bestehende Fixtures müssen mitziehen

**Hintergrund:** M0s Migration `0002_machine_tags.sql` hat `machine_id` bewusst ohne Fremdschlüssel und ohne Check-Constraint gelassen, mit dem dokumentierten Versprechen, das hier nachzuholen. Das bricht zwei bestehende Test-Fixtures, die einen `status: 'active'`-Tag ohne `machine_id` anlegen — beide werden in diesem Task korrigiert.

**Files:**
- Create: `supabase/migrations/0008_machine_tags_fk.sql`
- Modify: `tests/integration/rls-machine-tags.test.ts`
- Modify: `e2e/tag-fallback.spec.ts`

**Interfaces:**
- Consumes: `machines` aus Task 5
- Produces: Fremdschlüssel `machine_tags.machine_id -> machines.id`; Check-Constraint `status <> 'active' or machine_id is not null`

- [ ] **Step 1: Migration schreiben**

`supabase/migrations/0008_machine_tags_fk.sql`:

```sql
-- on delete restrict, nicht set null: ein gelöschtes Geraet wuerde sonst bei
-- revozierten Tags die machine_id stillschweigend auf NULL setzen und damit
-- die fachliche Historie zerstoeren (welcher Tag hing an welchem Geraet), und
-- bei aktiven Tags mit einem kryptischen Verstoss gegen die Check-Constraint
-- unten abbrechen. Restrict macht die Regel explizit: bevor ein Geraet
-- geloescht werden kann, muessen seine Tags bewusst umgehaengt oder entfernt
-- werden. Konsistent mit machines.equipment_model_id (ebenfalls restrict).
alter table public.machine_tags
  add constraint machine_tags_machine_id_fkey
    foreign key (machine_id) references public.machines (id) on delete restrict;

alter table public.machine_tags
  add constraint machine_tags_active_needs_machine
    check (status <> 'active' or machine_id is not null);
```

- [ ] **Step 2: Migration anwenden und bestehende Tests laufen lassen — Fehlschlag bestätigen**

```bash
pnpm exec supabase db reset
pnpm test:integration
```

Erwartet: FAIL in `tests/integration/rls-machine-tags.test.ts` — der `beforeAll`-Hook verletzt jetzt `machine_tags_active_needs_machine` (zwei `status: 'active'`-Inserts ohne `machine_id`).

- [ ] **Step 3: `tests/integration/rls-machine-tags.test.ts` korrigieren**

Den `beforeAll`-Block ersetzen (nur dieser Block ändert sich, der Rest der Datei bleibt unverändert):

```ts
beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioError } = await admin
    .from("studios")
    .insert([{ name: "Tag-Studio A" }, { name: "Tag-Studio B" }])
    .select("id");
  if (studioError) throw studioError;
  studioA = studios[0]!.id;
  studioB = studios[1]!.id;

  emailA = uniqueEmail("tag-a");
  const userA = await createTestUser(emailA);
  const { error: membershipError } = await admin
    .from("studio_memberships")
    .insert({ studio_id: studioA, user_id: userA, role: "member" });
  if (membershipError) throw membershipError;

  const { data: models, error: modelError } = await admin
    .from("equipment_models")
    .insert([
      { studio_id: studioA, name: "Tag-Testgeraet A", weight_step_kg: 5 },
      { studio_id: studioB, name: "Tag-Testgeraet B", weight_step_kg: 5 },
    ])
    .select("id");
  if (modelError) throw modelError;

  const { data: machines, error: machineError } = await admin
    .from("machines")
    .insert([
      { studio_id: studioA, equipment_model_id: models[0]!.id, label: "Geraet A" },
      { studio_id: studioB, equipment_model_id: models[1]!.id, label: "Geraet B" },
    ])
    .select("id");
  if (machineError) throw machineError;

  tokenA = createTagToken();
  tokenB = createTagToken();
  const { error: tagError } = await admin.from("machine_tags").insert([
    {
      studio_id: studioA,
      machine_id: machines[0]!.id,
      token_hash: hashTagToken(tokenA),
      status: "active",
    },
    {
      studio_id: studioB,
      machine_id: machines[1]!.id,
      token_hash: hashTagToken(tokenB),
      status: "active",
    },
  ]);
  if (tagError) throw tagError;
});
```

- [ ] **Step 4: Tests laufen lassen — bestätigen, dass `rls-machine-tags.test.ts` wieder grün ist**

```bash
pnpm test:integration
```

Erwartet: alle Tests in `rls-machine-tags.test.ts` bestehen wieder.

- [ ] **Step 5: E2E-Test laufen lassen — Fehlschlag im dritten Testfall bestätigen**

```bash
pnpm test:e2e
```

Erwartet: FAIL im Test „aktiver Tag ohne Geraet zeigt den Installationshinweis" (`e2e/tag-fallback.spec.ts`) — derselbe Constraint-Verstoß wie in Step 2.

- [ ] **Step 6: `e2e/tag-fallback.spec.ts` korrigieren**

Den dritten Testfall (`"aktiver Tag ohne Geraet zeigt den Installationshinweis"`) ersetzen und einen neuen Testfall für den Status `unassigned` ergänzen. Die Datei sieht danach so aus:

```ts
import { expect, test } from "@playwright/test";
import { createClient } from "@supabase/supabase-js";
import { createTagToken, hashTagToken } from "@fitretro/domain";

function admin() {
  return createClient(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    { auth: { persistSession: false } },
  );
}

test("unbekannter Token zeigt eine neutrale Fehlermeldung", async ({ page }) => {
  await page.goto(`/t/${createTagToken()}`);
  await expect(page.getByTestId("tag-unknown")).toBeVisible();
});

test("ungueltiges Tokenformat zeigt dieselbe neutrale Meldung", async ({
  page,
}) => {
  await page.goto("/t/viel-zu-kurz");
  await expect(page.getByTestId("tag-unknown")).toBeVisible();
});

test("aktiver Tag mit zugewiesenem Geraet zeigt den Installationshinweis", async ({
  page,
}) => {
  const client = admin();
  const { data: studio, error: studioError } = await client
    .from("studios")
    .insert({ name: "Fallback Studio" })
    .select("id")
    .single();
  if (studioError) throw studioError;

  const { data: model, error: modelError } = await client
    .from("equipment_models")
    .insert({ studio_id: studio.id, name: "Testgeraet", weight_step_kg: 5 })
    .select("id")
    .single();
  if (modelError) throw modelError;

  const { data: machine, error: machineError } = await client
    .from("machines")
    .insert({
      studio_id: studio.id,
      equipment_model_id: model.id,
      label: "Testgeraet 1",
    })
    .select("id")
    .single();
  if (machineError) throw machineError;

  const token = createTagToken();
  const { error: tagError } = await client.from("machine_tags").insert({
    studio_id: studio.id,
    machine_id: machine.id,
    token_hash: hashTagToken(token),
    status: "active",
  });
  if (tagError) throw tagError;

  await page.goto(`/t/${token}`);
  await expect(page.getByTestId("install-hint")).toBeVisible();
});

test("noch nicht zugewiesener Tag zeigt dieselbe neutrale Meldung", async ({
  page,
}) => {
  const client = admin();
  const { data: studio, error: studioError } = await client
    .from("studios")
    .insert({ name: "Unassigned Studio" })
    .select("id")
    .single();
  if (studioError) throw studioError;

  const token = createTagToken();
  const { error: tagError } = await client.from("machine_tags").insert({
    studio_id: studio.id,
    token_hash: hashTagToken(token),
    status: "unassigned",
  });
  if (tagError) throw tagError;

  await page.goto(`/t/${token}`);
  await expect(page.getByTestId("tag-unknown")).toBeVisible();
});

test("gesperrter Tag liefert keine Geraetedaten", async ({ page }) => {
  const client = admin();
  const { data: studio, error: studioError } = await client
    .from("studios")
    .insert({ name: "Revoked Studio" })
    .select("id")
    .single();
  if (studioError) throw studioError;

  const token = createTagToken();
  const { error: tagError } = await client.from("machine_tags").insert({
    studio_id: studio.id,
    token_hash: hashTagToken(token),
    status: "revoked",
  });
  if (tagError) throw tagError;

  await page.goto(`/t/${token}`);
  await expect(page.getByTestId("tag-unknown")).toBeVisible();
});
```

- [ ] **Step 7: Alle Tests einmal komplett laufen lassen**

```bash
pnpm typecheck
pnpm test
pnpm test:integration
pnpm test:e2e
```

Erwartet: alles grün — inklusive des neuen fünften E2E-Tests (vorher vier, jetzt fünf Testfälle in `tag-fallback.spec.ts`).

- [ ] **Step 8: Committen**

```bash
git add supabase/migrations/0008_machine_tags_fk.sql tests/integration/rls-machine-tags.test.ts e2e/tag-fallback.spec.ts
git commit -m "feat: machine_tags.machine_id bekommt Fremdschluessel und Aktiv-Constraint"
```

---

## Nach diesem Plan

Es existieren dann: 8 zusätzliche Migrationen (der Web-Fallback braucht keinen Service-Role-Key mehr; der komplette Gerätekatalog mit rollenbasierter RLS steht; `machine_tags` ist vollständig an `machines` gebunden). Kein neues UI, keine Storage-Buckets, kein Medien-Upload — das ist der nächste Plan („Trainer-Weboberfläche"), der auf diesem Schema aufbaut:

- Trainer-Web-UI zum Anlegen/Bearbeiten von Gerätemodellen, Übungen, Einstellparametern
- Tag-Zuweisung (Tag ↔ Geräteinstanz) über die Oberfläche statt direkt in der DB — **inklusive der in diesem Plan bewusst ausgelassenen Insert/Update-RLS-Policies auf `machine_tags` für Trainer/Owner** (siehe Global Constraints oben)
- Medien-Upload für `equipment_models.photo_path` und `instruction_assets.storage_path` mit den Formatgrenzen aus Spec Abschnitt 6.8 (Private Buckets, signierte URLs, kein Transcoding)
- Erweiterung von `resolve_tag_fallback` und der Fallback-Seite um Gerätename/Foto/Einweisung (Spec Abschnitt 6.4) — erst sinnvoll, sobald echte Inhalte existieren
