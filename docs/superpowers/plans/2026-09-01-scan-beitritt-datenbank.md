# Beitritt durch Scannen — Datenbank und Portal

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ein Scan auf einen aktiven Tag macht das scannende Konto zum Mitglied des zugehörigen Studios — mit Aushang-Tags, Selbstaustritt und einem Web-Fallback, der den Kaltstart benennt.

> **Task 5 ist gestrichen.** Die Aushang-Verwaltung im Portal stand ursprünglich mit im Ziel; sie ist von `2026-09-01-einrichtung-am-geraet-design.md` abgelöst worden, weil Tags jetzt als Lieferung kommen und das Portal keine Tokens mehr erzeugt. Zu bauen bleiben **fünf** Aufgaben: drei Migrationen, die Fachschicht und der Web-Fallback.

**Architecture:** Die Beitrittslogik liegt in einer `SECURITY DEFINER`-Funktion, nicht in einer Insert-Policy: ein Nicht-Mitglied darf `machine_tags` nicht lesen, kann also die Zuordnung nicht selbst herstellen. `machine_tags` bekommt eine Spalte `kind`, statt eine zweite Tabelle zu erhalten — Tokenraum, URL und Auflösung bleiben eins. Portal und Web-Fallback sind Next.js App Router; die Fachschicht liegt in `@fitretro/domain` und wird gegen echtes Postgres mit aktiver RLS getestet.

**Tech Stack:** PostgreSQL über Supabase (SQL-Migrationen in `supabase/migrations/`), TypeScript, Next.js App Router, Vitest für Integrationstests gegen eine laufende Datenbank, Playwright für E2E.

**Spec:** `docs/superpowers/specs/2026-09-01-scan-beitritt-design.md`

## Global Constraints

- **Migrationen sind fortlaufend nummeriert und werden nie geändert.** Nächste freie Nummer: `0022`. Eine bereits gepushte Migration wird durch eine neue korrigiert, nicht überschrieben.
- **Jede `SECURITY DEFINER`-Funktion braucht beide Zeilen** — das ist die Lehre aus `0009`, und sie ist keine Formalie:
  ```sql
  revoke all on function public.<name>(<typen>) from public, anon, authenticated, service_role;
  grant execute on function public.<name>(<typen>) to <rolle>;
  ```
  `revoke ... from public` allein genügt auf Supabase **nicht**: `ALTER DEFAULT PRIVILEGES` gewährt `EXECUTE` zusätzlich an `anon`, `authenticated` und `service_role`. Ohne den ausdrücklichen Entzug ist die Funktion faktisch für alle drei aufrufbar.
- **Jede `SECURITY DEFINER`-Funktion setzt `set search_path = public, pg_temp`.**
- **Unbekannt, gesperrt und nicht zugewiesen antworten identisch** — leeres Ergebnis, nie ein unterscheidbarer Fehler. Differenziert eine Antwort, lassen sich gültige Tokens durch Ausprobieren finden.
- **Der Klartext-Token existiert genau einmal.** `createTag` gibt ihn zurück, gespeichert wird nur `token_hash`. Er darf nirgends protokolliert werden und ist später **nicht wiederherstellbar** — jede Oberfläche muss damit rechnen, dass es keinen zweiten Blick gibt.
- **Die Rolle beim Beitritt ist immer `member`.** Nie `trainer`, nie `owner`, und niemals als Parameter von außen.
- **Fehlercodes der Fachschicht** sind ausschließlich `validation_failed`, `unauthorized`, `not_found`, `conflict`, `internal` (`packages/domain/src/errors.ts`). Ein Objekt aus einem fremden Studio liefert `not_found`, nicht `unauthorized`.
- **Tests laufen gegen echtes Postgres.** `pnpm test:integration` braucht `SUPABASE_URL`, `SUPABASE_ANON_KEY` und den Service-Key in der Umgebung; `fileParallelism` ist aus.
- **Nach Migrationen:** `pnpm exec supabase db reset` lokal, `pnpm exec supabase db push` gegen das verknüpfte Projekt.

---

### Task 1: Migration 0022 — die zweite Tag-Sorte

**Files:**
- Create: `supabase/migrations/0022_studio_tags.sql`
- Test: `tests/integration/machine-tags-kind.test.ts`

**Interfaces:**
- Consumes: `public.machine_tags` und `public.tag_status` aus `0002`, den Check-Constraint `machine_tags_active_needs_machine` aus `0008`.
- Produces: den Enum-Typ `public.tag_kind` mit den Werten `'machine'` und `'studio'`, die Spalte `machine_tags.kind` (`not null default 'machine'`) und den Constraint `machine_tags_machine_kind`. Task 2 und Task 4 bauen darauf auf.

- [ ] **Step 1: Den fehlschlagenden Test schreiben**

`tests/integration/machine-tags-kind.test.ts`:

