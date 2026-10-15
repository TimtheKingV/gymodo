# Training fortsetzen – Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ein von Hand beendetes Training lässt sich innerhalb von 30 Minuten über einen Play-Button in der Zusammenfassung fortsetzen. Die Lücke zählt dabei als Pause, und Home zeigt die Dauer ohne Pausen.

**Architecture:**
- **Server:** speichert eine Pausensumme je Einheit und kann eine beendete Einheit im Fenster wieder öffnen (`reopen`).
- **App:** hebt die zuletzt beendete Einheit lokal auf. Nach erfolgreichem `reopen` macht sie daraus wieder die laufende Einheit; die Lücke kommt in die Pausendauer.

**Tech Stack:**
- Postgres-Migration (Supabase).
- TypeScript-Domain (`packages/domain`, Zod, Vitest).
- Next.js-Route-Handler (`apps/web`).
- SwiftUI-App (`apps/ios-member`, Swift Testing).

**Spec:** `docs/superpowers/specs/2026-10-15-training-fortsetzen-design.md`

## Global Constraints

- **Fenster:** 30 Minuten ab `completed_at` (`REOPEN_FENSTER_MS = 30 * 60 * 1000`).
- **Wiederöffnen** nur bei `completed_reason = 'manual'`. Bei `'auto'` gibt es `conflict`, „Dieses Training wurde automatisch beendet.“
- **Zu spät:** `conflict`, „Zu spät zum Fortsetzen.“
- **Schon offen:** Erfolg ohne Schreiben (idempotent).
- **Spalte:** `workout_sessions.paused_seconds integer not null default 0 check (paused_seconds >= 0)`.
- **`complete` ohne Rumpf** (alte App) bleibt gültig, die Pausensumme ist dann 0.
- **Zweiter `complete`-Aufruf** auf eine beendete Einheit schreibt nichts, auch nicht `paused_seconds`.
- **Keine Ablage** für eine Einheit ohne Satz und beim Ortswechsel. `reset()` (Abmelden) löscht die Ablage.
- **`wiederaufnehmen`** heißt nicht `fortsetzen`, denn das ist schon „Pause beenden“.
- **Play-Button:** `play.fill`, Accessibility-Label „Training fortsetzen“, Testnotiz-ID `session.fortsetzen`.
- **Meldung ohne Netz:** „Ohne Verbindung geht Fortsetzen nicht.“
- **Kommentare** im Code verweisen auf „(Testnotiz 14.10., 18:45 #3/#4)“. Bezeichner sind deutsch wie im Umfeld.
- **Auslieferung:** erst Migration 0053 auf Prod, dann Web-Deploy, dann App.

## Review Focus

1. **Doppeltipp auf Play,** oder die App wird zwischen `reopen` und `wiederaufnehmen` beendet: Der zweite Versuch muss gelingen und darf die Lücke nicht doppelt als Pause buchen. Abgedeckt durch die Tests in Task 2 (reopen idempotent) und Task 6 (zweites `wiederaufnehmen` liefert nil, Pause unverändert).
2. **Beendet während einer Pause:** Die angebrochene Pause wird bis `beendetAm` abgeschlossen, dann kommt die Lücke dazu. Sie darf nicht doppelt zählen und nicht offen bleiben. Test in Task 6.
3. **Ein neues Training wurde gestartet,** solange die Ablage noch frisch ist: Der Button darf nicht erscheinen, denn zwei Trainings gleichzeitig gibt es nicht. Tests in Task 6 und Task 7.
4. **Die Uhr von Gerät und Server weicht ab** (App sagt 29 min, Server 31 min): Die App zeigt die Server-Meldung, verwirft die Ablage, und der Button verschwindet. Test in Task 7 (`ablageVerwerfen` nach conflict).
5. **Die zusammengelegte Karte** (zwei Einheiten mit weniger als 1 h Abstand): Nur der jüngste Teil zählt für den Button, auch wenn die Detailseite über die ID des ältesten Teils geöffnet wurde. Test in Task 7.

## Dateiübersicht

**Server**
- `supabase/migrations/0053_pausensumme.sql` (neu): die Spalte.
- `packages/domain/src/workout.ts`:
  - `completeSessionInputSchema` bekommt `pausedSeconds`.
  - `completeSession` schreibt `paused_seconds`.
  - Neu sind `wiederoeffnenEntscheidung`, `reopenSession` und `REOPEN_FENSTER_MS`.
- `packages/domain/src/workout.test.ts`: Unit-Tests der Entscheidung und des Schemas. Falls die Datei fehlt, wird sie angelegt.
- `packages/domain/src/index.ts`: Export von `reopenSession`.
- `packages/domain/src/sessions.ts`: `SessionSummary.pausedSeconds`.
- `packages/domain/src/abschluss.test.ts`: Test „zweiter Abschluss gewinnt“.
- `apps/web/app/api/v1/workout-sessions/[sessionId]/complete/route.ts`: liest den optionalen Rumpf.
- `apps/web/app/api/v1/workout-sessions/[sessionId]/reopen/route.ts` (neu).
- `tests/integration/domain-reopen-session.test.ts` (neu).

**App**
- `Networking/DTOs/SessionSummary.swift`: `pausedSeconds`.
- `Verlauf/HomeZeilen.swift`: Dauer abzüglich Pausen.
- `Workout/LokaleSession.swift`: `pausenSekunden(jetzt:)`.
- `Workout/GeraetLoading.swift` und `Networking/APIClient.swift`:
  - `completeSession(sessionId:pausedSeconds:)`.
  - `reopenSession(sessionId:)` (nur `APIClient`).
- `Workout/WorkoutSessionStore+Ortswechsel.swift`: `Ortswechselende.abgeschlossen(UUID, pausedSeconds:)`.
- `Workout/Trainingszusammenfassung.swift`: `pausedSeconds`.
- `Screens/Training/TrainingAbschlussView.swift`: reicht die Pausensumme weiter.
- `Workout/SessionFileStore.swift`: zweite Datei `zuletzt-beendet.json`.
- `Workout/WorkoutSessionStore.swift`: Ablage, `kannWiederaufnehmen`, `wiederaufnehmen`, `ablageVerwerfen`.
- `Verlauf/Fortsetzbarkeit.swift` (neu): reine Sichtbarkeitsregel. Sie ist neu, deshalb muss das Projekt neu erzeugt werden (`xcodegen`).
- `Screens/Home/SessionDetailView.swift`: Play-Button.
- `Screens/Home/HomeRootView.swift`: `beiFortgesetzt` durchreichen.
- `Screens/Training/TrainingRootView.swift`: Pfad zurücksetzen, wenn ein Training wieder aktiv wird.

**Tests (App):**
- `FitnessMemberTests/HomeZeilenTests.swift`
- `FitnessMemberTests/LokaleSessionTests.swift`
- `FitnessMemberTests/OrtswechselBeendenTests.swift`
- `FitnessMemberTests/GeraetModelTests.swift` (der Fake-Loader)
- `FitnessMemberTests/WiederaufnehmenTests.swift` (neu)
- `FitnessMemberTests/FortsetzbarkeitTests.swift` (neu)
- `FitnessMemberTests/DTOTests.swift`

## Befehle

- **Vitest (Domain):** `cd packages/domain && npx vitest run <datei>`.
- **Integration** (braucht lokales Supabase, `supabase start`): `pnpm test:integration tests/integration/<datei>`.
- **Swift-Tests:**
  ```bash
  cd apps/ios-member && xcodebuild test -project FitnessMember.xcodeproj -scheme FitnessMember \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FitnessMemberTests/<Suite> 2>&1 \
    | grep -E "error:|✘|TEST (SUCCEEDED|FAILED)|Test run with"
  ```
  - Neue Dateien in `FitnessMember/` oder `FitnessMemberTests/` erfordern vorher `cd apps/ios-member && xcodegen generate`.
  - Ein Fehler „mkstemp“ oder „failed to launch“ ist Infrastruktur (die Platte ist knapp). Einmal wiederholen.

---

### Task 1: Pausensumme am Server

**Files:**
- Create: `supabase/migrations/0053_pausensumme.sql`
- Modify: `packages/domain/src/workout.ts`, Schema bei Zeile ~406, `completeSession` bei ~440–505
- Modify: `apps/web/app/api/v1/workout-sessions/[sessionId]/complete/route.ts`
- Test: `packages/domain/src/workout.test.ts`, `tests/integration/domain-complete-session.test.ts`

**Interfaces:**
- Produces:
  - `completeSessionInputSchema: z.object({ sessionId: uuid, pausedSeconds?: int >= 0 })`
  - `completeSession(client, { sessionId, pausedSeconds? })`

- [ ] **Step 1: Write the failing unit test**

In `packages/domain/src/workout.test.ts` (anlegen, falls nicht vorhanden; Import-Stil wie `bootstrap.test.ts`):

```ts
import { describe, expect, it } from "vitest";
import { completeSessionInputSchema } from "./workout.js";

describe("completeSessionInputSchema", () => {
  const sessionId = "6f1c2b9e-3c1a-4a51-9a4e-1d2f3a4b5c6d";

  // Testnotiz 14.10., 18:45 #3/#4: die Pausensumme kommt mit dem Abschluss.
  it("nimmt eine Pausensumme an", () => {
    expect(completeSessionInputSchema.parse({ sessionId, pausedSeconds: 1080 }).pausedSeconds).toBe(1080);
  });

  it("laesst die Pausensumme weg, wie eine alte App", () => {
    expect(completeSessionInputSchema.parse({ sessionId }).pausedSeconds).toBeUndefined();
  });

  it("weist eine negative oder gebrochene Pausensumme ab", () => {
    expect(completeSessionInputSchema.safeParse({ sessionId, pausedSeconds: -1 }).success).toBe(false);
    expect(completeSessionInputSchema.safeParse({ sessionId, pausedSeconds: 1.5 }).success).toBe(false);
  });
});
```

- [ ] **Step 2: Run it, expect FAIL**

Run: `cd packages/domain && npx vitest run src/workout.test.ts`
Expected: FAIL. `pausedSeconds` ist undefined beim ersten Test, und die Ablehnung schlägt fehl, weil Zod unbekannte Schlüssel verwirft.

- [ ] **Step 3: Migration**

`supabase/migrations/0053_pausensumme.sql`:

```sql
-- Testnotiz 14.10., 18:45 #3/#4: Training fortsetzen.
--
-- Die Luecke zwischen Beenden und Fortsetzen zaehlt als Pause, und Home
-- soll sie nicht als Trainingszeit zeigen. Der Server kannte bisher keine
-- Pause: die Dauer war Start bis Ende. paused_seconds ist die Summe aller
-- Pausen der Einheit, gesetzt vom Client beim Abschluss. Alte Einheiten
-- haben 0 und zeigen damit dieselbe Dauer wie bisher. Kein eigener Grant:
-- workout_sessions hat keine Spaltenrechte, die Update-Policy (0047) deckt
-- die Spalte mit.
alter table public.workout_sessions
  add column paused_seconds integer not null default 0
    constraint workout_sessions_paused_seconds_nicht_negativ
    check (paused_seconds >= 0);
```

- [ ] **Step 4: Schema und `completeSession`**

In `packages/domain/src/workout.ts`:

```ts
export const completeSessionInputSchema = z.object({
  sessionId: z.string().uuid(),
  /** Summe aller Pausen in Sekunden (Testnotiz 14.10., 18:45 #3/#4). Fehlt bei alten Apps. */
  pausedSeconds: z.number().int().min(0).optional(),
});
```

Im `update` von `completeSession` (der Zweig für die noch offene Einheit, **nicht** im Frühausstieg):

```ts
    .update({
      completed_at: new Date().toISOString(),
      completed_reason: "manual",
      ...(parsed.data.pausedSeconds !== undefined
        ? { paused_seconds: parsed.data.pausedSeconds }
        : {}),
    })
```

- [ ] **Step 5: Route liest den optionalen Rumpf**

In `apps/web/app/api/v1/workout-sessions/[sessionId]/complete/route.ts` den Doc-Kommentar und den Aufruf ersetzen:

```ts
/**
 * Beendet eine Trainingseinheit ausdruecklich (Spec 5.2).
 *
 * Der Rumpf ist optional: `{ pausedSeconds }` seit dem Fortsetzen
 * (Testnotiz 14.10., 18:45 #3/#4). Eine alte App schickt keinen -- dann
 * bleibt die Pausensumme, wie sie ist. Der Grund ist bei diesem Weg immer
 * `manual`.
 */
export async function POST(
  request: Request,
  context: Context,
): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) {
    return errorResponse("unauthorized", "Anmeldung erforderlich.");
  }

  const { sessionId } = await context.params;
  const text = await request.text();
  let rumpf: Record<string, unknown> = {};
  if (text.trim() !== "") {
    try {
      rumpf = JSON.parse(text) as Record<string, unknown>;
    } catch {
      return errorResponse("validation_failed", "Der Rumpf ist kein JSON.");
    }
  }

  try {
    const completed = await completeSession(client, { ...rumpf, sessionId });
    return Response.json(completed, { status: 200 });
  } catch (error) {
    return fromDomainError(error);
  }
}
```

- [ ] **Step 6: Integrationstest**

In `tests/integration/domain-complete-session.test.ts` im `describe("completeSession")` ergänzen:

```ts
  it("haelt die Pausensumme fest, ein Wiederholer aendert sie nicht", async () => {
    const client = await userClient(memberAEmail);
    const sessionId = await seedSession(memberAId);

    await completeSession(client, { sessionId, pausedSeconds: 600 });
    await completeSession(client, { sessionId, pausedSeconds: 9999 });

    const { data } = await serviceClient()
      .from("workout_sessions").select("paused_seconds").eq("id", sessionId).single();
    expect(data?.paused_seconds).toBe(600);
  });

  it("laesst die Pausensumme ohne Angabe bei 0", async () => {
    const client = await userClient(memberAEmail);
    const sessionId = await seedSession(memberAId);

    await completeSession(client, { sessionId });

    const { data } = await serviceClient()
      .from("workout_sessions").select("paused_seconds").eq("id", sessionId).single();
    expect(data?.paused_seconds).toBe(0);
  });
```

- [ ] **Step 7: Run all, expect PASS**

Run:
- `cd packages/domain && npx vitest run src/workout.test.ts`
- `cd ../.. && supabase db reset && pnpm test:integration tests/integration/domain-complete-session.test.ts`

Expected: alles PASS.

- [ ] **Step 8: Commit**

```bash
git add supabase/migrations/0053_pausensumme.sql packages/domain/src/workout.ts packages/domain/src/workout.test.ts \
  "apps/web/app/api/v1/workout-sessions/[sessionId]/complete/route.ts" tests/integration/domain-complete-session.test.ts
git commit -m "feat(training): Pausensumme je Einheit, mit dem Abschluss gesendet"
```

---

### Task 2: `reopen` am Server

**Files:**
- Modify: `packages/domain/src/workout.ts`, nach `completeSession`
- Modify: `packages/domain/src/index.ts`
- Create: `apps/web/app/api/v1/workout-sessions/[sessionId]/reopen/route.ts`
- Test: `packages/domain/src/workout.test.ts`, `tests/integration/domain-reopen-session.test.ts` (neu)

**Interfaces:**
- Consumes: `SessionRow` (workout.ts) und `DomainError`.
- Produces:
  - `REOPEN_FENSTER_MS: number`
  - `wiederoeffnenEntscheidung(row: { completed_at: string | null; completed_reason: "manual" | "auto" | null }, jetzt: Date): "offen" | "oeffnen" | { fehler: string }`
  - `reopenSession(client, rawInput: unknown, jetzt?: Date): Promise<{ id: string; startedAt: string }>`
  - `POST /api/v1/workout-sessions/{id}/reopen` → 200 `{ id, startedAt }`, 409 bei conflict, 404 bei not_found.

- [ ] **Step 1: Write the failing unit test**

An `packages/domain/src/workout.test.ts` anhängen. Den Import auf `import { completeSessionInputSchema, REOPEN_FENSTER_MS, wiederoeffnenEntscheidung } from "./workout.js";` erweitern.

```ts
describe("wiederoeffnenEntscheidung", () => {
  const ende = "2026-10-14T18:52:00.000Z";
  const nach = (min: number) => new Date(Date.parse(ende) + min * 60_000);

  it("oeffnet 29 Minuten nach dem Beenden", () => {
    expect(wiederoeffnenEntscheidung({ completed_at: ende, completed_reason: "manual" }, nach(29))).toBe("oeffnen");
  });

  it("oeffnet genau an der Grenze", () => {
    expect(REOPEN_FENSTER_MS).toBe(30 * 60 * 1000);
    expect(wiederoeffnenEntscheidung({ completed_at: ende, completed_reason: "manual" }, nach(30))).toBe("oeffnen");
  });

  it("lehnt nach 31 Minuten ab", () => {
    expect(wiederoeffnenEntscheidung({ completed_at: ende, completed_reason: "manual" }, nach(31)))
      .toEqual({ fehler: "Zu spät zum Fortsetzen." });
  });

  it("lehnt eine selbsttaetig beendete Einheit ab", () => {
    expect(wiederoeffnenEntscheidung({ completed_at: ende, completed_reason: "auto" }, nach(1)))
      .toEqual({ fehler: "Dieses Training wurde automatisch beendet." });
  });

  // Doppeltipp oder Wiederholer: schon offen ist kein Fehler.
  it("laesst eine offene Einheit offen", () => {
    expect(wiederoeffnenEntscheidung({ completed_at: null, completed_reason: null }, nach(0))).toBe("offen");
  });
});
```

- [ ] **Step 2: Run, expect FAIL**

Run: `cd packages/domain && npx vitest run src/workout.test.ts`
Expected: FAIL, Export `wiederoeffnenEntscheidung` fehlt.

- [ ] **Step 3: Implementation**

In `packages/domain/src/workout.ts` nach `completeSession`:

```ts
/** Wie lange nach "Training beenden" ein Fortsetzen geht (Testnotiz 14.10., 18:45 #3). */
export const REOPEN_FENSTER_MS = 30 * 60 * 1000;

export const reopenSessionInputSchema = z.object({
  sessionId: z.string().uuid(),
});

/**
 * Die Regel hinter reopenSession, ohne Datenbank pruefbar. "offen" ist kein
 * Fehler: ein Doppeltipp oder ein Wiederholer nach Netzabbruch trifft eine
 * schon geoeffnete Einheit und soll trotzdem gelingen.
 */
export function wiederoeffnenEntscheidung(
  row: Pick<SessionRow, "completed_at" | "completed_reason">,
  jetzt: Date,
): "offen" | "oeffnen" | { fehler: string } {
  if (row.completed_at === null) return "offen";
  if (row.completed_reason === "auto") {
    return { fehler: "Dieses Training wurde automatisch beendet." };
  }
  if (jetzt.getTime() - Date.parse(row.completed_at) > REOPEN_FENSTER_MS) {
    return { fehler: "Zu spät zum Fortsetzen." };
  }
  return "oeffnen";
}

/**
 * Oeffnet eine von Hand beendete Einheit wieder (Testnotiz 14.10., 18:45
 * #3/#4). paused_seconds bleibt stehen: der naechste Abschluss schreibt die
 * neue Gesamtsumme. Die Vorschlaege des ersten Abschlusses bleiben als
 * Protokoll; beim zweiten Abschluss gilt je Block die juengere Zeile
 * (ausGespeichertenZeilen nimmt die aelteste AB completed_at).
 */
export async function reopenSession(
  client: SupabaseClient,
  rawInput: unknown,
  jetzt: Date = new Date(),
): Promise<{ id: string; startedAt: string }> {
  const parsed = reopenSessionInputSchema.safeParse(rawInput);
  if (!parsed.success) {
    throw new DomainError("validation_failed", parsed.error.issues[0]!.message);
  }
  const userId = await requireUserId(client);

  const { data: existing } = await client
    .from("workout_sessions")
    .select("id, started_at, completed_at, completed_reason")
    .eq("id", parsed.data.sessionId)
    .eq("user_id", userId)
    .maybeSingle<SessionRow>();
  if (!existing) {
    throw new DomainError("not_found", "Training nicht gefunden.");
  }

  const entscheidung = wiederoeffnenEntscheidung(existing, jetzt);
  if (typeof entscheidung === "object") {
    throw new DomainError("conflict", entscheidung.fehler);
  }
  if (entscheidung === "oeffnen") {
    const { error } = await client
      .from("workout_sessions")
      .update({ completed_at: null, completed_reason: null })
      .eq("id", existing.id);
    if (error) throw new DomainError("internal", error.message);
  }
  return { id: existing.id, startedAt: existing.started_at };
}
```

In `packages/domain/src/index.ts` an der Stelle, die `completeSession` exportiert (`grep -n completeSession packages/domain/src/index.ts`), `reopenSession` daneben in denselben Export aufnehmen.

- [ ] **Step 4: Route**

`apps/web/app/api/v1/workout-sessions/[sessionId]/reopen/route.ts`:

```ts
import { reopenSession } from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

type Context = { params: Promise<{ sessionId: string }> };

/**
 * Oeffnet eine von Hand beendete Einheit wieder, hoechstens 30 Minuten nach
 * dem Beenden (Testnotiz 14.10., 18:45 #3/#4). Ohne Rumpf. 409 mit Text,
 * wenn es zu spaet ist oder die Einheit selbsttaetig beendet wurde.
 */
export async function POST(request: Request, context: Context): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) return errorResponse("unauthorized", "Anmeldung erforderlich.");

  const { sessionId } = await context.params;
  try {
    return Response.json(await reopenSession(client, { sessionId }), { status: 200 });
  } catch (error) {
    return fromDomainError(error);
  }
}
```

- [ ] **Step 5: Integrationstest**

`tests/integration/domain-reopen-session.test.ts`. Den `beforeAll` mit Studio und zwei Mitgliedern 1:1 aus `domain-complete-session.test.ts` übernehmen, mit Namen „Fortsetzen Studio“ und `uniqueEmail("fortsetzen-a")` bzw. `"fortsetzen-a2"`. Dazu:

```ts
import { completeSession, getSessions, reopenSession } from "@fitretro/domain";

async function seedBeendet(userId: string, minutenHer: number, grund: "manual" | "auto" = "manual"): Promise<string> {
  const id = crypto.randomUUID();
  const ende = new Date(Date.now() - minutenHer * 60_000).toISOString();
  const { error } = await serviceClient().from("workout_sessions").insert({
    id, studio_id: studioA, user_id: userId,
    started_at: new Date(Date.now() - (minutenHer + 60) * 60_000).toISOString(),
    completed_at: ende, completed_reason: grund, paused_seconds: 120,
  });
  if (error) throw error;
  return id;
}

describe("reopenSession", () => {
  it("oeffnet eine vor 10 Minuten beendete Einheit, ein zweiter Aufruf ebenso", async () => {
    const client = await userClient(memberAEmail);
    const sessionId = await seedBeendet(memberAId, 10);

    await reopenSession(client, { sessionId });
    await reopenSession(client, { sessionId });

    const { data } = await serviceClient().from("workout_sessions")
      .select("completed_at, completed_reason, paused_seconds").eq("id", sessionId).single();
    expect(data).toEqual({ completed_at: null, completed_reason: null, paused_seconds: 120 });
  });

  it("lehnt nach 31 Minuten ab", async () => {
    const client = await userClient(memberAEmail);
    const sessionId = await seedBeendet(memberAId, 31);
    await expect(reopenSession(client, { sessionId }))
      .rejects.toMatchObject({ code: "conflict", message: "Zu spät zum Fortsetzen." });
  });

  it("lehnt eine selbsttaetig beendete Einheit ab", async () => {
    const client = await userClient(memberAEmail);
    const sessionId = await seedBeendet(memberAId, 5, "auto");
    await expect(reopenSession(client, { sessionId })).rejects.toMatchObject({ code: "conflict" });
  });

  it("findet die Einheit eines anderen Mitglieds nicht", async () => {
    const client = await userClient(memberAEmail);
    const fremd = await seedBeendet(memberA2Id, 5);
    await expect(reopenSession(client, { sessionId: fremd })).rejects.toMatchObject({ code: "not_found" });
  });

  it("zweiter Abschluss setzt neues Ende und neue Pausensumme", async () => {
    const client = await userClient(memberAEmail);
    const sessionId = await seedBeendet(memberAId, 10);

    await reopenSession(client, { sessionId });
    const zweiter = await completeSession(client, { sessionId, pausedSeconds: 1320 });

    expect(Date.now() - Date.parse(zweiter.completedAt)).toBeLessThan(60_000);
    const { sessions } = await getSessions(client);
    expect(sessions.find((s) => s.id === sessionId)?.pausedSeconds).toBe(1320);
  });
});
```

**Hinweis:** Der letzte Test braucht `pausedSeconds` in `getSessions`. Er wird erst nach Task 3 grün. Bis dahin markiert `it.skip` ihn **nicht**: Task 3 folgt direkt, und der Test bleibt rot bis dahin. Gibt `getSessions` eine andere Signatur als `(client)` (`grep -n "export async function getSessions" packages/domain/src/sessions.ts`), den Aufruf entsprechend anpassen.

- [ ] **Step 6: Run, expect PASS (bis auf den letzten Integrationstest)**

Run:
- `cd packages/domain && npx vitest run src/workout.test.ts`
- `pnpm test:integration tests/integration/domain-reopen-session.test.ts`

Expected: Unit alle PASS. Integration 4 PASS und 1 FAIL („zweiter Abschluss“, `pausedSeconds` undefined).

- [ ] **Step 7: Commit**

```bash
git add packages/domain/src/workout.ts packages/domain/src/workout.test.ts packages/domain/src/index.ts \
  "apps/web/app/api/v1/workout-sessions/[sessionId]/reopen/route.ts" tests/integration/domain-reopen-session.test.ts
git commit -m "feat(training): reopen oeffnet eine von Hand beendete Einheit 30 min lang wieder"
```

---

### Task 3: `pausedSeconds` im Verlauf, Vorschläge nach dem zweiten Abschluss

**Files:**
- Modify: `packages/domain/src/sessions.ts`, `SessionSummary` (~167), `SessionRow` (~191), Select (~282), Mapping (~395)
- Test: `packages/domain/src/abschluss.test.ts`, `tests/integration/domain-reopen-session.test.ts` (aus Task 2)

**Interfaces:**
- Produces: `SessionSummary.pausedSeconds: number`

- [ ] **Step 1: Failing test, Vorschläge**

In `packages/domain/src/abschluss.test.ts` im `describe("ausGespeichertenZeilen")`:

```ts
  // Training fortsetzen (Testnotiz 14.10., 18:45 #3/#4): nach dem zweiten
  // Abschluss liegen zwei Generationen Vorschlaege im Fenster. Es gilt die
  // des zweiten Abschlusses -- sie ist die aelteste AB completed_at.
  it("nimmt nach einem zweiten Abschluss dessen Vorschlag, nicht den des ersten", () => {
    const zweiterAbschluss = "2026-09-08T18:08:00.000Z";
    const vorschlaege = ausGespeichertenZeilen(
      [paare[0]!],
      [
        zeile({ created_at: "2026-09-08T18:00:01.000Z", result_load: 82.5 }),
        zeile({ created_at: "2026-09-08T18:08:01.000Z", result_load: 85 }),
      ],
      zweiterAbschluss,
      einheiten,
    );

    expect(vorschlaege[0]?.resultLoad).toBe(85);
  });
```

Dieser Test belegt bestehendes Verhalten. Er sollte direkt PASS sein; das ist hier gewollt, denn er sichert die Annahme der Spec ab. Ist er FAIL, die Auswahl in `ausGespeichertenZeilen` so ändern, dass die älteste Zeile **ab** `completedAt` gewinnt. Prüfe vorher, ob das Feld im Ergebnis `resultLoad` heißt (`grep -n "resultLoad" packages/domain/src/abschluss.ts`).

- [ ] **Step 2: Run**

Run: `cd packages/domain && npx vitest run src/abschluss.test.ts`
Expected: PASS (siehe oben).

- [ ] **Step 3: `pausedSeconds` in `sessions.ts`**

- `SessionSummary` bekommt nach `completedReason`:
  ```ts
  /** Summe der Pausen in Sekunden (0 bei Einheiten von vor 0053). Home zieht sie von der Dauer ab. */
  pausedSeconds: number;
  ```
- `SessionRow` (~191) bekommt `paused_seconds: number;`.
- Der Select (~282) wird `"id, started_at, completed_at, completed_reason, paused_seconds"`.
- Im zurückgegebenen Objekt (~395) nach `completedReason,`: `pausedSeconds: session.paused_seconds ?? 0,`.

- [ ] **Step 4: Run, expect PASS**

Run:
- `cd packages/domain && npx vitest run && npx tsc --noEmit -p . 2>&1 | grep -v sticker`
- `pnpm test:integration tests/integration/domain-reopen-session.test.ts tests/integration/domain-sessions.test.ts`

Expected:
- Vitest PASS, bis auf `sticker.test.ts`. Dort fehlen lokal Pakete; das war schon vorher so und ist nicht zu beheben.
- tsc ohne neue Fehler.
- Integration komplett PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/domain/src/sessions.ts packages/domain/src/abschluss.test.ts
git commit -m "feat(training): Verlauf liefert die Pausensumme; Vorschlag nach zweitem Abschluss belegt"
```

---

### Task 4: App – Dauer auf Home ohne Pausen

**Files:**
- Modify: `apps/ios-member/FitnessMember/Networking/DTOs/SessionSummary.swift:89-96`
- Modify: `apps/ios-member/FitnessMember/Verlauf/HomeZeilen.swift`, `dauerMinuten` (~47)
- Test: `apps/ios-member/FitnessMemberTests/HomeZeilenTests.swift`, `apps/ios-member/FitnessMemberTests/DTOTests.swift`

**Interfaces:**
- Produces: `SessionSummary.pausedSeconds: Int?` (`var … = nil`, damit der Memberwise-Init kompatibel bleibt)

- [ ] **Step 1: Failing tests**

In `HomeZeilenTests.swift` die Hilfsfunktion `einheit(...)` um `pausedSeconds: Int? = nil` erweitern und an `SessionSummary(...)` als letztes Argument `pausedSeconds: pausedSeconds` übergeben. Dann:

```swift
    /// Training fortsetzen (Testnotiz 14.10., 18:45 #3/#4): die Pausen,
    /// darunter die Luecke bis zum Fortsetzen, zaehlen nicht zur Dauer.
    @Test func dieDauerZaehltDiePausenNicht() {
        // 16:04 bis 16:51 sind 47 min, davon 12 min Pause.
        #expect(HomeZeilen.dauerText(einheit(pausedSeconds: 720)) == "35 min")
    }

    @Test func ohnePausensummeBleibtDieDauer() {
        #expect(HomeZeilen.dauerText(einheit(pausedSeconds: nil)) == "47 min")
    }
```

In `DTOTests.swift` (dem Muster dort folgen):

```swift
    @Test func sessionSummaryLiestDiePausensumme() throws {
        let json = """
        {"id":"s1","startedAt":"2026-10-14T17:47:00Z","completedAt":"2026-10-14T18:52:00Z",
         "completedReason":"manual","machineCount":0,"setCount":0,"blocks":[],"pausedSeconds":1080}
        """
        let summary = try JSONDecoder().decode(SessionSummary.self, from: Data(json.utf8))
        #expect(summary.pausedSeconds == 1080)
    }
```

- [ ] **Step 2: Run, expect FAIL (Compilerfehler, Feld fehlt)**

Run: Swift-Tests mit `-only-testing:FitnessMemberTests/HomeZeilenTests -only-testing:FitnessMemberTests/DTOTests`

- [ ] **Step 3: Implementation**

`SessionSummary.swift` nach `let blocks: [Block]`:

```swift
    /// Summe der Pausen in Sekunden (Testnotiz 14.10., 18:45 #3/#4). Fehlt
    /// in einem Cache von vor dieser Fassung und bei einem alten Server.
    var pausedSeconds: Int? = nil
```

`HomeZeilen.dauerMinuten`:

```swift
    private static func dauerMinuten(_ session: SessionSummary) -> Int? {
        guard let start = Zeitpunkt.parse(session.startedAt),
              let ende = gueltigesEnde(session)
        else { return nil }

        // Ohne Pausen (Testnotiz 14.10., 18:45 #3/#4): auch die Luecke bis
        // zum Fortsetzen ist eine.
        let pause = TimeInterval(session.pausedSeconds ?? 0)
        return Int((max(0, ende.timeIntervalSince(start) - pause) / 60).rounded())
    }
```

- [ ] **Step 4: Run, expect PASS**

Gleicher Befehl. Expected: TEST SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add apps/ios-member/FitnessMember/Networking/DTOs/SessionSummary.swift apps/ios-member/FitnessMember/Verlauf/HomeZeilen.swift \
  apps/ios-member/FitnessMemberTests/HomeZeilenTests.swift apps/ios-member/FitnessMemberTests/DTOTests.swift
git commit -m "feat(home): Dauer eines Trainings ohne Pausen"
```

---

### Task 5: App – Pausensumme beim Beenden senden

**Files:**
- Modify: `apps/ios-member/FitnessMember/Workout/LokaleSession.swift`, nach `trainiert(bis:)` (~169)
- Modify: `apps/ios-member/FitnessMember/Workout/GeraetLoading.swift:15`
- Modify: `apps/ios-member/FitnessMember/Networking/APIClient.swift:90-92`
- Modify: `apps/ios-member/FitnessMember/Workout/WorkoutSessionStore+Ortswechsel.swift`
- Modify: `apps/ios-member/FitnessMember/Workout/Trainingszusammenfassung.swift:36-58`
- Modify: `apps/ios-member/FitnessMember/Screens/Training/TrainingAbschlussView.swift:125`
- Test: `apps/ios-member/FitnessMemberTests/LokaleSessionTests.swift`, `apps/ios-member/FitnessMemberTests/OrtswechselBeendenTests.swift`, Fake in `apps/ios-member/FitnessMemberTests/GeraetModelTests.swift:1518`

**Interfaces:**
- Produces:
  - `LokaleSession.pausenSekunden(jetzt: Date) -> Int`
  - `GeraetLoading.completeSession(sessionId: UUID, pausedSeconds: Int) async throws(APIError) -> CompletedSession`
  - `WorkoutSessionStore.Ortswechselende.abgeschlossen(UUID, pausedSeconds: Int)`
  - `Trainingszusammenfassung.pausedSeconds: Int`

- [ ] **Step 1: Failing tests**

`LokaleSessionTests.swift`:

```swift
    /// Was beim Beenden an den Server geht (Testnotiz 14.10., 18:45 #3/#4):
    /// abgeschlossene Pausen plus eine noch laufende, in ganzen Sekunden.
    @Test func pausenSekundenZaehltDieLaufendePauseMit() {
        let start = Date(timeIntervalSince1970: 0)
        var session = LokaleSession(id: UUID(), startedAt: start, bloecke: [])
        session.pausieren(jetzt: start.addingTimeInterval(60))
        session.fortsetzen(jetzt: start.addingTimeInterval(160))       // 100 s
        session.pausieren(jetzt: start.addingTimeInterval(300))
        #expect(session.pausenSekunden(jetzt: start.addingTimeInterval(350.6)) == 151)  // 100 + 50,6
    }
```

`OrtswechselBeendenTests.swift`:
- Im `MeldeLoader` die Signatur auf `completeSession(sessionId: UUID, pausedSeconds: Int)` ändern und `pausedSeconds` in `private(set) var pausen: [Int] = []` mitschreiben.
- Die bestehenden Erwartungen auf `.abgeschlossen(satz.sessionId, pausedSeconds: 0)` bzw. `.abgeschlossen(UUID(), pausedSeconds: 0)` umstellen.
- Neu:

```swift
    @Test func meldenSchicktDiePausensumme() async {
        let loader = MeldeLoader()
        await WorkoutSessionStore.melden(.abgeschlossen(UUID(), pausedSeconds: 90), loader: loader)
        #expect(await loader.pausen == [90])
    }
```

In `GeraetModelTests.swift:1518` die Fake-Signatur ebenso auf `completeSession(sessionId: UUID, pausedSeconds: Int)` ändern.

- [ ] **Step 2: Run, expect FAIL (Compilerfehler)**

Run: `-only-testing:FitnessMemberTests/LokaleSessionTests -only-testing:FitnessMemberTests/OrtswechselBeendenTests`

- [ ] **Step 3: Implementation**

`LokaleSession.swift` nach `trainiert(bis:)`:

```swift
    /// Die Pausensumme fuer den Abschluss (Testnotiz 14.10., 18:45 #3/#4):
    /// abgeschlossene Pausen plus eine laufende bis `jetzt`. Der Server
    /// rechnet die Dauer bis zum Tipp auf "Beenden", deshalb zaehlt eine
    /// offene Pause bis dahin mit.
    func pausenSekunden(jetzt: Date) -> Int {
        let laufend = pausiertSeit.map { max(0, jetzt.timeIntervalSince($0)) } ?? 0
        return Int((pausenDauer + laufend).rounded(.down))
    }
```

`GeraetLoading.swift:15`:

```swift
    func completeSession(sessionId: UUID, pausedSeconds: Int) async throws(APIError) -> CompletedSession
```

`APIClient.swift:90`:

```swift
    func completeSession(sessionId: UUID, pausedSeconds: Int) async throws(APIError) -> CompletedSession {
        try await send("workout-sessions/\(sessionId.uuidString)/complete", method: "POST",
                       body: ["pausedSeconds": pausedSeconds])
    }
```

Danach `postNoBody` prüfen (`grep -n "postNoBody(" apps/ios-member/FitnessMember/Networking/APIClient.swift`). Gibt es keinen Aufrufer mehr, `postNoBody` entfernen und den Kommentar an `sendNoBody` anpassen: „postNoBody(_:) bleibt für completeSession“ stimmt dann nicht mehr. Ist `sendNoBody` danach unbenutzt, ebenfalls entfernen.

`WorkoutSessionStore+Ortswechsel.swift`:

```swift
    enum Ortswechselende: Equatable {
        case verworfen
        case abgeschlossen(UUID, pausedSeconds: Int)
    }
```

In `beendenFuerOrtswechsel()` vor `beenden()`: `let pausen = session.pausenSekunden(jetzt: Date())`, Rückgabe `.abgeschlossen(session.id, pausedSeconds: pausen)`.

In `melden`:

```swift
        guard case .abgeschlossen(let id, let pausen) = ende else { return }
        _ = try? await loader.completeSession(sessionId: id, pausedSeconds: pausen)
```

`Trainingszusammenfassung.swift`:
- Feld `let pausedSeconds: Int` nach `bloecke`.
- In `init?(_ session: LokaleSession)` ergänzen:
  ```swift
          // Fuer den Abschluss am Server (Testnotiz 14.10., 18:45 #3/#4): bis
          // zum Tipp auf "Beenden", nicht bis zum letzten Satz -- der Server
          // setzt completed_at auf jetzt.
          pausedSeconds = session.pausenSekunden(jetzt: Date())
  ```
- Steht dort ein expliziter `init(von:bis:...)` für Tests (`grep -n "init(" apps/ios-member/FitnessMember/Workout/Trainingszusammenfassung.swift`), ihm `pausedSeconds: Int = 0` als letzten Parameter mit Vorgabe geben.

`TrainingAbschlussView.swift:125`:

```swift
                vorschlaege = try await apiClient.completeSession(
                    sessionId: sessionId, pausedSeconds: zusammenfassung.pausedSeconds).vorschlaege
```

- [ ] **Step 4: Run the full Swift suite, expect PASS**

Run: alle Swift-Tests (ohne `-only-testing`). Expected: TEST SUCCEEDED. Weitere Aufrufer der alten Signatur meldet der Compiler; sie werden auf dieselbe Weise angepasst.

- [ ] **Step 5: Commit**

```bash
git add apps/ios-member
git commit -m "feat(training): Pausensumme geht mit dem Abschluss an den Server"
```

---

### Task 6: App – Ablage und Wiederaufnehmen im Store

**Files:**
- Modify: `apps/ios-member/FitnessMember/Workout/SessionFileStore.swift`
- Modify: `apps/ios-member/FitnessMember/Workout/WorkoutSessionStore.swift` (`init`, `beenden` ~218, `reset`)
- Modify: `apps/ios-member/FitnessMember/Workout/WorkoutSessionStore+Ortswechsel.swift`, `beendenFuerOrtswechsel`
- Test: `apps/ios-member/FitnessMemberTests/WiederaufnehmenTests.swift` (neu, danach `xcodegen generate`)

**Interfaces:**
- Consumes: `LokaleSession` mit `pausieren`, `fortsetzen` und `hatSaetze`.
- Produces:
  - `struct BeendeteSession: Codable, Equatable { let session: LokaleSession; let beendetAm: Date }`
  - `SessionFileStore.loadBeendet() -> BeendeteSession?` und `saveBeendet(_: BeendeteSession?)`
  - `WorkoutSessionStore.beenden(jetzt: Date = Date(), ablegen: Bool = true) -> UUID?`
  - `WorkoutSessionStore.zuletztBeendet: BeendeteSession?` (lesbar)
  - `WorkoutSessionStore.kannWiederaufnehmen(sessionId: String, jetzt: Date = Date()) -> Bool`
  - `WorkoutSessionStore.wiederaufnehmen(jetzt: Date = Date()) -> LokaleSession?`
  - `WorkoutSessionStore.ablageVerwerfen()`
  - `WorkoutSessionStore.wiederaufnahmeFenster: TimeInterval = 30 * 60` (static)

- [ ] **Step 1: Failing tests**

`apps/ios-member/FitnessMemberTests/WiederaufnehmenTests.swift`:

```swift
import Foundation
import Testing
@testable import FitnessMember

/// Training fortsetzen (Testnotiz 14.10., 18:45 #3/#4): die zuletzt
/// beendete Einheit bleibt 30 Minuten lokal, und die Luecke zaehlt als Pause.
@MainActor
struct WiederaufnehmenTests {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func store(_ verzeichnis: URL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)) -> WorkoutSessionStore {
        WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))
    }

    /// Ein Training mit einem Satz bei t0+10 min, beendet bei t0+20 min.
    private func beendet(_ sessions: WorkoutSessionStore) -> UUID {
        sessions.trainingStarten(jetzt: t0)
        _ = sessions.satzSichern(station: .testGeraet("m1"), exerciseId: "e1",
                                  einheiten: .kilogrammWiederholungen, load: 40, volume: 10,
                                  problemFlag: false, problemReason: nil,
                                  jetzt: t0.addingTimeInterval(600))
        return sessions.beenden(jetzt: t0.addingTimeInterval(1200))!
    }

    @Test func beendenLegtDieEinheitAb() {
        let sessions = store()
        let id = beendet(sessions)
        #expect(sessions.aktiveSession(jetzt: t0.addingTimeInterval(1201)) == nil)
        #expect(sessions.zuletztBeendet?.session.id == id)
        #expect(sessions.zuletztBeendet?.beendetAm == t0.addingTimeInterval(1200))
    }

    @Test func ohneSatzWirdNichtAbgelegt() {
        let sessions = store()
        sessions.trainingStarten(jetzt: t0)
        sessions.beenden(jetzt: t0.addingTimeInterval(60))
        #expect(sessions.zuletztBeendet == nil)
    }

    @Test func dasFensterIstDreissigMinuten() {
        let sessions = store()
        let id = beendet(sessions).uuidString
        #expect(sessions.kannWiederaufnehmen(sessionId: id, jetzt: t0.addingTimeInterval(1200 + 1800)))
        #expect(!sessions.kannWiederaufnehmen(sessionId: id, jetzt: t0.addingTimeInterval(1200 + 1801)))
        #expect(!sessions.kannWiederaufnehmen(sessionId: UUID().uuidString, jetzt: t0.addingTimeInterval(1300)))
    }

    @Test func dieLueckeZaehltAlsPause() {
        let sessions = store()
        let id = beendet(sessions)
        let wieder = sessions.wiederaufnehmen(jetzt: t0.addingTimeInterval(1200 + 1080))  // 18 min spaeter
        #expect(wieder?.id == id)
        #expect(wieder?.startedAt == t0)
        #expect(wieder?.pausenDauer == 1080)
        #expect(sessions.aktiveSession(jetzt: t0.addingTimeInterval(2300))?.id == id)
        #expect(sessions.zuletztBeendet == nil)
    }

    /// Review Focus 1: ein zweiter Aufruf bucht die Luecke nicht doppelt.
    @Test func einZweitesWiederaufnehmenAendertNichts() {
        let sessions = store()
        _ = beendet(sessions)
        _ = sessions.wiederaufnehmen(jetzt: t0.addingTimeInterval(1500))
        #expect(sessions.wiederaufnehmen(jetzt: t0.addingTimeInterval(1600)) == nil)
        #expect(sessions.aktiveSession(jetzt: t0.addingTimeInterval(1600))?.pausenDauer == 300)
    }

    /// Review Focus 2: beendet waehrend einer Pause.
    @Test func eineOffenePauseWirdBisZumBeendenAbgeschlossen() {
        let sessions = store()
        sessions.trainingStarten(jetzt: t0)
        _ = sessions.satzSichern(station: .testGeraet("m1"), exerciseId: "e1",
                                  einheiten: .kilogrammWiederholungen, load: 40, volume: 10,
                                  problemFlag: false, problemReason: nil,
                                  jetzt: t0.addingTimeInterval(600))
        sessions.pausieren(jetzt: t0.addingTimeInterval(900))
        sessions.beenden(jetzt: t0.addingTimeInterval(1200))                 // 300 s Pause offen
        let wieder = sessions.wiederaufnehmen(jetzt: t0.addingTimeInterval(1500))  // + 300 s Luecke
        #expect(wieder?.istPausiert == false)
        #expect(wieder?.pausenDauer == 600)
    }

    /// Review Focus 3: ein neues Training sperrt das Fortsetzen.
    @Test func einLaufendesTrainingSperrt() {
        let sessions = store()
        let id = beendet(sessions).uuidString
        sessions.trainingStarten(jetzt: t0.addingTimeInterval(1300))
        #expect(!sessions.kannWiederaufnehmen(sessionId: id, jetzt: t0.addingTimeInterval(1310)))
        #expect(sessions.wiederaufnehmen(jetzt: t0.addingTimeInterval(1310)) == nil)
    }

    @Test func ortswechselLegtNichtsAb() {
        let sessions = store()
        sessions.trainingStarten(jetzt: t0)
        _ = sessions.satzSichern(station: .testGeraet("m1"), exerciseId: "e1",
                                  einheiten: .kilogrammWiederholungen, load: 40, volume: 10,
                                  problemFlag: false, problemReason: nil)
        _ = sessions.beendenFuerOrtswechsel()
        #expect(sessions.zuletztBeendet == nil)
    }

    @Test func abmeldenLoeschtDieAblage() {
        let sessions = store()
        _ = beendet(sessions)
        sessions.reset()
        #expect(sessions.zuletztBeendet == nil)
    }

    @Test func dieAblageUeberstehtEinenNeustart() {
        let verzeichnis = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let id = beendet(store(verzeichnis))
        #expect(store(verzeichnis).zuletztBeendet?.session.id == id)
    }
}
```

**Hinweis:**
- Ob `satzSichern` einen Parameter `jetzt:` hat und wie `trainingStarten` aufgerufen wird, prüfst du mit `grep -n "func satzSichern" -A14 apps/ios-member/FitnessMember/Workout/WorkoutSessionStore.swift`.
- Fehlt `jetzt:`, nimmt der Test die Echtzeit. Dann legst du `t0` auf `Date()` und rechnest relativ dazu.
- Die Erwartungen bleiben gleich.

Danach: `cd apps/ios-member && xcodegen generate`.

- [ ] **Step 2: Run, expect FAIL (Compilerfehler)**

Run: `-only-testing:FitnessMemberTests/WiederaufnehmenTests`

- [ ] **Step 3: Implementation**

`SessionFileStore.swift`:
- Eine zweite URL `beendetURL = directory.appendingPathComponent("zuletzt-beendet.json")`, in `init` gesetzt.
- Dazu:

```swift
/// Die zuletzt beendete Einheit, 30 Minuten lang fortsetzbar (Testnotiz
/// 14.10., 18:45 #3/#4).
struct BeendeteSession: Codable, Equatable {
    let session: LokaleSession
    let beendetAm: Date
}

    func loadBeendet() -> BeendeteSession? {
        guard let data = try? Data(contentsOf: beendetURL) else { return nil }
        return try? JSONDecoder().decode(BeendeteSession.self, from: data)
    }

    func saveBeendet(_ beendet: BeendeteSession?) {
        guard let beendet else {
            try? FileManager.default.removeItem(at: beendetURL)
            return
        }
        guard let data = try? JSONEncoder().encode(beendet) else { return }
        try? data.write(to: beendetURL, options: .atomic)
    }
```

`WorkoutSessionStore.swift`:

```swift
    /// Wie lange "Fortsetzen" angeboten wird (Testnotiz 14.10., 18:45 #3).
    /// Der Server prueft dasselbe Fenster (REOPEN_FENSTER_MS).
    static let wiederaufnahmeFenster: TimeInterval = 30 * 60

    private(set) var zuletztBeendet: BeendeteSession?
```

In `init` nach `gespeicherteSession = fileStore.load()`: `zuletztBeendet = fileStore.loadBeendet()`.

`beenden` ersetzen:

```swift
    /// Gibt die Kennung zurueck, damit der Aufrufer POST .../complete
    /// schicken kann -- oder, ohne Satz, gar nichts (TrainingRootView.beenden
    /// verwirft dann).
    ///
    /// `ablegen`: die Einheit bleibt als `zuletztBeendet` 30 Minuten
    /// fortsetzbar (Testnotiz 14.10., 18:45 #3/#4) -- nur mit Satz, und nicht
    /// beim Ortswechsel (dort beginnt ein neues Training).
    @discardableResult
    func beenden(jetzt: Date = Date(), ablegen: Bool = true) -> UUID? {
        let session = gespeicherteSession
        if ablegen, let session, session.hatSaetze {
            zuletztBeendet = BeendeteSession(session: session, beendetAm: jetzt)
            fileStore.saveBeendet(zuletztBeendet)
        }
        gespeicherteSession = nil
        fileStore.save(nil)
        return session?.id
    }

    func kannWiederaufnehmen(sessionId: String, jetzt: Date = Date()) -> Bool {
        guard let beendet = zuletztBeendet,
              beendet.session.id.uuidString.lowercased() == sessionId.lowercased(),
              jetzt.timeIntervalSince(beendet.beendetAm) <= Self.wiederaufnahmeFenster,
              aktiveSession(jetzt: jetzt) == nil
        else { return false }
        return true
    }

    /// Macht die zuletzt beendete Einheit wieder zur laufenden -- erst
    /// NACH einem erfolgreichen reopen am Server rufen. Eine beim Beenden
    /// offene Pause endet beim Beenden; die Luecke bis jetzt kommt als
    /// Pause dazu. Nicht `fortsetzen`: das heisst hier "Pause beenden".
    @discardableResult
    func wiederaufnehmen(jetzt: Date = Date()) -> LokaleSession? {
        guard let beendet = zuletztBeendet,
              kannWiederaufnehmen(sessionId: beendet.session.id.uuidString, jetzt: jetzt)
        else { return nil }
        var session = beendet.session
        session.fortsetzen(jetzt: beendet.beendetAm)
        session.pausenDauer += max(0, jetzt.timeIntervalSince(beendet.beendetAm))
        gespeicherteSession = session
        fileStore.save(session)
        ablageVerwerfen()
        return session
    }

    /// Nach "zu spaet" vom Server (oder beim Abmelden): kein Button mehr.
    func ablageVerwerfen() {
        zuletztBeendet = nil
        fileStore.saveBeendet(nil)
    }
```

`reset()`:

```swift
    func reset() {
        beenden(ablegen: false)
        ablageVerwerfen()
    }
```

`WorkoutSessionStore+Ortswechsel.swift`: Beide `beenden()`-Aufrufe in `beendenFuerOrtswechsel()` werden zu `beenden(ablegen: false)`.

**Wichtig:** Der UUID-Vergleich läuft kleingeschrieben. Der Server liefert IDs in Kleinbuchstaben, `UUID.uuidString` ist groß.

- [ ] **Step 4: Run, expect PASS; dann die volle Suite**

Run: `-only-testing:FitnessMemberTests/WiederaufnehmenTests`, danach alle Swift-Tests.
Expected: TEST SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add apps/ios-member
git commit -m "feat(training): zuletzt beendete Einheit 30 min fortsetzbar, Luecke als Pause"
```

---

### Task 7: App – Play-Button, `reopen` und Tab-Wechsel

**Files:**
- Modify: `apps/ios-member/FitnessMember/Networking/APIClient.swift`, neben `completeSession`
- Create: `apps/ios-member/FitnessMember/Verlauf/Fortsetzbarkeit.swift`
- Modify: `apps/ios-member/FitnessMember/Screens/Home/SessionDetailView.swift`
- Modify: `apps/ios-member/FitnessMember/Screens/Home/HomeRootView.swift:152`
- Modify: `apps/ios-member/FitnessMember/Screens/Training/TrainingRootView.swift`
- Test: `apps/ios-member/FitnessMemberTests/FortsetzbarkeitTests.swift` (neu)

**Interfaces:**
- Consumes: `WorkoutSessionStore.kannWiederaufnehmen`, `wiederaufnehmen` und `ablageVerwerfen` (Task 6); `Trainingskarte.teile` (aufsteigend).
- Produces:
  - `APIClient.reopenSession(sessionId: String) async throws(APIError)`
  - `enum Fortsetzbarkeit { static func fortsetzbarerTeil(_ karte: Trainingskarte, darf: (String) -> Bool) -> String? }`
  - `enum Fortsetzbarkeit { static func folgeNachFehler(_ fehler: APIError) -> (text: String, ablageVerwerfen: Bool) }`
  - `SessionDetailView(sessionId:apiClient:beiFortgesetzt:)`

- [ ] **Step 1: Failing tests**

`apps/ios-member/FitnessMemberTests/FortsetzbarkeitTests.swift`:

```swift
import Foundation
import Testing
@testable import FitnessMember

struct FortsetzbarkeitTests {
    private func teil(_ id: String, start: String) -> SessionSummary {
        SessionSummary(id: id, startedAt: start, completedAt: nil, completedReason: "manual",
                       machineCount: 0, setCount: 0, blocks: [])
    }

    /// Review Focus 5: eine zusammengelegte Karte setzt ihren JUENGSTEN Teil fort.
    @Test func nurDerJuengsteTeilZaehlt() {
        let karte = Trainingskarte(teile: [teil("alt", start: "2026-10-14T17:00:00Z"),
                                           teil("neu", start: "2026-10-14T17:47:00Z")])
        #expect(Fortsetzbarkeit.fortsetzbarerTeil(karte) { $0 == "neu" } == "neu")
        #expect(Fortsetzbarkeit.fortsetzbarerTeil(karte) { $0 == "alt" } == nil)
    }

    @Test func ohneErlaubnisKeinButton() {
        let karte = Trainingskarte(teile: [teil("s1", start: "2026-10-14T17:47:00Z")])
        #expect(Fortsetzbarkeit.fortsetzbarerTeil(karte) { _ in false } == nil)
    }

    /// Review Focus 4: bei jedem conflict verschwindet der Button, die
    /// Meldung kommt vom Server.
    @Test func conflictVerwirftDieAblage() {
        let folge = Fortsetzbarkeit.folgeNachFehler(.conflict(message: "Zu spät zum Fortsetzen."))
        #expect(folge.text == "Zu spät zum Fortsetzen.")
        #expect(folge.ablageVerwerfen)
    }

    @Test func ohneNetzBleibtDieAblage() {
        let folge = Fortsetzbarkeit.folgeNachFehler(.offline)
        #expect(folge.text == "Ohne Verbindung geht Fortsetzen nicht.")
        #expect(!folge.ablageVerwerfen)
    }
}
```

Hat `Trainingskarte` keinen zugänglichen Memberwise-Init (`grep -n "struct Trainingskarte" -A3 apps/ios-member/FitnessMember/Verlauf/HomeZeilen.swift`), stattdessen `HomeZeilen.karte(fuer: "neu", in: [teil("alt",...), teil("neu",...)])!` verwenden. Die zwei Teile liegen weniger als eine Stunde auseinander, `trainingskarten` legt sie also zusammen. Dann bekommt `teil(...)` ein `completedAt` von 30 min nach `start`.

Danach: `cd apps/ios-member && xcodegen generate`.

- [ ] **Step 2: Run, expect FAIL (Compilerfehler)**

Run: `-only-testing:FitnessMemberTests/FortsetzbarkeitTests`

- [ ] **Step 3: `Fortsetzbarkeit` und `reopenSession`**

`apps/ios-member/FitnessMember/Verlauf/Fortsetzbarkeit.swift`:

```swift
import Foundation

/// Wann die Zusammenfassung "Fortsetzen" anbietet und was ein Fehler danach
/// bedeutet (Testnotiz 14.10., 18:45 #3/#4) -- als reine Regeln, damit sie
/// ohne View pruefbar sind.
enum Fortsetzbarkeit {
    /// Die Id des Teils, den der Play-Button fortsetzt, oder nil. Eine
    /// zusammengelegte Karte setzt nur ihren juengsten Teil fort: nur der
    /// wurde zuletzt beendet. `darf` ist `WorkoutSessionStore.kannWiederaufnehmen`.
    static func fortsetzbarerTeil(_ karte: Trainingskarte, darf: (String) -> Bool) -> String? {
        guard let juengster = karte.teile.last, darf(juengster.id) else { return nil }
        return juengster.id
    }

    /// Jeder conflict ("zu spaet", "automatisch beendet") heisst: der Server
    /// oeffnet diese Einheit nie mehr -- die Ablage geht, der Button auch.
    static func folgeNachFehler(_ fehler: APIError) -> (text: String, ablageVerwerfen: Bool) {
        switch fehler {
        case .offline: ("Ohne Verbindung geht Fortsetzen nicht.", false)
        case .conflict(let message): (message, true)
        default: (fehler.servertext, false)
        }
    }
}
```

`APIClient.swift` nach `completeSession`:

```swift
    /// Oeffnet eine von Hand beendete Einheit wieder (Testnotiz 14.10.,
    /// 18:45 #3/#4). Die Antwort traegt nichts, was die App braucht.
    func reopenSession(sessionId: String) async throws(APIError) {
        struct Antwort: Decodable { let id: String }
        let _: Antwort = try await postNoBody("workout-sessions/\(sessionId)/reopen")
    }
```

Hat Task 5 `postNoBody`/`sendNoBody` entfernt, beide hier wieder einsetzen und den Kommentar auf „für reopenSession“ anpassen.

- [ ] **Step 4: Run, expect PASS**

Run: `-only-testing:FitnessMemberTests/FortsetzbarkeitTests`

- [ ] **Step 5: Button in `SessionDetailView`**

Neue Eigenschaften:

```swift
    /// Nach erfolgreichem Fortsetzen: Home-Pfad leeren, auf den Training-Tab.
    var beiFortgesetzt: () -> Void = {}

    @Environment(WorkoutSessionStore.self) private var sessions
    @State private var fortsetzenLaeuft = false
    @State private var fortsetzenFehler: String?
```

An den `ScrollView` nach `.navigationBarTitleDisplayMode(.inline)`:

```swift
        // Play oben rechts (Testnotiz 14.10., 18:45 #4). TimelineView prueft
        // jede Minute neu, damit der Button nach 30 min auch auf einer
        // offenen Seite verschwindet.
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                TimelineView(.everyMinute) { kontext in
                    if let karte,
                       let teilId = Fortsetzbarkeit.fortsetzbarerTeil(karte, darf: {
                           sessions.kannWiederaufnehmen(sessionId: $0, jetzt: kontext.date)
                       }) {
                        Button { Task { await fortsetzen(teilId) } } label: {
                            if fortsetzenLaeuft { ProgressView() } else { Image(systemName: "play.fill") }
                        }
                        .disabled(fortsetzenLaeuft)
                        .accessibilityLabel("Training fortsetzen")
                        .testnotizElement("session.fortsetzen", typ: "Button")
                    }
                }
            }
        }
