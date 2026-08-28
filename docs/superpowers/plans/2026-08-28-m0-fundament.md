# M0 + Fundament — Implementierungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ein physischer NFC-Tap auf ein Fitnessgerät öffnet über einen Universal Link die eigene iOS-App und zeigt den erkannten Tag-Token — auf einer echten Domain, mit echtem Login, echter Mandantentrennung und aktiver RLS.

**Architecture:** Monorepo mit pnpm und Turborepo. Next.js App Router auf Vercel liefert die API, das Webportal, die `apple-app-site-association`-Datei und den Web-Fallback unter `/t/<token>`. Supabase-managed PostgreSQL hält die Daten, RLS ist ab der ersten Tabelle aktiv. Die native SwiftUI-App entsteht auf dem Mac und validiert eingehende Universal Links, leitet daraus aber keine Berechtigung ab.

**Tech Stack:** TypeScript (strict), Next.js App Router, Supabase (PostgreSQL, Auth, CLI lokal via Docker), Zod, Vitest, Playwright, pnpm, Turborepo · Swift 6 (strict concurrency), SwiftUI, Swift Testing, Xcode

**Spec:** `docs/superpowers/specs/2026-08-28-fitness-retrofit-m1-design.md`

## Global Constraints

Diese Werte gelten in jedem Task. Sie werden **einmal** festgelegt und danach überall identisch verwendet.

- **`DOMAIN`** — die produktive HTTPS-Domain, unter der App-Links und Web-Fallback laufen. Beispiel: `app.fitretro.de`. Wird in Task 6 registriert und muss ab dann in `next.config.mjs`, in der AASA-Datei, im Xcode-Entitlement und im Swift-Parser identisch sein.
- **`TEAM_ID`** — Apple Developer Team ID, zehnstellig. Zu finden unter developer.apple.com → Membership Details.
- **`BUNDLE_ID`** — Bundle Identifier der Member-App, z. B. `de.fitretro.member`. Muss der bereits registrierten App-ID entsprechen.
- **Sprachen:** TypeScript `strict: true`, kein `any`, kein `@ts-ignore`. Swift 6 mit vollständiger Strict-Concurrency-Prüfung. Keine Force Unwraps, kein `try!`.
- **Mandantentrennung:** Jede fachliche Tabelle hat `studio_id`, `ENABLE ROW LEVEL SECURITY` **und** `FORCE ROW LEVEL SECURITY`. Jede Policy braucht Positiv-, Negativ- und Cross-Tenant-Test. Eine fehlende `studio_id` blockiert den Merge.
- **Migrationen:** ausschließlich versionierte, vorwärtsgerichtete SQL-Dateien in `supabase/migrations/`. Keine Änderungen im Supabase-Dashboard.
- **Schlüssel:** Der Service-Role-Key wird ausschließlich in Tests und serverseitigen Betriebsaufgaben verwendet, niemals im Browser, im iOS-Bundle oder in normalen Request-Handlern.
- **Tag-Token:** 128 Bit Zufall, base64url, 22 Zeichen. In der Datenbank wird **nur** der SHA-256-Hash gespeichert. Der Token darf niemals in Logs, Fehlerberichten oder Analytics erscheinen.
- **Zeit:** alle Zeitstempel `timestamptz` in UTC.
- **Commits:** klein und häufig, ein Commit je abgeschlossenem Task-Schritt-Block wie in den Steps angegeben.

### Umgebungshinweise Windows

- **Docker Desktop muss laufen**, bevor `supabase start` funktioniert.
- Falls npm/pnpm mit `SELF_SIGNED_CERT_IN_CHAIN` abbricht (SSL-Interception im Firmennetz): `NODE_OPTIONS=--use-system-ca` setzen.
- Node: aktuelle LTS-Version.

### Abbruchpunkt

**Task 8 ist ein Gate, kein gewöhnlicher Task.** Liest der NFC-Tag am echten Fitnessgerät nicht zuverlässig, wird das Produkt QR-first statt NFC-first. In diesem Fall wird nicht weitergebaut, sondern die Spec angepasst — Abschnitt 3 (M0) und Abschnitt 8.1 der Spec.

---

## Dateistruktur

Nach diesem Plan existiert:

```text
/
├─ apps/
│  ├─ web/                          # Next.js: API, Portal, Web-Fallback, AASA
│  │  ├─ app/
│  │  │  ├─ api/aasa/route.ts       # liefert apple-app-site-association
│  │  │  ├─ login/page.tsx          # E-Mail-OTP-Login
│  │  │  ├─ t/[token]/page.tsx      # Web-Fallback
│  │  │  └─ layout.tsx
│  │  ├─ lib/supabase/server.ts     # SSR-Client
│  │  ├─ next.config.mjs            # Rewrite /.well-known/... → /api/aasa
│  │  └─ package.json
│  └─ ios-member/                   # Xcode-Projekt (entsteht auf dem Mac)
│     ├─ FitnessMember/
│     │  ├─ FitnessMemberApp.swift
│     │  ├─ ContentView.swift
│     │  └─ TagLink.swift           # Universal-Link-Validierung
│     └─ FitnessMemberTests/
│        └─ TagLinkTests.swift
├─ packages/
│  ├─ domain/                       # Fachlogik, framework-frei
│  │  ├─ src/tags.ts                # Tokenerzeugung, Hashing, Auflösung
│  │  └─ src/index.ts
│  └─ config/
│     └─ tsconfig.base.json
├─ supabase/
│  ├─ migrations/
│  │  ├─ 0001_tenancy.sql
│  │  └─ 0002_machine_tags.sql
│  └─ config.toml
├─ tests/
│  └─ integration/
│     ├─ helpers/clients.ts         # Service-Role- und Nutzer-Clients
│     ├─ rls-tenancy.test.ts
│     └─ rls-machine-tags.test.ts
├─ e2e/
│  └─ login.spec.ts                 # Playwright, OTP über Inbucket
├─ pnpm-workspace.yaml
├─ turbo.json
└─ package.json
```

**Verantwortlichkeiten:** `packages/domain` enthält reine Funktionen ohne Framework- oder Datenbankbezug und ist damit ohne laufende Infrastruktur testbar. `apps/web` enthält ausschließlich Transport, Rendering und Session — keine Fachregeln. `supabase/migrations` ist die einzige Quelle für Schemaänderungen. `tests/integration` prüft RLS gegen echtes PostgreSQL, weil Mocks das nicht ersetzen.

---

## Task 1: Monorepo-Grundgerüst

**Files:**
- Create: `package.json`, `pnpm-workspace.yaml`, `turbo.json`, `.gitignore`, `.npmrc`
- Create: `packages/config/tsconfig.base.json`
- Create: `packages/domain/package.json`, `packages/domain/tsconfig.json`, `packages/domain/src/index.ts`
- Test: `packages/domain/src/index.test.ts`

**Interfaces:**
- Consumes: nichts
- Produces: Workspace-Kommandos `pnpm typecheck`, `pnpm test`, `pnpm build`; das Paket `@fitretro/domain` als Abhängigkeit für spätere Tasks

- [ ] **Step 1: Wurzeldateien anlegen**

`package.json`:

```json
{
  "name": "fitretro",
  "private": true,
  "packageManager": "pnpm@9.12.0",
  "scripts": {
    "typecheck": "turbo run typecheck",
    "test": "turbo run test",
    "build": "turbo run build"
  },
  "devDependencies": {
    "turbo": "^2.1.0",
    "typescript": "^5.6.0",
    "vitest": "^2.1.0"
  }
}
```

`pnpm-workspace.yaml`:

```yaml
packages:
  - "apps/*"
  - "packages/*"
```

`turbo.json`:

```json
{
  "$schema": "https://turbo.build/schema.json",
  "tasks": {
    "typecheck": { "dependsOn": ["^typecheck"] },
    "test": { "dependsOn": ["^build"] },
    "build": { "dependsOn": ["^build"], "outputs": ["dist/**", ".next/**"] }
  }
}
```

`.npmrc`:

```text
auto-install-peers=true
strict-peer-dependencies=false
```

`.gitignore`:

```text
node_modules/
.next/
dist/
.turbo/
.env
.env.local
*.log
.DS_Store
xcuserdata/
*.xcuserstate
```

- [ ] **Step 2: Gemeinsame TypeScript-Konfiguration**

`packages/config/tsconfig.base.json`:

```json
{
  "$schema": "https://json.schemastore.org/tsconfig",
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2022"],
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "exactOptionalPropertyTypes": true,
    "verbatimModuleSyntax": true,
    "skipLibCheck": true,
    "esModuleInterop": true,
    "resolveJsonModule": true,
    "declaration": true,
    "sourceMap": true
  }
}
```

- [ ] **Step 3: Domain-Paket anlegen**

`packages/domain/package.json`:

```json
{
  "name": "@fitretro/domain",
  "version": "0.0.0",
  "private": true,
  "type": "module",
  "main": "./src/index.ts",
  "types": "./src/index.ts",
  "scripts": {
    "typecheck": "tsc --noEmit",
    "test": "vitest run",
    "build": "tsc --emitDeclarationOnly --outDir dist"
  },
  "devDependencies": {
    "typescript": "^5.6.0",
    "vitest": "^2.1.0"
  }
}
```

`packages/domain/tsconfig.json`:

```json
{
  "extends": "../config/tsconfig.base.json",
  "include": ["src/**/*.ts"]
}
```

- [ ] **Step 4: Den ersten Test schreiben (er soll fehlschlagen)**

`packages/domain/src/index.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { DOMAIN_PACKAGE_NAME } from "./index.js";

describe("domain package", () => {
  it("ist eingebunden und auflösbar", () => {
    expect(DOMAIN_PACKAGE_NAME).toBe("@fitretro/domain");
  });
});
```

- [ ] **Step 5: Test laufen lassen und Fehlschlag bestätigen**

```bash
pnpm install
pnpm --filter @fitretro/domain test
```

Erwartet: FAIL — `Failed to resolve import "./index.js"`.

- [ ] **Step 6: Minimale Implementierung**

`packages/domain/src/index.ts`:

```ts
export const DOMAIN_PACKAGE_NAME = "@fitretro/domain";
```

- [ ] **Step 7: Test laufen lassen und Erfolg bestätigen**

```bash
pnpm --filter @fitretro/domain test
pnpm typecheck
```

Erwartet: 1 passed, typecheck ohne Fehler.

- [ ] **Step 8: Committen**

```bash
git add -A
git commit -m "chore: Monorepo-Grundgeruest mit pnpm, Turborepo und Domain-Paket"
```

---

## Task 2: Mandantenschema mit RLS

**Files:**
- Create: `supabase/migrations/0001_tenancy.sql`
- Create: `tests/integration/helpers/clients.ts`
- Create: `.env.example`
- Test: `tests/integration/rls-tenancy.test.ts`

**Interfaces:**
- Consumes: Workspace aus Task 1
- Produces: Tabellen `studios`, `profiles`, `studio_memberships`; SQL-Funktion `public.is_studio_member(uuid) returns boolean`; Testhelfer `serviceClient()`, `createTestUser(email)`, `userClient(email, password)`

- [ ] **Step 1: Supabase lokal initialisieren**

Docker Desktop starten, dann:

```bash
pnpm add -Dw supabase @supabase/supabase-js dotenv
pnpm exec supabase init
pnpm exec supabase start
```

`supabase start` gibt am Ende `API URL`, `anon key` und `service_role key` aus. Diese Werte in eine Datei namens **`.env`** im Wurzelverzeichnis schreiben (nicht committen — `.env` ist bereits über die `.gitignore` aus Task 1 ausgeschlossen).

**Wichtig zum Dateinamen:** `tests/integration/helpers/clients.ts` (Step 2) und später `playwright.config.ts` (Task 4) laden Umgebungsvariablen über `import "dotenv/config"`. Dieser Import sucht standardmäßig eine Datei namens `.env` — **nicht** `.env.local`. Die Datei muss deshalb exakt `.env` heißen, sonst bleiben `SUPABASE_URL` und die beiden Keys für alle root-seitigen Test-Skripte unauffindbar.

Zusätzlich die committete Vorlage anlegen, `.env.example`:

```text
SUPABASE_URL=http://127.0.0.1:54321
SUPABASE_ANON_KEY=<anon key aus "supabase start">
SUPABASE_SERVICE_ROLE_KEY=<service_role key aus "supabase start">
```

- [ ] **Step 2: Testhelfer schreiben**

`tests/integration/helpers/clients.ts`:

```ts
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import "dotenv/config";

function required(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`Umgebungsvariable ${name} fehlt`);
  return value;
}

const URL = required("SUPABASE_URL");
const ANON = required("SUPABASE_ANON_KEY");
const SERVICE = required("SUPABASE_SERVICE_ROLE_KEY");

export function serviceClient(): SupabaseClient {
  return createClient(URL, SERVICE, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

export const TEST_PASSWORD = "test-passwort-1234";

export async function createTestUser(email: string): Promise<string> {
  const admin = serviceClient();
  const { data, error } = await admin.auth.admin.createUser({
    email,
    password: TEST_PASSWORD,
    email_confirm: true,
  });
  if (error) throw error;
  return data.user.id;
}

export async function userClient(email: string): Promise<SupabaseClient> {
  const client = createClient(URL, ANON, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { error } = await client.auth.signInWithPassword({
    email,
    password: TEST_PASSWORD,
  });
  if (error) throw error;
  return client;
}

export function uniqueEmail(prefix: string): string {
  return `${prefix}-${crypto.randomUUID()}@example.test`;
}
```

- [ ] **Step 3: Den fehlschlagenden RLS-Test schreiben**

`tests/integration/rls-tenancy.test.ts`:

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
let emailA: string;
let emailB: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioError } = await admin
    .from("studios")
    .insert([{ name: "Studio A" }, { name: "Studio B" }])
    .select("id");
  if (studioError) throw studioError;
  studioA = studios[0]!.id;
  studioB = studios[1]!.id;

  emailA = uniqueEmail("a");
  emailB = uniqueEmail("b");
  const userA = await createTestUser(emailA);
  const userB = await createTestUser(emailB);

  const { error: membershipError } = await admin
    .from("studio_memberships")
    .insert([
      { studio_id: studioA, user_id: userA, role: "member" },
      { studio_id: studioB, user_id: userB, role: "member" },
    ]);
  if (membershipError) throw membershipError;
});

describe("RLS auf studios", () => {
  it("positiv: Nutzer A sieht sein eigenes Studio", async () => {
    const client = await userClient(emailA);
    const { data, error } = await client.from("studios").select("id");
    expect(error).toBeNull();
    expect(data?.map((row) => row.id)).toEqual([studioA]);
  });

  it("cross-tenant: Nutzer A sieht Studio B nicht", async () => {
    const client = await userClient(emailA);
    const { data } = await client.from("studios").select("id").eq("id", studioB);
    expect(data).toEqual([]);
  });

  it("negativ: Nutzer A kann kein Studio anlegen", async () => {
    const client = await userClient(emailA);
    const { error } = await client.from("studios").insert({ name: "Schwarz" });
    expect(error).not.toBeNull();
  });
});