```ts
import { beforeAll, describe, expect, it } from "vitest";
import { createTagToken, hashTagToken } from "@fitretro/domain";
import { serviceClient } from "./helpers/clients.js";

let studioId: string;
let machineId: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studio, error: studioError } = await admin
    .from("studios")
    .insert({ name: "Tag-Sorten Studio" })
    .select("id")
    .single();
  if (studioError) throw studioError;
  studioId = studio.id;

  const { data: model, error: modelError } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioId, name: "Tag-Sorten Geraet", weight_step_kg: 5 })
    .select("id")
    .single();
  if (modelError) throw modelError;

  const { data: machine, error: machineError } = await admin
    .from("machines")
    .insert({ studio_id: studioId, equipment_model_id: model.id, label: "01" })
    .select("id")
    .single();
  if (machineError) throw machineError;
  machineId = machine.id;
});

describe("machine_tags.kind", () => {
  it("legt bestehende und neue Zeilen als 'machine' an", async () => {
    const admin = serviceClient();
    const { data, error } = await admin
      .from("machine_tags")
      .insert({
        studio_id: studioId,
        machine_id: machineId,
        token_hash: hashTagToken(createTagToken()),
        status: "active",
      })
      .select("kind")
      .single();
    expect(error).toBeNull();
    expect(data?.kind).toBe("machine");
  });

  it("speichert einen aktiven Aushang ohne Geraet", async () => {
    const admin = serviceClient();
    const { data, error } = await admin
      .from("machine_tags")
      .insert({
        studio_id: studioId,
        kind: "studio",
        token_hash: hashTagToken(createTagToken()),
        status: "active",
      })
      .select("id, kind, machine_id")
      .single();
    expect(error).toBeNull();
    expect(data?.kind).toBe("studio");
    expect(data?.machine_id).toBeNull();
  });

  it("lehnt einen Aushang mit Geraet ab", async () => {
    const admin = serviceClient();
    const { error } = await admin.from("machine_tags").insert({
      studio_id: studioId,
      kind: "studio",
      machine_id: machineId,
      token_hash: hashTagToken(createTagToken()),
      status: "active",
    });
    expect(error).not.toBeNull();
  });

  it("lehnt einen aktiven Geraetetag ohne Geraet weiterhin ab", async () => {
    // Der Schutz aus 0008 darf beim Umbau nicht verloren gehen.
    const admin = serviceClient();
    const { error } = await admin.from("machine_tags").insert({
      studio_id: studioId,
      kind: "machine",
      token_hash: hashTagToken(createTagToken()),
      status: "active",
    });
    expect(error).not.toBeNull();
  });
});
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag bestätigen**

```bash
pnpm test:integration -- machine-tags-kind
```

Erwartet: FAIL. Der zweite und der dritte Test scheitern, weil die Spalte `kind` nicht existiert.

- [ ] **Step 3: Die Migration schreiben**

`supabase/migrations/0022_studio_tags.sql`:

```sql
-- Ein Aushang am Eingang traegt denselben Tokenraum und dieselbe URL wie ein
-- Geraeteaufkleber -- nur zeigt er auf kein Geraet. Eine Spalte statt einer
-- zweiten Tabelle: eine Umbenennung von machine_tags zoege sechs Migrationen,
-- zwei Policies, zwei Indizes und resolve_tag_fallback hinter sich her.
create type public.tag_kind as enum ('machine', 'studio');

alter table public.machine_tags
  add column kind public.tag_kind not null default 'machine';

comment on column public.machine_tags.kind is
  'machine = Aufkleber am Geraet, studio = Aushang am Eingang. Der Tabellenname stammt aus 0002, als es nur die erste Sorte gab.';

-- 0008 verlangte: ein aktiver Tag haengt an einem Geraet. Ein Aushang hat
-- keines und muss aktiv sein. Die Regel faellt nicht ersatzlos -- sonst
-- verliert der Geraetefall seinen Schutz --, sie differenziert nach Sorte.
alter table public.machine_tags
  drop constraint machine_tags_active_needs_machine;

alter table public.machine_tags
  add constraint machine_tags_machine_kind
    check (case kind
             when 'machine' then status <> 'active' or machine_id is not null
             when 'studio'  then machine_id is null
           end);
```

- [ ] **Step 4: Datenbank zurücksetzen und Test laufen lassen**

```bash
pnpm exec supabase db reset
pnpm test:integration -- machine-tags-kind
```

Erwartet: PASS, vier Tests.

- [ ] **Step 5: Die bestehende Tag-Testsuite muss unberührt durchlaufen**

```bash
pnpm test:integration -- rls-machine-tags resolve-tag-fallback domain-catalog
```

Erwartet: PASS. Schlägt hier etwas fehl, hat der Constraint-Umbau einen bestehenden Pfad verletzt — das ist der eigentliche Zweck dieses Schritts.

- [ ] **Step 6: Commit**

```bash
git add supabase/migrations/0022_studio_tags.sql tests/integration/machine-tags-kind.test.ts
git commit -m "feat(db): Aushang-Tags als zweite Tag-Sorte"
```

---

### Task 2: Migration 0023 — Beitritt durch Scannen

**Files:**
- Create: `supabase/migrations/0023_join_studio_by_tag.sql`
- Test: `tests/integration/join-studio-by-tag.test.ts`

**Interfaces:**
- Consumes: `machine_tags.kind` aus Task 1, `studio_memberships` und `studio_role` aus `0001`.
- Produces: `public.join_studio_by_tag(p_token_hash text)`, ausführbar nur für `authenticated`, Rückgabe `table (studio_id uuid, machine_id uuid, joined boolean)`. Task 7 ruft sie auf.

- [ ] **Step 1: Den fehlschlagenden Test schreiben**

`tests/integration/join-studio-by-tag.test.ts`:

```ts
import { beforeAll, describe, expect, it } from "vitest";
import { createClient } from "@supabase/supabase-js";
import { createTagToken, hashTagToken } from "@fitretro/domain";
import { serviceClient, createTestUser, userClient, uniqueEmail } from "./helpers/clients.js";

function anonClient() {
  const url = process.env.SUPABASE_URL;
  const anonKey = process.env.SUPABASE_ANON_KEY;
  if (!url || !anonKey) throw new Error("SUPABASE_URL/SUPABASE_ANON_KEY fehlen");
  return createClient(url, anonKey, { auth: { persistSession: false } });
}