```

Im `VStack` des Inhalts nach `if let loeschFehler { … }`:

```swift
                    if let fortsetzenFehler {
                        InlineBanner(tone: .danger, message: fortsetzenFehler)
                    }
```

Methode:

```swift
    /// Erst der Server, dann lokal: ohne reopen haengten neue Saetze an
    /// einer beendeten Einheit, und das zweite Beenden aenderte nichts.
    private func fortsetzen(_ teilId: String) async {
        fortsetzenLaeuft = true
        defer { fortsetzenLaeuft = false }
        do throws(APIError) {
            try await apiClient.reopenSession(sessionId: teilId)
            sessions.wiederaufnehmen()
            fortsetzenFehler = nil
            beiFortgesetzt()
        } catch {
            let folge = Fortsetzbarkeit.folgeNachFehler(error)
            fortsetzenFehler = folge.text
            if folge.ablageVerwerfen { sessions.ablageVerwerfen() }
        }
    }
```

**Hinweise:**
- `testnotizElement` gibt es schon (siehe `GeraetView.swift`, `.testnotizElement("geraet.weitere-uebung", typ: "PrimaryButton")`).
- Ist `apiClient` dort kein `APIClient`, sondern ein Protokoll, den Aufruf über den vorhandenen Typ führen.

- [ ] **Step 6: Verdrahten**

`HomeRootView.swift:152`:

```swift
                    SessionDetailView(sessionId: id, apiClient: apiClient, beiFortgesetzt: {
                        pfad.removeAll()
                        beiTrainingZeigen()
                    })