describe("RLS auf studio_memberships", () => {
  it("positiv: Nutzer A sieht seine eigene Mitgliedschaft", async () => {
    const client = await userClient(emailA);
    const { data, error } = await client
      .from("studio_memberships")
      .select("studio_id");
    expect(error).toBeNull();
    expect(data?.map((row) => row.studio_id)).toEqual([studioA]);
  });

  it("cross-tenant: Nutzer A sieht die Mitgliedschaft von B nicht", async () => {
    const client = await userClient(emailA);
    const { data } = await client
      .from("studio_memberships")
      .select("studio_id")
      .eq("studio_id", studioB);
    expect(data).toEqual([]);
  });

  it("negativ: Nutzer A kann sich nicht selbst in Studio B eintragen", async () => {
    const client = await userClient(emailA);
    const { data: me } = await client.auth.getUser();
    const { error } = await client.from("studio_memberships").insert({
      studio_id: studioB,
      user_id: me.user?.id,
      role: "member",
    });
    expect(error).not.toBeNull();
  });
});
```

- [ ] **Step 4: Vitest für Integrationstests konfigurieren**

`vitest.config.ts` im Wurzelverzeichnis:

```ts
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["tests/integration/**/*.test.ts"],
    testTimeout: 30_000,
    hookTimeout: 30_000,
    fileParallelism: false,
  },
});
```

Im Wurzel-`package.json` das Skript ergänzen:

```json
"test:integration": "vitest run --config vitest.config.ts"
```

- [ ] **Step 5: Test laufen lassen und Fehlschlag bestätigen**

```bash
pnpm test:integration
```

Erwartet: FAIL — `relation "public.studios" does not exist`.

- [ ] **Step 6: Migration schreiben**

`supabase/migrations/0001_tenancy.sql`:

```sql
create extension if not exists pgcrypto;

create table public.studios (
  id          uuid primary key default gen_random_uuid(),
  name        text not null check (length(trim(name)) > 0),
  timezone    text not null default 'Europe/Berlin',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create type public.studio_role as enum ('owner', 'trainer', 'member');

create table public.studio_memberships (
  id          uuid primary key default gen_random_uuid(),
  studio_id   uuid not null references public.studios (id) on delete cascade,
  user_id     uuid not null references auth.users (id) on delete cascade,
  role        public.studio_role not null,
  created_at  timestamptz not null default now(),
  unique (studio_id, user_id)
);

create index on public.studio_memberships (user_id);
create index on public.studio_memberships (studio_id);

-- SECURITY DEFINER, damit die Policy auf studio_memberships nicht rekursiv
-- dieselbe Tabelle unter RLS abfragt. Diese Funktion ist die einzige Stelle,
-- an der RLS umgangen wird — deshalb hat sie ein festes search_path und
-- liefert ausschliesslich einen Boolean zurueck, niemals Daten.
create or replace function public.is_studio_member(p_studio_id uuid)
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
  );
$$;

revoke all on function public.is_studio_member(uuid) from public;
grant execute on function public.is_studio_member(uuid) to authenticated;

alter table public.studios             enable row level security;
alter table public.studios             force  row level security;
alter table public.profiles            enable row level security;
alter table public.profiles            force  row level security;
alter table public.studio_memberships  enable row level security;
alter table public.studio_memberships  force  row level security;

create policy studios_select on public.studios
  for select to authenticated
  using (public.is_studio_member(id));

create policy profiles_select_own on public.profiles
  for select to authenticated
  using (id = auth.uid());

create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

create policy memberships_select_own on public.studio_memberships
  for select to authenticated
  using (user_id = auth.uid());
```

Es gibt bewusst **keine** Insert- oder Update-Policy auf `studios` und `studio_memberships`. Anlegen erfolgt in M1 ausschließlich serverseitig mit erhöhten Rechten. Ohne Policy verweigert RLS die Operation — genau das prüfen die Negativtests.

- [ ] **Step 7: Migration anwenden und Tests laufen lassen**

```bash
pnpm exec supabase db reset
pnpm test:integration
```

Erwartet: 6 passed.

- [ ] **Step 8: Committen**

```bash
git add -A
git commit -m "feat: Mandantenschema mit RLS und Cross-Tenant-Tests"
```

---

## Task 3: Tag-Token — Erzeugung, Hashing, Auflösung

**Files:**
- Create: `supabase/migrations/0002_machine_tags.sql`
- Create: `packages/domain/src/tags.ts`
- Modify: `packages/domain/src/index.ts`
- Test: `packages/domain/src/tags.test.ts`, `tests/integration/rls-machine-tags.test.ts`

**Interfaces:**
- Consumes: `is_studio_member(uuid)` aus Task 2
- Produces:
  - `createTagToken(): string` — 22 Zeichen base64url
  - `hashTagToken(token: string): string` — 64 Zeichen Hex (SHA-256)
  - `isValidTagToken(value: string): boolean`
  - Tabelle `machine_tags` mit `token_hash`, `status`, `machine_id` (nullable)

- [ ] **Step 1: Den fehlschlagenden Unit-Test schreiben**

`packages/domain/src/tags.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { createTagToken, hashTagToken, isValidTagToken } from "./tags.js";

describe("createTagToken", () => {
  it("erzeugt 22 Zeichen base64url", () => {
    const token = createTagToken();
    expect(token).toHaveLength(22);
    expect(token).toMatch(/^[A-Za-z0-9_-]{22}$/);
  });

  it("erzeugt bei 1000 Aufrufen keine Kollision", () => {
    const tokens = new Set(
      Array.from({ length: 1000 }, () => createTagToken()),
    );
    expect(tokens.size).toBe(1000);
  });
});

describe("hashTagToken", () => {
  it("liefert 64 Zeichen Hex", () => {
    expect(hashTagToken("abc")).toMatch(/^[0-9a-f]{64}$/);
  });

  it("ist deterministisch", () => {
    expect(hashTagToken("abc")).toBe(hashTagToken("abc"));
  });

  it("liefert fuer verschiedene Eingaben verschiedene Hashes", () => {
    expect(hashTagToken("abc")).not.toBe(hashTagToken("abd"));
  });

  it("enthaelt den Token nicht im Ergebnis", () => {
    const token = createTagToken();
    expect(hashTagToken(token)).not.toContain(token);
  });
});

describe("isValidTagToken", () => {
  it("akzeptiert einen erzeugten Token", () => {
    expect(isValidTagToken(createTagToken())).toBe(true);
  });

  it.each([
    ["zu kurz", "abc"],
    ["zu lang", "a".repeat(23)],
    ["unerlaubtes Zeichen", "a".repeat(21) + "/"],
    ["leer", ""],
    ["Pfadanteil", "../".padEnd(22, "a")],
  ])("weist %s zurueck", (_name, value) => {
    expect(isValidTagToken(value)).toBe(false);
  });
});
```

- [ ] **Step 2: Test laufen lassen und Fehlschlag bestätigen**

```bash
pnpm --filter @fitretro/domain test
```

Erwartet: FAIL — `Failed to resolve import "./tags.js"`.

- [ ] **Step 3: Implementierung schreiben**

`packages/domain/src/tags.ts`:

```ts
import { createHash, randomBytes } from "node:crypto";

/** Laenge eines base64url-kodierten 128-Bit-Tokens. */
const TOKEN_LENGTH = 22;
const TOKEN_PATTERN = /^[A-Za-z0-9_-]{22}$/;

/**
 * Erzeugt einen Tag-Token mit 128 Bit Zufall.
 * Der Token ist ein oeffentlicher Locator, keine Authentisierung.
 */
export function createTagToken(): string {
  return randomBytes(16).toString("base64url");
}

/**
 * SHA-256 des Tokens als Hex. Nur dieser Wert wird gespeichert —
 * der Token selbst verlaesst niemals den Tag beziehungsweise die Anfrage.
 */
export function hashTagToken(token: string): string {
  return createHash("sha256").update(token, "utf8").digest("hex");
}