let studioId: string;
let machineId: string;
let geraetToken: string;
let aushangToken: string;
let gesperrtToken: string;
let fremdEmail: string;
let trainerEmail: string;
let trainerId: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studio, error: studioError } = await admin
    .from("studios")
    .insert({ name: "Beitritts-Studio" })
    .select("id")
    .single();
  if (studioError) throw studioError;
  studioId = studio.id;

  const { data: model, error: modelError } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioId, name: "Beitritts-Geraet", weight_step_kg: 5 })
    .select("id")
    .single();
  if (modelError) throw modelError;

  const { data: machine, error: machineError } = await admin
    .from("machines")
    .insert({ studio_id: studioId, equipment_model_id: model.id, label: "07" })
    .select("id")
    .single();
  if (machineError) throw machineError;
  machineId = machine.id;

  geraetToken = createTagToken();
  aushangToken = createTagToken();
  gesperrtToken = createTagToken();
  const { error: tagError } = await admin.from("machine_tags").insert([
    {
      studio_id: studioId,
      machine_id: machineId,
      token_hash: hashTagToken(geraetToken),
      status: "active",
    },
    {
      studio_id: studioId,
      kind: "studio",
      token_hash: hashTagToken(aushangToken),
      status: "active",
    },
    { studio_id: studioId, token_hash: hashTagToken(gesperrtToken), status: "revoked" },
  ]);
  if (tagError) throw tagError;

  fremdEmail = uniqueEmail("beitritt-fremd");
  await createTestUser(fremdEmail);

  trainerEmail = uniqueEmail("beitritt-trainer");
  trainerId = await createTestUser(trainerEmail);
  const { error: mitgliedError } = await admin
    .from("studio_memberships")
    .insert({ studio_id: studioId, user_id: trainerId, role: "trainer" });
  if (mitgliedError) throw mitgliedError;
});

describe("join_studio_by_tag", () => {
  it("macht ein fremdes Konto durch einen Geraetetag zum Mitglied", async () => {
    const client = await userClient(fremdEmail);
    const { data, error } = await client.rpc("join_studio_by_tag", {
      p_token_hash: hashTagToken(geraetToken),
    });
    expect(error).toBeNull();
    expect(data).toHaveLength(1);
    expect(data[0].studio_id).toBe(studioId);
    expect(data[0].machine_id).toBe(machineId);
    expect(data[0].joined).toBe(true);
  });

  it("ist beim zweiten Scan wirkungslos und meldet joined = false", async () => {
    const client = await userClient(fremdEmail);
    const { data, error } = await client.rpc("join_studio_by_tag", {
      p_token_hash: hashTagToken(geraetToken),
    });
    expect(error).toBeNull();
    expect(data[0].joined).toBe(false);

    const admin = serviceClient();
    const { data: zeilen } = await admin
      .from("studio_memberships")
      .select("id")
      .eq("studio_id", studioId);
    // Trainer plus genau ein beigetretenes Mitglied -- kein Duplikat.
    expect(zeilen).toHaveLength(2);
  });

  it("liefert beim Aushang ein Studio ohne Geraet", async () => {
    const email = uniqueEmail("beitritt-aushang");
    await createTestUser(email);
    const client = await userClient(email);
    const { data, error } = await client.rpc("join_studio_by_tag", {
      p_token_hash: hashTagToken(aushangToken),
    });
    expect(error).toBeNull();
    expect(data[0].studio_id).toBe(studioId);
    expect(data[0].machine_id).toBeNull();
    expect(data[0].joined).toBe(true);
  });

  it("stuft einen Trainer nicht auf member zurueck", async () => {
    const client = await userClient(trainerEmail);
    const { error } = await client.rpc("join_studio_by_tag", {
      p_token_hash: hashTagToken(geraetToken),
    });
    expect(error).toBeNull();

    const admin = serviceClient();
    const { data } = await admin
      .from("studio_memberships")
      .select("role")
      .eq("studio_id", studioId)
      .eq("user_id", trainerId)
      .single();
    expect(data?.role).toBe("trainer");
  });

  it("liefert nichts fuer einen gesperrten Token und traegt niemanden ein", async () => {
    const email = uniqueEmail("beitritt-gesperrt");
    const userId = await createTestUser(email);
    const client = await userClient(email);
    const { data, error } = await client.rpc("join_studio_by_tag", {
      p_token_hash: hashTagToken(gesperrtToken),
    });
    expect(error).toBeNull();
    expect(data).toEqual([]);

    const admin = serviceClient();
    const { data: zeilen } = await admin
      .from("studio_memberships")
      .select("id")
      .eq("user_id", userId);
    expect(zeilen).toEqual([]);
  });

  it("liefert nichts fuer einen unbekannten Token", async () => {
    const email = uniqueEmail("beitritt-unbekannt");
    await createTestUser(email);
    const client = await userClient(email);
    const { data, error } = await client.rpc("join_studio_by_tag", {
      p_token_hash: hashTagToken(createTagToken()),
    });
    expect(error).toBeNull();
    expect(data).toEqual([]);
  });

  it("ist fuer anon nicht aufrufbar", async () => {
    // Regressionstest fuer 0009: ohne den Entzug der Default-Grants waere
    // die Funktion fuer anon faktisch aufrufbar -- und damit ein Orakel.
    const { error } = await anonClient().rpc("join_studio_by_tag", {
      p_token_hash: hashTagToken(geraetToken),
    });
    expect(error).not.toBeNull();
  });
});
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag bestätigen**

```bash
pnpm test:integration -- join-studio-by-tag
```

Erwartet: FAIL, `function public.join_studio_by_tag(text) does not exist` in allen Tests außer dem letzten.

- [ ] **Step 3: Die Migration schreiben**

`supabase/migrations/0023_join_studio_by_tag.sql`:

```sql
-- Der Beitritt liegt in einer Funktion, nicht in einer Insert-Policy: ein
-- Nicht-Mitglied darf machine_tags nicht lesen (machine_tags_select verlangt
-- is_studio_member), kann die Zuordnung also nicht selbst herstellen. Ein
-- Insert-Recht auf studio_memberships waere zudem breiter als noetig -- es
-- erlaubte, sich in ein beliebiges Studio einzutragen, statt nur in das,
-- dessen Tag man in der Hand haelt.
create or replace function public.join_studio_by_tag(p_token_hash text)
returns table (studio_id uuid, machine_id uuid, joined boolean)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user    uuid := auth.uid();
  v_studio  uuid;
  v_machine uuid;
  v_neu     boolean;
begin
  if v_user is null then
    return;
  end if;

  -- Unbekannt, gesperrt und nicht zugewiesen antworten identisch: leer.
  -- Differenzierte Antworten machten die Funktion zum Orakel, mit dem sich
  -- gueltige Tokens durch Ausprobieren finden liessen.
  select t.studio_id, t.machine_id
    into v_studio, v_machine
    from public.machine_tags t
   where t.token_hash = p_token_hash
     and t.status = 'active';

  if v_studio is null then
    return;
  end if;

  -- do nothing, nicht do update: ein Trainer, der ein Geraet im eigenen
  -- Studio scannt, darf dabei nicht auf member zurueckfallen. Die Rolle
  -- steht fest im Rumpf und kommt nie von aussen -- ein Scan macht zum
  -- Mitglied, nie zum Trainer.
  insert into public.studio_memberships (studio_id, user_id, role)
  values (v_studio, v_user, 'member')
  on conflict (studio_id, user_id) do nothing;

  v_neu := found;

  return query select v_studio, v_machine, v_neu;
end;
$$;

-- revoke ... from public allein genuegt auf Supabase nicht (siehe 0009).
revoke all on function public.join_studio_by_tag(text)
  from public, anon, authenticated, service_role;
grant execute on function public.join_studio_by_tag(text) to authenticated;
```

- [ ] **Step 4: Datenbank zurücksetzen und Test laufen lassen**

```bash
pnpm exec supabase db reset
pnpm test:integration -- join-studio-by-tag
```

Erwartet: PASS, sieben Tests.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/0023_join_studio_by_tag.sql tests/integration/join-studio-by-tag.test.ts
git commit -m "feat(db): Beitritt durch Scannen als SECURITY DEFINER-Funktion"
```

---

### Task 3: Migration 0024 — Selbstaustritt

**Files:**
- Create: `supabase/migrations/0024_membership_self_leave.sql`
- Test: `tests/integration/rls-membership-self-leave.test.ts`

**Interfaces:**
- Consumes: `studio_memberships` und `memberships_select_own` aus `0001`.
- Produces: die Policy `memberships_delete_own_membership`. Keine spätere Aufgabe baut darauf auf; sie ist die Kehrseite von Task 2.

- [ ] **Step 1: Den fehlschlagenden Test schreiben**

`tests/integration/rls-membership-self-leave.test.ts`:

```ts
import { beforeAll, describe, expect, it } from "vitest";
import { serviceClient, createTestUser, userClient, uniqueEmail } from "./helpers/clients.js";

let studioId: string;
let mitgliedEmail: string;
let mitgliedId: string;
let trainerEmail: string;
let trainerId: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studio, error: studioError } = await admin
    .from("studios")
    .insert({ name: "Austritts-Studio" })
    .select("id")
    .single();
  if (studioError) throw studioError;
  studioId = studio.id;

  mitgliedEmail = uniqueEmail("austritt-mitglied");
  mitgliedId = await createTestUser(mitgliedEmail);
  trainerEmail = uniqueEmail("austritt-trainer");
  trainerId = await createTestUser(trainerEmail);

  const { error } = await admin.from("studio_memberships").insert([
    { studio_id: studioId, user_id: mitgliedId, role: "member" },
    { studio_id: studioId, user_id: trainerId, role: "trainer" },
  ]);
  if (error) throw error;
});

describe("Selbstaustritt", () => {
  it("ein Trainer kann sich selbst nicht entfernen", async () => {
    const client = await userClient(trainerEmail);
    await client.from("studio_memberships").delete().eq("user_id", trainerId);

    const admin = serviceClient();
    const { data } = await admin
      .from("studio_memberships")
      .select("id")
      .eq("user_id", trainerId);
    expect(data).toHaveLength(1);
  });

  it("ein Mitglied kann eine fremde Mitgliedschaft nicht entfernen", async () => {
    const client = await userClient(mitgliedEmail);
    await client.from("studio_memberships").delete().eq("user_id", trainerId);

    const admin = serviceClient();
    const { data } = await admin
      .from("studio_memberships")
      .select("id")
      .eq("user_id", trainerId);
    expect(data).toHaveLength(1);
  });

  it("ein Mitglied kann die eigene Mitgliedschaft entfernen", async () => {
    const client = await userClient(mitgliedEmail);
    const { error } = await client
      .from("studio_memberships")
      .delete()
      .eq("user_id", mitgliedId);
    expect(error).toBeNull();

    const admin = serviceClient();
    const { data } = await admin
      .from("studio_memberships")
      .select("id")
      .eq("user_id", mitgliedId);
    expect(data).toEqual([]);
  });
});
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag bestätigen**

```bash
pnpm test:integration -- rls-membership-self-leave
```

Erwartet: FAIL im dritten Test — ohne Delete-Policy verweigert RLS auch dem Eigentümer, die Zeile bleibt stehen. Die ersten beiden Tests bestehen schon jetzt und sind der Beweis, dass die Migration nichts aufreißt.

- [ ] **Step 3: Die Migration schreiben**

`supabase/migrations/0024_membership_self_leave.sql`:

```sql
-- Wer mit einem Tap beitritt, muss mit einem Tap gehen koennen. Das ist die
-- Kehrseite von 0023: ohne Rueckweg waere ein versehentlicher Scan eine
-- Mitgliedschaft, die nur das Studio wieder aufloesen kann.
--
-- Die Einschraenkung auf 'member' haelt die Regel, dass sich niemand selbst
-- die letzte Inhaberrolle entzieht, ohne dafuer zaehlen zu muessen. Trainer
-- und Inhaber werden weiterhin unter Leute -> Mitarbeiter entfernt.
create policy memberships_delete_own_membership on public.studio_memberships
  for delete to authenticated
  using (user_id = auth.uid() and role = 'member');
```