```

`TrainingRootView.swift`: An den äußeren View (dort, wo die anderen `.onChange` hängen; `grep -n "\.onChange" apps/ios-member/FitnessMember/Screens/Training/TrainingRootView.swift`) kommt:

```swift
            // Fortsetzen (Testnotiz 14.10., 18:45 #3): wird ein Training wieder
            // aktiv, waehrend der Tab noch die alte Zusammenfassung zeigt,
            // geht es zur Wurzel -- dort steht "Training laeuft".
            .onChange(of: sessions.aktiveSession()?.id) { alt, neu in
                guard alt == nil, neu != nil, case .abschluss? = pfad.last else { return }
                pfad.removeAll()
            }
```

- [ ] **Step 7: Volle Suite und Build**

Run: alle Swift-Tests. Expected: TEST SUCCEEDED.

- [ ] **Step 8: Commit**

```bash
git add apps/ios-member
git commit -m "feat(home): Play in der Zusammenfassung setzt ein Training fort"
```

---

### Task 8: Abschluss

- [ ] **Step 1:** `cd packages/domain && npx vitest run`. Ebenso alle Swift-Tests und `pnpm test:integration`. Ergebnisse festhalten, auch bekannte Ausfälle (`sticker.test.ts`).
- [ ] **Step 2:** Diesen Plan um einen Abschnitt „## Ergebnis“ ergänzen: Testzahlen, Abweichungen vom Plan und offene Punkte. Offen sind: Migration 0053 auf Prod, Web-Deploy, Prüfung auf dem Gerät nach Spec „Auf dem Gerät“.
- [ ] **Step 3:** Commit `docs(plan): Training fortsetzen umgesetzt`. Danach Push und PR gegen `master`. **Kein Merge ohne Freigabe.**
- [ ] **Step 4: Auslieferung, nur auf Freigabe in dieser Reihenfolge**
  1. `supabase db push --linked` (Migration 0053) und `pnpm smoke:migrations`.
  2. PR mergen. Vercel baut die Web-App.
  3. App-Build aufs Gerät.