/** Formatpruefung vor jeder Verwendung. Ersetzt keine Autorisierung. */
export function isValidTagToken(value: string): boolean {
  return value.length === TOKEN_LENGTH && TOKEN_PATTERN.test(value);
}
```

`packages/domain/src/index.ts` ergänzen:

```ts
export const DOMAIN_PACKAGE_NAME = "@fitretro/domain";
export { createTagToken, hashTagToken, isValidTagToken } from "./tags.js";
```

- [ ] **Step 4: Unit-Tests laufen lassen**

```bash
pnpm --filter @fitretro/domain test
```

Erwartet: alle passed.

- [ ] **Step 5: Den fehlschlagenden Integrationstest schreiben**

`tests/integration/rls-machine-tags.test.ts`:

```ts
import { beforeAll, describe, expect, it } from "vitest";
import { createTagToken, hashTagToken } from "@fitretro/domain";
import {
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";

let studioA: string;
let studioB: string;
let emailA: string;
let tokenA: string;
let tokenB: string;

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

  tokenA = createTagToken();
  tokenB = createTagToken();
  const { error: tagError } = await admin.from("machine_tags").insert([
    { studio_id: studioA, token_hash: hashTagToken(tokenA), status: "active" },
    { studio_id: studioB, token_hash: hashTagToken(tokenB), status: "active" },
  ]);
  if (tagError) throw tagError;
});

describe("machine_tags", () => {
  it("speichert nur den Hash, nie den Token", async () => {
    const admin = serviceClient();
    const { data } = await admin
      .from("machine_tags")
      .select("token_hash")
      .eq("studio_id", studioA);
    expect(data?.[0]?.token_hash).toBe(hashTagToken(tokenA));
    expect(JSON.stringify(data)).not.toContain(tokenA);
  });

  it("erzwingt Eindeutigkeit des Hashes", async () => {
    const admin = serviceClient();
    const { error } = await admin.from("machine_tags").insert({
      studio_id: studioA,
      token_hash: hashTagToken(tokenA),
      status: "active",
    });
    expect(error).not.toBeNull();
  });

  it("positiv: Nutzer A sieht die Tags seines Studios", async () => {
    const client = await userClient(emailA);
    const { data, error } = await client.from("machine_tags").select("id");
    expect(error).toBeNull();
    expect(data).toHaveLength(1);
  });

  it("cross-tenant: Nutzer A sieht die Tags von Studio B nicht", async () => {
    const client = await userClient(emailA);
    const { data } = await client
      .from("machine_tags")
      .select("id")
      .eq("studio_id", studioB);
    expect(data).toEqual([]);
  });

  it("negativ: Nutzer A kann keinen Tag anlegen", async () => {
    const client = await userClient(emailA);
    const { error } = await client.from("machine_tags").insert({
      studio_id: studioA,
      token_hash: hashTagToken(createTagToken()),
      status: "active",
    });
    expect(error).not.toBeNull();
  });
});
```

`packages/domain` als Abhängigkeit im Wurzel-`package.json` ergänzen:

```json
"dependencies": {
  "@fitretro/domain": "workspace:*"
}
```

- [ ] **Step 6: Test laufen lassen und Fehlschlag bestätigen**

```bash
pnpm install
pnpm test:integration
```

Erwartet: FAIL — `relation "public.machine_tags" does not exist`.

- [ ] **Step 7: Migration schreiben**

`supabase/migrations/0002_machine_tags.sql`:

```sql
create type public.tag_status as enum ('unassigned', 'active', 'revoked', 'replaced');

create table public.machine_tags (
  id          uuid primary key default gen_random_uuid(),
  studio_id   uuid not null references public.studios (id) on delete cascade,
  machine_id  uuid,
  token_hash  text not null check (token_hash ~ '^[0-9a-f]{64}$'),
  status      public.tag_status not null default 'unassigned',
  created_at  timestamptz not null default now(),
  revoked_at  timestamptz,
  constraint machine_tags_token_hash_key unique (token_hash)
);

create index on public.machine_tags (studio_id);

alter table public.machine_tags enable row level security;
alter table public.machine_tags force  row level security;

create policy machine_tags_select on public.machine_tags
  for select to authenticated
  using (public.is_studio_member(studio_id));
```

**Warum `machine_id` hier ohne Fremdschlüssel und ohne Constraint bleibt:** In M0 existiert die Tabelle `machines` noch nicht, und für den physischen Test in Task 8 muss ein aktiver Tag ohne Geräteinstanz bestehen können. Im Folgeplan „Gerätekatalog" bekommt die Spalte ihren Fremdschlüssel auf `machines(id)` und die Constraint `check (status <> 'active' or machine_id is not null)` — als eigene, vorwärtsgerichtete Migration.

- [ ] **Step 8: Migration anwenden und alle Tests laufen lassen**

```bash
pnpm exec supabase db reset
pnpm test:integration
pnpm test
```

Erwartet: alle passed.

- [ ] **Step 9: Committen**

```bash
git add -A
git commit -m "feat: Tag-Token mit Hash-Speicherung und RLS auf machine_tags"
```

---

## Task 4: Next.js-App mit E-Mail-OTP-Login

**Files:**
- Create: `apps/web/package.json`, `apps/web/tsconfig.json`, `apps/web/next.config.mjs`
- Create: `apps/web/app/layout.tsx`, `apps/web/app/page.tsx`
- Create: `apps/web/app/login/page.tsx`, `apps/web/app/login/actions.ts`
- Create: `apps/web/lib/supabase/server.ts`
- Create: `apps/web/.env.local.example`
- Test: `e2e/login.spec.ts`

**Interfaces:**
- Consumes: Supabase-Instanz aus Task 2
- Produces: `createServerSupabaseClient()` für Server Components und Server Actions; Route `/login`; Startseite `/`, die den eingeloggten Nutzer und seine Studios zeigt

- [ ] **Step 1: Next.js-App anlegen**

`apps/web/package.json`:

```json
{
  "name": "@fitretro/web",
  "version": "0.0.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "typecheck": "tsc --noEmit"
  },
  "dependencies": {
    "@fitretro/domain": "workspace:*",
    "@supabase/ssr": "^0.5.0",
    "@supabase/supabase-js": "^2.45.0",
    "next": "^15.0.0",
    "react": "^19.0.0",
    "react-dom": "^19.0.0",
    "zod": "^3.23.0"
  },
  "devDependencies": {
    "@types/node": "^22.0.0",
    "@types/react": "^19.0.0",
    "typescript": "^5.6.0"
  }
}
```

`apps/web/tsconfig.json`:

```json
{
  "extends": "../../packages/config/tsconfig.base.json",
  "compilerOptions": {
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "jsx": "preserve",
    "noEmit": true,
    "allowJs": true,
    "incremental": true,
    "plugins": [{ "name": "next" }],
    "paths": { "@/*": ["./*"] }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
```

`apps/web/next.config.mjs`:

```js
/** @type {import('next').NextConfig} */
const nextConfig = {
  async rewrites() {
    return [
      {
        source: "/.well-known/apple-app-site-association",
        destination: "/api/aasa",
      },
    ];
  },
};

export default nextConfig;
```

- [ ] **Step 2: Supabase-Serverclient schreiben**

`apps/web/lib/supabase/server.ts`:

```ts
import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

export async function createServerSupabaseClient() {
  const cookieStore = await cookies();

  return createServerClient(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll: () => cookieStore.getAll(),
        setAll: (toSet) => {
          try {
            for (const { name, value, options } of toSet) {
              cookieStore.set(name, value, options);
            }
          } catch {
            // In Server Components ist Schreiben nicht erlaubt.
            // Die Middleware beziehungsweise Server Action uebernimmt das.
          }
        },
      },
    },
  );
}
```

- [ ] **Step 3: Layout und Startseite schreiben (noch ohne Login)**

Die App muss booten können, bevor ein E2E-Test gegen sie laufen kann. Der Login selbst entsteht erst nach dem fehlschlagenden Test in Step 6.

`apps/web/app/layout.tsx`:

```tsx
export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="de">
      <body>{children}</body>
    </html>
  );
}
```

`apps/web/app/page.tsx`:

```tsx
import { createServerSupabaseClient } from "@/lib/supabase/server";