- [ ] **Step 4: Datenbank zurücksetzen und Test laufen lassen**

```bash
pnpm exec supabase db reset
pnpm test:integration -- rls-membership-self-leave rls-tenancy
```

Erwartet: PASS in beiden Dateien.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/0024_membership_self_leave.sql tests/integration/rls-membership-self-leave.test.ts
git commit -m "feat(db): Mitglieder koennen ihre Mitgliedschaft selbst beenden"
```

---

### Task 4: Fachschicht — Aushang anlegen und lesen

**Files:**
- Modify: `packages/domain/src/catalog.ts` (`createTag` ab Zeile 492, `CatalogTag` ab Zeile 628, die Tag-Abfrage in `getStudioCatalog`)
- Test: `tests/integration/domain-catalog.test.ts` (ergänzen, nicht ersetzen)

**Interfaces:**
- Consumes: `machine_tags.kind` aus Task 1.
- Produces:
  - `createTag(client, { studioId, machineId?, kind? })` mit `kind?: "machine" | "studio"`, Vorgabe `"machine"`
  - `CatalogTag` um das Feld `kind: "machine" | "studio"` erweitert

- [ ] **Step 1: Den fehlschlagenden Test an `domain-catalog.test.ts` anhängen**

```ts
describe("createTag mit Aushang", () => {
  it("legt einen Aushang sofort aktiv und ohne Geraet an", async () => {
    const client = await userClient(trainerEmail);
    const tag = await createTag(client, { studioId, kind: "studio" });

    const admin = serviceClient();
    const { data } = await admin
      .from("machine_tags")
      .select("kind, status, machine_id")
      .eq("id", tag.id)
      .single();
    expect(data?.kind).toBe("studio");
    expect(data?.status).toBe("active");
    expect(data?.machine_id).toBeNull();
  });

  it("weist einen Aushang mit Geraet ab", async () => {
    const client = await userClient(trainerEmail);
    await expect(
      createTag(client, { studioId, machineId, kind: "studio" }),
    ).rejects.toMatchObject({ code: "validation_failed" });
  });

  it("liefert die Sorte im Katalog mit", async () => {
    const client = await userClient(trainerEmail);
    const katalog = await getStudioCatalog(client, studioId);
    expect(katalog.tags.every((tag) => tag.kind === "machine" || tag.kind === "studio")).toBe(true);
  });
});
```

*Die Namen `trainerEmail`, `studioId`, `machineId`, `userClient`, `serviceClient`, `createTag`, `getStudioCatalog` stehen in dieser Datei bereits. Vor dem Anhängen die vorhandenen Bezeichner am Dateikopf ablesen und übernehmen — sie können abweichend heißen.*

- [ ] **Step 2: Test laufen lassen, Fehlschlag bestätigen**

```bash
pnpm test:integration -- domain-catalog
```

Erwartet: FAIL — `kind` ist kein bekanntes Feld von `createTag`, TypeScript bricht bereits beim Übersetzen ab.

- [ ] **Step 3: `createTag` erweitern**

In `packages/domain/src/catalog.ts` die Signatur und den Rumpf ersetzen. Der Kommentarblock darüber bekommt einen Absatz, weil sich seine Aussage ändert:

```ts
/**
 * Einen Tag anlegen. Der Klartext-Token wird genau einmal zurueckgegeben --
 * gespeichert ist nur sein Hash, es gibt keinen Weg, ihn spaeter noch einmal
 * zu erfahren. Er darf deshalb nirgends protokolliert werden (Spec 10.4).
 *
 * Mit machineId entsteht ein Geraetetag sofort aktiv: der Check-Constraint
 * aus 0022 laesst 'active' fuer kind='machine' nur zusammen mit einem Geraet
 * zu, ein zweistufiges "erst anlegen, dann aktivieren" waere gar nicht
 * speicherbar.
 *
 * Ein Aushang (kind='studio') entsteht dagegen immer sofort aktiv und immer
 * ohne Geraet -- er haengt am Eingang, nicht an einer Maschine. Ein
 * vorraetiger Aushang ergaebe keinen Sinn: er wird gedruckt, sobald er
 * existiert, und ohne Token gibt es nichts zu drucken.
 */
export async function createTag(
  client: SupabaseClient,
  input: { studioId: string; machineId?: string | null; kind?: "machine" | "studio" },
): Promise<{ id: string; token: string }> {
  const userId = await requireUserId(client);
  await requireStudioStaff(client, input.studioId, userId);

  const kind = input.kind ?? "machine";

  if (kind === "studio" && input.machineId) {
    throw new DomainError(
      "validation_failed",
      "Ein Aushang gehoert zu keinem Geraet.",
    );
  }

  if (input.machineId) {
    const studioDesGeraets = await studioOfMachine(client, input.machineId);
    if (studioDesGeraets !== input.studioId) {
      throw new DomainError("not_found", "Dieses Geraet gibt es nicht.");
    }
  }

  const token = createTagToken();
  const { data, error } = await client
    .from("machine_tags")
    .insert({
      studio_id: input.studioId,
      machine_id: input.machineId ?? null,
      kind,
      token_hash: hashTagToken(token),
      status: kind === "studio" || input.machineId ? "active" : "unassigned",
    })
    .select("id")
    .single<{ id: string }>();

  if (error || !data) {
    throw new DomainError("internal", error?.message ?? "Tag nicht angelegt.");
  }
  return { id: data.id, token };
}
```

- [ ] **Step 4: `CatalogTag` und die Abfrage erweitern**

Der Typ:

```ts
export type CatalogTag = {
  id: string;
  status: string;
  kind: "machine" | "studio";
  machineId: string | null;
  createdAt: string;
};
```

Die Abfrage in `getStudioCatalog`:

```ts
  const { data: tags } = await client
    .from("machine_tags")
    .select("id, status, kind, machine_id, created_at")
    .eq("studio_id", studioId)
    .order("created_at", { ascending: false });
