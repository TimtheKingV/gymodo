# Studio-Einstellungen und Datenschutzgrenze — Umsetzungsplan

> **Für agentische Ausführung:** ERFORDERLICHE UNTER-SKILL: `superpowers:subagent-driven-development` (empfohlen) oder `superpowers:executing-plans`, um diesen Plan Aufgabe für Aufgabe umzusetzen. Die Schritte tragen Checkboxen (`- [ ]`) zur Nachverfolgung.

**Ziel:** Die beiden letzten offenen Bauabschnitte von Phase 2 schließen — das Studio bekommt Einstellungen, die sich speichern lassen, und die Datenbank zieht die Datenschutzgrenze, die den Überblick freischaltet.

**Architektur:** Drei Migrationen (`0032`–`0034`), eine neue Domain-Datei, zwei neue Portalbereiche. `0032` hängt die Stornofrist ans Studio und gibt Personal ein Speicherrecht, das den Beitrittscode über ein **Spaltenrecht** ausspart — eine Policy kann „diese Spalte bleibt unverändert" nicht ausdrücken, ein Grant schon. `0033` nimmt vier Select-Policies die Staff-Klausel; danach ist kein Trainingsdatum eines Mitglieds für Personal mehr erreichbar. `0034` baut den einzigen verbliebenen Weg dorthin: eine `SECURITY DEFINER`-Funktion, die ausschließlich Summen liefert und die Aufschlüsselung je Gerät unterhalb von fünf aktiven Mitgliedern verschweigt.

**Tech-Stack:** PostgreSQL 15 mit RLS · Supabase (lokal über `supabase migration up --local`) · TypeScript · Next.js App Router mit Server Actions · Vitest (Integration gegen echtes Postgres) · Playwright (E2E)

**Spec:** `docs/superpowers/specs/2026-08-31-trainerportal-struktur-design.md` — Abschnitt 1 (Informationsarchitektur), Abschnitt 4 (Die Datenschutzgrenze), Abschnitt 5 (Zustände), Abschnitt 7 (Was kein Backend hat), Abschnitt 8 (Offene Punkte)

**Artboards:** `docs/superpowers/design/portal/Main.dc.html` (Überblick), `EinstellungenStudio.dc.html`, `EinstellungenKonto.dc.html`, `LeuteMitglieder.dc.html`

**Einordnung:** Strang A aus `2026-09-01-gesamtfahrplan.md` Abschnitt 5, Phase 2 Punkte 3 und 4. Läuft parallel zu Strang B (Phase 3, Einrichtung am Gerät) und Strang C (iOS).

---

## Global Constraints

Diese Regeln gelten für **jede** Aufgabe. Sie sind aus Spec und Bestandscode wörtlich übernommen.