export default async function HomePage() {
  const supabase = await createServerSupabaseClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return <p data-testid="anonymous">Nicht angemeldet.</p>;
  }

  const { data: studios } = await supabase.from("studios").select("id, name");

  return (
    <main>
      <p data-testid="user-email">{user.email}</p>
      <ul data-testid="studio-list">
        {(studios ?? []).map((studio) => (
          <li key={studio.id}>{studio.name}</li>
        ))}
      </ul>
    </main>
  );
}
```

- [ ] **Step 4: Umgebungsvariablen für die Web-App bereitstellen**

`apps/web/.env.local` mit denselben drei Werten wie in Task 2 anlegen (nicht committen). Die Datei ist bereits über `.gitignore` ausgeschlossen. Next.js lädt `.env.local` für `next dev`/`next build` automatisch aus dem Verzeichnis, in dem der Befehl läuft — hier ist das korrekt, im Unterschied zur root-seitigen `.env` aus Task 2.

Daneben `apps/web/.env.local.example` als committete Vorlage anlegen (dieselben drei Schlüsselnamen, ohne echte Werte). Task 5 ergänzt darin später die beiden Apple-Schlüssel.

- [ ] **Step 5: Den fehlschlagenden E2E-Test schreiben**

Lokales Supabase enthält Inbucket unter `http://127.0.0.1:54324`. Dessen API liefert die zugestellte Mail samt OTP.