```

Und in der Zuordnung, die aus den Zeilen `CatalogTag`-Objekte baut, `kind: zeile.kind` ergänzen. **Die Stelle in derselben Funktion suchen, wo `machineId: ...` gesetzt wird**, und dort danebenstellen — der Zeilentyp weiter unten in der Datei braucht `kind` ebenfalls.

- [ ] **Step 5: Tests und Typprüfung laufen lassen**

```bash
pnpm typecheck
pnpm test:integration -- domain-catalog
```

Erwartet: beides PASS. `typecheck` deckt auf, wenn die Zuordnung in Step 4 vergessen wurde.

- [ ] **Step 6: Commit**

```bash
git add packages/domain/src/catalog.ts tests/integration/domain-catalog.test.ts
git commit -m "feat(domain): Aushang-Tags anlegen und im Katalog fuehren"
```

---

### Task 5: Portal — Aushang anlegen, sperren, drucken *(gestrichen, überholt)*

> **Status: nicht bauen.** Nach dem Schreiben dieses Plans entstand `docs/superpowers/specs/2026-09-01-einrichtung-am-geraet-design.md`. Sie entscheidet: **Tags kommen als Lieferung, das Studio erzeugt keine** — im Portal entsteht kein Token mehr, auch nicht für den Aushang, und der Erzeugen-und-Drucken-Pfad verschwindet aus Oberfläche und Code. Damit fallen die Server Action `aushangAnlegen`, die Komponente `AushangAnlegen.tsx`, die `qrcode`-Abhängigkeit und der Druckbogen ersatzlos weg.
>
> Was an ihre Stelle tritt — Chargen, Lieferungen, die Tags-Seite als Auskunft — steht in jener Spec und bekommt einen eigenen Plan. **Task 4 ist davon mitbetroffen, stärker als hier zunächst angenommen:** jene Spec führt `createTag` selbst unter dem, was entfällt (§6, zusammen mit `TagAnlegen.tsx` und `TagZuweisen.tsx`) — die Funktion verschwindet, nicht nur ihr Aufrufer. Der Schreibpfad aus Task 4 ist damit vorläufig: die Erweiterung der Signatur um `kind` und der dazu neue Test zielen auf eine Funktion, die zum Abbau vorgesehen ist. Der Lesepfad aus Task 4 dagegen steht: `CatalogTag.kind` wird weiterhin gebraucht, damit die Tags-Seite die Sorte anzeigen kann. Wer diesen Plan ausführt, muss das vor Beginn von Task 4 wissen.
>
> Der ursprüngliche Aufgabentext steht unverändert darunter, damit nachvollziehbar bleibt, was verworfen wurde und warum.

---

#### Ursprünglicher Aufgabentext (nicht mehr gültig)

**Files:**
- Modify: `apps/web/app/portal/actions.ts` (`tagAnlegen` ab Zeile 293)
- Create: `apps/web/app/portal/[studioId]/tags/AushangAnlegen.tsx`
- Modify: `apps/web/app/portal/[studioId]/tags/page.tsx`
- Modify: `apps/web/app/portal/portal.module.css` (Druckregeln)

**Interfaces:**
- Consumes: `createTag` mit `kind` aus Task 4, `CatalogTag.kind` aus Task 4, `tagSperren` aus `actions.ts` (unverändert — `revokeTag` arbeitet auf der Id, die Sorte ist ihm gleich).
- Produces: die Server Action `aushangAnlegen(studioId: string, pfad: string): Promise<{ ok: true; token: string; tagId: string } | { ok: false; error: string }>`.

**Der Grund für den eigenwilligen Zuschnitt.** Die Spec sieht eine Nebenaktion *Druckbogen* je Aushang-Zeile vor. **Das ist nicht baubar:** der Klartext-Token existiert genau einmal, gespeichert ist nur sein Hash. Ein Druckbogen kann deshalb nur im selben Augenblick entstehen, in dem der Aushang angelegt wird. Wer den Bogen verliert, sperrt den Aushang und legt einen neuen an — genau der Weg, den die Tag-Seite für Gerätetags schon heute geht. Die Oberfläche muss das aussprechen, nicht verschweigen.

- [ ] **Step 1: QR-Erzeugung als Abhängigkeit aufnehmen**

```bash
pnpm --filter web add qrcode
pnpm --filter web add -D @types/qrcode
```

Der QR wird **im Browser** gezeichnet, nicht auf dem Server: der Token liegt nach dem Anlegen ohnehin im Client, und ein zweiter Weg über den Server wäre eine zweite Stelle, an der er auftauchen kann.

- [ ] **Step 2: Die Server Action ergänzen**

In `apps/web/app/portal/actions.ts`, direkt hinter `tagAnlegen`:

```ts
/**
 * Ein Aushang haengt am Eingang und macht jeden, der ihn scannt, zum
 * Mitglied. Wie beim Geraetetag gibt es den Token genau einmal zu sehen --
 * hier wiegt das schwerer, weil daraus ein Druckbogen entstehen muss.
 */
export async function aushangAnlegen(
  studioId: string,
  pfad: string,
): Promise<
  { ok: true; token: string; tagId: string } | { ok: false; error: string }
> {
  const client = await createServerSupabaseClient();
  try {
    const tag = await createTag(client, { studioId, kind: "studio" });
    revalidatePath(pfad);
    return { ok: true, token: tag.token, tagId: tag.id };
  } catch (fehler) {
    if (fehler instanceof DomainError) return { ok: false, error: fehler.message };
    console.error("Aushang nicht angelegt:", fehler);
    return { ok: false, error: "Der Aushang liess sich nicht anlegen." };
  }
}
```

- [ ] **Step 3: Die Komponente `AushangAnlegen.tsx` schreiben**

```tsx
"use client";