- **Sprache:** Alle Bezeichner in der Datenbank sind englisch (`join_code`, `location_note`, `problem_flag`). Alle Kommentare, Testnamen, Fehlermeldungen und Oberflächentexte sind deutsch. SQL-Kommentare stehen **ohne Umlaute** (`moeglich`, `waere`, `pruefen`) — so hält es der gesamte Bestand ab `0001`.
- **RLS-Muster:** `auth.uid()` immer als `(select auth.uid())` — einmal ausgewertet statt je Zeile. Äußere Spalten in Policies mit Tabellennamen qualifizieren (`workout_sets.studio_id`, nie `studio_id`), sonst löst PostgreSQL gegen die innere Tabelle auf und die Prüfung prüft stillschweigend nichts.
- **`SECURITY DEFINER`-Muster:** immer `set search_path = public, pg_temp`, immer eine ausdrückliche `is_studio_staff`- oder `is_studio_member`-Prüfung im Rumpf, immer `revoke all … from public, anon, authenticated, service_role` gefolgt von einem gezielten `grant execute … to authenticated`.
- **Abweisung ohne Auskunft:** Wer nicht darf, bekommt eine leere Antwort, keinen Fehler — wie `list_studio_members` (0031) und `join_studio_by_code` (0030). Eine unterschiedliche Antwort machte die Funktion zum Orakel.
- **Migrationsnummern:** `0032`, `0033`, `0034` sind für diesen Plan reserviert. Strang B (Phase 3) braucht laut Spec keine Migration; falls doch, beginnt er bei `0035`.
- **Anwenden lokal:** `npx --no-install supabase migration up --local`. `pnpm smoke:migrations` und `supabase db push` scheitern auf dieser Maschine mit `TransportError` (ausgehend gesperrte Ports 5432/6543, Fahrplan Abschnitt 4d) — der Cloud-Abgleich läuft am Schluss über den Supabase-MCP und braucht danach die Normalisierung der Zeitstempel-Versionen auf `0032`–`0034`.
- **Tests laufen gegen echtes Postgres.** `tests/integration/**` braucht `.env` mit `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` und einen laufenden lokalen Stack. Aufruf: `pnpm vitest run --config vitest.config.ts <datei>`.
- **Zustände (Spec Abschnitt 5):** Im Portal gelten drei — *Leer* (Überschrift plus nächster Schritt, **nie** eine Statistik voller Nullen), *Fehler* (sagt, was falsch ist **und** was gilt, nie nur „ungültig"), *Deaktiviert* (nie stumm — daneben steht, was fehlt). *Skelett* nur für Medien, *Offline* gar nicht.
- **Ein Formular je Bildschirmabschnitt**, und genau eine Akzentfläche je Formular (`styles.primary`).
- **Passwortregel:** mindestens zehn Zeichen, keine Zeichenklassenpflicht. So steht es in `apps/web/app/passwort-vergessen/actions.ts` und so bleibt es.
- **Commit-Nachrichten** enden mit:
  ```
  Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01N9D8evoBWvz734s2yrygfE
  ```

---

## Dateiübersicht

Was entsteht, was sich ändert, und wofür jede Datei zuständig ist.

### Datenbank

| Datei | Zuständig für |
| --- | --- |
| `supabase/migrations/0032_studio_einstellungen.sql` | **neu** — Spalte `cancellation_deadline_hours`, Policy `studios_update_staff`, Spaltenrechte, die `join_code` aussparen |
| `supabase/migrations/0033_datenschutzgrenze.sql` | **neu** — vier Select-Policies verlieren die Staff-Klausel |
| `supabase/migrations/0034_studio_ueberblick.sql` | **neu** — `studio_overview`, die einzige Stelle, an der Trainingsdaten für Personal noch erreichbar sind |

### Fachschicht

| Datei | Zuständig für |
| --- | --- |
| `packages/domain/src/studio.ts` | **ändern** — `getStudioSettings`, `updateStudioSettings` neben dem bestehenden `requireStudioStaff` |
| `packages/domain/src/overview.ts` | **neu** — `getStudioOverview`, Übersetzung der `jsonb`-Antwort in getippte Werte |
| `packages/domain/src/index.ts` | **ändern** — die neuen Ausfuhren |

### Oberfläche

| Datei | Zuständig für |
| --- | --- |
| `apps/web/app/portal/[studioId]/page.tsx` | **ersetzen** — war Gerätekatalog, wird **Überblick** |
| `apps/web/app/portal/[studioId]/modelle/page.tsx` | **neu** — der bisherige Inhalt der Wurzelseite (Modellliste + „Modell anlegen") |
| `apps/web/app/portal/[studioId]/einstellungen/page.tsx` | **neu** — Reiter *Studio*: Stammdaten, Stornofrist, Beitrittscode |
| `apps/web/app/portal/[studioId]/einstellungen/konto/page.tsx` | **neu** — Reiter *Konto*: E-Mail, Passwort ändern, Abmelden |
| `apps/web/app/portal/[studioId]/einstellungen/Reiter.tsx` | **neu** — die zwei Reiter, ein Client-Bauteil wegen `usePathname` |
| `apps/web/app/portal/[studioId]/einstellungen/EinstellungenActions.tsx` | **neu** — `BeitrittscodeKarte` (aus `leute/` hierher gezogen) und `PasswortAendernFormular` |
| `apps/web/app/portal/[studioId]/leute/LeuteActions.tsx` | **ändern** — `BeitrittscodeKarte` zieht aus |
| `apps/web/app/portal/[studioId]/leute/page.tsx` | **ändern** — statt der Karte eine Zeile mit Verweis auf *Einstellungen*, wie im Artboard |
| `apps/web/app/portal/[studioId]/Rail.tsx` | **ändern** — Einträge *Überblick* und *Einstellungen*, „Modell anlegen" zeigt auf `/modelle` |
| `apps/web/app/portal/actions.ts` | **ändern** — `studioSpeichern`, `passwortAendern`, `abmelden` |
| `apps/web/app/portal/portal.module.css` | **ändern** — drei Klassen für die Reiter, vier für die Kennzahlkacheln |

### Tests

| Datei | Zuständig für |
| --- | --- |
| `tests/integration/rls-studio-einstellungen.test.ts` | **liegt bereits im Worktree, im RED-Zustand** — Spalte, Speicherrecht, Spaltenrecht auf `join_code` |
| `tests/integration/rls-workout-sessions.test.ts` | **ändern** — ein positiver Staff-Test wird negativ |
| `tests/integration/rls-workout-sets.test.ts` | **ändern** — dito |
| `tests/integration/rls-member-machine-calibrations.test.ts` | **ändern** — dito |
| `tests/integration/rls-progression-suggestions.test.ts` | **ändern** — dito |
| `tests/integration/studio-ueberblick.test.ts` | **neu** — Summen, Mindestzahl, Abweisung |
| `e2e/einstellungen.spec.ts` | **neu** — Stornofrist speichern, Code erneuern, Passwort ändern |
| `e2e/trainerportal.spec.ts` | **ändern** — der Katalog liegt jetzt unter `/modelle` |

### Dokumentation

| Datei | Zuständig für |
| --- | --- |
| `docs/superpowers/plans/2026-09-01-gesamtfahrplan.md` | **ändern** — Abschnitt 3, Abschnitt 5 Phase 2, Abschnitt 6 |

---

## Reihenfolge und Abhängigkeiten

```
Aufgabe 1 (0032)  →  Aufgabe 2 (Fachschicht)  →  Aufgabe 3 (Reiter Studio)  →  Aufgabe 4 (Reiter Konto)
                                                          ↓
Aufgabe 5 (0033)  →  Aufgabe 6 (0034)  →  Aufgabe 7 (Fachschicht)  →  Aufgabe 8 (Überblick + Umzug)
                                                          ↓
                                                 Aufgabe 9 (E2E + Doku)
```

Aufgabe 5 und 6 hängen nicht an 1–4. Wer den Plan zu zweit ausführt, kann bei 1 und bei 5 gleichzeitig anfangen; beide fassen unterschiedliche Tabellen an. Aufgabe 8 braucht beide Stränge, weil die Rail in beiden geändert wird.

---

### Aufgabe 1: Migration 0032 — Spalten und Speicherrecht am Studio

Bis hier trägt `studios` genau eine Policy: `studios_select` aus `0001`. Es gibt keine Spalte für die Stornofrist und keinen Weg, den Namen zu ändern. Die Einstellungsseite hätte nichts zu speichern.

**Dateien:**
- Erstellen: `supabase/migrations/0032_studio_einstellungen.sql`
- Test: `tests/integration/rls-studio-einstellungen.test.ts` *(liegt bereits im Worktree)*

**Schnittstellen:**
- Verbraucht: `public.is_studio_staff(uuid)` aus `0004`, `studios_join_code_unique` aus `0030`
- Liefert: Spalte `public.studios.cancellation_deadline_hours` (`int not null`, Vorgabe `2`, Bereich 0–168) · Policy `studios_update_staff` · Spaltenrechte, die `join_code` und `join_code_active` für `authenticated` sperren

- [ ] **Schritt 1: Den vorhandenen Test lesen**

Die Datei `tests/integration/rls-studio-einstellungen.test.ts` liegt bereits im Worktree und deckt zehn Fälle ab: die Vorgabe von 2 Stunden, die untere und obere Schranke, den positiven Staff-Pfad, den negativen Mitgliedspfad, den Cross-Tenant-Pfad, die weiterhin geltende Namensprüfung aus `0001` und drei Fälle rund um den Beitrittscode.

Falls sie im Worktree fehlt, ist dies ihr vollständiger Inhalt:

```typescript
import { beforeAll, describe, expect, it } from "vitest";
import { createTestUser, serviceClient, uniqueEmail, userClient } from "./helpers/clients.js";

/**
 * Studio-Einstellungen, Spec 2026-08-31-trainerportal-struktur-design.md
 * Abschnitt 7: `studios` hatte bis 0032 nur `studios_select` -- Speichern war
 * nicht moeglich. Diese Datei haelt fest, wer speichern darf und was dabei
 * unerreichbar bleibt.
 */

let studioId: string;
let fremdStudioId: string;
let trainerEmail: string;
let mitgliedEmail: string;
let fremdTrainerEmail: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioError } = await admin
    .from("studios")
    .insert([{ name: "Einstellungen-Studio" }, { name: "Fremdes Einstellungen-Studio" }])
    .select("id");
  if (studioError) throw studioError;
  studioId = studios[0]!.id;
  fremdStudioId = studios[1]!.id;

  trainerEmail = uniqueEmail("einst-trainer");
  mitgliedEmail = uniqueEmail("einst-mitglied");
  fremdTrainerEmail = uniqueEmail("einst-fremd-trainer");

  const trainerId = await createTestUser(trainerEmail);
  const mitgliedId = await createTestUser(mitgliedEmail);
  const fremdTrainerId = await createTestUser(fremdTrainerEmail);

  const { error } = await admin.from("studio_memberships").insert([
    { studio_id: studioId, user_id: trainerId, role: "trainer" },
    { studio_id: studioId, user_id: mitgliedId, role: "member" },
    { studio_id: fremdStudioId, user_id: fremdTrainerId, role: "trainer" },
  ]);
  if (error) throw error;
});

describe("Stornofrist als Spalte am Studio", () => {
  it("jedes Studio hat von Anfang an eine Frist -- kein NULL, das die Oberflaeche deuten muesste", async () => {
    const admin = serviceClient();
    const { data, error } = await admin
      .from("studios")
      .select("cancellation_deadline_hours")
      .eq("id", studioId)
      .single();

    expect(error).toBeNull();
    expect(data!.cancellation_deadline_hours).toBe(2);
  });

  it("eine negative Frist ist keine Frist", async () => {
    const admin = serviceClient();
    const { error } = await admin
      .from("studios")
      .update({ cancellation_deadline_hours: -1 })
      .eq("id", studioId);

    expect(error).not.toBeNull();
    expect(error!.code).toBe("23514");
  });

  it("mehr als eine Woche Vorlauf ist ein Tippfehler, keine Studioregel", async () => {
    const admin = serviceClient();
    const { error } = await admin
      .from("studios")
      .update({ cancellation_deadline_hours: 169 })
      .eq("id", studioId);

    expect(error).not.toBeNull();
    expect(error!.code).toBe("23514");
  });
});

describe("studios_update_staff", () => {
  it("positiv: ein Trainer speichert Name, Zeitzone und Stornofrist", async () => {
    const client = await userClient(trainerEmail);
    const { data, error } = await client
      .from("studios")
      .update({
        name: "Kraftwerk Nord",
        timezone: "Europe/Vienna",
        cancellation_deadline_hours: 6,
      })
      .eq("id", studioId)
      .select("name, timezone, cancellation_deadline_hours");

    expect(error).toBeNull();
    expect(data).toEqual([
      { name: "Kraftwerk Nord", timezone: "Europe/Vienna", cancellation_deadline_hours: 6 },
    ]);
  });

  it("negativ: ein Mitglied speichert nicht", async () => {
    const client = await userClient(mitgliedEmail);
    const { data, error } = await client
      .from("studios")
      .update({ name: "Von einem Mitglied umbenannt" })
      .eq("id", studioId)
      .select("id");

    expect(error).toBeNull();
    expect(data).toEqual([]);
  });

  it("cross-tenant: der Trainer eines anderen Studios speichert nicht", async () => {
    const client = await userClient(fremdTrainerEmail);
    const { data, error } = await client
      .from("studios")
      .update({ name: "Von aussen umbenannt" })
      .eq("id", studioId)
      .select("id");

    expect(error).toBeNull();
    expect(data).toEqual([]);
  });

  it("ein leerer Name bleibt abgelehnt -- die Pruefung aus 0001 gilt weiter", async () => {
    const client = await userClient(trainerEmail);
    const { error } = await client
      .from("studios")
      .update({ name: "   " })
      .eq("id", studioId);

    expect(error).not.toBeNull();
  });
});

describe("Der Beitrittscode bleibt den Funktionen aus 0030 vorbehalten", () => {
  it("ein Trainer setzt join_code nicht per UPDATE", async () => {
    const client = await userClient(trainerEmail);
    const { error } = await client
      .from("studios")
      .update({ join_code: "AAAAAAAA" })
      .eq("id", studioId);

    // Spaltenrecht, nicht Policy: die Ablehnung kommt als Fehler, nicht als
    // leere Treffermenge. Sonst waere die Retry-Schleife gegen
    // studios_join_code_unique in regenerate_studio_join_code umgehbar.
    expect(error).not.toBeNull();
    expect(error!.code).toBe("42501");
  });

  it("ein Trainer sperrt den Code nicht per UPDATE", async () => {
    const client = await userClient(trainerEmail);
    const { error } = await client
      .from("studios")
      .update({ join_code_active: false })
      .eq("id", studioId);

    expect(error).not.toBeNull();
    expect(error!.code).toBe("42501");
  });

  it("set_studio_join_code_active bleibt der Weg -- und er wirkt", async () => {
    const client = await userClient(trainerEmail);
    const { error } = await client.rpc("set_studio_join_code_active", {
      p_studio_id: studioId,
      p_active: false,
    });
    expect(error).toBeNull();

    const { data } = await client
      .from("studios")
      .select("join_code_active")
      .eq("id", studioId)
      .single();
    expect(data!.join_code_active).toBe(false);

    await client.rpc("set_studio_join_code_active", {
      p_studio_id: studioId,
      p_active: true,
    });
  });
});
```

- [ ] **Schritt 2: Test laufen lassen und den RED-Zustand bestätigen**

```bash
npx --no-install supabase migration up --local
pnpm vitest run --config vitest.config.ts tests/integration/rls-studio-einstellungen.test.ts
```

Erwartet: **fünf** Fehlschläge, und zwar mit diesen Gründen — jeder andere Grund heißt, dass die Umgebung nicht stimmt:

| Test | Erwarteter Fehler |
| --- | --- |
| „jedes Studio hat von Anfang an eine Frist" | `42703` — Spalte existiert nicht |
| „eine negative Frist ist keine Frist" | `PGRST204` statt `23514` — Spalte nicht im Schema-Cache |
| „mehr als eine Woche Vorlauf" | `PGRST204` statt `23514` |
| „positiv: ein Trainer speichert" | `PGRST204` |
| „ein leerer Name bleibt abgelehnt" | `expected null not to be null` — es gibt keine Update-Policy, das UPDATE trifft null Zeilen und meldet keinen Fehler |
| „ein Trainer setzt join_code nicht per UPDATE" | `expected null not to be null` — derselbe Grund |
| „ein Trainer sperrt den Code nicht per UPDATE" | derselbe Grund |

Die drei übrigen (Mitglied, Cross-Tenant, `set_studio_join_code_active`) bestehen bereits. Das ist richtig so: sie sind Wächter, die nach der Migration weiter bestehen müssen.

- [ ] **Schritt 3: Die Migration schreiben**

Datei `supabase/migrations/0032_studio_einstellungen.sql`:

```sql
-- Studio-Einstellungen, Spec 2026-08-31-trainerportal-struktur-design.md
-- Abschnitt 7: `studios` trug bis hier nur studios_select aus 0001. Es gab
-- keine Spalte fuer die Stornofrist und keinen Weg, Name oder Zeitzone zu
-- aendern -- die Einstellungsseite haette nichts zu speichern gehabt.

alter table public.studios
  add column cancellation_deadline_hours int not null default 2
    constraint studios_cancellation_deadline_range
      check (cancellation_deadline_hours between 0 and 168);

comment on column public.studios.cancellation_deadline_hours is
  'Stornofrist in Stunden vor Kursbeginn. Eine Studioregel, keine Plattformregel (Spec Abschnitt 8) -- deshalb steht sie am Studio und nicht in der Anwendung. 0 heisst "bis zum Beginn". Die Obergrenze von 168 Stunden ist eine Woche: was darueber steht, ist ein Tippfehler, keine Regel. Die Vorgabe von 2 Stunden stammt aus dem Artboard EinstellungenStudio; sie gilt auch fuer bereits bestehende Studios, weil ADD COLUMN mit DEFAULT jede Zeile fuellt -- ein NULL muesste die Oberflaeche sonst deuten.';

-- Speichern darf Personal, wie ueberall im Katalog (0004 ff.). Die
-- Bedingung steht auf beiden Seiten: ohne with check koennte ein Trainer
-- eine Zeile aus seinem Studio heraus-aendern, wenn studios je eine
-- zweite Zugehoerigkeitsspalte bekaeme.
create policy studios_update_staff on public.studios
  for update to authenticated
  using (public.is_studio_staff(id))
  with check (public.is_studio_staff(id));

-- Der Beitrittscode bleibt aussen vor -- und zwar ueber das Spaltenrecht,
-- nicht ueber die Policy.
--
-- 0030 haelt fest: "Nur regenerate_studio_join_code und
-- set_studio_join_code_active duerfen ihn aendern." Eine Policy kann das
-- nicht ausdruecken: with check sieht die neue Zeile, nie die alte, und
-- kann deshalb nicht verlangen, dass eine Spalte unveraendert bleibt. Ein
-- Grant kann es -- ohne UPDATE-Recht auf join_code prallt der Versuch
-- schon vor der Policy ab, mit 42501 statt einer leeren Treffermenge.
--
-- Was ohne diese Grenze offenstuende: studios_join_code_unique gilt ueber
-- alle Studios hinweg. Ein Trainer koennte einen fremden Code raten und
-- besetzen -- der Eigentuemer bekaeme beim naechsten Erneuern eine
-- unique_violation, und nach fuenf Versuchen bricht
-- regenerate_studio_join_code ab.
--
-- service_role bleibt unberuehrt (Onboarding legt Studios an), und die
-- SECURITY DEFINER-Funktionen aus 0030 laufen als Funktionsbesitzer, nicht
-- als Aufrufer -- dieser Entzug erreicht sie nicht.
revoke update on public.studios from authenticated;
grant update (name, timezone, cancellation_deadline_hours)
  on public.studios to authenticated;
```

- [ ] **Schritt 4: Anwenden und GREEN prüfen**

```bash
npx --no-install supabase migration up --local
pnpm vitest run --config vitest.config.ts tests/integration/rls-studio-einstellungen.test.ts
```

Erwartet: `Tests 10 passed (10)`, keine Warnungen.

- [ ] **Schritt 5: Die übrigen RLS-Tests gegenprüfen**

Der Entzug von `update on public.studios` ist ein grober Schnitt. Er muss belegt nichts anderes treffen:

```bash
pnpm vitest run --config vitest.config.ts tests/integration/rls-tenancy.test.ts tests/integration/join-studio-by-code.test.ts tests/integration/rls-membership-staff.test.ts
```

Erwartet: alles grün.

- [ ] **Schritt 6: Commit**

```bash
git add supabase/migrations/0032_studio_einstellungen.sql tests/integration/rls-studio-einstellungen.test.ts
git commit -m "$(cat <<'EOF'
feat(db): 0032 gibt dem Studio eine Stornofrist und ein Speicherrecht

Der Beitrittscode bleibt per Spaltenrecht ausgespart -- eine Policy sieht
die alte Zeile nicht und kann "bleibt unveraendert" nicht verlangen.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01N9D8evoBWvz734s2yrygfE
EOF
)"
```

---

### Aufgabe 2: Fachschicht — Einstellungen lesen und speichern

**Dateien:**
- Ändern: `packages/domain/src/studio.ts`
- Ändern: `packages/domain/src/index.ts`
- Test: `tests/integration/domain-studio-einstellungen.test.ts` *(neu)*

**Schnittstellen:**
- Verbraucht: `requireStudioStaff(client, studioId, userId)` und `requireUserId(client)` aus `./auth.js`, `DomainError` aus `./errors.js`, Spalte aus Aufgabe 1
- Liefert:
  ```typescript
  export type StudioSettings = {
    id: string;
    name: string;
    timezone: string;
    cancellationDeadlineHours: number;
    joinCode: string;
    joinCodeActive: boolean;
  };
  export async function getStudioSettings(client: SupabaseClient, studioId: string): Promise<StudioSettings>;
  export async function updateStudioSettings(
    client: SupabaseClient,
    studioId: string,
    input: { name: string; timezone: string; cancellationDeadlineHours: number },
  ): Promise<void>;
  ```

- [ ] **Schritt 1: Den fehlschlagenden Test schreiben**

Datei `tests/integration/domain-studio-einstellungen.test.ts`:

```typescript
import { beforeAll, describe, expect, it } from "vitest";
import { DomainError, getStudioSettings, updateStudioSettings } from "@fitretro/domain";
import { createTestUser, serviceClient, uniqueEmail, userClient } from "./helpers/clients.js";

let studioId: string;
let trainerEmail: string;
let mitgliedEmail: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studio, error: studioError } = await admin
    .from("studios")
    .insert({ name: "Fachschicht-Einstellungen" })
    .select("id")
    .single();
  if (studioError) throw studioError;
  studioId = studio.id;

  trainerEmail = uniqueEmail("fach-einst-trainer");
  mitgliedEmail = uniqueEmail("fach-einst-mitglied");
  const trainerId = await createTestUser(trainerEmail);
  const mitgliedId = await createTestUser(mitgliedEmail);

  const { error } = await admin.from("studio_memberships").insert([
    { studio_id: studioId, user_id: trainerId, role: "trainer" },
    { studio_id: studioId, user_id: mitgliedId, role: "member" },
  ]);
  if (error) throw error;
});

describe("getStudioSettings", () => {
  it("liefert Stammdaten, Frist und Code in einem Rutsch", async () => {
    const client = await userClient(trainerEmail);
    const einstellungen = await getStudioSettings(client, studioId);

    expect(einstellungen.name).toBe("Fachschicht-Einstellungen");
    expect(einstellungen.timezone).toBe("Europe/Berlin");
    expect(einstellungen.cancellationDeadlineHours).toBe(2);
    expect(einstellungen.joinCode).toMatch(/^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{8}$/);
    expect(einstellungen.joinCodeActive).toBe(true);
  });

  it("ein Mitglied bekommt eine Absage, keine Daten", async () => {
    const client = await userClient(mitgliedEmail);
    await expect(getStudioSettings(client, studioId)).rejects.toThrow(DomainError);
  });
});

describe("updateStudioSettings", () => {
  it("speichert Name, Zeitzone und Frist", async () => {
    const client = await userClient(trainerEmail);
    await updateStudioSettings(client, studioId, {
      name: "Kraftwerk Süd",
      timezone: "Europe/Zurich",
      cancellationDeadlineHours: 12,
    });

    const danach = await getStudioSettings(client, studioId);
    expect(danach.name).toBe("Kraftwerk Süd");
    expect(danach.timezone).toBe("Europe/Zurich");
    expect(danach.cancellationDeadlineHours).toBe(12);
  });

  it("ein leerer Name sagt, was gilt -- nicht nur, dass es nicht ging", async () => {
    const client = await userClient(trainerEmail);
    await expect(
      updateStudioSettings(client, studioId, {
        name: "   ",
        timezone: "Europe/Berlin",
        cancellationDeadlineHours: 2,
      }),
    ).rejects.toThrow(/Name/);
  });

  it("eine Frist jenseits einer Woche wird vor der Datenbank abgefangen", async () => {
    const client = await userClient(trainerEmail);
    await expect(
      updateStudioSettings(client, studioId, {
        name: "Kraftwerk Süd",
        timezone: "Europe/Berlin",
        cancellationDeadlineHours: 169,
      }),
    ).rejects.toThrow(/168|Woche/);
  });

  it("eine unbekannte Zeitzone wird abgewiesen", async () => {
    const client = await userClient(trainerEmail);
    await expect(
      updateStudioSettings(client, studioId, {
        name: "Kraftwerk Süd",
        timezone: "Mond/Krater",
        cancellationDeadlineHours: 2,
      }),
    ).rejects.toThrow(/Zeitzone/);
  });

  it("ein Mitglied speichert nicht", async () => {
    const client = await userClient(mitgliedEmail);
    await expect(
      updateStudioSettings(client, studioId, {
        name: "Von einem Mitglied",
        timezone: "Europe/Berlin",
        cancellationDeadlineHours: 2,
      }),
    ).rejects.toThrow(DomainError);
  });
});
```

- [ ] **Schritt 2: Test laufen lassen und den RED-Zustand bestätigen**

```bash
pnpm vitest run --config vitest.config.ts tests/integration/domain-studio-einstellungen.test.ts
```

Erwartet: Sammelfehler beim Import — `getStudioSettings` und `updateStudioSettings` sind keine Ausfuhren von `@fitretro/domain`.

- [ ] **Schritt 3: Die Fachschicht schreiben**

An `packages/domain/src/studio.ts` anhängen (der bestehende `requireStudioStaff` bleibt unverändert stehen). Der Import-Kopf der Datei wird zu:

```typescript
import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";
import { requireUserId } from "./auth.js";
import { DomainError } from "./errors.js";
```

Und darunter:

```typescript
export type StudioSettings = {
  id: string;
  name: string;
  timezone: string;
  cancellationDeadlineHours: number;
  joinCode: string;
  joinCodeActive: boolean;
};

/**
 * Die Zeitzone wird gegen die Liste des Laufzeitsystems geprueft, nicht
 * gegen eine eigene Aufzaehlung: `studios.timezone` ist ein freier Text
 * (0001), und eine Zeitzone, die Intl nicht kennt, laesst spaeter jede
 * Kursanzeige auflaufen. Die Pruefung gehoert deshalb vor das Speichern,
 * nicht vor das Anzeigen.
 */
function istBekannteZeitzone(wert: string): boolean {
  try {
    new Intl.DateTimeFormat("de-DE", { timeZone: wert });
    return true;
  } catch {
    return false;
  }
}

const einstellungenSchema = z.object({
  name: z.string().trim().min(1, "Das Studio braucht einen Namen."),
  timezone: z
    .string()
    .trim()
    .refine(istBekannteZeitzone, "Diese Zeitzone kennt das System nicht."),
  cancellationDeadlineHours: z
    .number()
    .int("Die Stornofrist zaehlt in ganzen Stunden.")
    .min(0, "Eine negative Frist gibt es nicht. 0 heisst: bis zum Beginn.")
    .max(168, "Mehr als 168 Stunden -- eine Woche -- ist keine Frist mehr."),
});

export type StudioSettingsInput = z.infer<typeof einstellungenSchema>;

export async function getStudioSettings(
  client: SupabaseClient,
  studioId: string,
): Promise<StudioSettings> {
  const userId = await requireUserId(client);
  await requireStudioStaff(client, studioId, userId);

  const { data, error } = await client
    .from("studios")
    .select("id, name, timezone, cancellation_deadline_hours, join_code, join_code_active")
    .eq("id", studioId)
    .single<{
      id: string;
      name: string;
      timezone: string;
      cancellation_deadline_hours: number;
      join_code: string;
      join_code_active: boolean;
    }>();

  if (error) throw new DomainError("internal", error.message);
  if (!data) throw new DomainError("not_found", "Dieses Studio gibt es nicht.");

  return {
    id: data.id,
    name: data.name,
    timezone: data.timezone,
    cancellationDeadlineHours: data.cancellation_deadline_hours,
    joinCode: data.join_code,
    joinCodeActive: data.join_code_active,
  };
}

/**
 * Der Beitrittscode fehlt hier mit Absicht: er wird ueber
 * regenerate_studio_join_code und set_studio_join_code_active geaendert,
 * und seit 0032 hat `authenticated` gar kein Spaltenrecht darauf.
 */
export async function updateStudioSettings(
  client: SupabaseClient,
  studioId: string,
  input: StudioSettingsInput,
): Promise<void> {
  const userId = await requireUserId(client);
  await requireStudioStaff(client, studioId, userId);

  const parsed = einstellungenSchema.safeParse(input);
  if (!parsed.success) {
    throw new DomainError("validation_failed", parsed.error.issues[0]!.message);
  }

  const { data, error } = await client
    .from("studios")
    .update({
      name: parsed.data.name,
      timezone: parsed.data.timezone,
      cancellation_deadline_hours: parsed.data.cancellationDeadlineHours,
    })
    .eq("id", studioId)
    .select("id");

  if (error) throw new DomainError("internal", error.message);
  if (!data || data.length === 0) {
    throw new DomainError("unauthorized", "Nur Trainer und Inhaber aendern die Einstellungen.");
  }
}
```

In `packages/domain/src/index.ts` die Zeile

```typescript
export { requireStudioStaff } from "./studio.js";
```

ersetzen durch:

```typescript
export { getStudioSettings, requireStudioStaff, updateStudioSettings } from "./studio.js";
export type { StudioSettings, StudioSettingsInput } from "./studio.js";
```

- [ ] **Schritt 4: GREEN prüfen**

```bash
pnpm vitest run --config vitest.config.ts tests/integration/domain-studio-einstellungen.test.ts
pnpm typecheck
```

Erwartet: `Tests 7 passed (7)` und ein sauberer Typecheck.

- [ ] **Schritt 5: Commit**

```bash
git add packages/domain/src/studio.ts packages/domain/src/index.ts tests/integration/domain-studio-einstellungen.test.ts
git commit -m "$(cat <<'EOF'
feat(domain): Studio-Einstellungen lesen und speichern

Die Zeitzone wird gegen Intl geprueft statt gegen eine eigene Liste --
eine unbekannte Zone laesst sonst spaeter jede Kursanzeige auflaufen.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01N9D8evoBWvz734s2yrygfE
EOF
)"
```

---

### Aufgabe 3: Einstellungen — Reiter *Studio*

Artboard `EinstellungenStudio.dc.html`: drei Abschnitte untereinander — *Stammdaten* (Name, Zeitzone, ein Speicherknopf), *Kurse* (Stornofrist mit Nachsatz „Bis wann sich ein Mitglied abmelden kann. Das ist eure Regel, keine Vorgabe von gymodo."), *Studio-Code* (Code groß, Kopieren, Neuen Code erzeugen, Warnhinweis).

Der Beitrittscode zieht dabei von *Leute* hierher um. Das Artboard `LeuteMitglieder.dc.html` sagt es ausdrücklich: dort steht nur noch die Zeile „Mitglieder treten über den Studio-Code bei — *Einstellungen*" mit Verweis.

**Dateien:**
- Erstellen: `apps/web/app/portal/[studioId]/einstellungen/page.tsx`
- Erstellen: `apps/web/app/portal/[studioId]/einstellungen/Reiter.tsx`
- Erstellen: `apps/web/app/portal/[studioId]/einstellungen/EinstellungenActions.tsx`
- Ändern: `apps/web/app/portal/actions.ts` (neu: `studioSpeichern`)
- Ändern: `apps/web/app/portal/[studioId]/leute/LeuteActions.tsx` (`BeitrittscodeKarte` entfernen)
- Ändern: `apps/web/app/portal/[studioId]/leute/page.tsx` (Karte durch Verweis ersetzen)
- Ändern: `apps/web/app/portal/[studioId]/Rail.tsx` (Eintrag *Einstellungen*)
- Ändern: `apps/web/app/portal/portal.module.css` (Klassen `tabs`, `tab`, `tabActive`)

**Schnittstellen:**
- Verbraucht: `getStudioSettings`, `updateStudioSettings` aus Aufgabe 2 · `beitrittscodeErneuern`, `beitrittscodeAktivSetzen` aus `apps/web/app/portal/actions.ts` (stehen bereits) · `AktionsFormular`, `Feld`, `AktionsKnopf` aus `apps/web/app/portal/Form.tsx`
- Liefert: Server Action `studioSpeichern(studioId: string, pfad: string, _prev: unknown, formData: FormData): Promise<ActionResult>` · Client-Bauteile `Reiter`, `BeitrittscodeKarte`

- [ ] **Schritt 1: Die CSS-Klassen anlegen**

An `apps/web/app/portal/portal.module.css` anhängen:

```css
/* Reiter innerhalb einer Seite. Ein Reiter je Bildschirm bedeutet ein
   Formular je Bildschirm (Spec Abschnitt 1) -- deshalb sind das Links auf
   eigene Routen und keine Umschalter im selben Dokument. */
.tabs {
  display: flex;
  gap: var(--s4);
  border-bottom: 1px solid var(--line);
  margin-top: var(--s24);
}

.tab {
  padding: var(--s8) var(--s16);
  border-bottom: 2px solid transparent;
  color: var(--text-muted);
  text-decoration: none;
  font-weight: 500;
}

.tabActive {
  border-bottom-color: var(--accent);
  color: var(--text);
}
```

> **Die Tokens dieses Projekts** heißen `--line`, `--text`, `--text-muted`, `--text-faint`, `--accent`, `--surface`, `--surface-raised`, dazu die Abstände `--s4` bis `--s48` und die Radien `--r-card` / `--r-control` (`apps/web/app/globals.css`). Das Portal ist **dunkel** (`--bg: #0a0b0d`, `--accent: #d4ff3f`). Der Hausbrauch in `portal.module.css` schreibt `var(--token)` **ohne** Rückfallwert und ohne `rem`.

- [ ] **Schritt 2: Die Server Action schreiben**

In `apps/web/app/portal/actions.ts` den Import aus `@fitretro/domain` um `updateStudioSettings` erweitern und ans Ende der Datei anhängen:

```typescript
export async function studioSpeichern(
  studioId: string,
  pfad: string,
  _prev: unknown,
  formData: FormData,
): Promise<ActionResult> {
  const stunden = zahl(formData, "cancellationDeadlineHours");
  if (stunden === undefined || Number.isNaN(stunden)) {
    return { ok: false, error: "Die Stornofrist braucht eine Zahl. 0 heißt: bis zum Beginn." };
  }

  return fuehreAus(pfad, async (client) => {
    await updateStudioSettings(client, studioId, {
      name: text(formData, "name"),
      timezone: text(formData, "timezone"),
      cancellationDeadlineHours: stunden,
    });
  });
}
```

- [ ] **Schritt 3: Die Reiter schreiben**

Datei `apps/web/app/portal/[studioId]/einstellungen/Reiter.tsx`:

```tsx
"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import styles from "../../portal.module.css";

/**
 * Zwei Routen, kein Umschalter im selben Dokument: ein Reiter je Bildschirm
 * bedeutet ein Formular je Bildschirm (Spec Abschnitt 1), und damit haelt
 * die Regel des Designsystems, dass es genau eine Akzentflaeche gibt.
 */
export function Reiter({ studioId }: { studioId: string }) {
  const pfad = usePathname();
  const basis = `/portal/${studioId}/einstellungen`;

  const klasse = (aktiv: boolean) =>
    aktiv ? `${styles.tab} ${styles.tabActive}` : styles.tab;

  return (
    <nav className={styles.tabs} aria-label="Einstellungen">
      <Link href={basis} className={klasse(pfad === basis)}>
        Studio
      </Link>
      <Link href={`${basis}/konto`} className={klasse(pfad === `${basis}/konto`)}>
        Konto
      </Link>
    </nav>
  );
}
```

- [ ] **Schritt 4: Die Client-Bauteile schreiben**

Datei `apps/web/app/portal/[studioId]/einstellungen/EinstellungenActions.tsx` — die `BeitrittscodeKarte` ist wortgleich aus `leute/LeuteActions.tsx` übernommen und um den Kopierknopf und den Warnhinweis aus dem Artboard ergänzt:

```tsx
"use client";

import { useState } from "react";
import { AktionsKnopf } from "../../Form";
import { beitrittscodeAktivSetzen, beitrittscodeErneuern } from "../../actions";
import styles from "../../portal.module.css";

export function BeitrittscodeKarte({
  studioId,
  pfad,
  code,
  active,
}: {
  studioId: string;
  pfad: string;
  code: string;
  active: boolean;
}) {
  const [angezeigterCode, setAngezeigterCode] = useState(code);
  const [istAktiv, setIstAktiv] = useState(active);
  const [kopiert, setKopiert] = useState(false);

  return (
    <div className={styles.section}>
      <div className={styles.sectionHead}>
        <h2 className={styles.sectionTitle}>Studio-Code</h2>
      </div>
      <p className={styles.sectionNote}>
        Der zweite Weg ins Studio, wenn kein Aushangschild zur Hand ist:
        Mitglieder geben den Code in der App ein. Er macht niemanden zum
        Trainer — Mitarbeiter fügt ihr unter Leute hinzu.
      </p>
      <p className={styles.token}>
        {angezeigterCode}
        {istAktiv ? null : " · gesperrt"}
      </p>
      <div className={styles.rowActions}>
        <button
          type="button"
          className={styles.secondary}
          onClick={async () => {
            await navigator.clipboard.writeText(angezeigterCode);
            setKopiert(true);
          }}
        >
          {kopiert ? "Kopiert" : "Kopieren"}
        </button>
        <AktionsKnopf
          label="Neuen Code erzeugen"
          laufendLabel="Wird erzeugt …"
          bestaetigung="Wirklich? Der alte Code gilt dann nicht mehr."
          aktion={async () => {
            const antwort = await beitrittscodeErneuern(studioId, pfad);
            if (antwort.ok) {
              setAngezeigterCode(antwort.code);
              setIstAktiv(true);
              setKopiert(false);
              return { ok: true as const };
            }
            return antwort;
          }}
        />
        <AktionsKnopf
          label={istAktiv ? "Code sperren" : "Code entsperren"}
          art={istAktiv ? "destructive" : "secondary"}
          aktion={async () => {
            const antwort = await beitrittscodeAktivSetzen(studioId, pfad, !istAktiv);
            if (antwort.ok) setIstAktiv(!istAktiv);
            return antwort;
          }}
        />
      </div>
      <p className={styles.hint}>
        Ein neuer Code macht den alten sofort ungültig. Ausdrucke und Verträge
        mit dem alten Code funktionieren dann nicht mehr. Aushangschilder
        tragen keinen Code — sie bleiben gültig.
      </p>
    </div>
  );
}
```

- [ ] **Schritt 5: Die Seite schreiben**

Datei `apps/web/app/portal/[studioId]/einstellungen/page.tsx`:

```tsx
import { DomainError, getStudioSettings } from "@fitretro/domain";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { AktionsFormular, Feld } from "../../Form";
import { studioSpeichern } from "../../actions";
import styles from "../../portal.module.css";
import { Reiter } from "./Reiter";
import { BeitrittscodeKarte } from "./EinstellungenActions";

export default async function EinstellungenPage({
  params,
}: {
  params: Promise<{ studioId: string }>;
}) {
  const { studioId } = await params;
  const client = await createServerSupabaseClient();
  const pfad = `/portal/${studioId}/einstellungen`;

  let einstellungen: Awaited<ReturnType<typeof getStudioSettings>>;
  try {
    einstellungen = await getStudioSettings(client, studioId);
  } catch (fehler) {
    // Wie in leute/page.tsx: das Layout prueft nur Mitgliedschaft, nicht
    // Rolle -- diese Seite muss sich selbst sperren, sonst laedt sie
    // darunter den echten Beitrittscode.
    if (fehler instanceof DomainError && fehler.code === "unauthorized") {
      return (
        <main className={styles.content}>
          <h1 className={styles.pageTitle}>Einstellungen</h1>
          <div className={styles.section}>
            <div className={styles.empty}>
              <p className={styles.emptyTitle}>
                Diese Seite ist Trainern und Inhabern vorbehalten.
              </p>
              <p className={styles.emptyNext}>
                Frag jemanden mit Trainerrolle, wenn sich etwas ändern soll.
              </p>
            </div>
          </div>
        </main>
      );
    }
    throw fehler;
  }

  return (
    <main className={styles.content}>
      <h1 className={styles.pageTitle}>Einstellungen</h1>
      <p className={styles.pageLead}>
        Stammdaten des Studios, die Regel für Kurse und der Code, mit dem
        Mitglieder beitreten.
      </p>

      <Reiter studioId={studioId} />

      <section className={styles.section}>
        <div className={styles.sectionHead}>
          <h2 className={styles.sectionTitle}>Stammdaten</h2>
        </div>
        <AktionsFormular
          action={studioSpeichern.bind(null, studioId, pfad)}
          submitLabel="Änderungen speichern"
        >
          <div className={styles.grid}>
            <Feld
              name="name"
              label="Name"
              required
              defaultValue={einstellungen.name}
            />
            <Feld
              name="timezone"
              label="Zeitzone"
              required
              defaultValue={einstellungen.timezone}
              hint="Zum Beispiel Europe/Berlin. Sie bestimmt, wann ein Kurstermin beginnt."
            />
            <Feld
              name="cancellationDeadlineHours"
              label="Stornofrist"
              required
              inputMode="numeric"
              defaultValue={String(einstellungen.cancellationDeadlineHours)}
              hint="Stunden vor Beginn. Bis wann sich ein Mitglied abmelden kann. Das ist eure Regel, keine Vorgabe von gymodo. 0 heißt: bis zum Beginn."
            />
          </div>
        </AktionsFormular>
      </section>

      <BeitrittscodeKarte
        studioId={studioId}
        pfad={pfad}
        code={einstellungen.joinCode}
        active={einstellungen.joinCodeActive}
      />
    </main>
  );
}
```

> **Abweichung vom Artboard, bewusst:** Das Artboard trennt *Stammdaten* und *Kurse* in zwei Abschnitte mit je einem Speicherknopf. Hier steht die Stornofrist im selben Formular. Grund: zwei Formulare auf einer Seite bedeuten zwei Akzentflächen, und die Regel des Designsystems lässt genau eine zu. Die Gestaltung in Phase 5 kann das anders lösen (ein Abschnittstitel „Kurse" innerhalb desselben Formulars); die Fachschicht ändert sich dadurch nicht.

- [ ] **Schritt 6: Den Beitrittscode aus *Leute* entfernen**

In `apps/web/app/portal/[studioId]/leute/LeuteActions.tsx` die gesamte Funktion `BeitrittscodeKarte` löschen sowie die dann unbenutzten Importe `beitrittscodeErneuern` und `beitrittscodeAktivSetzen`.

In `apps/web/app/portal/[studioId]/leute/page.tsx`:
- den Import `import { BeitrittscodeKarte, MitgliedZeile } from "./LeuteActions";` zu `import { MitgliedZeile } from "./LeuteActions";` kürzen,
- die Abfrage `client.from("studios").select("join_code, join_code_active")…` samt der `{studio ? <BeitrittscodeKarte … /> : null}`-Ausgabe ersetzen durch:

```tsx
      <p className={styles.sectionNote}>
        Mitglieder treten über den Studio-Code bei —{" "}
        <Link href={`/portal/${studioId}/einstellungen`}>Einstellungen</Link>
      </p>
```

und `import Link from "next/link";` an den Dateikopf setzen.

- [ ] **Schritt 7: Die Rail um *Einstellungen* erweitern**

In `apps/web/app/portal/[studioId]/Rail.tsx` innerhalb der Gruppe *Verwaltung*, direkt nach dem Link auf *Leute*:

```tsx
        <Link
          href={`${basis}/einstellungen`}
          className={klasse(pfad.startsWith(`${basis}/einstellungen`))}
        >
          <span className={styles.navItemTitle}>Einstellungen</span>
        </Link>
```

`startsWith` statt `===`, damit der Eintrag auch auf dem Reiter *Konto* markiert bleibt.

- [ ] **Schritt 8: Bauen und von Hand ansehen**

```bash
pnpm typecheck
pnpm --filter web build
```

Erwartet: beides sauber. Der eigentliche Beweis kommt in Aufgabe 9 aus dem E2E-Gang.

- [ ] **Schritt 9: Commit**

```bash
git add apps/web/app/portal
git commit -m "$(cat <<'EOF'
feat(web): Einstellungen -- Reiter Studio mit Stammdaten, Frist und Code

Der Beitrittscode zieht von Leute hierher um; Leute traegt nur noch den
Verweis, wie im Artboard LeuteMitglieder.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01N9D8evoBWvz734s2yrygfE
EOF
)"
```

---

### Aufgabe 4: Einstellungen — Reiter *Konto*

Artboard `EinstellungenKonto.dc.html`: E-Mail mit der Zeile „Inhaber von … seit …", darunter *Passwort ändern* (aktuelles, neues, Wiederholung) und *Abmelden*.

**Dateien:**
- Erstellen: `apps/web/app/portal/[studioId]/einstellungen/konto/page.tsx`
- Ändern: `apps/web/app/portal/[studioId]/einstellungen/EinstellungenActions.tsx` (`PasswortAendernFormular`)
- Ändern: `apps/web/app/portal/actions.ts` (`passwortAendern`, `abmelden`)

**Schnittstellen:**
- Verbraucht: `createServerSupabaseClient` · `supabase.auth.signInWithPassword`, `.updateUser`, `.signOut`
- Liefert: `passwortAendern(_prev: unknown, formData: FormData): Promise<ActionResult>` · `abmelden(): Promise<never>`

- [ ] **Schritt 1: Die Server Actions schreiben**

An `apps/web/app/portal/actions.ts` anhängen. `redirect` wird oben schon nicht importiert — den Import ergänzen: `import { redirect } from "next/navigation";`

```typescript
/**
 * Das aktuelle Passwort wird durch eine zweite Anmeldung geprueft, nicht
 * durch updateUser allein: Supabase laesst eine Passwortaenderung mit
 * gueltiger Sitzung ohne Nachweis zu. An einem unbeaufsichtigten Rechner
 * im Studio waere das ein offenes Scheunentor.
 */
export async function passwortAendern(
  _prev: unknown,
  formData: FormData,
): Promise<ActionResult> {
  const aktuell = String(formData.get("aktuell") ?? "");
  const neu = String(formData.get("neu") ?? "");
  const wiederholung = String(formData.get("wiederholung") ?? "");

  if (neu.length < 10) {
    return { ok: false, error: "Das neue Passwort braucht mindestens zehn Zeichen." };
  }
  if (neu !== wiederholung) {
    return { ok: false, error: "Die beiden neuen Passwörter sind nicht gleich." };
  }
  if (neu === aktuell) {
    return { ok: false, error: "Das ist das alte Passwort." };
  }

  const client = await createServerSupabaseClient();
  const {
    data: { user },
  } = await client.auth.getUser();
  if (!user?.email) {
    return { ok: false, error: "Die Sitzung ist abgelaufen. Bitte neu anmelden." };
  }

  const { error: pruefung } = await client.auth.signInWithPassword({
    email: user.email,
    password: aktuell,
  });
  if (pruefung) {
    return { ok: false, error: "Das aktuelle Passwort stimmt nicht." };
  }

  const { error } = await client.auth.updateUser({ password: neu });
  if (error) {
    console.error("Passwortaenderung fehlgeschlagen:", error.message);
    return { ok: false, error: "Das Passwort ließ sich nicht ändern." };
  }
  return { ok: true };
}

export async function abmelden(): Promise<never> {
  const client = await createServerSupabaseClient();
  await client.auth.signOut();
  redirect("/login");
}
```

- [ ] **Schritt 2: Das Formular schreiben**

An `apps/web/app/portal/[studioId]/einstellungen/EinstellungenActions.tsx` anhängen und den Import um `AktionsFormular`, `Feld` sowie `passwortAendern` und `abmelden` erweitern:

```tsx
export function PasswortAendernFormular() {
  const [fertig, setFertig] = useState(false);

  return (
    <div className={styles.section}>
      <div className={styles.sectionHead}>
        <h2 className={styles.sectionTitle}>Passwort ändern</h2>
      </div>
      {fertig ? (
        <p className={styles.sectionNote}>Das Passwort ist geändert.</p>
      ) : null}
      <AktionsFormular
        action={passwortAendern}
        submitLabel="Passwort ändern"
        onErfolg={() => setFertig(true)}
      >
        <div className={styles.grid}>
          <Feld name="aktuell" label="Aktuelles Passwort" type="password" required autoComplete="current-password" />
          <Feld
            name="neu"
            label="Neues Passwort"
            type="password"
            required
            autoComplete="new-password"
            hint="Mindestens zehn Zeichen. Keine Pflicht zu Sonderzeichen — Länge trägt weiter als Zeichenklassen."
          />
          <Feld name="wiederholung" label="Wiederholen" type="password" required autoComplete="new-password" />
        </div>
      </AktionsFormular>
    </div>
  );
}

export function AbmeldeKnopf() {
  return (
    <form action={abmelden}>
      <button type="submit" className={styles.secondary}>
        Abmelden
      </button>
    </form>
  );
}
```

- [ ] **Schritt 3: Die Seite schreiben**

Datei `apps/web/app/portal/[studioId]/einstellungen/konto/page.tsx`:

```tsx
import { redirect } from "next/navigation";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import styles from "../../../portal.module.css";
import { Reiter } from "../Reiter";
import { AbmeldeKnopf, PasswortAendernFormular } from "../EinstellungenActions";

const rollenLabel: Record<string, string> = {
  owner: "Inhaber",
  trainer: "Trainer",
  member: "Mitglied",
};

export default async function KontoPage({
  params,
}: {
  params: Promise<{ studioId: string }>;
}) {
  const { studioId } = await params;
  const client = await createServerSupabaseClient();

  const {
    data: { user },
  } = await client.auth.getUser();
  if (!user) redirect("/login");

  // memberships_select_own (0001) reicht dafuer -- die eigene Zeile darf
  // jeder lesen, auch ein einfaches Mitglied. Dieser Reiter ist deshalb
  // bewusst nicht auf Personal beschraenkt: das eigene Passwort geht
  // jeden etwas an.
  const { data: mitgliedschaft } = await client
    .from("studio_memberships")
    .select("role, created_at")
    .eq("studio_id", studioId)
    .eq("user_id", user.id)
    .maybeSingle<{ role: string; created_at: string }>();

  const { data: studio } = await client
    .from("studios")
    .select("name")
    .eq("id", studioId)
    .maybeSingle<{ name: string }>();

  return (
    <main className={styles.content}>
      <h1 className={styles.pageTitle}>Einstellungen</h1>
      <p className={styles.pageLead}>
        Deine E-Mail, dein Passwort und die Sitzung, in der du gerade
        angemeldet bist.
      </p>

      <Reiter studioId={studioId} />

      <section className={styles.section}>
        <div className={styles.sectionHead}>
          <h2 className={styles.sectionTitle}>Konto</h2>
        </div>
        <p className={styles.rowTitle}>{user.email}</p>
        {mitgliedschaft && studio ? (
          <p className={styles.rowMeta}>
            {rollenLabel[mitgliedschaft.role] ?? mitgliedschaft.role} von {studio.name}{" "}
            seit{" "}
            {new Intl.DateTimeFormat("de-DE", { dateStyle: "full" }).format(
              new Date(mitgliedschaft.created_at),
            )}
          </p>
        ) : null}
      </section>

      <PasswortAendernFormular />

      <section className={styles.section}>
        <div className={styles.sectionHead}>
          <h2 className={styles.sectionTitle}>Abmelden</h2>
        </div>
        <AbmeldeKnopf />
      </section>
    </main>
  );
}
```

- [ ] **Schritt 4: Bauen**

```bash
pnpm typecheck
pnpm --filter web build
```

- [ ] **Schritt 5: Commit**

```bash
git add apps/web/app/portal
git commit -m "$(cat <<'EOF'
feat(web): Einstellungen -- Reiter Konto mit Passwortwechsel und Abmelden

Das aktuelle Passwort wird durch eine zweite Anmeldung geprueft: Supabase
laesst updateUser mit gueltiger Sitzung sonst ohne Nachweis zu.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01N9D8evoBWvz734s2yrygfE
EOF
)"
```

---

### Aufgabe 5: Migration 0033 — Die Datenschutzgrenze

Spec Abschnitt 4: **Das Portal sieht Mitgliedschaft und Anwesenheit, aber keine Trainingsdaten.** Vier Policies geben Personal heute Leserecht auf die Trainingsdaten jedes Mitglieds. Alle vier verlieren die Staff-Klausel.

Das Artboard `LeuteMitglieder.dc.html` trägt den Vorbehalt am Fuß und wird durch diese Aufgabe eingelöst: „Heute lassen die Richtlinien der Datenbank Mitarbeiter noch an Sätze, Gewichte und Verläufe heran; das Portal zeigt sie nirgends, verhindert ist es damit aber nicht."

**Dateien:**
- Erstellen: `supabase/migrations/0033_datenschutzgrenze.sql`
- Ändern: `tests/integration/rls-workout-sessions.test.ts:130`
- Ändern: `tests/integration/rls-workout-sets.test.ts:227`
- Ändern: `tests/integration/rls-member-machine-calibrations.test.ts:190`
- Ändern: `tests/integration/rls-progression-suggestions.test.ts:192`

**Schnittstellen:**
- Verbraucht: `is_studio_member(uuid)` aus `0001`
- Liefert: vier Select-Policies, die ausschließlich die eigenen Zeilen freigeben. Ab hier ist `studio_overview` (Aufgabe 6) der einzige Weg zu Trainingsdaten für Personal.

- [ ] **Schritt 1: Die vier positiven Staff-Tests umdrehen**

Jeweils der Test „positiv: ein Trainer sieht …" wird zum negativen. Der Aufbau bleibt in allen vier gleich: eine Zeile per Service-Client für ein **Mitglied** anlegen, dann mit dem **Trainer-Client** danach fragen und `[]` erwarten. Die jeweils vorhandenen Tests „positiv: ein Mitglied sieht seine eigenen …" bleiben unverändert stehen — sie sind der Gegenbeweis, dass die Policy nicht einfach alles sperrt.

Die Helfer (`newId()`, `calibrationOfMemberA()`, `suggestionForMemberA()`) und die Variablen (`studioA`, `memberAId`, `trainerAEmail`, `sessionA`, `machineA`, `exerciseA`) stehen in den Dateien bereits.

**`tests/integration/rls-workout-sessions.test.ts`, Zeilen 130–147 ersetzen durch:**

```typescript
  it("Datenschutzgrenze: ein Trainer sieht die Sessions seiner Studiomitglieder nicht", async () => {
    const admin = serviceClient();
    const sessionId = newId();
    const { error: seedError } = await admin.from("workout_sessions").insert({
      id: sessionId,
      studio_id: studioA,
      user_id: memberAId,
    });
    if (seedError) throw seedError;

    const client = await userClient(trainerAEmail);
    const { data, error } = await client
      .from("workout_sessions")
      .select("id")
      .eq("id", sessionId);

    // Spec Abschnitt 4: das Portal sieht Mitgliedschaft und Anwesenheit,
    // aber keine Trainingsdaten -- je Mitglied nichts. Die Grenze zieht
    // die Datenbank, nicht die Oberflaeche.
    expect(error).toBeNull();
    expect(data).toEqual([]);
  });
```

**`tests/integration/rls-workout-sets.test.ts`, Zeilen 227–250 ersetzen durch:**

```typescript
  it("Datenschutzgrenze: ein Trainer sieht die Saetze seiner Studiomitglieder nicht", async () => {
    const admin = serviceClient();
    const setId = newId();
    const { error: seedError } = await admin.from("workout_sets").insert({
      id: setId,
      studio_id: studioA,
      user_id: memberAId,
      session_id: sessionA,
      machine_id: machineA,
      exercise_id: exerciseA,
      set_index: 90,
      weight_kg: 80,
      reps: 10,
    });
    if (seedError) throw seedError;

    const client = await userClient(trainerAEmail);
    const { data, error } = await client
      .from("workout_sets")
      .select("id")
      .eq("id", setId);

    // Gewicht und Wiederholungen sind das Kernstueck dessen, was Spec
    // Abschnitt 4 hinter die Grenze stellt.
    expect(error).toBeNull();
    expect(data).toEqual([]);
  });
```

**`tests/integration/rls-member-machine-calibrations.test.ts`, Zeilen 190–206 ersetzen durch:**

```typescript
  it("Datenschutzgrenze: ein Trainer sieht die Einstellwerte seiner Studiomitglieder nicht", async () => {
    const admin = serviceClient();
    const { data: seeded, error: seedError } = await admin
      .from("member_machine_calibrations")
      .insert(calibrationOfMemberA())
      .select("id")
      .single();
    if (seedError) throw seedError;

    const client = await userClient(trainerAEmail);
    const { data, error } = await client
      .from("member_machine_calibrations")
      .select("id")
      .eq("id", seeded!.id);

    // Auch die trainerbegleitete Erfassung bleibt danach unsichtbar: wer
    // dabei war, steht in recorded_by, das Leserecht folgt daraus nicht.
    expect(error).toBeNull();
    expect(data).toEqual([]);
  });
```

**`tests/integration/rls-progression-suggestions.test.ts`, Zeilen 192–208 ersetzen durch:**

```typescript
  it("Datenschutzgrenze: ein Trainer sieht die Vorschlaege seiner Studiomitglieder nicht", async () => {
    const admin = serviceClient();
    const { data: seeded, error: seedError } = await admin
      .from("progression_suggestions")
      .insert(suggestionForMemberA())
      .select("id")
      .single();
    if (seedError) throw seedError;

    const client = await userClient(trainerAEmail);
    const { data, error } = await client
      .from("progression_suggestions")
      .select("id")
      .eq("id", seeded!.id);

    expect(error).toBeNull();
    expect(data).toEqual([]);
  });
```

- [ ] **Schritt 2: RED bestätigen**

```bash
pnpm vitest run --config vitest.config.ts \
  tests/integration/rls-workout-sessions.test.ts \
  tests/integration/rls-workout-sets.test.ts \
  tests/integration/rls-member-machine-calibrations.test.ts \
  tests/integration/rls-progression-suggestions.test.ts
```

Erwartet: **vier** Fehlschläge, jeweils „expected [ { id: … } ] to equal []" — der Trainer sieht die Zeile noch. Jeder andere Fehler heißt, dass der umgeschriebene Test nicht sauber aufgebaut ist.

- [ ] **Schritt 3: Die Migration schreiben**

Datei `supabase/migrations/0033_datenschutzgrenze.sql`:

```sql
-- Die Datenschutzgrenze, Spec 2026-08-31-trainerportal-struktur-design.md
-- Abschnitt 4 und Entscheidung 7.
--
-- Das Portal sieht Mitgliedschaft und Anwesenheit, aber keine
-- Trainingsdaten -- je Mitglied nichts. Bis hier gaben vier Policies
-- Trainern und Inhabern Leserecht auf die Trainingsdaten jedes Mitglieds
-- ihres Studios (0012 bis 0015, jeweils "or public.is_studio_staff(...)").
-- Alle vier verlieren diese Klausel.
--
-- Die Mitgliedschaftspruefung bleibt neben der Eigentuemerpruefung stehen,
-- obwohl sie fuer die eigenen Zeilen redundant aussieht: wer aus einem
-- Studio austritt (0024), verliert damit auch den Blick auf seine dortige
-- Historie. Das ist die bestehende Regel aus 0012, und dieser Schnitt
-- aendert sie nicht.
--
-- Ab hier ist studio_overview (0034) die einzige Stelle, an der
-- Trainingsdaten fuer Personal ueberhaupt noch erreichbar sind -- und sie
-- gibt ausschliesslich Summen heraus.
--
-- Fuer M3 zurueckzunehmen: Trainerbetreuung braucht den Verlauf. Der Weg
-- dorthin ist eine ausdrueckliche Freigabe durch das Mitglied, nicht die
-- pauschale Rolle.

drop policy workout_sessions_select on public.workout_sessions;
create policy workout_sessions_select on public.workout_sessions
  for select to authenticated
  using (
    public.is_studio_member(workout_sessions.studio_id)
    and workout_sessions.user_id = (select auth.uid())
  );

drop policy workout_sets_select on public.workout_sets;
create policy workout_sets_select on public.workout_sets
  for select to authenticated
  using (
    public.is_studio_member(workout_sets.studio_id)
    and workout_sets.user_id = (select auth.uid())
  );

drop policy member_machine_calibrations_select on public.member_machine_calibrations;
create policy member_machine_calibrations_select
  on public.member_machine_calibrations
  for select to authenticated
  using (
    public.is_studio_member(member_machine_calibrations.studio_id)
    and member_machine_calibrations.user_id = (select auth.uid())
  );

drop policy progression_suggestions_select on public.progression_suggestions;
create policy progression_suggestions_select
  on public.progression_suggestions
  for select to authenticated
  using (
    public.is_studio_member(progression_suggestions.studio_id)
    and progression_suggestions.user_id = (select auth.uid())
  );
```

- [ ] **Schritt 4: Anwenden und GREEN prüfen**

```bash
npx --no-install supabase migration up --local
pnpm vitest run --config vitest.config.ts
```

Hier läuft die **gesamte** Integrationssuite, nicht nur die vier Dateien: der Schnitt kann jeden Lesepfad treffen, der bisher unbemerkt über die Staff-Klausel lief. Erwartet: alles grün. Fällt etwas anderes aus, ist das ein Fund, kein Störgeräusch — dann steht in der Fachschicht ein Pfad, der Trainingsdaten je Person liest, und der gehört in den Bericht.

- [ ] **Schritt 5: Commit**

```bash
git add supabase/migrations/0033_datenschutzgrenze.sql tests/integration
git commit -m "$(cat <<'EOF'
feat(db): 0033 zieht die Datenschutzgrenze in der Datenbank

Vier Select-Policies verlieren die Staff-Klausel. Personal kommt an
Traingsdaten je Mitglied nicht mehr heran -- auch nicht bei einem Fehler
in der Oberflaeche.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01N9D8evoBWvz734s2yrygfE
EOF
)"
```

---

### Aufgabe 6: Migration 0034 — `studio_overview`

Die Funktion, deren Signatur laut Spec „die Datenschutzgrenze in Code-Form" ist. Sie liefert Summen und niemals Zeilen.

**Die Mindestzahl.** Spec Abschnitt 4 warnt: „Bei einem kleinen Studio mit wenigen aktiven Mitgliedern lässt eine Geräterangliste Rückschlüsse zu — wer montags allein da war, hat die 312 Sätze an der Beinpresse gemacht. Summen sind nicht automatisch anonym." Der Wert war offen; **entschieden am 2. September: fünf.** Unterhalb von fünf aktiven Mitgliedern im Zeitraum liefert die Funktion die vier Kennzahlen, aber keine Aufschlüsselung je Gerät. Die Zahl steht als benannte Konstante im Rumpf und wird im Rückgabewert mitgeliefert, damit die Oberfläche den Leer-Zustand begründen kann statt bloß leer zu sein.

**Dateien:**
- Erstellen: `supabase/migrations/0034_studio_ueberblick.sql`
- Test: `tests/integration/studio-ueberblick.test.ts` *(neu)*

**Schnittstellen:**
- Verbraucht: `is_studio_staff(uuid)` aus `0004` · `workout_sessions`, `workout_sets`, `machines`
- Liefert: `public.studio_overview(p_studio_id uuid, p_days int default 30) returns jsonb`, mit dieser Gestalt:
  ```json
  {
    "days": 30,
    "active_members": 23,
    "sets": 412,
    "problem_reports": 7,
    "min_members": 5,
    "breakdown": true,
    "top_machines": [{ "machine_id": "…", "label": "Beinpresse 7", "status": "active", "sets": 148 }],
    "problems":     [{ "machine_id": "…", "label": "Latzug 13", "reason": "schmerz", "count": 2 }]
  }
  ```
  Wer kein Personal des Studios ist, bekommt SQL-`NULL`.

- [ ] **Schritt 1: Den fehlschlagenden Test schreiben**

Datei `tests/integration/studio-ueberblick.test.ts`:

```typescript
import { beforeAll, describe, expect, it } from "vitest";
import { createTestUser, serviceClient, uniqueEmail, userClient } from "./helpers/clients.js";

/**
 * studio_overview, Spec 2026-08-31-trainerportal-struktur-design.md
 * Abschnitt 4: die einzige Stelle, an der Trainingsdaten fuer Personal
 * ueberhaupt noch erreichbar sind -- ausschliesslich als Summe.
 *
 * Das Studio bekommt sechs aktive Mitglieder, damit die Mindestzahl von
 * fuenf ueberschritten ist. Ein zweites Studio mit nur zwei aktiven
 * Mitgliedern prueft die Gegenrichtung.
 */

type Uebersicht = {
  days: number;
  active_members: number;
  sets: number;
  problem_reports: number;
  min_members: number;
  breakdown: boolean;
  top_machines: { machine_id: string; label: string; status: string; sets: number }[];
  problems: { machine_id: string; label: string; reason: string | null; count: number }[];
};

let studioId: string;
let kleinStudioId: string;
let trainerEmail: string;
let mitgliedEmail: string;
let fremdTrainerEmail: string;
let kleinTrainerEmail: string;
let beinpresseId: string;
let latzugId: string;

async function studioMitDaten(
  admin: ReturnType<typeof serviceClient>,
  name: string,
  anzahlMitglieder: number,
): Promise<{ studioId: string; machineIds: string[] }> {
  const { data: studio, error: studioError } = await admin
    .from("studios")
    .insert({ name })
    .select("id")
    .single();
  if (studioError) throw studioError;

  const { data: modell, error: modellError } = await admin
    .from("equipment_models")
    .insert({ studio_id: studio.id, name: "Kraftgerät", weight_step_kg: 2.5 })
    .select("id")
    .single();
  if (modellError) throw modellError;

  // exercises haengt nicht am Modell -- die Zuordnung liegt in
  // equipment_model_exercises (0005). Fuer den Ueberblick reicht die
  // Uebung selbst, weil workout_sets direkt auf sie zeigt.
  const { data: uebung, error: uebungError } = await admin
    .from("exercises")
    .insert({
      studio_id: studio.id,
      name: "Zug",
      target_reps_min: 8,
      target_reps_max: 12,
    })
    .select("id")
    .single();
  if (uebungError) throw uebungError;

  const { data: geraeteZeilen, error: geraeteError } = await admin
    .from("machines")
    .insert([
      { studio_id: studio.id, equipment_model_id: modell.id, label: "Beinpresse 7" },
      { studio_id: studio.id, equipment_model_id: modell.id, label: "Latzug 13" },
    ])
    .select("id, label");
  if (geraeteError) throw geraeteError;

  // Nach Beschriftung nachschlagen statt nach Position: die Reihenfolge
  // eines mehrzeiligen Inserts ist nicht zugesichert, und ein Test, der
  // sie annimmt, faellt irgendwann ohne Grund aus.
  const geraete = ["Beinpresse 7", "Latzug 13"].map(
    (label) => geraeteZeilen.find((zeile) => zeile.label === label)!,
  );

  for (let i = 0; i < anzahlMitglieder; i += 1) {
    const email = uniqueEmail(`ueb-${name}-m${i}`);
    const userId = await createTestUser(email);
    await admin
      .from("studio_memberships")
      .insert({ studio_id: studio.id, user_id: userId, role: "member" });

    const sessionId = crypto.randomUUID();
    await admin.from("workout_sessions").insert({
      id: sessionId,
      studio_id: studio.id,
      user_id: userId,
    });

    // Zwei Saetze an der Beinpresse, einer am Latzug -- damit die
    // Rangliste eine Reihenfolge hat. Der Latzugsatz meldet ein Problem.
    await admin.from("workout_sets").insert([
      {
        id: crypto.randomUUID(),
        studio_id: studio.id,
        user_id: userId,
        session_id: sessionId,
        machine_id: geraete[0]!.id,
        exercise_id: uebung.id,
        set_index: 1,
        weight_kg: 40,
        reps: 10,
      },
      {
        id: crypto.randomUUID(),
        studio_id: studio.id,
        user_id: userId,
        session_id: sessionId,
        machine_id: geraete[0]!.id,
        exercise_id: uebung.id,
        set_index: 2,
        weight_kg: 40,
        reps: 8,
      },
      {
        id: crypto.randomUUID(),
        studio_id: studio.id,
        user_id: userId,
        session_id: sessionId,
        machine_id: geraete[1]!.id,
        exercise_id: uebung.id,
        set_index: 1,
        weight_kg: 30,
        reps: 12,
        problem_flag: true,
        problem_reason: "schmerz",
      },
    ]);
  }

  return { studioId: studio.id, machineIds: geraete.map((g) => g.id) };
}

beforeAll(async () => {
  const admin = serviceClient();

  const gross = await studioMitDaten(admin, "Ueberblick-Studio", 6);
  studioId = gross.studioId;
  beinpresseId = gross.machineIds[0]!;
  latzugId = gross.machineIds[1]!;

  const klein = await studioMitDaten(admin, "Kleines Ueberblick-Studio", 2);
  kleinStudioId = klein.studioId;

  trainerEmail = uniqueEmail("ueb-trainer");
  mitgliedEmail = uniqueEmail("ueb-mitglied");
  fremdTrainerEmail = uniqueEmail("ueb-fremd-trainer");
  kleinTrainerEmail = uniqueEmail("ueb-klein-trainer");

  const trainerId = await createTestUser(trainerEmail);
  const mitgliedId = await createTestUser(mitgliedEmail);
  const fremdTrainerId = await createTestUser(fremdTrainerEmail);
  const kleinTrainerId = await createTestUser(kleinTrainerEmail);

  const { error } = await admin.from("studio_memberships").insert([
    { studio_id: studioId, user_id: trainerId, role: "trainer" },
    { studio_id: studioId, user_id: mitgliedId, role: "member" },
    { studio_id: kleinStudioId, user_id: kleinTrainerId, role: "trainer" },
    { studio_id: kleinStudioId, user_id: fremdTrainerId, role: "trainer" },
  ]);
  if (error) throw error;
});

describe("studio_overview -- die Summen", () => {
  it("zaehlt aktive Mitglieder, Saetze und gemeldete Probleme", async () => {
    const client = await userClient(trainerEmail);
    const { data, error } = await client.rpc("studio_overview", {
      p_studio_id: studioId,
      p_days: 30,
    });

    expect(error).toBeNull();
    const uebersicht = data as Uebersicht;
    expect(uebersicht.active_members).toBe(6);
    expect(uebersicht.sets).toBe(18);
    expect(uebersicht.problem_reports).toBe(6);
    expect(uebersicht.days).toBe(30);
  });

  it("zaehlt nur das eigene Studio", async () => {
    const client = await userClient(kleinTrainerEmail);
    const { data } = await client.rpc("studio_overview", {
      p_studio_id: kleinStudioId,
      p_days: 30,
    });

    const uebersicht = data as Uebersicht;
    expect(uebersicht.active_members).toBe(2);
    expect(uebersicht.sets).toBe(6);
  });
});

describe("studio_overview -- die Aufschluesselung", () => {
  it("nennt die meistgenutzten Geraete mit Beschriftung und Anzahl", async () => {
    const client = await userClient(trainerEmail);
    const { data } = await client.rpc("studio_overview", {
      p_studio_id: studioId,
      p_days: 30,
    });

    const uebersicht = data as Uebersicht;
    expect(uebersicht.breakdown).toBe(true);
    expect(uebersicht.top_machines[0]).toEqual({
      machine_id: beinpresseId,
      label: "Beinpresse 7",
      status: "active",
      sets: 12,
    });
    expect(uebersicht.top_machines[1]!.sets).toBe(6);
  });

  it("nennt gemeldete Probleme je Geraet und Grund -- ohne Namen", async () => {
    const client = await userClient(trainerEmail);
    const { data } = await client.rpc("studio_overview", {
      p_studio_id: studioId,
      p_days: 30,
    });

    const uebersicht = data as Uebersicht;
    expect(uebersicht.problems).toEqual([
      { machine_id: latzugId, label: "Latzug 13", reason: "schmerz", count: 6 },
    ]);
    // Der Beweis, dass hier kein Personenbezug durchkommt: keine Zeile der
    // Antwort traegt ein Feld, das nach einem Nutzer aussieht.
    expect(JSON.stringify(uebersicht)).not.toMatch(/user_id|email/);
  });
});

describe("studio_overview -- die Mindestzahl", () => {
  it("unter fuenf aktiven Mitgliedern gibt es keine Aufschluesselung je Geraet", async () => {
    const client = await userClient(kleinTrainerEmail);
    const { data } = await client.rpc("studio_overview", {
      p_studio_id: kleinStudioId,
      p_days: 30,
    });

    const uebersicht = data as Uebersicht;
    // Die Summen bleiben -- sie sagen, OB das Studio benutzt wird.
    expect(uebersicht.sets).toBe(6);
    // Die Rangliste faellt weg: bei zwei Aktiven verraet sie, wer was
    // trainiert hat (Spec Abschnitt 4, Vorbehalt).
    expect(uebersicht.breakdown).toBe(false);
    expect(uebersicht.top_machines).toEqual([]);
    expect(uebersicht.problems).toEqual([]);
    // Die Schwelle reist mit, damit die Oberflaeche den Leer-Zustand
    // begruenden kann statt bloss leer zu sein.
    expect(uebersicht.min_members).toBe(5);
  });
});

describe("studio_overview -- wer darf", () => {
  it("ein Mitglied bekommt nichts", async () => {
    const client = await userClient(mitgliedEmail);
    const { data, error } = await client.rpc("studio_overview", {
      p_studio_id: studioId,
      p_days: 30,
    });

    // Leer, nicht Fehler -- sonst waere die Funktion ein Orakel darueber,
    // welche Studios es gibt.
    expect(error).toBeNull();
    expect(data).toBeNull();
  });

  it("cross-tenant: der Trainer eines anderen Studios bekommt nichts", async () => {
    const client = await userClient(fremdTrainerEmail);
    const { data, error } = await client.rpc("studio_overview", {
      p_studio_id: studioId,
      p_days: 30,
    });

    expect(error).toBeNull();
    expect(data).toBeNull();
  });
});
```

- [ ] **Schritt 2: RED bestätigen**

```bash
pnpm vitest run --config vitest.config.ts tests/integration/studio-ueberblick.test.ts
```

Erwartet: alle Tests scheitern mit `PGRST202` — „Could not find the function public.studio_overview".

- [ ] **Schritt 3: Die Migration schreiben**

Datei `supabase/migrations/0034_studio_ueberblick.sql`:

```sql
-- Der Ueberblick, Spec 2026-08-31-trainerportal-struktur-design.md
-- Abschnitt 4.
--
-- Seit 0033 kommt Personal an kein einzelnes Trainingsdatum mehr heran.
-- Diese Funktion ist die einzige Stelle, an der Trainingsdaten fuer
-- Personal ueberhaupt noch erreichbar sind -- und sie gibt ausschliesslich
-- Summen heraus, niemals Zeilen. Ihre Signatur ist damit die
-- Datenschutzgrenze in Code-Form: jede spaetere Erweiterung um eine
-- Aufschluesselung nach Person ist eine Entscheidung, keine Kleinigkeit.
--
-- Die Mindestzahl: Spec Abschnitt 4 haelt fest, dass Summen nicht
-- automatisch anonym sind -- wer montags allein da war, hat die 312 Saetze
-- an der Beinpresse gemacht. Unterhalb von fuenf aktiven Mitgliedern im
-- Zeitraum liefert die Funktion deshalb die vier Kennzahlen, aber keine
-- Aufschluesselung je Geraet. Die Schwelle reist im Rueckgabewert mit
-- ('min_members'), damit die Oberflaeche den Leer-Zustand begruenden kann
-- statt bloss leer zu sein.
--
-- jsonb statt einer Tabelle: der Ueberblick besteht aus vier Skalaren und
-- zwei Listen unterschiedlicher Gestalt. Als returns table waeren das drei
-- Funktionen -- und damit drei Stellen, an denen die Grenze spaeter
-- aufgeweicht werden koennte.

create or replace function public.studio_overview(
  p_studio_id uuid,
  p_days      int default 30
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
stable
as $$
declare
  -- Die Mindestzahl aktiver Mitglieder, ab der es eine Aufschluesselung je
  -- Geraet gibt. Entschieden am 2. September 2026; Spec Abschnitt 4 liess
  -- den Wert offen und verlangte ihn "vor dem ersten echten Mitglied".
  k_mindestzahl constant int := 5;

  v_tage      int := least(greatest(coalesce(p_days, 30), 1), 365);
  v_von       timestamptz;
  v_aktive    int;
  v_saetze    int;
  v_probleme  int;
  v_geraete   jsonb := '[]'::jsonb;
  v_meldungen jsonb := '[]'::jsonb;
begin
  -- Leer, nicht Fehler -- wie list_studio_members (0031) und
  -- join_studio_by_code (0030). Eine unterschiedliche Antwort machte die
  -- Funktion zum Orakel darueber, welche Studios es gibt.
  if not public.is_studio_staff(p_studio_id) then
    return null;
  end if;

  v_von := now() - make_interval(days => v_tage);

  -- "Aktiv" heisst: hat im Zeitraum eine Einheit begonnen. Nicht "ist
  -- Mitglied" -- die Zahl soll sagen, ob das Studio benutzt wird, nicht
  -- wie lang die Kartei ist.
  select count(distinct s.user_id)::int
    into v_aktive
    from public.workout_sessions s
   where s.studio_id = p_studio_id
     and s.started_at >= v_von;

  select count(*)::int, count(*) filter (where w.problem_flag)::int
    into v_saetze, v_probleme
    from public.workout_sets w
   where w.studio_id = p_studio_id
     and w.performed_at >= v_von;

  if v_aktive >= k_mindestzahl then
    select coalesce(
             jsonb_agg(
               jsonb_build_object(
                 'machine_id', t.machine_id,
                 'label',      t.label,
                 'status',     t.status,
                 'sets',       t.saetze
               )
               order by t.saetze desc, t.label asc
             ),
             '[]'::jsonb
           )
      into v_geraete
      from (
        select w.machine_id,
               m.label,
               m.status::text as status,
               count(*)::int  as saetze
          from public.workout_sets w
          join public.machines m on m.id = w.machine_id
         where w.studio_id = p_studio_id
           and w.performed_at >= v_von
         group by w.machine_id, m.label, m.status
         order by count(*) desc, m.label asc
         limit 5
      ) t;

    select coalesce(
             jsonb_agg(
               jsonb_build_object(
                 'machine_id', t.machine_id,
                 'label',      t.label,
                 'reason',     t.reason,
                 'count',      t.anzahl
               )
               order by t.anzahl desc, t.label asc
             ),
             '[]'::jsonb
           )
      into v_meldungen
      from (
        select w.machine_id,
               m.label,
               w.problem_reason::text as reason,
               count(*)::int          as anzahl
          from public.workout_sets w
          join public.machines m on m.id = w.machine_id
         where w.studio_id = p_studio_id
           and w.performed_at >= v_von
           and w.problem_flag
         group by w.machine_id, m.label, w.problem_reason
         order by count(*) desc, m.label asc
         limit 5
      ) t;
  end if;

  return jsonb_build_object(
    'days',            v_tage,
    'active_members',  v_aktive,
    'sets',            v_saetze,
    'problem_reports', v_probleme,
    'min_members',     k_mindestzahl,
    'breakdown',       v_aktive >= k_mindestzahl,
    'top_machines',    v_geraete,
    'problems',        v_meldungen
  );
end;
$$;

comment on function public.studio_overview(uuid, int) is
  'Studioweite Summen fuer den Ueberblick. Liefert nie eine Zeile und nie einen Personenbezug -- die einzige Stelle, an der Trainingsdaten fuer Personal seit 0033 noch erreichbar sind. Unterhalb von fuenf aktiven Mitgliedern entfaellt die Aufschluesselung je Geraet (Spec Abschnitt 4). Wer kein Personal des Studios ist, bekommt NULL, keinen Fehler.';

revoke all on function public.studio_overview(uuid, int)
  from public, anon, authenticated, service_role;
grant execute on function public.studio_overview(uuid, int) to authenticated;
```

- [ ] **Schritt 4: Anwenden und GREEN prüfen**

```bash
npx --no-install supabase migration up --local
pnpm vitest run --config vitest.config.ts tests/integration/studio-ueberblick.test.ts
```

Erwartet: `Tests 7 passed (7)`.

- [ ] **Schritt 5: Die Indexlage prüfen**

`studio_overview` fragt `workout_sets` nach `(studio_id, performed_at)` — der bestehende Index aus `0013` beginnt mit `(studio_id, user_id, machine_id, exercise_id, performed_at desc)`. Für die Gruppierung ohne `user_id` trägt er nur die erste Spalte.

```bash
npx --no-install supabase migration up --local
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -c "explain analyze select count(*) from public.workout_sets where studio_id = (select id from public.studios limit 1) and performed_at >= now() - interval '30 days';"
```

**Kein Index wird in dieser Aufgabe angelegt.** Bei den Datenmengen dieses Systems — ein Studio, ein paar tausend Sätze — ist ein Seq Scan das Richtige, und ein Index auf Verdacht ist Schreiblast ohne Gegenwert. Das `explain` gehört trotzdem in den Abschlussbericht: es ist die Ausgangsmessung, gegen die sich ein späterer Bedarf belegen lässt.

- [ ] **Schritt 6: Commit**

```bash
git add supabase/migrations/0034_studio_ueberblick.sql tests/integration/studio-ueberblick.test.ts
git commit -m "$(cat <<'EOF'
feat(db): 0034 liefert den Ueberblick als reine Summen

Unter fuenf aktiven Mitgliedern entfaellt die Aufschluesselung je Geraet.
Der Wert war in der Spec offen; entschieden am 2. September.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01N9D8evoBWvz734s2yrygfE
EOF
)"
```

---

### Aufgabe 7: Fachschicht — `getStudioOverview`

**Dateien:**
- Erstellen: `packages/domain/src/overview.ts`
- Ändern: `packages/domain/src/index.ts`
- Test: `tests/integration/domain-studio-ueberblick.test.ts` *(neu)*

**Schnittstellen:**
- Verbraucht: `studio_overview(uuid, int)` aus Aufgabe 6 · `ProblemReason` aus `./workout.js`
- Liefert:
  ```typescript
  export type OverviewMachine = { machineId: string; label: string; status: "active" | "inactive"; sets: number };
  export type OverviewProblem = { machineId: string; label: string; reason: ProblemReason | null; count: number };
  export type StudioOverview = {
    days: number;
    activeMembers: number;
    sets: number;
    problemReports: number;
    minMembers: number;
    breakdown: boolean;
    topMachines: OverviewMachine[];
    problems: OverviewProblem[];
  };
  export async function getStudioOverview(
    client: SupabaseClient, studioId: string, days?: number,
  ): Promise<StudioOverview | null>;
  ```

- [ ] **Schritt 1: Den fehlschlagenden Test schreiben**

Datei `tests/integration/domain-studio-ueberblick.test.ts`:

```typescript
import { beforeAll, describe, expect, it } from "vitest";
import { getStudioOverview } from "@fitretro/domain";
import { createTestUser, serviceClient, uniqueEmail, userClient } from "./helpers/clients.js";

let studioId: string;
let trainerEmail: string;
let mitgliedEmail: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studio, error } = await admin
    .from("studios")
    .insert({ name: "Fachschicht-Ueberblick" })
    .select("id")
    .single();
  if (error) throw error;
  studioId = studio.id;

  trainerEmail = uniqueEmail("fach-ueb-trainer");
  mitgliedEmail = uniqueEmail("fach-ueb-mitglied");
  const trainerId = await createTestUser(trainerEmail);
  const mitgliedId = await createTestUser(mitgliedEmail);

  await admin.from("studio_memberships").insert([
    { studio_id: studioId, user_id: trainerId, role: "trainer" },
    { studio_id: studioId, user_id: mitgliedId, role: "member" },
  ]);
});

describe("getStudioOverview", () => {
  it("ein leeres Studio liefert Nullen und keine Aufschluesselung", async () => {
    const client = await userClient(trainerEmail);
    const uebersicht = await getStudioOverview(client, studioId);

    expect(uebersicht).not.toBeNull();
    expect(uebersicht!.activeMembers).toBe(0);
    expect(uebersicht!.sets).toBe(0);
    expect(uebersicht!.problemReports).toBe(0);
    expect(uebersicht!.breakdown).toBe(false);
    expect(uebersicht!.minMembers).toBe(5);
    expect(uebersicht!.topMachines).toEqual([]);
  });

  it("ein Mitglied bekommt null statt eines Fehlers", async () => {
    const client = await userClient(mitgliedEmail);
    await expect(getStudioOverview(client, studioId)).resolves.toBeNull();
  });

  it("der Zeitraum reist mit", async () => {
    const client = await userClient(trainerEmail);
    const uebersicht = await getStudioOverview(client, studioId, 7);
    expect(uebersicht!.days).toBe(7);
  });
});
```

- [ ] **Schritt 2: RED bestätigen**

```bash
pnpm vitest run --config vitest.config.ts tests/integration/domain-studio-ueberblick.test.ts
```

Erwartet: Importfehler — `getStudioOverview` ist keine Ausfuhr von `@fitretro/domain`.

- [ ] **Schritt 3: Die Fachschicht schreiben**

Datei `packages/domain/src/overview.ts`:

```typescript
import type { SupabaseClient } from "@supabase/supabase-js";
import { DomainError } from "./errors.js";
import type { ProblemReason } from "./workout.js";

/**
 * Der Ueberblick, Spec 2026-08-31-trainerportal-struktur-design.md
 * Abschnitt 4.
 *
 * Diese Datei uebersetzt nur -- sie rechnet nichts. Die Summen entstehen in
 * studio_overview (0034), weil die Rohzeilen dort noch erreichbar sind und
 * hier nicht mehr. Wer hier eine Kennzahl ergaenzen will, ergaenzt sie in
 * der Funktion; das ist die Absicht.
 */

export type OverviewMachine = {
  machineId: string;
  label: string;
  status: "active" | "inactive";
  sets: number;
};

export type OverviewProblem = {
  machineId: string;
  label: string;
  reason: ProblemReason | null;
  count: number;
};

export type StudioOverview = {
  days: number;
  activeMembers: number;
  sets: number;
  problemReports: number;
  /** Ab wie vielen aktiven Mitgliedern es eine Aufschluesselung gibt. */
  minMembers: number;
  breakdown: boolean;
  topMachines: OverviewMachine[];
  problems: OverviewProblem[];
};

type RohUebersicht = {
  days: number;
  active_members: number;
  sets: number;
  problem_reports: number;
  min_members: number;
  breakdown: boolean;
  top_machines: { machine_id: string; label: string; status: string; sets: number }[];
  problems: { machine_id: string; label: string; reason: string | null; count: number }[];
};

/**
 * `null` heisst: der Aufrufer ist kein Personal dieses Studios. Kein Fehler
 * -- die Funktion antwortet fuer ein fremdes und fuer ein nicht
 * existierendes Studio gleich.
 */
export async function getStudioOverview(
  client: SupabaseClient,
  studioId: string,
  days = 30,
): Promise<StudioOverview | null> {
  const { data, error } = await client.rpc("studio_overview", {
    p_studio_id: studioId,
    p_days: days,
  });
  if (error) throw new DomainError("internal", error.message);
  if (!data) return null;

  const roh = data as RohUebersicht;
  return {
    days: roh.days,
    activeMembers: roh.active_members,
    sets: roh.sets,
    problemReports: roh.problem_reports,
    minMembers: roh.min_members,
    breakdown: roh.breakdown,
    topMachines: roh.top_machines.map((zeile) => ({
      machineId: zeile.machine_id,
      label: zeile.label,
      status: zeile.status as OverviewMachine["status"],
      sets: zeile.sets,
    })),
    problems: roh.problems.map((zeile) => ({
      machineId: zeile.machine_id,
      label: zeile.label,
      reason: (zeile.reason as ProblemReason | null) ?? null,
      count: zeile.count,
    })),
  };
}
```

In `packages/domain/src/index.ts` anhängen:

```typescript
export { getStudioOverview } from "./overview.js";
export type {
  OverviewMachine,
  OverviewProblem,
  StudioOverview,
} from "./overview.js";
```

- [ ] **Schritt 4: GREEN prüfen**

```bash
pnpm vitest run --config vitest.config.ts tests/integration/domain-studio-ueberblick.test.ts
pnpm typecheck
```

- [ ] **Schritt 5: Commit**

```bash
git add packages/domain tests/integration/domain-studio-ueberblick.test.ts
git commit -m "$(cat <<'EOF'
feat(domain): getStudioOverview uebersetzt die Summen aus 0034

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01N9D8evoBWvz734s2yrygfE
EOF
)"
```

---

### Aufgabe 8: Die Wurzelseite wird der Überblick

Spec Abschnitt 1 stellt *Überblick* an den Anfang der Rail; heute liegt auf `/portal/<studio>` der Gerätekatalog. Der Katalog zieht nach `/portal/<studio>/modelle`.

Artboard `Main.dc.html`: vier Kennzahlkacheln (*Geräte erreichbar*, *Mitglieder aktiv*, *Sätze erfasst*, *Probleme gemeldet*), darunter *Diese Woche* (Kurse), *Was noch fehlt*, *Meistgenutzt*, *Gemeldete Probleme*.

**Was hier gebaut wird und was nicht:** *Diese Woche* bleibt weg — Kurse sind Phase 4 und haben noch nicht einmal eine Spec. *Was noch fehlt* wird gebaut: es kommt vollständig aus dem Katalog, den `ladeKatalog` ohnehin lädt, und ist ohne es eine Seite, die sagt, dass etwas benutzt wird, aber nicht, was zu tun wäre.

**Dateien:**
- Erstellen: `apps/web/app/portal/[studioId]/modelle/page.tsx`
- Ersetzen: `apps/web/app/portal/[studioId]/page.tsx`
- Ändern: `apps/web/app/portal/[studioId]/Rail.tsx`
- Ändern: `apps/web/app/portal/portal.module.css` (Klassen `kacheln`, `kachel`, `kachelZahl`, `kachelLabel`)
- Ändern: `e2e/trainerportal.spec.ts`

**Schnittstellen:**
- Verbraucht: `getStudioOverview` aus Aufgabe 7 · `ladeKatalog`, `erreichbarkeit` aus `apps/web/app/portal/[studioId]/catalog.ts`

- [ ] **Schritt 1: Den Katalog nach `/modelle` umziehen**

`git mv` gibt es hier nicht — die Datei bekommt einen neuen Ort und die Wurzel einen neuen Inhalt:

```bash
mkdir -p "apps/web/app/portal/[studioId]/modelle"
cp "apps/web/app/portal/[studioId]/page.tsx" "apps/web/app/portal/[studioId]/modelle/page.tsx"
```

In der Kopie `apps/web/app/portal/[studioId]/modelle/page.tsx`:
- die Importpfade um eine Ebene tiefer ziehen: `"../Form"` → `"../../Form"`, `"../actions"` → `"../../actions"`, `"../portal.module.css"` → `"../../portal.module.css"`, `"./catalog"` → `"../catalog"`,
- den Funktionsnamen `StudioPage` zu `ModellePage` ändern,
- `<h1 className={styles.pageTitle}>Gerätekatalog</h1>` beibehalten — der Titel bleibt, nur der Ort ändert sich.

- [ ] **Schritt 2: Die Kachel-Klassen anlegen**

An `apps/web/app/portal/portal.module.css` anhängen:

```css
/* Kennzahlen des Ueberblicks. Vier Kacheln nebeneinander, auf schmalen
   Fenstern zwei. Bewusst ohne Balken und ohne Ziel: der Ueberblick sagt,
   OB das Studio benutzt wird, nicht wie weit es von irgendwas entfernt
   ist. */
.kacheln {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: var(--s12);
  margin-top: var(--s32);
}

.kachel {
  padding: var(--s20) var(--s24);
  border: 1px solid var(--line);
  border-radius: var(--r-card);
  background: var(--surface);
}

.kachelZahl {
  font-size: 32px;
  font-weight: 600;
  line-height: 1.1;
  color: var(--text);
}

.kachelLabel {
  margin-top: var(--s4);
  color: var(--text-muted);
}
```

> **Achtung, hier ist im Plan schon einmal ein Fehler passiert:** Die Tokens dieses Projekts heißen `--line`, `--text`, `--text-muted`, `--text-faint`, `--accent`, `--surface`, `--surface-raised`, dazu die Abstände `--s4` bis `--s48` und die Radien `--r-card` / `--r-control` (`apps/web/app/globals.css`). Das Portal ist **dunkel** (`--bg: #0a0b0d`, `--accent: #d4ff3f`). Der Hausbrauch in `portal.module.css` schreibt `var(--token)` **ohne** Rückfallwert und ohne `rem`. Erfundene Namen fallen nicht auf — sie greifen still auf den Rückfallwert zurück und ergeben ein helles Element auf dunklem Grund.

- [ ] **Schritt 3: Die Überblicksseite schreiben**

`apps/web/app/portal/[studioId]/page.tsx` **vollständig ersetzen** durch:

```tsx
import Link from "next/link";
import { getStudioOverview } from "@fitretro/domain";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { erreichbarkeit, ladeKatalog } from "./catalog";
import styles from "../portal.module.css";

const problemLabel: Record<string, string> = {
  schmerz: "Schmerz",
  geraet_passt_nicht: "Gerät passt nicht",
  zu_schwer: "Zu schwer",
  sonstiges: "Sonstiges",
};

export default async function UeberblickPage({
  params,
}: {
  params: Promise<{ studioId: string }>;
}) {
  const { studioId } = await params;
  const katalog = await ladeKatalog(studioId);
  const client = await createServerSupabaseClient();
  const uebersicht = await getStudioOverview(client, studioId, 30);

  const geraeteGesamt = katalog.models.reduce(
    (summe, modell) => summe + erreichbarkeit(modell).geraete,
    0,
  );
  const erreichbarGesamt = katalog.models.reduce(
    (summe, modell) => summe + erreichbarkeit(modell).erreichbar,
    0,
  );
  const ohneTag = geraeteGesamt - erreichbarGesamt;
  const uebungenOhneVideo = katalog.models.reduce(
    (summe, modell) => summe + modell.exercises.filter((u) => !u.hasVideo).length,
    0,
  );
  const vorrat = katalog.tags.filter((tag) => tag.status === "unassigned").length;

  // Ein einfaches Mitglied bekommt aus studio_overview null. Es hat auf
  // dieser Seite nichts verloren -- aber es soll einen Satz sehen, keinen
  // Absturz.
  if (!uebersicht) {
    return (
      <main className={styles.content}>
        <h1 className={styles.pageTitle}>Überblick</h1>
        <div className={styles.section}>
          <div className={styles.empty}>
            <p className={styles.emptyTitle}>
              Der Überblick ist Trainern und Inhabern vorbehalten.
            </p>
            <p className={styles.emptyNext}>
              Deine eigenen Trainingsdaten siehst du in der App, nicht hier.
            </p>
          </div>
        </div>
      </main>
    );
  }

  return (
    <main className={styles.content}>
      <h1 className={styles.pageTitle}>Überblick</h1>
      <p className={styles.pageLead}>
        Letzte {uebersicht.days} Tage. Studioweite Summen — welches Mitglied was
        trainiert hat, zeigt das Portal nirgends.
      </p>

      <div className={styles.kacheln}>
        <div className={styles.kachel}>
          <div className={styles.kachelZahl}>
            {erreichbarGesamt} / {geraeteGesamt}
          </div>
          <div className={styles.kachelLabel}>Geräte erreichbar</div>
        </div>
        <div className={styles.kachel}>
          <div className={styles.kachelZahl}>{uebersicht.activeMembers}</div>
          <div className={styles.kachelLabel}>Mitglieder aktiv</div>
        </div>
        <div className={styles.kachel}>
          <div className={styles.kachelZahl}>{uebersicht.sets}</div>
          <div className={styles.kachelLabel}>Sätze erfasst</div>
        </div>
        <div className={styles.kachel}>
          <div className={styles.kachelZahl}>{uebersicht.problemReports}</div>
          <div className={styles.kachelLabel}>Probleme gemeldet</div>
        </div>
      </div>

      <section className={styles.section}>
        <div className={styles.sectionHead}>
          <h2 className={styles.sectionTitle}>Was noch fehlt</h2>
        </div>
        {ohneTag === 0 && uebungenOhneVideo === 0 && geraeteGesamt > 0 ? (
          <p className={styles.sectionNote}>
            Nichts. Jedes Gerät in Betrieb ist erreichbar, jede Übung hat ein
            Einweisungsvideo.
          </p>
        ) : (
          <ul className={styles.rows}>
            {geraeteGesamt === 0 ? (
              <li className={styles.row}>
                <div className={styles.rowMain}>
                  <div className={styles.rowTitle}>Noch kein Gerät angelegt</div>
                  <div className={styles.rowMeta}>
                    Fang mit dem Gerät an, das am häufigsten benutzt wird.
                  </div>
                </div>
                <div className={styles.rowActions}>
                  <Link className={styles.secondary} href={`/portal/${studioId}/modelle`}>
                    Modell anlegen
                  </Link>
                </div>
              </li>
            ) : null}
            {ohneTag > 0 ? (
              <li className={styles.row}>
                <div className={styles.rowMain}>
                  <div className={styles.rowTitle}>
                    {ohneTag === 1 ? "1 Gerät ohne Tag" : `${ohneTag} Geräte ohne Tag`}
                  </div>
                  <div className={styles.rowMeta}>
                    Für Mitglieder nicht auffindbar ·{" "}
                    {vorrat === 0 ? (
                      <span className={styles.absent}>kein Tag vorrätig</span>
                    ) : (
                      `${vorrat} vorrätig`
                    )}
                  </div>
                </div>
                <div className={styles.rowActions}>
                  <Link className={styles.secondary} href={`/portal/${studioId}/tags`}>
                    Tag verbinden
                  </Link>
                </div>
              </li>
            ) : null}
            {uebungenOhneVideo > 0 ? (
              <li className={styles.row}>
                <div className={styles.rowMain}>
                  <div className={styles.rowTitle}>
                    {uebungenOhneVideo === 1
                      ? "1 Übung ohne Einweisungsvideo"
                      : `${uebungenOhneVideo} Übungen ohne Einweisungsvideo`}
                  </div>
                  <div className={styles.rowMeta}>Nutzbar, nur ohne Anleitung</div>
                </div>
                <div className={styles.rowActions}>
                  <Link className={styles.secondary} href={`/portal/${studioId}/modelle`}>
                    Ansehen
                  </Link>
                </div>
              </li>
            ) : null}
          </ul>
        )}
      </section>

      <section className={styles.section}>
        <div className={styles.sectionHead}>
          <h2 className={styles.sectionTitle}>Meistgenutzt</h2>
        </div>
        {!uebersicht.breakdown ? (
          <div className={styles.empty}>
            <p className={styles.emptyTitle}>Noch keine Rangliste.</p>
            <p className={styles.emptyNext}>
              Sie erscheint ab {uebersicht.minMembers} aktiven Mitgliedern im
              Zeitraum. Bei weniger ließe sich aus ihr ablesen, wer was
              trainiert hat — und das zeigt das Portal nicht.
            </p>
          </div>
        ) : uebersicht.topMachines.length === 0 ? (
          <div className={styles.empty}>
            <p className={styles.emptyTitle}>Noch kein Satz erfasst.</p>
            <p className={styles.emptyNext}>
              Aktive Mitglieder gibt es — eine Einheit gilt als begonnen, sobald
              jemand ein Gerät antippt. Gezählt wird hier erst, was am Gerät
              bestätigt wurde.
            </p>
          </div>
        ) : (
          <ul className={styles.rows}>
            {uebersicht.topMachines.map((geraet) => (
              <li key={geraet.machineId} className={styles.row}>
                <div className={styles.rowMain}>
                  <div className={styles.rowTitle}>
                    {geraet.label}{" "}
                    {geraet.status === "inactive" ? (
                      <span className={styles.badge}>stillgelegt</span>
                    ) : null}
                  </div>
                </div>
                <div className={styles.rowMeta}>
                  {geraet.sets} {geraet.sets === 1 ? "Satz" : "Sätze"}
                </div>
              </li>
            ))}
          </ul>
        )}
      </section>

      <section className={styles.section}>
        <div className={styles.sectionHead}>
          <h2 className={styles.sectionTitle}>Gemeldete Probleme</h2>
          <span className={styles.sectionNote}>
            Ohne Namen. Wer gemeldet hat, steht hier nicht.
          </span>
        </div>
        {!uebersicht.breakdown ? (
          <div className={styles.empty}>
            <p className={styles.emptyTitle}>Noch keine Aufschlüsselung.</p>
            <p className={styles.emptyNext}>
              Sie erscheint ab {uebersicht.minMembers} aktiven Mitgliedern im
              Zeitraum. Die Kachel oben zählt alle Meldungen; welches Gerät
              betroffen ist, bleibt bis dahin verdeckt.
            </p>
          </div>
        ) : uebersicht.problems.length === 0 ? (
          <div className={styles.empty}>
            <p className={styles.emptyTitle}>Keine Meldung im Zeitraum.</p>
          </div>
        ) : (
          <ul className={styles.rows}>
            {uebersicht.problems.map((meldung) => (
              <li
                key={`${meldung.machineId}-${meldung.reason ?? "ohne"}`}
                className={styles.row}
              >
                <div className={styles.rowMain}>
                  <div className={styles.rowTitle}>{meldung.label}</div>
                  <div className={styles.rowMeta}>
                    {meldung.reason
                      ? (problemLabel[meldung.reason] ?? meldung.reason)
                      : "ohne Angabe"}
                  </div>
                </div>
                <div className={styles.rowMeta}>{meldung.count} ×</div>
              </li>
            ))}
          </ul>
        )}
      </section>

      <p className={styles.hint}>
        gymodo misst nichts. Alles hier ist gezählt, was Mitglieder selbst
        bestätigt haben.
      </p>
    </main>
  );
}
```

- [ ] **Schritt 4: Die Rail nachziehen**

In `apps/web/app/portal/[studioId]/Rail.tsx`:

- ganz oben, **vor** der Gruppe *Gerätemodelle*, eine Gruppe *Studio* einfügen:

```tsx
      <div className={styles.group}>
        <h2 className={styles.groupLabel}>Studio</h2>
        <Link href={basis} className={klasse(pfad === basis)}>
          <span className={styles.navItemTitle}>Überblick</span>
        </Link>
      </div>
```

- den Link „Modell anlegen" von `href={basis}` auf `href={`${basis}/modelle`}` umstellen und seine Aktivmarkierung entsprechend auf `pfad === `${basis}/modelle``,
- den Eintrag *Einstellungen* aus Aufgabe 3 Schritt 7 an derselben Stelle behalten.

> Die vollständige Umgruppierung der Rail auf die drei Gruppen aus Spec Abschnitt 1 (*Studio · Katalog · Verwaltung* mit je zwei Einträgen) gehört zu Phase 5 — dort verschwinden auch die einzelnen Modelleinträge. Hier wird nur so viel geändert, wie die neuen Seiten erreichbar macht.

- [ ] **Schritt 5: Den E2E-Gang nachziehen**

In `e2e/trainerportal.spec.ts` zwei Stellen:

- Zeile 89 (`Trainer in einem Studio mit weiterem Personal …`): `await expect(page.getByRole("heading", { name: "Gerätekatalog" })).toBeVisible();` wird zu `await expect(page.getByRole("heading", { name: "Überblick" })).toBeVisible();`
- Zeile 124 ff. (der große Gang): nach dem Redirect auf `/portal/<id>` einen Schritt auf den Katalog einfügen, bevor das Modell angelegt wird:

```typescript
  await page.goto("/portal");
  await expect(page).toHaveURL(new RegExp(`/portal/${studio.id}$`));
  await expect(page.getByRole("heading", { name: "Überblick" })).toBeVisible();

  // Der Katalog liegt seit dem Ueberblick unter /modelle.
  await page.goto(`/portal/${studio.id}/modelle`);
  await expect(page.getByRole("heading", { name: "Gerätekatalog" })).toBeVisible();
```

Der Rest des Gangs bleibt unverändert.

- [ ] **Schritt 6: Bauen und E2E laufen lassen**

```bash
pnpm typecheck
pnpm --filter web build
pnpm test:e2e e2e/trainerportal.spec.ts
```

Erwartet: grün.

- [ ] **Schritt 7: Commit**

```bash
git add apps/web e2e
git commit -m "$(cat <<'EOF'
feat(web): die Wurzelseite ist der Ueberblick, der Katalog zieht nach /modelle

Meistgenutzt und Gemeldete Probleme erscheinen erst ab fuenf aktiven
Mitgliedern -- darunter steht, warum sie fehlen, statt bloss nichts.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01N9D8evoBWvz734s2yrygfE
EOF
)"
```

---

### Aufgabe 9: E2E-Gang durch die Einstellungen, Cloud-Abgleich, Dokumentation

**Dateien:**
- Erstellen: `e2e/einstellungen.spec.ts`
- Ändern: `docs/superpowers/plans/2026-09-01-gesamtfahrplan.md`

- [ ] **Schritt 1: Den E2E-Gang schreiben**

Datei `e2e/einstellungen.spec.ts`:

```typescript
import { expect, test } from "@playwright/test";
import { createClient } from "@supabase/supabase-js";
import { E2E_PASSWORD, anmelden } from "./helpers/login";

/**
 * Der Gang durch die Einstellungen: Stammdaten speichern, Stornofrist
 * setzen, Code erneuern, Passwort aendern. Was hier belegt wird, ist der
 * Weg des Trainers durch die Oberflaeche -- die Grenzen selbst stehen in
 * tests/integration/rls-studio-einstellungen.test.ts.
 */
test("ein Trainer pflegt die Studio-Einstellungen", async ({ page }) => {
  const admin = createClient(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    { auth: { persistSession: false } },
  );

  const email = `einst-${crypto.randomUUID()}@example.test`;
  const { data: user, error: userError } = await admin.auth.admin.createUser({
    email,
    password: E2E_PASSWORD,
    email_confirm: true,
  });
  if (userError) throw userError;

  const { data: studio, error: studioError } = await admin
    .from("studios")
    .insert({ name: "Einstellungen E2E Studio" })
    .select("id, join_code")
    .single();
  if (studioError) throw studioError;

  const { error: membershipError } = await admin.from("studio_memberships").insert({
    studio_id: studio.id,
    user_id: user.user.id,
    role: "trainer",
  });
  if (membershipError) throw membershipError;

  await anmelden(page, email);
  await page.goto(`/portal/${studio.id}/einstellungen`);

  // Stammdaten und Stornofrist -- ein Formular, ein Knopf.
  await expect(page.getByRole("heading", { name: "Einstellungen" })).toBeVisible();
  await page.getByLabel("Name").fill("Kraftwerk Nord");
  await page.getByLabel("Stornofrist").fill("6");
  await page.getByRole("button", { name: "Änderungen speichern" }).click();

  await page.reload();
  await expect(page.getByLabel("Name")).toHaveValue("Kraftwerk Nord");
  await expect(page.getByLabel("Stornofrist")).toHaveValue("6");

  // Die Fehlermeldung sagt, was gilt -- nicht nur, dass es nicht ging.
  await page.getByLabel("Stornofrist").fill("200");
  await page.getByRole("button", { name: "Änderungen speichern" }).click();
  await expect(page.getByRole("alert")).toContainText("168");

  // Der Code erneuert sich, und der alte gilt danach nicht mehr.
  await page.reload();
  await expect(page.getByText(studio.join_code)).toBeVisible();
  await page.getByRole("button", { name: "Neuen Code erzeugen" }).click();
  await page.getByRole("button", { name: /Wirklich/ }).click();
  await expect(page.getByText(studio.join_code)).toBeHidden();

  // Der Reiter Konto: Passwort aendern.
  await page.getByRole("link", { name: "Konto" }).click();
  await expect(page.getByText(email)).toBeVisible();

  const neuesPasswort = `e2e-neu-${crypto.randomUUID()}`;
  await page.getByLabel("Aktuelles Passwort").fill(E2E_PASSWORD);
  await page.getByLabel("Neues Passwort").fill(neuesPasswort);
  await page.getByLabel("Wiederholen").fill(neuesPasswort);
  await page.getByRole("button", { name: "Passwort ändern" }).click();
  await expect(page.getByText("Das Passwort ist geändert.")).toBeVisible();

  // Und das alte trägt nicht mehr.
  await page.getByRole("button", { name: "Abmelden" }).click();
  await expect(page).toHaveURL(/\/login/);
});
```

- [ ] **Schritt 2: E2E laufen lassen**

```bash
pnpm test:e2e e2e/einstellungen.spec.ts
```

Erwartet: grün. Schlägt der Kopierknopf im Kopf-losen Browser fehl, liegt es an der Clipboard-Berechtigung — dann den Kopierknopf aus dem Test lassen, nicht die Berechtigung global aufmachen.

- [ ] **Schritt 3: Die gesamte Suite**

```bash
pnpm typecheck
pnpm vitest run --config vitest.config.ts
pnpm test:e2e
```

Erwartet: alles grün. **Ohne diese drei Zeilen im Bericht gilt der Bauabschnitt nicht als fertig** — der Fahrplan verlangt Beleg, keine Behauptung.

- [ ] **Schritt 4: Die drei Migrationen in die Cloud**

`supabase db push` scheitert auf dieser Maschine (`TransportError`, Fahrplan 4d). Der Weg geht über den Supabase-MCP:

1. `mcp__plugin_supabase_supabase__list_migrations` — Ausgangsstand festhalten (soll: 31 Einträge, `0001`–`0031`).
2. `mcp__plugin_supabase_supabase__apply_migration` je Datei, Inhalt wörtlich.
3. Die vergebenen Zeitstempel-Versionen auf `0032`, `0033`, `0034` normalisieren — sonst meldet `supabase migration list` dauerhaft Drift, obwohl das Schema stimmt:
   ```sql
   update supabase_migrations.schema_migrations set version = '0032' where version = '<zeitstempel>';
   ```
   über `mcp__plugin_supabase_supabase__execute_sql`.
4. `mcp__plugin_supabase_supabase__list_migrations` — Gleichstand über **34** Einträge belegen.
5. `mcp__plugin_supabase_supabase__get_advisors` mit `type: "security"` — die neue `SECURITY DEFINER`-Funktion und der Rechte-Entzug auf `studios` gehören einmal durch den Advisor.

- [ ] **Schritt 5: Den Fahrplan nachziehen**

In `docs/superpowers/plans/2026-09-01-gesamtfahrplan.md`:

- **Kopftabelle:** Bezugsstand auf den Merge-Commit dieses Zweigs.
- **Abschnitt 3, Tabelle:** die Zeile „Studio-Einstellungen, Datenschutzgrenze, Überblick" durchstreichen und auf ✅ setzen, Migrationen `0032`–`0034`, Umsetzungsplan `2026-09-02-studio-einstellungen-datenschutzgrenze.md`, 9 Aufgaben.
- **Abschnitt 3, „Was von den vier ‚am weitesten offenen' übrig ist":** beide verbleibenden Punkte durchstreichen. Damit sind alle vier zu.
- **Abschnitt 5, Phase 2:** Punkte 3 und 4 auf ✅, Überschrift von „*(halb)*" auf „✅ *abgeschlossen 2. September*".
- **Abschnitt 5, „Was parallel geht":** Strang A streichen; übrig bleiben B und C.
- **Abschnitt 6:** die Zeile „Stornofrist — Wert offen" streichen (entschieden: Vorgabe 2 Stunden, Bereich 0–168). Neue Zeile: „Mindestzahl für die Aufschlüsselung im Überblick — auf 5 gesetzt, vor dem ersten echten Mitglied zu prüfen | 0034, Spec §4 | nichts".
- **Abschnitt 2, Tabelle:** neue Zeile „**Studio-Einstellungen und Datenschutzgrenze** — Stornofrist, Speicherrecht mit Spaltengrenze, vier Policies ohne Staff-Klausel, `studio_overview` | ✅ neu".

- [ ] **Schritt 6: Commit**

```bash
git add e2e/einstellungen.spec.ts docs/superpowers/plans/2026-09-01-gesamtfahrplan.md
git commit -m "$(cat <<'EOF'
test(e2e): der Gang durch die Einstellungen, Planstand nachgezogen

Phase 2 ist damit zu -- alle vier Bauabschnitte gebaut.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01N9D8evoBWvz734s2yrygfE
EOF
)"
```

---

## Was dieser Plan bewusst nicht baut

| Weggelassen | Warum |
| --- | --- |
| *Diese Woche* auf dem Überblick (Kursliste) | Kurse sind Phase 4 und haben nicht einmal eine Spec. Der Abschnitt kommt mit den Kursen, nicht davor. |
| Die vollständige Umgruppierung der Rail auf drei Gruppen zu zwei Einträgen (Spec §1) | Phase 5. Dort verschwinden auch die einzelnen Modelleinträge aus der Rail. Hier wird nur ergänzt, was die neuen Seiten erreichbar macht. |
| Ein Index auf `workout_sets (studio_id, performed_at)` | Bei den Datenmengen dieses Systems ist ein Seq Scan das Richtige. Aufgabe 6 Schritt 5 nimmt stattdessen die Ausgangsmessung auf. |
| Zusammenlegung von *Geräte* und *Gerätemodelle* zu einem Bereich (Spec §1, Entscheidung 5) | Phase 5. Der Umzug auf `/modelle` in Aufgabe 8 ist ein Ortswechsel, kein Umbau. |
| Rücknahme der Datenschutzgrenze für Trainerbetreuung | M3. Spec §4: „Der Weg dorthin ist eine ausdrückliche Freigabe durch das Mitglied, nicht die pauschale Rolle." |

## Was auffallen wird und kein Fehler ist

- **Der Überblick sieht mit Testdaten kahl aus.** Ein Entwicklungsstudio hat selten fünf aktive Mitglieder; *Meistgenutzt* und *Gemeldete Probleme* zeigen dann ihren Leer-Zustand mit Begründung. Das ist die Mindestzahl bei der Arbeit, nicht ein Fehler.
- **`auth_leaked_password_protection` bleibt aus.** Der Haken im Supabase-Dashboard (Authentication → Policies) steht im Fahrplan als offener Punkt von Phase 0 und gehört nicht in diesen Plan — er ist Konfiguration, kein Code. Aufgabe 4 macht ihn dringender: ab jetzt ändern Betreiber ihr Passwort im Portal.