*(Testcode und Playwright-Konfiguration siehe unten in diesem Task — sie stehen im Block „E2E-Test und Playwright-Konfiguration".)*

- [ ] **Step 6: Test laufen lassen und Fehlschlag bestätigen**

```bash
pnpm add -Dw @playwright/test
pnpm exec playwright install chromium
pnpm test:e2e
```

Erwartet: FAIL — `/login` liefert 404, die Route existiert noch nicht.

- [ ] **Step 7: Login implementieren**

`apps/web/app/login/actions.ts`:

```ts
"use server";

import { redirect } from "next/navigation";
import { z } from "zod";
import { createServerSupabaseClient } from "@/lib/supabase/server";

const emailSchema = z.object({ email: z.string().email() });
const otpSchema = z.object({
  email: z.string().email(),
  token: z.string().regex(/^\d{6}$/),
});

export async function requestOtp(_prev: unknown, formData: FormData) {
  const parsed = emailSchema.safeParse({ email: formData.get("email") });
  if (!parsed.success) return { error: "Bitte eine gueltige E-Mail eingeben." };

  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.auth.signInWithOtp({
    email: parsed.data.email,
    options: { shouldCreateUser: false },
  });
  if (error) return { error: "Code konnte nicht gesendet werden." };

  return { sentTo: parsed.data.email };
}

export async function verifyOtp(_prev: unknown, formData: FormData) {
  const parsed = otpSchema.safeParse({
    email: formData.get("email"),
    token: formData.get("token"),
  });
  if (!parsed.success) return { error: "Der Code besteht aus sechs Ziffern." };

  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.auth.verifyOtp({
    email: parsed.data.email,
    token: parsed.data.token,
    type: "email",
  });
  if (error) return { error: "Der Code ist ungueltig oder abgelaufen." };

  redirect("/");
}
```

`apps/web/app/login/page.tsx`:

```tsx
"use client";

import { useActionState } from "react";
import { requestOtp, verifyOtp } from "./actions";

export default function LoginPage() {
  const [requestState, requestAction] = useActionState(requestOtp, null);
  const [verifyState, verifyAction] = useActionState(verifyOtp, null);

  if (requestState && "sentTo" in requestState && requestState.sentTo) {
    return (
      <form action={verifyAction}>
        <input type="hidden" name="email" value={requestState.sentTo} />
        <label htmlFor="token">Code aus der E-Mail</label>
        <input id="token" name="token" inputMode="numeric" required />
        <button type="submit">Anmelden</button>
        {verifyState && "error" in verifyState && <p>{verifyState.error}</p>}
      </form>
    );
  }

  return (
    <form action={requestAction}>
      <label htmlFor="email">E-Mail</label>
      <input id="email" name="email" type="email" required />
      <button type="submit">Code anfordern</button>
      {requestState && "error" in requestState && <p>{requestState.error}</p>}
    </form>
  );
}
```

**E2E-Test und Playwright-Konfiguration** (gehören zu Step 5):

`e2e/login.spec.ts`:

```ts
import { expect, test } from "@playwright/test";
import { createClient } from "@supabase/supabase-js";

const INBUCKET = "http://127.0.0.1:54324";

async function latestOtpFor(email: string): Promise<string> {
  const mailbox = email.split("@")[0]!;
  for (let attempt = 0; attempt < 20; attempt++) {
    const list = await fetch(`${INBUCKET}/api/v1/mailbox/${mailbox}`);
    const messages = (await list.json()) as Array<{ id: string }>;
    const newest = messages.at(-1);
    if (newest) {
      const detail = await fetch(
        `${INBUCKET}/api/v1/mailbox/${mailbox}/${newest.id}`,
      );
      const body = (await detail.json()) as { body: { text: string } };
      const match = body.body.text.match(/\b(\d{6})\b/);
      if (match) return match[1]!;
    }
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  throw new Error(`Kein OTP fuer ${email} in Inbucket gefunden`);
}

test("Mitglied meldet sich per E-Mail-Code an und sieht sein Studio", async ({
  page,
}) => {
  const admin = createClient(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    { auth: { persistSession: false } },
  );

  const email = `e2e-${crypto.randomUUID()}@example.test`;
  const { data: user, error: userError } = await admin.auth.admin.createUser({
    email,
    email_confirm: true,
  });
  if (userError) throw userError;

  const { data: studio, error: studioError } = await admin
    .from("studios")
    .insert({ name: "E2E Studio" })
    .select("id")
    .single();
  if (studioError) throw studioError;

  const { error: membershipError } = await admin
    .from("studio_memberships")
    .insert({
      studio_id: studio.id,
      user_id: user.user.id,
      role: "member",
    });
  if (membershipError) throw membershipError;

  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByRole("button", { name: "Code anfordern" }).click();

  const otp = await latestOtpFor(email);
  await page.getByLabel("Code aus der E-Mail").fill(otp);
  await page.getByRole("button", { name: "Anmelden" }).click();

  await expect(page.getByTestId("user-email")).toHaveText(email);
  await expect(page.getByTestId("studio-list")).toContainText("E2E Studio");
});
```

`playwright.config.ts` im Wurzelverzeichnis:

```ts
import { defineConfig } from "@playwright/test";
import "dotenv/config";

export default defineConfig({
  testDir: "./e2e",
  timeout: 60_000,
  use: { baseURL: "http://127.0.0.1:3000" },
  webServer: {
    command: "pnpm --filter @fitretro/web dev",
    url: "http://127.0.0.1:3000",
    reuseExistingServer: true,
    timeout: 120_000,
  },
});
```

Im Wurzel-`package.json`:

```json
"test:e2e": "playwright test"
```

- [ ] **Step 8: Test laufen lassen und Erfolg bestätigen**

```bash
pnpm test:e2e
```

Erwartet: 1 passed.

- [ ] **Step 9: Committen**

```bash
git add -A
git commit -m "feat: Next.js-App mit E-Mail-OTP-Login und E2E-Test ueber Inbucket"
```

---

## Task 5: AASA-Route und Web-Fallback unter `/t/<token>`

**Files:**
- Create: `apps/web/app/api/aasa/route.ts`
- Create: `apps/web/app/t/[token]/page.tsx`
- Modify: `apps/web/package.json` (Vitest ergänzen), `apps/web/.env.local`, `apps/web/.env.local.example` (Apple-Schlüssel ergänzen)
- Test: `apps/web/app/api/aasa/route.test.ts`, `e2e/tag-fallback.spec.ts`

**Interfaces:**
- Consumes: `isValidTagToken`, `hashTagToken` aus Task 3; `createServerSupabaseClient` aus Task 4
- Produces: Route `/.well-known/apple-app-site-association` mit `Content-Type: application/json` ohne Redirect; Route `/t/<token>`

- [ ] **Step 1: Den fehlschlagenden Unit-Test für die AASA-Route schreiben**

`apps/web/app/api/aasa/route.test.ts`:

**Hinweis zu den Umgebungsvariablen:** `GET()` liest `APPLE_TEAM_ID`/`APPLE_BUNDLE_ID` erst beim Aufruf, nicht beim Modul-Import — deshalb reicht `vi.stubEnv` in `beforeAll`, ohne echte `.env`-Datei einzubinden. Das funktioniert unverändert in CI, wo keine Apple-Secrets hinterlegt sind.

```ts
import { beforeAll, describe, expect, it, vi } from "vitest";
import { GET } from "./route";

beforeAll(() => {
  vi.stubEnv("APPLE_TEAM_ID", "ABCDE12345");
  vi.stubEnv("APPLE_BUNDLE_ID", "de.fitretro.member");
});

describe("apple-app-site-association", () => {
  it("liefert Content-Type application/json", async () => {
    const response = await GET();
    expect(response.headers.get("content-type")).toContain("application/json");
  });

  it("antwortet mit 200 und ohne Redirect", async () => {
    const response = await GET();
    expect(response.status).toBe(200);
    expect(response.headers.get("location")).toBeNull();
  });

  it("enthaelt genau einen applinks-Eintrag mit /t/*", async () => {
    const body = (await (await GET()).json()) as {
      applinks: {
        details: Array<{ appIDs: string[]; components: Array<{ "/": string }> }>;
      };
    };
    expect(body.applinks.details).toHaveLength(1);
    expect(body.applinks.details[0]!.components[0]!["/"]).toBe("/t/*");
  });

  it("nennt die App-ID aus der Umgebung", async () => {
    const body = (await (await GET()).json()) as {
      applinks: { details: Array<{ appIDs: string[] }> };
    };
    expect(body.applinks.details[0]!.appIDs[0]).toMatch(/^[A-Z0-9]{10}\..+/);
  });
});
```

`apps/web` braucht dafür Vitest. In `apps/web/package.json` **ergänzen** (die bestehenden `scripts` und `devDependencies` aus Task 4 bleiben erhalten, hier wird zusammengeführt, nicht ersetzt):

```json
"scripts": {
  "test": "vitest run"
},
"devDependencies": {
  "vitest": "^2.1.0"
}
```

- [ ] **Step 2: Test laufen lassen und Fehlschlag bestätigen**

```bash
pnpm --filter @fitretro/web test
```

Erwartet: FAIL — `Failed to resolve import "./route"`.

- [ ] **Step 3: AASA-Route implementieren**

`apps/web/app/api/aasa/route.ts`:

```ts
import { NextResponse } from "next/server";

export const dynamic = "force-static";

/**
 * Apple laedt diese Datei unter /.well-known/apple-app-site-association.
 * Der Pfad wird in next.config.mjs auf diese Route umgeschrieben.
 * Bedingungen von Apple: HTTPS, kein Redirect, Content-Type application/json.
 */
export function GET(): NextResponse {
  const appId = `${process.env.APPLE_TEAM_ID}.${process.env.APPLE_BUNDLE_ID}`;

  return NextResponse.json(
    {
      applinks: {
        details: [
          {
            appIDs: [appId],
            components: [{ "/": "/t/*", comment: "Geraete-Tags" }],
          },
        ],
      },
    },
    { headers: { "content-type": "application/json" } },
  );
}
```

In `apps/web/.env.local` **und** `apps/web/.env.local.example` (beide aus Task 4) ergänzen:

```text
APPLE_TEAM_ID=<TEAM_ID aus den Global Constraints>
APPLE_BUNDLE_ID=<BUNDLE_ID aus den Global Constraints>
```

Diese Werte versorgen ausschließlich den echten `next dev`-Lauf; der Unit-Test oben hängt davon nicht ab (siehe `vi.stubEnv` in Step 1).

- [ ] **Step 4: Test laufen lassen und Erfolg bestätigen**

```bash
pnpm --filter @fitretro/web test
```

Erwartet: 4 passed.

- [ ] **Step 5: Den fehlschlagenden E2E-Test für den Fallback schreiben**

`e2e/tag-fallback.spec.ts`:

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

test("aktiver Tag ohne Geraet zeigt den Installationshinweis", async ({
  page,
}) => {
  const client = admin();
  const { data: studio, error: studioError } = await client
    .from("studios")
    .insert({ name: "Fallback Studio" })
    .select("id")
    .single();
  if (studioError) throw studioError;

  const token = createTagToken();
  const { error: tagError } = await client.from("machine_tags").insert({
    studio_id: studio.id,
    token_hash: hashTagToken(token),
    status: "active",
  });
  if (tagError) throw tagError;

  await page.goto(`/t/${token}`);
  await expect(page.getByTestId("install-hint")).toBeVisible();
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

- [ ] **Step 6: Test laufen lassen und Fehlschlag bestätigen**

```bash
pnpm test:e2e
```

Erwartet: FAIL — 404 auf `/t/...`.

- [ ] **Step 7: Fallback-Route implementieren**

`apps/web/app/t/[token]/page.tsx`:

```tsx
import { createClient } from "@supabase/supabase-js";
import { hashTagToken, isValidTagToken } from "@fitretro/domain";

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

  // Oeffentlicher Endpunkt ohne Nutzersession: bewusst mit erhoehten Rechten,
  // liefert aber ausschliesslich nicht personenbezogene Tagdaten zurueck.
  const client = createClient(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    { auth: { persistSession: false } },
  );

  const { data: tag } = await client
    .from("machine_tags")
    .select("id, status")
    .eq("token_hash", hashTagToken(token))
    .eq("status", "active")
    .maybeSingle();

  if (!tag) return unknown;

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

- [ ] **Step 8: Tests laufen lassen und Erfolg bestätigen**

```bash
pnpm test:e2e
```

Erwartet: 5 passed (Login plus vier Fallback-Tests).

- [ ] **Step 9: Committen**

```bash
git add -A
git commit -m "feat: AASA-Route und Web-Fallback unter /t/<token>"
```

---

## Task 6: Deployment auf echte Domain

**Files:**
- Create: `.github/workflows/ci.yml`
- Create: `scripts/smoke-aasa.mjs`
- Modify: `package.json` (Skript `smoke:aasa`)

**Interfaces:**
- Consumes: Web-App aus Task 4 und 5
- Produces: erreichbare `DOMAIN` mit gültiger AASA-Datei; Smoke-Test-Skript, das die Apple-Bedingungen prüft

- [ ] **Step 1: Den fehlschlagenden Smoke-Test schreiben**

`scripts/smoke-aasa.mjs`:

```js
#!/usr/bin/env node
const domain = process.argv[2];
if (!domain) {
  console.error("Aufruf: node scripts/smoke-aasa.mjs <domain>");
  process.exit(2);
}

const url = `https://${domain}/.well-known/apple-app-site-association`;
const response = await fetch(url, { redirect: "manual" });

const failures = [];
if (response.status !== 200) {
  failures.push(`Status ${response.status}, erwartet 200`);
}
if (response.headers.get("location")) {
  failures.push("Redirect vorhanden — Apple folgt keinem Redirect");
}
const contentType = response.headers.get("content-type") ?? "";
if (!contentType.includes("application/json")) {
  failures.push(`Content-Type "${contentType}", erwartet application/json`);
}

let body;
try {
  body = await response.json();
} catch {
  failures.push("Antwort ist kein gueltiges JSON");
}

const component = body?.applinks?.details?.[0]?.components?.[0]?.["/"];
if (component !== "/t/*") {
  failures.push(`Pfadkomponente "${component}", erwartet "/t/*"`);
}

const appId = body?.applinks?.details?.[0]?.appIDs?.[0];
if (!/^[A-Z0-9]{10}\..+/.test(appId ?? "")) {
  failures.push(`App-ID "${appId}" hat nicht das Format TEAMID.BUNDLEID`);
}

if (failures.length > 0) {
  console.error(`AASA-Smoke-Test fehlgeschlagen fuer ${url}:`);
  for (const failure of failures) console.error(`  - ${failure}`);
  process.exit(1);
}

console.log(`AASA-Smoke-Test bestanden fuer ${url}`);
```

Im Wurzel-`package.json`:

```json
"smoke:aasa": "node scripts/smoke-aasa.mjs"
```

- [ ] **Step 2: Smoke-Test laufen lassen und Fehlschlag bestätigen**

```bash
pnpm smoke:aasa <DOMAIN>
```

Erwartet: FAIL — die Domain existiert noch nicht.

- [ ] **Step 3: Supabase-Projekt in `eu-central-1` anlegen und Migrationen ausspielen**

Projekt in der Supabase-Konsole in der Region Frankfurt (`eu-central-1`) anlegen, dann:

```bash
pnpm exec supabase link --project-ref <project-ref>
pnpm exec supabase db push
```

- [ ] **Step 4: Auf Vercel deployen und Domain verbinden**

- Repository auf GitHub veröffentlichen (privates Repo).
- Vercel-Projekt anlegen, Root Directory `apps/web`, Region `fra1`.
- Umgebungsvariablen setzen: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `APPLE_TEAM_ID`, `APPLE_BUNDLE_ID`.
- `DOMAIN` als Custom Domain verbinden und HTTPS-Zertifikat abwarten.

- [ ] **Step 5: Smoke-Test laufen lassen und Erfolg bestätigen**

```bash
pnpm smoke:aasa <DOMAIN>
```

Erwartet: `AASA-Smoke-Test bestanden`.

Zusätzlich Apples eigene Prüfung aufrufen, um die Auslieferung an das CDN zu bestätigen:

```bash
curl -sS "https://app-site-association.cdn-apple.com/a/v1/<DOMAIN>"
```

Erwartet: dasselbe JSON. Ist die Antwort leer, ist die Datei noch nicht im Apple-CDN — das kann bis zu 24 Stunden dauern und ist kein Fehler in deinem Deployment.

- [ ] **Step 6: CI einrichten**

`.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  web:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
        with:
          version: 9
      - uses: actions/setup-node@v4
        with:
          node-version: lts/*
          cache: pnpm
      - run: pnpm install --frozen-lockfile
      - run: pnpm typecheck
      - run: pnpm test
      - run: pnpm exec supabase start
      - run: pnpm test:integration
        env:
          SUPABASE_URL: http://127.0.0.1:54321
          SUPABASE_ANON_KEY: ${{ secrets.LOCAL_ANON_KEY }}
          SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.LOCAL_SERVICE_ROLE_KEY }}
```

Die beiden lokalen Schlüssel sind bei Supabase-CLI-Instanzen deterministisch und werden von `supabase start` ausgegeben. Sie schützen nichts Produktives, gehören aber trotzdem in die Repository-Secrets statt in die Datei.

- [ ] **Step 7: Committen**

```bash
git add -A
git commit -m "ci: Deployment auf eigene Domain plus AASA-Smoke-Test"
```

---

## Task 7: iOS-App mit Universal-Link-Validierung *(auf dem Mac)*

**Files:**
- Create: `apps/ios-member/FitnessMember/TagLink.swift`
- Create: `apps/ios-member/FitnessMember/FitnessMemberApp.swift`
- Create: `apps/ios-member/FitnessMember/ContentView.swift`
- Test: `apps/ios-member/FitnessMemberTests/TagLinkTests.swift`

**Interfaces:**
- Consumes: `DOMAIN`, `TEAM_ID`, `BUNDLE_ID` aus den Global Constraints; die in Task 6 ausgelieferte AASA-Datei
- Produces: `TagLink.token(from: URL) -> String?`

**Voraussetzung:** Repository auf dem Mac auschecken. Xcode-Projekt in `apps/ios-member/` mit Product Name `FitnessMember`, Bundle Identifier `BUNDLE_ID`, Interface SwiftUI, Testing System **Swift Testing**.

- [ ] **Step 1: Den fehlschlagenden Test schreiben**

`apps/ios-member/FitnessMemberTests/TagLinkTests.swift`:

```swift
import Testing
@testable import FitnessMember

@Suite("TagLink")
struct TagLinkTests {
    @Test("akzeptiert einen gueltigen Tag-Link")
    func acceptsValidLink() {
        let url = URL(string: "https://\(TagLink.host)/t/abcdefghij0123456789AB")!
        #expect(TagLink.token(from: url) == "abcdefghij0123456789AB")
    }

    @Test("weist eine fremde Domain zurueck")
    func rejectsForeignHost() {
        let url = URL(string: "https://boese.example/t/abcdefghij0123456789AB")!
        #expect(TagLink.token(from: url) == nil)
    }

    @Test("weist http zurueck")
    func rejectsHttp() {
        let url = URL(string: "http://\(TagLink.host)/t/abcdefghij0123456789AB")!
        #expect(TagLink.token(from: url) == nil)
    }

    @Test("weist einen falschen Pfad zurueck")
    func rejectsWrongPath() {
        let url = URL(string: "https://\(TagLink.host)/x/abcdefghij0123456789AB")!
        #expect(TagLink.token(from: url) == nil)
    }

    @Test("weist einen zu kurzen Token zurueck")
    func rejectsShortToken() {
        let url = URL(string: "https://\(TagLink.host)/t/kurz")!
        #expect(TagLink.token(from: url) == nil)
    }

    @Test("weist unerlaubte Zeichen zurueck")
    func rejectsIllegalCharacters() {
        let url = URL(string: "https://\(TagLink.host)/t/abcdefghij0123456789A%2F")!
        #expect(TagLink.token(from: url) == nil)
    }

    @Test("weist zusaetzliche Pfadsegmente zurueck")
    func rejectsExtraSegments() {
        let url = URL(string: "https://\(TagLink.host)/t/abcdefghij0123456789AB/extra")!
        #expect(TagLink.token(from: url) == nil)
    }
}
```

- [ ] **Step 2: Test laufen lassen und Fehlschlag bestätigen**

In Xcode `⌘U`, oder:

```bash
xcodebuild test -scheme FitnessMember -destination 'platform=iOS Simulator,name=iPhone 16'
```

Erwartet: Compile-Fehler — `cannot find 'TagLink' in scope`.

- [ ] **Step 3: Implementierung schreiben**

`apps/ios-member/FitnessMember/TagLink.swift`:

```swift
import Foundation

/// Validierung eingehender Universal Links.
///
/// Der Tag-Token ist ein oeffentlicher Locator. Aus einem gueltigen Link
/// folgt ausdruecklich keine Berechtigung — die Autorisierung findet
/// ausschliesslich serverseitig statt.
enum TagLink {
    static let host = "app.beispiel.de"   // <- DOMAIN aus den Global Constraints

    private static let tokenLength = 22

    static func token(from url: URL) -> String? {
        guard url.scheme == "https", url.host() == host else { return nil }

        let segments = url.pathComponents.filter { $0 != "/" }
        guard segments.count == 2, segments[0] == "t" else { return nil }

        let token = segments[1]
        guard token.count == tokenLength,
              token.allSatisfy(isAllowedTokenCharacter)
        else { return nil }

        return token
    }

    private static func isAllowedTokenCharacter(_ character: Character) -> Bool {
        character.isASCII
            && (character.isLetter || character.isNumber
                || character == "-" || character == "_")
    }
}
```

`apps/ios-member/FitnessMember/ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    let token: String?

    var body: some View {
        VStack(spacing: 16) {
            if let token {
                Text("Tag erkannt")
                    .font(.headline)
                Text(token)
                    .font(.system(.body, design: .monospaced))
                    .accessibilityIdentifier("tag-token")
            } else {
                Text("Noch kein Tag gescannt")
                    .accessibilityIdentifier("tag-empty")
            }
        }
        .padding()
    }
}
```

`apps/ios-member/FitnessMember/FitnessMemberApp.swift`:

```swift
import SwiftUI

@main
struct FitnessMemberApp: App {
    @State private var token: String?

    var body: some Scene {
        WindowGroup {
            ContentView(token: token)
                .onOpenURL { url in
                    // Ungueltige Links werden still verworfen; der Screen
                    // bleibt im leeren Zustand.
                    if let parsed = TagLink.token(from: url) {
                        token = parsed
                    }
                }
        }
    }
}
```

- [ ] **Step 4: Tests laufen lassen und Erfolg bestätigen**

```bash
xcodebuild test -scheme FitnessMember -destination 'platform=iOS Simulator,name=iPhone 16'
```

Erwartet: 7 Tests bestanden.

- [ ] **Step 5: Associated Domains aktivieren**

In Xcode: Target `FitnessMember` → Signing & Capabilities → **+ Capability** → *Associated Domains* → Eintrag hinzufügen:

```text
applinks:<DOMAIN>
```

Signing Team auf das Team mit `TEAM_ID` setzen.

- [ ] **Step 6: Universal Link auf einem echten iPhone prüfen**

Die App auf ein per Kabel verbundenes iPhone installieren (Simulator genügt hier nicht). Dann in **Notizen** — nicht in Safari, denn dort öffnet die Adressleiste den Link im Browser — folgende Adresse eintippen, antippen und lange gedrückt halten:

```text
https://<DOMAIN>/t/abcdefghij0123456789AB
```

Erwartet: Die App öffnet und zeigt `abcdefghij0123456789AB`.

Öffnet stattdessen Safari, in dieser Reihenfolge prüfen:

1. `pnpm smoke:aasa <DOMAIN>` erneut laufen lassen.
2. `curl -sS "https://app-site-association.cdn-apple.com/a/v1/<DOMAIN>"` — leer heißt: Apple hat die Datei noch nicht abgeholt, bis zu 24 Stunden warten.
3. App löschen, iPhone neu starten, neu installieren — iOS cacht die Zuordnung aggressiv.
4. `TEAM_ID` und `BUNDLE_ID` in der AASA-Datei gegen die Xcode-Einstellungen prüfen.

- [ ] **Step 7: Committen**

```bash
git add -A
git commit -m "feat(ios): App-Shell mit validiertem Universal-Link-Einstieg"
```

---

## Task 8: Physischer NFC-Test *(Gate — hier wird entschieden)*

**Files:**
- Create: `docs/m0-ergebnis.md`

**Interfaces:**
- Consumes: funktionierender Universal Link aus Task 7
- Produces: die dokumentierte Entscheidung NFC-first oder QR-first

- [ ] **Step 1: Tags beschaffen**

**On-Metal-NFC-Tags mit Ferritschicht**, NTAG213 oder NTAG215, rund oder rechteckig, selbstklebend. Suchbegriff: „NFC Tag on metal NTAG213 anti-metal". Mindestens fünf Stück bestellen, damit mehrere Anbringungsorte getestet werden können.

Gewöhnliche NTAG213-Aufkleber ohne Ferritschicht sind für diesen Test unbrauchbar — auf Stahl koppelt die Antenne nicht.

- [ ] **Step 2: Einen Tag beschreiben**

App **NFC Tools** (iOS) installieren. Dort *Schreiben* → *Datensatz hinzufügen* → *URL* → eintragen:

```text
https://<DOMAIN>/t/abcdefghij0123456789AB
```

Danach *Schreiben* und den Tag an das iPhone halten. Anschließend im Reiter *Lesen* prüfen, dass genau diese URL als NDEF-Datensatz auf dem Tag steht.

- [ ] **Step 3: Auf dem Tisch testen**

Tag auf den Tisch legen, iPhone entsperrt darüberhalten (obere Kante, Bereich der Kamera). Erwartet: Systembanner erscheint, Antippen öffnet die App und zeigt den Token.

Erscheint kein Banner: Background Tag Reading funktioniert nicht bei aktivem Low Power Mode, geöffneter Kamera oder aktivem Apple Pay. Diese Bedingungen ausschließen und wiederholen.

- [ ] **Step 4: Am echten Fitnessgerät testen**

Den Tag an einem echten Gerät anbringen und **mindestens drei Anbringungsorte** vergleichen:

- am Rahmen aus Stahlrohr
- an einer Kunststoffabdeckung
- an der Gewichtsblock-Verkleidung

Je Position zehn Versuche zählen. Notieren: Trefferquote, Abstand in Zentimetern, ob das iPhone auf die Position ausgerichtet werden musste.

- [ ] **Step 5: Ergebnis dokumentieren und entscheiden**

`docs/m0-ergebnis.md` anlegen mit: Tagmodell und Bezugsquelle, Stückpreis, getestete Positionen, Trefferquote je Position, das verwendete iPhone-Modell und die iOS-Version, sowie die Entscheidung.

**Entscheidungsregel:**

- **Trefferquote ≥ 90 % an mindestens einer praktikablen Position → NFC-first.** Der Plan geht weiter mit dem Gerätekatalog. Die getestete Position wird als Anbringungsvorgabe für Studios festgehalten.
- **Trefferquote darunter → QR-first.** Nicht weiterbauen, sondern zuerst Spec-Abschnitt 3 (M0) und 8.1 anpassen: QR wird der Haupteinstieg, NFC bleibt optional. Der In-App-Scanner wird damit pilotkritisch statt optional und muss in den Folgeplan.

- [ ] **Step 6: Committen**

```bash
git add docs/m0-ergebnis.md
git commit -m "docs: M0-Ergebnis — Entscheidung NFC-first oder QR-first"
```

---

## Nach diesem Plan

Es existieren dann: ein lauffähiges Monorepo, vier Tabellen mit getesteter Mandantentrennung, ein Login per E-Mail-Code, eine echte Domain mit gültiger AASA-Datei, ein Web-Fallback, eine iOS-App, die sich per NFC-Tap öffnen lässt, und eine belastbare Entscheidung über den Haupteinstiegsweg.

Die nächsten Pläne, jeweils für sich lauffähig:

1. **Gerätekatalog** — `equipment_models`, `equipment_setting_definitions`, `exercises`, `equipment_model_exercises`, `instruction_assets`, `machines`; Tagzuweisung; Trainer-Weboberfläche; Medien-Upload mit Formatgrenzen.
2. **Member-App** — Tab-Navigation, `GET /me/bootstrap` mit Prefetch, `GET /tags/{token}/context`, Selbstkalibrierung, Satz-Logging mit clientgenerierten UUIDs, Blockstruktur der Session.
3. **Fortschritt und Abschluss** — `GET /me/sessions`, `GET /me/progress`, Home-Tab mit Swift Charts, Session-Detail, Session-Abschluss inklusive trägem Autoabschluss.
4. **Progression und Web-Fallback-Ausbau** — deterministische Regelengine mit Begründungscodes, Problemmeldung, Fallback mit Einweisungsinhalten.