import { useState } from "react";
import QRCode from "qrcode";
import { AktionsKnopf } from "../../Form";
import { aushangAnlegen } from "../../actions";
import styles from "../../portal.module.css";

/**
 * Der Bogen entsteht genau hier und genau jetzt. Gespeichert ist nur der
 * Hash des Tokens -- diese Ansicht ein zweites Mal zu oeffnen gibt es
 * nicht, und die Oberflaeche sagt das, statt es den Nutzer herausfinden
 * zu lassen.
 */
export function AushangAnlegen({
  studioId,
  studioName,
  pfad,
  basisUrl,
}: {
  studioId: string;
  studioName: string;
  pfad: string;
  basisUrl: string;
}) {
  const [fehler, setFehler] = useState<string | null>(null);
  const [bogen, setBogen] = useState<{ url: string; qr: string } | null>(null);

  async function anlegen() {
    setFehler(null);
    const ergebnis = await aushangAnlegen(studioId, pfad);
    if (!ergebnis.ok) {
      setFehler(ergebnis.error);
      return;
    }
    const url = `${basisUrl}/t/${ergebnis.token}`;
    const qr = await QRCode.toDataURL(url, {
      errorCorrectionLevel: "Q",
      margin: 2,
      width: 720,
      color: { dark: "#0A0B0DFF", light: "#FFFFFFFF" },
    });
    setBogen({ url, qr });
  }

  if (bogen) {
    return (
      <div className={styles.printSheet}>
        <p className={styles.hint}>
          Diesen Bogen jetzt drucken. Der Code steht nur hier — gespeichert ist
          nur seine Prüfsumme. Geht der Ausdruck verloren, sperrst du den
          Aushang und legst einen neuen an.
        </p>
        <div className={styles.printArea}>
          <h2>Trainieren mit gymodo</h2>
          <p>{studioName}</p>
          <img src={bogen.qr} alt="QR-Code für den Studio-Beitritt" width={320} height={320} />
          <ol>
            <li>Code mit der Kamera scannen.</li>
            <li>gymodo laden und Konto anlegen.</li>
            <li>Diesen Code noch einmal scannen — fertig.</li>
          </ol>
        </div>
        <AktionsKnopf onClick={() => window.print()}>Drucken</AktionsKnopf>
      </div>
    );
  }

  return (
    <>
      {fehler ? <p className={styles.error}>{fehler}</p> : null}
      <AktionsKnopf onClick={anlegen}>Aushang anlegen</AktionsKnopf>
    </>
  );
}
```

*`AktionsKnopf` und die Klassennamen `hint`, `error` stammen aus dem bestehenden Portal. **Vor dem Schreiben die tatsächlichen Namen in `apps/web/app/portal/Form.tsx` und `portal.module.css` ablesen** und übernehmen; `printSheet` und `printArea` kommen in Step 5 neu hinzu.*

- [ ] **Step 4: Den Abschnitt `Aushang` auf der Tags-Seite ergänzen**

In `apps/web/app/portal/[studioId]/tags/page.tsx`, als **erster** Abschnitt vor der Liste der Gerätetags. Die Aushänge kommen aus dem Katalog, den die Seite schon lädt:

```tsx
  const aushaenge = katalog.tags.filter(
    (tag) => tag.kind === "studio" && tag.status === "active",
  );
```

Der Abschnitt zeigt je Aushang das Anlegedatum (`datum(tag.createdAt)` — die Funktion steht oben in der Datei) und die destruktive Aktion aus `tagSperren`. **Der Token selbst wird nicht angezeigt: es gibt ihn nicht mehr.** Darunter der Satz:

> „Ein Aushang macht jeden, der ihn scannt, zum Mitglied. Sperren macht jeden gedruckten Bogen ungültig — dann neu anlegen und neu drucken."

Und die Komponente aus Step 3 mit `basisUrl` aus der Umgebung (`requiredEnv` aus `@/lib/env`, dieselbe Herkunft wie in der AASA-Route).

- [ ] **Step 5: Druckregeln in `portal.module.css`**

```css
/* Der Bogen wird gedruckt, nicht angesehen: alles ausser ihm verschwindet.
   Ohne diese Regeln landet die Portal-Navigation mit auf dem Papier. */
.printSheet { display: flex; flex-direction: column; gap: 16px; }

.printArea {
  background: #fff;
  color: #0a0b0d;
  padding: 32px;
  border-radius: 8px;
  text-align: center;
}

@media print {
  body * { visibility: hidden; }
  .printArea, .printArea * { visibility: visible; }
  .printArea { position: absolute; inset: 0; border-radius: 0; }
}
```

- [ ] **Step 6: Übersetzen und ansehen**

```bash
pnpm typecheck
pnpm --filter web dev
```

Die Seite `/portal/<studioId>/tags` öffnen, einen Aushang anlegen, den Bogen in der Druckvorschau prüfen. Erwartet: QR, Studioname, drei Schritte — und **keine** Portal-Navigation auf dem Blatt.

- [ ] **Step 7: Commit**

```bash
git add apps/web/app/portal/actions.ts \
        apps/web/app/portal/\[studioId\]/tags/AushangAnlegen.tsx \
        apps/web/app/portal/\[studioId\]/tags/page.tsx \
        apps/web/app/portal/portal.module.css \
        apps/web/package.json pnpm-lock.yaml
git commit -m "feat(portal): Aushaenge anlegen, sperren und drucken"
```

---

### Task 6: Web-Fallback — Aushang-Zweig und Kaltstart

**Files:**
- Modify: `apps/web/app/t/[token]/page.tsx`
- Modify: `apps/web/app/t/[token]/fallback.module.css`
- Modify: `supabase/migrations/` — neue Datei `0025_resolve_tag_fallback_studio.sql`
- Test: `e2e/tag-fallback.spec.ts` (ergänzen)

**Interfaces:**
- Consumes: `machine_tags.kind` aus Task 1.
- Produces: `resolve_tag_fallback` liefert zusätzlich `kind` und `studio_name`; die Seite verzweigt darauf.

- [ ] **Step 1: Die Funktion erweitern**

`resolve_tag_fallback` gibt heute nur `machine_tag_id` zurück. Der Aushang hat kein Gerät — die Seite muss also schon aus der Auflösung wissen, was sie zeigen soll, und den Studionamen bekommen, ohne dafür `studios` lesen zu dürfen.

`supabase/migrations/0025_resolve_tag_fallback_studio.sql`:

```sql
-- Der Fallback muss zwei Faelle unterscheiden koennen, ohne dafuer eine
-- zweite Abfrage und ohne dafuer Leserecht auf studios. Der Studioname ist
-- Studioinhalt, kein Personenbezug -- er steht ohnehin auf jedem Aushang.
create or replace function public.resolve_tag_fallback(p_token_hash text)
returns table (machine_tag_id uuid, kind public.tag_kind, studio_name text)
language sql
security definer
set search_path = public, pg_temp
stable
as $$
  select t.id, t.kind, s.name
  from public.machine_tags t
  join public.studios s on s.id = t.studio_id
  where t.token_hash = p_token_hash
    and t.status = 'active';
$$;

revoke all on function public.resolve_tag_fallback(text)
  from public, anon, authenticated, service_role;
grant execute on function public.resolve_tag_fallback(text) to anon;
```

*`create or replace` scheitert, wenn sich die Rückgabespalten ändern. Schlägt der Lauf mit `cannot change return type of existing function` fehl, ist ein `drop function public.resolve_tag_fallback(text);` **vor** dem `create` nötig — dann steht es in derselben Migration, oberhalb.*

- [ ] **Step 2: Datenbank zurücksetzen, bestehenden Test laufen lassen**

```bash
pnpm exec supabase db reset
pnpm test:integration -- resolve-tag-fallback
```

Erwartet: die drei Tests auf leere und volle Ergebnisse bestehen weiter. Die Prüfung `toHaveLength(1)` bleibt gültig, weil sich die Zeilenzahl nicht ändert, nur die Spaltenzahl.

- [ ] **Step 3: Die Seite auf den Aushang-Zweig erweitern**

In `apps/web/app/t/[token]/page.tsx`: nach dem Auflösen auf `kind` verzweigen.

- Bei `kind === "machine"`: alles bleibt, wie es ist — Gerät, Foto, Videos, dann die Aufforderung. **Ergänzt** wird in der Aufforderungskarte der Satz über den zweiten Scan, mit dem Studionamen aus der Auflösung:
  > „Nach dem Laden diesen Code hier noch einmal scannen — dann bist du bei **{studioName}** angemeldet."
- Bei `kind === "studio"`: Studioname als Überschrift, drei Nutzenzeilen (Einweisung an jedem Gerät · Einstellungen bleiben · Kurse buchen), dann dieselbe Aufforderung mit den zwei nummerierten Schritten.
- Unbekannt, gesperrt, ungültig: **unverändert** dieselbe neutrale Antwort wie heute. Der bestehende Kommentarblock über `unbekannt` erklärt, warum — er bleibt stehen.

Die Gestaltung folgt Artboard 27 aus `docs/superpowers/design/member/FallbackAushang.dc.html`, gebaut im Designplan `2026-09-01-designplan-scan-beitritt.md`.

- [ ] **Step 4: E2E-Fall ergänzen**

An `e2e/tag-fallback.spec.ts` anhängen, nach dem Muster der bestehenden Fälle in dieser Datei:

```ts
test("ein Aushang-Token zeigt das Studio statt eines Geraets", async ({ page }) => {
  await page.goto(`/t/${aushangToken}`);
  await expect(page.getByTestId("tag-aushang")).toBeVisible();
  await expect(page.getByText("App laden")).toBeVisible();
});

test("ein unbekannter Token bleibt ununterscheidbar", async ({ page }) => {
  await page.goto(`/t/${unbekannterToken}`);
  await expect(page.getByTestId("tag-unknown")).toBeVisible();
});
```

*Das `data-testid="tag-unknown"` gibt es schon. `data-testid="tag-aushang"` kommt in Step 3 auf den Wurzelknoten des Aushang-Zweigs. Wie `aushangToken` im Test entsteht, aus dem `beforeAll` der Datei ablesen und demselben Muster folgen.*

- [ ] **Step 5: Tests laufen lassen**

```bash
pnpm typecheck
pnpm test:e2e -- tag-fallback
```

Erwartet: PASS, einschließlich der bestehenden Fälle.

- [ ] **Step 6: Commit**

```bash
git add supabase/migrations/0025_resolve_tag_fallback_studio.sql \
        apps/web/app/t/\[token\]/page.tsx \
        apps/web/app/t/\[token\]/fallback.module.css \
        e2e/tag-fallback.spec.ts
git commit -m "feat(web): Web-Fallback fuer Aushaenge und der zweite Scan"
```

---

## Was dieser Plan nicht baut

**Die App-Seite.** Scanner auf Zugang 03, die Pending-Route über die Registrierung hinweg, das lokal gehaltene aktive Studio, die Beitritts- und Wechselzeile auf Home und der Abschnitt *Studios* im Profil sind SwiftUI und entstehen auf dem Mac. Was sie brauchen, steht vollständig in Abschnitt 2 und 3 der Spec; der Aufruf ist `join_studio_by_tag` aus Task 2, der Austritt ein `delete` auf `studio_memberships` dank Task 3.

**Weg B**, der Beitritt im Web vor der Installation. Er hängt am SMTP-Versand und ist ein eigener Bauabschnitt (Spec, Abschnitt 5).

**Eine Ratenbegrenzung** auf `join_studio_by_tag`. Offen und in Spec Abschnitt 7 vermerkt.
