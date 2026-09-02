# Tags als Lieferung — Umsetzungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tag-Zeilen entstehen beim Betreiber statt im Portal — der Token steht im Klartext in der Datenbank, ist für Trainer und Mitglieder unlesbar, und ein Gerätetag lernt sein Studio erst beim Scan vor dem Gerät.

**Architecture:** Der Klartext-Token zieht in `machine_tags.token`; `token_hash` bleibt unter demselben Namen als *generierte* Spalte bestehen, wodurch `bootstrap.ts`, `tag-context.ts`, `resolve_tag_fallback` und `join_studio_by_tag` wörtlich unverändert bleiben. Spaltenrechte entziehen `authenticated` auf `token` `select` und `update`. Chargen und Lieferungen kommen als zwei Betreibertabellen dazu; `machine_tags.studio_id` wird nullbar, damit die Halde in derselben Tabelle liegt und ein Token nie an zwei Orten existiert. Zwei `SECURITY DEFINER`-Funktionen geben Auskunft über einen gescannten Tag und binden ihn. Das Anlegen der Zeilen ist ein Betreiberskript, kein Bildschirm.

**Tech Stack:** PostgreSQL 17 über Supabase (SQL-Migrationen in `supabase/migrations/`), TypeScript, Next.js App Router, Vitest für Integrationstests gegen eine laufende Datenbank, Playwright für E2E, `tsx` für die CLI-Schale.

**Spec:** `docs/superpowers/specs/2026-09-01-tag-lieferung-design.md`

> **Status: gebaut und ausgeliefert (2. September 2026).** Alle acht Aufgaben stehen im Code, die Haken darunter sind gesetzt. Nachtrag zur Nummerierung: aus den drei geplanten Migrationen sind vier geworden — `0029_tag_batches_read` kam beim Abschlussreview dazu, weil `tag_batches` ohne Policy für ein *verbundenes* Studio zu grob war und die Tags-Seite die Charge nicht anzeigen konnte. `0026`–`0029` liegen auf Platte **und** im Produktivprojekt (nachgezogen am 2. September).

## Global Constraints

- **Voraussetzung: `2026-09-01-scan-beitritt-datenbank.md` ist vollständig ausgeführt.** Dieser Plan braucht den Enum `public.tag_kind`, die Spalte `machine_tags.kind` und den Constraint `machine_tags_machine_kind` aus dessen `0022`, dazu `CatalogTag.kind` aus dessen Task 4. Auf Platte muss `0025` liegen, bevor Aufgabe 3 beginnt.
- **Migrationen sind fortlaufend nummeriert und werden nie geändert.** Dieser Plan belegt `0026`, `0027` und `0028`. Eine bereits gepushte Migration wird durch eine neue korrigiert, nicht überschrieben.
- **Jede `SECURITY DEFINER`-Funktion braucht beide Zeilen** — die Lehre aus `0009`, und sie ist keine Formalie:
  ```sql
  revoke all on function public.<name>(<typen>) from public, anon, authenticated, service_role;
  grant execute on function public.<name>(<typen>) to <rolle>;
  ```
  `revoke ... from public` allein genügt auf Supabase **nicht**: `ALTER DEFAULT PRIVILEGES` gewährt `EXECUTE` zusätzlich an `anon`, `authenticated` und `service_role`.
- **Jede `SECURITY DEFINER`-Funktion setzt `set search_path = public, pg_temp`.**
- **Unbekannt, gesperrt, fremd und nicht vorhanden antworten identisch.** Über ein fremdes Studio wird nie etwas verraten, auch nicht die Sorte.
- **Das Tokenformat ist unverändert:** 22 Zeichen `base64url`, erzeugt von `createTagToken()`, geprüft von `isValidTagToken()`. `hashTagToken` bleibt im Repo — die App vergleicht offline weiter gegen Hashes.
- **Tokens erscheinen nie auf `stdout` und nie in einem Log.** Das einzige Erzeugnis, das sie im Klartext zeigt, ist die CSV-Datei für den Lieferanten.
- **Fehlercodes der Fachschicht** sind ausschließlich `validation_failed`, `unauthorized`, `not_found`, `conflict`, `internal` (`packages/domain/src/errors.ts`). Ein Objekt aus einem fremden Studio liefert `not_found`, nicht `unauthorized`.
- **PostgREST liefert höchstens 1000 Zeilen je Abfrage** (`supabase/config.toml`, `max_rows = 1000`). Jede Abfrage, die eine ganze Charge liest, muss blättern — eine Tausendercharge trifft die Grenze exakt und würde still abgeschnitten.
- **Tests laufen gegen echtes Postgres.** `pnpm test:integration` braucht `SUPABASE_URL`, `SUPABASE_ANON_KEY` und `SUPABASE_SERVICE_ROLE_KEY` in der Umgebung; `fileParallelism` ist aus. In einem frischen Worktree fehlt `.env` — vor Aufgabe 1 aus `.env.example` anlegen und mit den Werten aus `pnpm exec supabase status` füllen.
- **Nach Migrationen:** `pnpm exec supabase db reset` lokal, `pnpm exec supabase db push` gegen das verknüpfte Projekt.
- **Sprache:** Bezeichner, Kommentare und Meldungen auf Deutsch, ohne Umlaute in SQL- und Code-Kommentaren — wie im bestehenden Bestand.

## Dateiübersicht

**Neu:**

| Datei | Verantwortung |
| --- | --- |
| `tests/helpers/tags.ts` | Charge und Tag-Zeile für Tests. Liegt **über** `tests/integration/`, weil `e2e/` sie ebenfalls braucht. |
| `supabase/migrations/0026_tag_klartext.sql` | Tokenraum: Klartext, generierter Hash, Spaltenrechte |
| `supabase/migrations/0027_tag_chargen.sql` | Chargen, Lieferungen, Halde |
| `supabase/migrations/0028_tag_binden.sql` | `inspect_tag`, `bind_tag_to_machine` |
| `packages/domain/src/chargen.ts` | Betreiber-Fachschicht: Charge anlegen, CSV-Zeilen, Lieferung, Bestand |
| `scripts/tags.ts` | CLI-Schale über `chargen.ts` |
| `tests/integration/tag-klartext.test.ts` | Die Sicherheitseigenschaft aus `0026` |
| `tests/integration/tag-chargen.test.ts` | `chargen.ts` und die RLS der beiden neuen Tabellen |
| `tests/integration/tag-binden.test.ts` | Je Zeile der Antworttabelle |
| `apps/web/app/portal/[studioId]/tags/TagBinden.tsx` | Token eintippen statt Gerät auswählen |

**Geändert:** `packages/domain/package.json`, `packages/domain/src/catalog.ts`, `packages/domain/src/index.ts`, `apps/web/app/portal/actions.ts`, `apps/web/app/portal/[studioId]/tags/page.tsx`, `apps/web/app/portal/[studioId]/geraete/page.tsx`, `apps/web/app/portal/[studioId]/modelle/[modelId]/page.tsx`, `package.json` (Wurzel), neun Integrationstests, zwei E2E-Dateien.

**Gelöscht:** `apps/web/app/portal/[studioId]/TagAnlegen.tsx`, `apps/web/app/portal/[studioId]/tags/TagZuweisen.tsx`.

## Reihenfolge und warum sie so ist

Das Repo ist nach **jedem** Commit übersetzbar und grün. Das erzwingt diese Folge:

1. Der Testhelfer kommt **vor** jeder Migration und schreibt zunächst genau das, was heute gilt. Danach ist die Umstellung auf den Klartext eine Änderung an *einer* Datei statt an zwölf.
2. `createTag` fällt **vor** `0026`. Nach `0026` kann es nicht mehr laufen; fiele es danach, wäre das Repo dazwischen rot.
3. `TagZuweisen` bleibt bis Aufgabe 7 stehen, damit zwischen Aufgabe 2 und 7 kein Weg fehlt, den es nicht gäbe.

---

### Task 1: Testhelfer und Fixture-Umbau

**Files:**
- Create: `tests/helpers/tags.ts`
- Modify: `tests/integration/rls-machine-tags.test.ts`, `tests/integration/rls-machine-tags-write.test.ts`, `tests/integration/rls-machines.test.ts`, `tests/integration/domain-bootstrap.test.ts`, `tests/integration/domain-tag-context.test.ts`, `tests/integration/api-tag-context.test.ts`, `tests/integration/resolve-tag-fallback.test.ts`, `tests/integration/fallback-inhalt.test.ts`, `tests/integration/machine-tags-kind.test.ts`, `e2e/tag-fallback.spec.ts`
- Test: keine neue Datei — die bestehenden müssen unverändert grün bleiben

**Interfaces:**
- Consumes: `createTagToken`, `hashTagToken` aus `@fitretro/domain`; `machine_tags` in seiner heutigen Form.
- Produces: `tagAnlegen(admin, zeile)` und `tagsAnlegen(admin, zeilen)` aus `tests/helpers/tags.ts`. Aufgabe 3 und Aufgabe 4 ändern **nur** deren Rumpf; alle Aufrufer bleiben danach unangetastet.

**Warum diese Aufgabe zuerst kommt.** Zwölf Dateien fügen heute `machine_tags`-Zeilen direkt ein und schreiben dabei `token_hash: hashTagToken(token)`. Ab `0026` heißt das `token`, ab `0027` kommen `batch_id` und `batch_index` als `not null` dazu. Wer die Migration zuerst schreibt, fasst zwölf Dateien zweimal an. Wer den Helfer zuerst einzieht, fasst sie einmal an und ändert danach eine.

- [x] **Step 1: Den Helfer anlegen**

`tests/helpers/tags.ts`:

```ts
import type { SupabaseClient } from "@supabase/supabase-js";
import { createTagToken, hashTagToken } from "@fitretro/domain";

export type TagSorte = "machine" | "studio";
export type TagStatus = "unassigned" | "active" | "revoked" | "replaced";

export type TagZeile = {
  studioId?: string | null | undefined;
  machineId?: string | null | undefined;
  kind?: TagSorte | undefined;
  status?: TagStatus | undefined;
  /** Vorgegebener Token, wenn der Test ihn danach selbst benutzt. */
  token?: string | undefined;
};

export type AngelegterTag = { id: string; token: string };

/**
 * Eine machine_tags-Zeile fuer einen Test anlegen -- mit dem Service-Client,
 * also an RLS vorbei.
 *
 * Der einzige Ort im Testbestand, der die Spaltenform von machine_tags kennt.
 * Das ist Absicht: der Tokenraum und die Chargenspalten aendern sich in diesem
 * Plan zweimal, und beide Male soll genau diese Datei sich aendern.
 */
export async function tagAnlegen(
  admin: SupabaseClient,
  zeile: TagZeile = {},
): Promise<AngelegterTag> {
  const [ergebnis] = await tagsAnlegen(admin, [zeile]);
  return ergebnis!;
}

export async function tagsAnlegen(
  admin: SupabaseClient,
  zeilen: TagZeile[],
): Promise<AngelegterTag[]> {
  const tokens = zeilen.map((zeile) => zeile.token ?? createTagToken());

  const datensaetze = zeilen.map((zeile, index) => ({
    studio_id: zeile.studioId ?? null,
    machine_id: zeile.machineId ?? null,
    kind: zeile.kind ?? "machine",
    status: zeile.status ?? "unassigned",
    token_hash: hashTagToken(tokens[index]!),
  }));

  const { data, error } = await admin
    .from("machine_tags")
    .insert(datensaetze)
    .select("id");
  if (error) throw error;

  return (data ?? []).map((reihe: { id: string }, index) => ({
    id: reihe.id,
    token: tokens[index]!,
  }));
}
```

- [x] **Step 2: Den Helfer gegen eine bestehende Datei ausprobieren**

In `tests/integration/rls-machine-tags.test.ts` den Import ergänzen und den ersten Einfügeblock ersetzen. Aus dem heutigen Block (ab Zeile 52):

```ts
  tokenA = createTagToken();
  tokenB = createTagToken();
  const { error: tagError } = await admin.from("machine_tags").insert([
    {
      studio_id: studioA,
      machine_id: machines[0]!.id,
      token_hash: hashTagToken(tokenA),
      status: "active",
    },
```

wird:

```ts
  tokenA = createTagToken();
  tokenB = createTagToken();
  await tagsAnlegen(admin, [
    { studioId: studioA, machineId: machines[0]!.id, token: tokenA, status: "active" },
    { studioId: studioB, machineId: machines[1]!.id, token: tokenB, status: "active" },
  ]);
```

Import am Dateikopf:

```ts
import { tagAnlegen, tagsAnlegen } from "../helpers/tags.js";
```

`createTagToken` bleibt importiert, solange die Datei ihn noch selbst aufruft; `hashTagToken` fällt aus dem Import, sobald kein Aufruf mehr übrig ist. **Ein übrig gebliebener Import ist kein Übersetzungsfehler** — die `tsconfig` hat weder `noUnusedLocals` noch einen Linter dahinter. Er fällt erst in Aufgabe 3 auf, wenn `hashTagToken` nicht mehr zu den Spalten passt. Lies die Importzeile also, statt dich auf `pnpm typecheck` zu verlassen.

- [x] **Step 3: Diese eine Datei laufen lassen**

```bash
pnpm test:integration -- rls-machine-tags
```

Erwartet: PASS, unverändert wie vorher.

- [x] **Step 4: Die restlichen Integrationsdateien umstellen**

Jede Einfügestelle nach demselben Muster — auch die übrigen sieben in `rls-machine-tags.test.ts`, von der Step 2 nur die erste erledigt hat. Die Stellen, Datei für Datei (Zeilennummern sind Anhaltspunkte, keine Zusicherung — sie verschieben sich, sobald du die erste ersetzt hast):

| Datei | Einfügestellen |
| --- | --- |
| `rls-machine-tags.test.ts` | ~52, 86, 112, 155, 172, 189, 207, 241 |
| `rls-machine-tags-write.test.ts` | ~35, 97, 117, 135, 153, 172, 191 |
| `rls-machines.test.ts` | ~457 |
| `domain-bootstrap.test.ts` | ~116, 122 |
| `domain-tag-context.test.ts` | ~206, 211, 217 |
| `api-tag-context.test.ts` | ~66, 71 |
| `resolve-tag-fallback.test.ts` | ~52, 55 |
| `fallback-inhalt.test.ts` | ~142, 148, 154 |
| `machine-tags-kind.test.ts` | alle Stellen aus Task 1 des Datenbankplans |

**Zwei Stellen brauchen mehr als eine Ersetzung:**

`rls-machine-tags-write.test.ts` prüft an mehreren Stellen mit `.eq("token_hash", hashTagToken(token))`, ob eine Zeile geschrieben wurde. Diese Leseabfragen bleiben in dieser Aufgabe **unverändert** — `token_hash` existiert weiter und trägt weiter denselben Wert. Sie fallen erst in Aufgabe 3 auf, wenn `select` auf `token` verboten wird; `token_hash` bleibt lesbar, also bleiben auch sie stehen.

`domain-catalog.test.ts` legt seine Tags über `createTag` an, nicht über ein direktes Insert. Diese Datei wird hier **nicht** angefasst — sie kommt in Aufgabe 2 dran.

- [x] **Step 5: `e2e/tag-fallback.spec.ts` umstellen**

Vier Einfügestellen (~77, 100, 121, 218). Der Import:

```ts
import { tagAnlegen } from "../tests/helpers/tags";
```

*(ohne `.js` — Playwright übersetzt anders als Vitest, und `e2e/helpers/login` wird dort ebenfalls extensionslos importiert)*

Aus:

```ts
  const token = createTagToken();
  const { error: tagError } = await client.from("machine_tags").insert({
    studio_id: studio.id,
    machine_id: machine.id,
    token_hash: hashTagToken(token),
    status: "active",
  });
  if (tagError) throw tagError;
```

wird:

```ts
  const { token } = await tagAnlegen(client, {
    studioId: studio.id,
    machineId: machine.id,
    status: "active",
  });
```

`hashTagToken` fällt danach aus dem Import am Dateikopf; `createTagToken` bleibt, weil zwei Tests ihn für einen absichtlich unbekannten Token brauchen.

- [x] **Step 6: Alles laufen lassen**

```bash
pnpm typecheck
pnpm test:integration
pnpm test:e2e
```

Erwartet: alles PASS, keine Verhaltensänderung. Diese Aufgabe ist ein reiner Umbau — schlägt etwas fehl, liegt es an einer falsch übertragenen Zeile, nicht an einer neuen Regel.

- [x] **Step 7: Commit**

```bash
git add tests/helpers/tags.ts tests/integration e2e
git commit -m "test: Tag-Fixtures hinter einem Helfer buendeln"
```

---

### Task 2: `createTag` und die Erzeugen-Oberfläche zurückbauen

**Files:**
- Delete: `apps/web/app/portal/[studioId]/TagAnlegen.tsx`
- Modify: `packages/domain/src/catalog.ts` (Funktion `createTag`, ~ab Zeile 483), `packages/domain/src/index.ts:35`, `apps/web/app/portal/actions.ts` (Funktion `tagAnlegen`, ~ab Zeile 288), `apps/web/app/portal/[studioId]/tags/page.tsx`, `apps/web/app/portal/[studioId]/geraete/page.tsx:5,93`, `apps/web/app/portal/[studioId]/modelle/[modelId]/page.tsx:19,318`
- Test: `tests/integration/domain-catalog.test.ts`, `e2e/trainerportal.spec.ts`

**Interfaces:**
- Consumes: `tagAnlegen` aus `tests/helpers/tags.ts` (Aufgabe 1).
- Produces: nichts Neues. Entfernt `createTag` aus `@fitretro/domain` und die Server Action `tagAnlegen` aus `apps/web/app/portal/actions.ts`.

**Warum das vor der Migration steht.** `createTag` schreibt `token_hash` mit dem Client des Trainers. Nach `0026` ist die Spalte generiert und `token` für `authenticated` nicht schreibbar — die Funktion kann dann nicht mehr laufen, egal ob jemand sie zurückbaut. Stünde dieser Rückbau danach, wäre das Repo zwischen zwei Commits rot. Er hängt an nichts aus `0026`, also kommt er davor.

**Was das kostet, offen gesagt:** Zwischen diesem Commit und Aufgabe 6 hat das Portal keinen Weg, einen Tag *anzulegen*. Das ist der Zielzustand (Einrichtungs-Spec, Entscheidung 2), nur früher als der Ersatz. Tags **binden** geht weiter — `TagZuweisen` bleibt bis Aufgabe 7 stehen.

- [x] **Step 1: Die Tests umschreiben, die `createTag` benutzen**

In `tests/integration/domain-catalog.test.ts` stehen zehn Aufrufe. Jeder wird zu einem Helferaufruf mit dem Service-Client. Aus:

```ts
    const { id, token } = await createTag(client, { studioId: studioA });
```

wird:

```ts
    const { id, token } = await tagAnlegen(serviceClient(), { studioId: studioA });
```

Und aus einem Aufruf mit Gerät:

```ts
    await createTag(client, { studioId: studioA, machineId });
```

wird:

```ts
    await tagAnlegen(serviceClient(), { studioId: studioA, machineId, status: "active" });
```

**`status: "active"` muss dabei stehen**, wo vorher eine `machineId` übergeben wurde: `createTag` hat den Status aus dem Vorhandensein des Geräts abgeleitet (`status: input.machineId ? "active" : "unassigned"`), der Helfer tut das nicht. Ohne diese Angabe entstehen `unassigned`-Zeilen mit Gerät, und die Prüfungen auf „aktiver Tag" schlagen fehl.

**Zwei Tests verlieren ihren Gegenstand und werden gelöscht** — die beiden am Dateiende, die prüfen, dass `createTag` für ein fremdes Studio bzw. ohne Mitgliedschaft `DomainError` wirft (~Zeile 528 und 534). Sie prüften die Autorisierung einer Funktion, die es nicht mehr gibt. Die Autorisierung von `assignTag` und `revokeTag` ist an anderer Stelle derselben Datei abgedeckt und bleibt.

Am Dateikopf `createTag` aus dem Import entfernen und `tagAnlegen` ergänzen:

```ts
import { tagAnlegen } from "../helpers/tags.js";
```

- [x] **Step 2: Tests laufen lassen, Fehlschlag bestätigen**

```bash
pnpm test:integration -- domain-catalog
```

Erwartet: PASS. Die Tests laufen bereits ohne `createTag`, die Funktion existiert nur noch unbenutzt.

- [x] **Step 3: `createTag` löschen**

In `packages/domain/src/catalog.ts` den kompletten Block entfernen — den Dokumentationskommentar *„Einen Tag anlegen. Der Klartext-Token wird genau einmal zurueckgegeben …"* und die Funktion `createTag` darunter (bis einschließlich `return { id: data.id, token };` und der schließenden Klammer).

Am Dateikopf wird aus:

```ts
import { createTagToken, hashTagToken } from "./tags.js";
```

ein ersatzloser Wegfall der Zeile — **beide** Namen werden in `catalog.ts` danach nicht mehr gebraucht. `pnpm typecheck` bestätigt das.

In `packages/domain/src/index.ts` die Zeile `  createTag,` aus dem `export { ... } from "./catalog.js"`-Block entfernen.

- [x] **Step 4: Die Server Action löschen**

In `apps/web/app/portal/actions.ts` den Kommentarblock *„Ein Tag entsteht mit einem Token, den es genau einmal zu sehen gibt …"* und die gesamte Funktion `tagAnlegen` entfernen. Aus dem Import am Dateikopf `createTag,` streichen.

`tagZuweisen` und `tagSperren` bleiben unverändert stehen.

- [x] **Step 5: Die Oberfläche zurückbauen**

`apps/web/app/portal/[studioId]/TagAnlegen.tsx` löschen.

Drei Aufrufstellen entfernen:

- `apps/web/app/portal/[studioId]/geraete/page.tsx`: Zeile 5 (Import) und Zeile 93 (`<TagAnlegen … />`).
- `apps/web/app/portal/[studioId]/modelle/[modelId]/page.tsx`: Zeile 19 (Import) und Zeile 318.
- `apps/web/app/portal/[studioId]/tags/page.tsx`: Zeile 4 (Import) und der ganze Abschnitt *„Auf Vorrat anlegen"* (Zeilen ~51–71), samt der Variablen `vorraetig`, die nur ihn versorgt.

Der Absatz unter der Überschrift auf der Tags-Seite beschreibt eine Welt, die es nicht mehr gibt. Er wird ersetzt:

```tsx
      <p className={styles.pageLead}>
        Tags kommen als Lieferung und werden nicht hier erzeugt. Welcher Tag an
        welchem Gerät hängt, entscheidet der Scan am Gerät. Aushangschilder sind
        ab Lieferung gültig und hängen an keinem Gerät.
      </p>
```

- [x] **Step 6: Den E2E-Gang umschreiben**

In `e2e/trainerportal.spec.ts` ersetzt Schritt 5 das Anlegen über die Oberfläche durch eine geseedete Zeile. Aus (~Zeile 118–124):

```ts
  // 5. Tag -- der Token steht genau einmal da
  await page.getByRole("button", { name: "Tag anlegen" }).click();
  await expect(page.getByText("Token — nur jetzt sichtbar")).toBeVisible();
  const token = (await page.getByTestId("tag-token").innerText()).trim();
  expect(token).toMatch(/^[A-Za-z0-9_-]{16,}$/);

  await page.getByRole("button", { name: "Fertig" }).click();
```

wird:

```ts
  // 5. Tag -- er kommt aus der Lieferung, nicht aus dem Portal. Aufgabe 7
  // ersetzt das Seeden hier durch den Weg ueber die Oberflaeche.
  const { data: geraeteZeile, error: geraeteFehler } = await admin
    .from("machines")
    .select("id")
    .eq("studio_id", studio.id)
    .single();
  if (geraeteFehler) throw geraeteFehler;

  const { token } = await tagAnlegen(admin, {
    studioId: studio.id,
    machineId: geraeteZeile.id,
    status: "active",
  });
```

Import am Dateikopf ergänzen:

```ts
import { tagAnlegen } from "../tests/helpers/tags";
```

Der Rest des Tests — der Aufruf gegen `/api/v1/tags/<token>/context` ohne und mit Bearer — bleibt wörtlich stehen. Er ist der eigentliche Beweis des Tests und von diesem Umbau unberührt.

- [x] **Step 7: Alles laufen lassen**

```bash
pnpm typecheck
pnpm test:integration
pnpm test:e2e
```

Erwartet: alles PASS. `typecheck` deckt eine vergessene Aufrufstelle von `TagAnlegen` oder `createTag` zuverlässig auf.

- [x] **Step 8: Commit**

```bash
git add -A
git commit -m "refactor: createTag und den Erzeugen-Pfad im Portal zurueckbauen"
```

---

### Task 3: Migration `0026` — Klartext, generierter Hash, Spaltenrechte

**Files:**
- Create: `supabase/migrations/0026_tag_klartext.sql`, `tests/integration/tag-klartext.test.ts`
- Modify: `tests/helpers/tags.ts`, `tests/integration/rls-machine-tags-write.test.ts`

**Interfaces:**
- Consumes: `machine_tags` mit `kind` aus `0022`, `machine_tags_insert` aus `0016`.
- Produces: `machine_tags.token` (Klartext, `not null`, unique, für `authenticated` weder les- noch schreibbar) und `machine_tags.token_hash` als generierte Spalte. Aufgabe 4 baut darauf auf, Aufgabe 5 sucht über `token`.

- [x] **Step 1: Den fehlschlagenden Test schreiben**

`tests/integration/tag-klartext.test.ts`:

```ts
import { beforeAll, describe, expect, it } from "vitest";
import { createTagToken, hashTagToken } from "@fitretro/domain";
import {
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";
import { tagAnlegen } from "../helpers/tags.js";

let studioId: string;
let trainerEmail: string;
let token: string;
let tagId: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studio, error: studioFehler } = await admin
    .from("studios")
    .insert({ name: "Klartext Studio" })
    .select("id")
    .single();
  if (studioFehler) throw studioFehler;
  studioId = studio.id;

  trainerEmail = uniqueEmail("klartext-trainer");
  const trainer = await createTestUser(trainerEmail);
  const { error: mitgliedFehler } = await admin
    .from("studio_memberships")
    .insert({ studio_id: studioId, user_id: trainer, role: "trainer" });
  if (mitgliedFehler) throw mitgliedFehler;

  token = createTagToken();
  const angelegt = await tagAnlegen(admin, { studioId, token });
  tagId = angelegt.id;
});

describe("machine_tags.token", () => {
  it("leitet token_hash aus dem Klartext ab", async () => {
    const admin = serviceClient();
    const { data, error } = await admin
      .from("machine_tags")
      .select("token, token_hash")
      .eq("id", tagId)
      .single<{ token: string; token_hash: string }>();
    expect(error).toBeNull();
    expect(data?.token).toBe(token);
    expect(data?.token_hash).toBe(hashTagToken(token));
  });

  it("laesst einen Trainer den Klartext nicht lesen", async () => {
    const client = await userClient(trainerEmail);
    const { error } = await client
      .from("machine_tags")
      .select("token")
      .eq("id", tagId);
    expect(error).not.toBeNull();
  });

  it("laesst einen Trainer die uebrigen Spalten weiter lesen", async () => {
    const client = await userClient(trainerEmail);
    const { data, error } = await client
      .from("machine_tags")
      .select("id, status, kind, token_hash")
      .eq("id", tagId)
      .single<{ id: string; status: string; kind: string; token_hash: string }>();
    expect(error).toBeNull();
    expect(data?.token_hash).toBe(hashTagToken(token));
  });

  it("laesst einen Trainer den Klartext nicht ueberschreiben", async () => {
    const client = await userClient(trainerEmail);
    const { error } = await client
      .from("machine_tags")
      .update({ token: createTagToken() })
      .eq("id", tagId);
    expect(error).not.toBeNull();
  });

  it("laesst einen Trainer keine Zeile mehr einfuegen", async () => {
    const client = await userClient(trainerEmail);
    const { error } = await client
      .from("machine_tags")
      .insert({ studio_id: studioId, status: "unassigned", kind: "machine" });
    expect(error).not.toBeNull();
  });
});
```

- [x] **Step 2: Test laufen lassen, Fehlschlag bestätigen**

```bash
pnpm test:integration -- tag-klartext
```

Erwartet: FAIL — `column machine_tags.token does not exist`.

- [x] **Step 3: Die Migration schreiben**

`supabase/migrations/0026_tag_klartext.sql`:

```sql
-- Der Token war bisher nur als SHA-256 gespeichert. Die eine Eigenschaft, die
-- das kaufte -- ein Datenbankabzug ist keine fertige Liste funktionierender
-- Adressen -- ist weniger wert als ihr Preis. Wer den Abzug hat, hat darin
-- ohnehin studios, machines, studio_memberships und ueber auth.users die
-- Mailadressen; die Tokenliste ist der harmloseste Posten darin. Bezahlt wurde
-- sie mit dem Druckbogen, danach mit der einmaligen Anzeige, und als naechstes
-- haette sie eine Klartextliste erzwungen, deren Verlust eine ganze Charge
-- verschrottet.
--
-- An ihre Stelle treten Spaltenrechte. Der Klartext steht in machine_tags.token,
-- aber authenticated darf ihn weder lesen noch schreiben. token_hash bleibt --
-- gleicher Name, gleiche Werte, gleiche Unique --, nur wird er jetzt abgeleitet
-- statt eingefuegt. Deshalb bleiben bootstrap.ts, tag-context.ts,
-- resolve_tag_fallback und join_studio_by_tag woertlich unveraendert.
--
-- Spec: docs/superpowers/specs/2026-09-01-tag-lieferung-design.md, Abschnitt 1.

-- Der Klartext bestehender Zeilen ist per Definition unwiederbringlich -- genau
-- die Eigenschaft, die diese Migration abschafft. Er kann nicht nachgetragen
-- werden, die Zeilen muessen weg. Bestand ist ausschliesslich synthetisch
-- (2026-08-28-fitness-retrofit-m1-design.md, Abschnitt 9), und kein Tag ist je
-- physisch gedruckt worden.
delete from public.machine_tags;

alter table public.machine_tags drop constraint machine_tags_token_hash_key;
alter table public.machine_tags drop column token_hash;

-- decode(token, 'escape') statt convert_to(token, 'UTF8'): convert_to ist
-- STABLE und in einer generierten Spalte nicht zulaessig, decode ist IMMUTABLE.
-- Das Tokenformat laesst ohnehin nur ASCII zu, also sind beide byteweise gleich.
alter table public.machine_tags
  add column token text not null
    check (token ~ '^[A-Za-z0-9_-]{22}$'),
  add column token_hash text
    generated always as (encode(sha256(decode(token, 'escape')), 'hex')) stored;

alter table public.machine_tags
  add constraint machine_tags_token_key      unique (token),
  add constraint machine_tags_token_hash_key unique (token_hash);

-- Der eigentliche Zweck. Ohne den Entzug von select liest jedes Mitglied ueber
-- machine_tags_select den Token des Aushangschilds seines Studios und kann die
-- Beitritts-URL streuen, ohne das Schild zu fotografieren. Ohne den Entzug von
-- update koennte ein Trainer einem Schild seines Studios einen selbst
-- gewaehlten Token geben und dasselbe tun.
revoke select, insert, update on public.machine_tags from authenticated, anon;

grant select (id, studio_id, machine_id, token_hash, status, kind,
              created_at, revoked_at)
  on public.machine_tags to authenticated;

grant update (machine_id, status, revoked_at)
  on public.machine_tags to authenticated;

-- Kein grant insert. token ist not null und wird nicht gewaehrt, also scheitert
-- jedes Insert eines Trainers ohnehin -- welche Spalten er auch nennt. Ein
-- Insert-Recht waere ein Versprechen ohne Deckung.
--
-- Damit faellt auch die Policy aus 0016. Ihre Begruendung dort -- "der Grund,
-- warum ein Studio sich nicht ohne Entwicklerhilfe einrichten liess" -- ist
-- durch die Lieferung abgeloest: Tag-Zeilen entstehen beim Betreiber. Wer sie
-- stehen liesse, hinterliesse eine Policy, die einen Weg beschreibt, den es
-- nicht gibt.
drop policy machine_tags_insert on public.machine_tags;
```

- [x] **Step 4: Den Helfer auf den Klartext umstellen**

In `tests/helpers/tags.ts` — **nur** der Datensatzaufbau ändert sich:

```ts
  const datensaetze = zeilen.map((zeile, index) => ({
    studio_id: zeile.studioId ?? null,
    machine_id: zeile.machineId ?? null,
    kind: zeile.kind ?? "machine",
    status: zeile.status ?? "unassigned",
    token: tokens[index]!,
  }));
```

Der Import am Dateikopf wird zu:

```ts
import { createTagToken } from "@fitretro/domain";
```

`hashTagToken` wird hier nicht mehr gebraucht. Es bleibt im Paket und in `tag-klartext.test.ts`.

- [x] **Step 5: Den Insert-Policy-Block in `rls-machine-tags-write.test.ts` umschreiben**

Diese Datei prüft ab Zeile 91 einen ganzen `describe`-Block *„machine_tags: Insert-Policy"* mit sechs Tests. Drei davon lassen einen Trainer **erfolgreich** einfügen — nach dieser Migration kann das niemand mehr, sie laufen rot. Die drei negativen prüfen, dass bestimmte Trainer *nicht* einfügen dürfen; sie sind gegenstandslos geworden, weil es überhaupt niemand mehr darf.

Der komplette Block von Zeile 91 (`describe("machine_tags: Insert-Policy", ...)`) bis zu seiner schließenden Klammer wird ersetzt durch:

```ts
// 0016 gab machine_tags eine Insert-Policy, damit ein Studio sich ohne
// Entwicklerhilfe einrichten liess. Das ist abgeloest: Tag-Zeilen entstehen
// beim Betreiber, aus der Lieferung. Uebrig bleibt genau eine Aussage.
describe("machine_tags: kein Schreibpfad mehr", () => {
  it("negativ: auch der Trainer legt keinen Tag mehr an", async () => {
    const client = await userClient(trainerA);
    const { error } = await client
      .from("machine_tags")
      .insert({ studio_id: studioA, status: "unassigned", kind: "machine" });
    expect(error).not.toBeNull();
  });

  it("derselbe Token laesst sich kein zweites Mal vergeben", async () => {
    const admin = serviceClient();
    const token = createTagToken();
    await tagAnlegen(admin, { studioId: studioA, token });
    await expect(tagAnlegen(admin, { studioId: studioA, token })).rejects.toMatchObject({
      code: "23505",
    });
  });
});
```

Der zweite Test hält die Aussage des alten *„Nebenlaeufigkeit"*-Tests fest — der Tokenraum bleibt kollisionsfrei —, prüft sie aber dort, wo jetzt geschrieben wird: über den Service-Client.

**Die Blöcke *„Update-Policy"* und *„kein Loeschpfad"* bleiben unverändert.** Sie arbeiten auf Zeilen, die `seedTag` mit `studio_id` anlegt; `is_studio_staff` greift dort weiter, und `update` auf `machine_id`, `status` und `revoked_at` ist dem Trainer weiterhin gewährt.

- [x] **Step 6: Datenbank zurücksetzen und alles laufen lassen**

```bash
pnpm exec supabase db reset
pnpm typecheck
pnpm test:integration
pnpm test:e2e
```

Erwartet: alles PASS.

**Wenn `resolve-tag-fallback` oder `fallback-inhalt` fehlschlagen**, ist die generierte Spalte falsch berechnet — vergleiche einen Wert von Hand:

```bash
docker exec supabase_db_m0-fundament psql -U postgres -d postgres \
  -c "select encode(sha256(decode('abcdefghijklmnopqrstuv','escape')),'hex');"
node -e "console.log(require('node:crypto').createHash('sha256').update('abcdefghijklmnopqrstuv','utf8').digest('hex'))"
```

Beide müssen `f69f9b70d1c9a5442258ca76f8b0a7a45fcb4e31c36141b6357ec591328b0624` liefern.

- [x] **Step 7: Commit**

```bash
git add supabase/migrations/0026_tag_klartext.sql tests/integration/tag-klartext.test.ts tests/integration/rls-machine-tags-write.test.ts tests/helpers/tags.ts
git commit -m "feat(db): Tag-Token im Klartext, token_hash generiert, Spaltenrechte"
```

---

### Task 4: Migration `0027` — Chargen, Lieferungen, Halde

**Files:**
- Create: `supabase/migrations/0027_tag_chargen.sql`
- Modify: `tests/helpers/tags.ts`
- Test: `tests/integration/tag-chargen.test.ts` (nur der RLS-Teil; die Fachschicht kommt in Aufgabe 6)

**Interfaces:**
- Consumes: `public.tag_kind` aus `0022`, `machine_tags.token` aus `0026`, `public.is_studio_staff` aus `0001`.
- Produces: `public.tag_batches`, `public.tag_shipments`, `machine_tags.batch_id`, `machine_tags.batch_index`, nullbares `machine_tags.studio_id`, Constraint `machine_tags_halde`. Aufgabe 5 und 6 bauen darauf auf. Aus `tests/helpers/tags.ts` zusätzlich `chargeFuerTest(admin, kind)`.

- [x] **Step 1: Den fehlschlagenden Test schreiben**

`tests/integration/tag-chargen.test.ts`:

```ts
import { beforeAll, describe, expect, it } from "vitest";
import {
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";
import { chargeFuerTest, tagAnlegen } from "../helpers/tags.js";

let studioA: string;
let studioB: string;
let trainerA: string;
let lieferungA: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioFehler } = await admin
    .from("studios")
    .insert([{ name: "Chargen Studio A" }, { name: "Chargen Studio B" }])
    .select("id");
  if (studioFehler) throw studioFehler;
  studioA = studios[0]!.id;
  studioB = studios[1]!.id;

  trainerA = uniqueEmail("chargen-trainer-a");
  const nutzer = await createTestUser(trainerA);
  const { error: mitgliedFehler } = await admin
    .from("studio_memberships")
    .insert({ studio_id: studioA, user_id: nutzer, role: "trainer" });
  if (mitgliedFehler) throw mitgliedFehler;

  const charge = await chargeFuerTest(admin, "machine");
  const { data: lieferung, error: lieferFehler } = await admin
    .from("tag_shipments")
    .insert([
      { batch_id: charge.id, studio_id: studioA, quantity: 100 },
      { batch_id: charge.id, studio_id: studioB, quantity: 50 },
    ])
    .select("id, studio_id");
  if (lieferFehler) throw lieferFehler;
  lieferungA = lieferung.find((zeile) => zeile.studio_id === studioA)!.id;
});

describe("Chargen und Lieferungen", () => {
  it("haelt tag_batches vor jedem angemeldeten Konto verschlossen", async () => {
    const client = await userClient(trainerA);
    const { data, error } = await client.from("tag_batches").select("id");
    expect(error).toBeNull();
    expect(data).toEqual([]);
  });

  it("zeigt einem Trainer die Lieferungen seines Studios", async () => {
    const client = await userClient(trainerA);
    const { data, error } = await client
      .from("tag_shipments")
      .select("id, quantity");
    expect(error).toBeNull();
    expect(data?.map((zeile) => zeile.id)).toEqual([lieferungA]);
    expect(data?.[0]?.quantity).toBe(100);
  });

  it("laesst einen Trainer keine Lieferung anlegen", async () => {
    const client = await userClient(trainerA);
    const charge = await chargeFuerTest(serviceClient(), "machine");
    const { error } = await client
      .from("tag_shipments")
      .insert({ batch_id: charge.id, studio_id: studioA, quantity: 1 });
    expect(error).not.toBeNull();
  });
});

describe("Die Halde", () => {
  it("speichert eine Zeile ohne Studio", async () => {
    const admin = serviceClient();
    const { id } = await tagAnlegen(admin, { studioId: null });
    const { data } = await admin
      .from("machine_tags")
      .select("studio_id, status")
      .eq("id", id)
      .single<{ studio_id: string | null; status: string }>();
    expect(data?.studio_id).toBeNull();
    expect(data?.status).toBe("unassigned");
  });

  it("verbirgt eine studiolose Zeile vor jedem angemeldeten Konto", async () => {
    const admin = serviceClient();
    const { id } = await tagAnlegen(admin, { studioId: null });
    const client = await userClient(trainerA);
    const { data } = await client.from("machine_tags").select("id").eq("id", id);
    expect(data).toEqual([]);
  });

  it("lehnt eine studiolose Zeile mit Geraet ab", async () => {
    const admin = serviceClient();
    const charge = await chargeFuerTest(admin, "machine");

    const { data: modell, error: modellFehler } = await admin
      .from("equipment_models")
      .insert({ studio_id: studioA, name: "Halde-Geraet", weight_step_kg: 5 })
      .select("id")
      .single();
    if (modellFehler) throw modellFehler;

    const { data: geraet, error: geraetFehler } = await admin
      .from("machines")
      .insert({ studio_id: studioA, equipment_model_id: modell.id, label: "H1" })
      .select("id")
      .single();
    if (geraetFehler) throw geraetFehler;

    const { error } = await admin.from("machine_tags").insert({
      studio_id: null,
      machine_id: geraet.id,
      kind: "machine",
      status: "unassigned",
      token: "AAAAAAAAAAAAAAAAAAAAAA",
      batch_id: charge.id,
      batch_index: 9001,
    });
    expect(error?.message).toContain("machine_tags_halde");
  });

  it("lehnt eine studiolose Zeile mit status active ab", async () => {
    const admin = serviceClient();
    const charge = await chargeFuerTest(admin, "studio");
    const { error } = await admin.from("machine_tags").insert({
      studio_id: null,
      kind: "studio",
      status: "active",
      token: "BBBBBBBBBBBBBBBBBBBBBB",
      batch_id: charge.id,
      batch_index: 9002,
    });
    expect(error?.message).toContain("machine_tags_halde");
  });

  it("erlaubt eine studiolose Zeile als revoked", async () => {
    const admin = serviceClient();
    const { id } = await tagAnlegen(admin, { studioId: null, status: "revoked" });
    expect(id).toBeTruthy();
  });
});
```

- [x] **Step 2: Test laufen lassen, Fehlschlag bestätigen**

```bash
pnpm test:integration -- tag-chargen
```

Erwartet: FAIL — `relation "public.tag_batches" does not exist`.

- [x] **Step 3: Die Migration schreiben**

`supabase/migrations/0027_tag_chargen.sql`:

```sql
-- Tags entstehen chargenweise beim Lieferanten und werden studioweise
-- ausgeliefert. Zwischen beidem liegt die Halde: Zeilen, die es gibt, aber noch
-- keinem Studio gehoeren.
--
-- Die Halde liegt in machine_tags selbst, nicht in einer eigenen Tabelle. Der
-- naheliegende Gegenentwurf -- tag_batch_items, aus dem beim Versand kopiert
-- wird -- haette denselben Token an zwei Orten und eine zweite Unique-Insel
-- ueber den Tokenraum, die auseinanderlaufen kann. Eine nullbare
-- Fremdschluesselspalte ist billiger zu bewachen als zwei Tabellen, die
-- dasselbe behaupten.
--
-- Spec: docs/superpowers/specs/2026-09-01-tag-lieferung-design.md, Abschnitt 2.

-- Eine Charge ist ein Herstellungslos: N Aufkleber oder N Schilder, in einem
-- Zug gedruckt. Sie ist ein Betreibergegenstand -- kein Studio hat ein Wort
-- dazu. Deshalb bekommt die Tabelle keine einzige Policy: mit aktivem RLS und
-- ohne Policy liefert sie jedem authenticated-Konto null Zeilen, und nur
-- service_role (rolbypassrls) erreicht sie. Das ist die Absicherung, nicht die
-- Grant-Lage -- auto_expose_new_tables ist auf dem Vorgabewert.
create table public.tag_batches (
  id          uuid primary key default gen_random_uuid(),
  code        text not null unique,
  kind        public.tag_kind not null,
  quantity    integer not null check (quantity > 0),
  supplier    text,
  ordered_on  date,
  scrapped_at timestamptz,
  created_at  timestamptz not null default now()
);

alter table public.tag_batches enable row level security;
alter table public.tag_batches force  row level security;

-- Eine Lieferung ist eine Zahl, keine Liste. Welche hundert Aufkleber in der
-- Kiste lagen, weiss niemand -- ein Geraetetag lernt sein Studio erst beim Scan
-- vor dem Geraet. Diese Zeile traegt allein die Auskunft auf der Tags-Seite:
-- "Lieferung vom 12. August * 100 Tags".
--
-- on delete restrict auf beiden Fremdschluesseln: eine Lieferung ist ein
-- Vorgang der Vergangenheit. Ein Studio wird stillgelegt, nicht geloescht --
-- dieselbe Linie wie bei machine_tags_machine_id_fkey aus 0008.
create table public.tag_shipments (
  id         uuid primary key default gen_random_uuid(),
  batch_id   uuid not null references public.tag_batches (id) on delete restrict,
  studio_id  uuid not null references public.studios     (id) on delete restrict,
  quantity   integer not null check (quantity > 0),
  shipped_on date not null default current_date,
  note       text,
  created_at timestamptz not null default now()
);

create index on public.tag_shipments (studio_id);

alter table public.tag_shipments enable row level security;
alter table public.tag_shipments force  row level security;

-- Nur lesen, und nur das eigene Studio. Angelegt wird eine Lieferung vom
-- Betreiberskript ueber service_role; im Portal gibt es dafuer keinen Weg.
create policy tag_shipments_select on public.tag_shipments
  for select to authenticated
  using (public.is_studio_staff(studio_id));

-- 0026 hat die Tabelle geleert. Falls zwischen beiden Migrationen doch Zeilen
-- entstanden sind, koennen sie keine Charge tragen -- und ein Tag ohne Charge
-- gibt es ab hier nicht mehr.
delete from public.machine_tags;

-- studio_id wird nullbar: das ist die Halde. Gefahrlos, weil is_studio_member
-- und is_studio_staff fuer null beide false liefern (m.studio_id = null trifft
-- nie zu) -- eine studiolose Zeile ist damit fuer jedes authenticated-Konto
-- unsichtbar, ohne dass eine einzige Policy sich aendert.
--
-- batch_index ist die auf dem Erzeugnis aufgedruckte laufende Nummer. Ohne sie
-- hat "Sperren" auf der Tags-Seite kein Ziel: ein Aushangschild hat kein
-- Geraet, ueber das es sich benennen liesse, und einen Ort hat nie jemand
-- eingegeben.
alter table public.machine_tags
  alter column studio_id drop not null,
  add column batch_id    uuid    not null references public.tag_batches (id) on delete restrict,
  add column batch_index integer not null check (batch_index >= 1);

alter table public.machine_tags
  add constraint machine_tags_batch_index_key unique (batch_id, batch_index);

create index on public.machine_tags (batch_id);

-- Vier Aussagen in einer Zeile: eine Zeile ohne Studio hat kein Geraet, ist nie
-- aktiv, und darf trotzdem revoked werden -- verlorene Packung, Fehldruck vor
-- dem Versand. Und weil sie nie aktiv sein kann, bleibt die Annahme
-- "studio_id: string" in getTagContext wahr, ohne dass die Datei sich aendert.
--
-- machine_tags_machine_kind aus 0022 bleibt daneben unveraendert gueltig.
alter table public.machine_tags
  add constraint machine_tags_halde
    check (studio_id is not null
           or (status in ('unassigned', 'revoked') and machine_id is null));

-- 0026 konnte die beiden neuen Spalten nicht nennen, es gab sie dort noch
-- nicht. Eine Spaltenliste ist eine Aufzaehlung, keine Ausnahme: ohne diese
-- Erneuerung kann die Tags-Seite "Charge 7" nicht anzeigen.
grant select (id, studio_id, machine_id, token_hash, status, kind,
              batch_id, batch_index, created_at, revoked_at)
  on public.machine_tags to authenticated;
```

- [x] **Step 4: Den Helfer um die Charge erweitern**

`tests/helpers/tags.ts` bekommt oben eine Chargenverwaltung und reicht `batch_id`/`batch_index` durch:

```ts
type ChargenEintrag = { id: string; naechsteNummer: number };

const chargen = new Map<TagSorte, ChargenEintrag>();

/**
 * Eine Charge je Sorte und Testdatei. Sie ist gross genug, dass keine Datei
 * sie ausschoepft, und die laufende Nummer zaehlt hoch -- (batch_id,
 * batch_index) ist unique.
 */
export async function chargeFuerTest(
  admin: SupabaseClient,
  kind: TagSorte,
): Promise<ChargenEintrag> {
  const vorhanden = chargen.get(kind);
  if (vorhanden) return vorhanden;

  const { data, error } = await admin
    .from("tag_batches")
    .insert({ code: `test-${kind}-${crypto.randomUUID()}`, kind, quantity: 10_000 })
    .select("id")
    .single<{ id: string }>();
  if (error) throw error;

  const eintrag: ChargenEintrag = { id: data.id, naechsteNummer: 1 };
  chargen.set(kind, eintrag);
  return eintrag;
}
```

und in `tagsAnlegen` vor dem Aufbau der Datensätze:

```ts
  const nachSorte = new Map<TagSorte, ChargenEintrag>();
  for (const zeile of zeilen) {
    const kind = zeile.kind ?? "machine";
    if (!nachSorte.has(kind)) nachSorte.set(kind, await chargeFuerTest(admin, kind));
  }

  const datensaetze = zeilen.map((zeile, index) => {
    const kind = zeile.kind ?? "machine";
    const charge = nachSorte.get(kind)!;
    return {
      studio_id: zeile.studioId ?? null,
      machine_id: zeile.machineId ?? null,
      kind,
      status: zeile.status ?? "unassigned",
      token: tokens[index]!,
      batch_id: charge.id,
      batch_index: charge.naechsteNummer++,
    };
  });
```

**Achtung auf die Vorgabe `studioId`:** `zeile.studioId ?? null` macht ein *fehlendes* Feld zu `null` — und `null` heißt ab jetzt „Halde". Alle Aufrufer aus Aufgabe 1 und 2 geben `studioId` ausdrücklich an; die neuen Tests in dieser Aufgabe lassen es bewusst weg. Das ist gewollt, aber es ist die Stelle, an der ein stiller Fehler entstünde, wenn ein Aufrufer es vergisst — dann prüft der Test die Halde statt des Studios.

- [x] **Step 5: Zurücksetzen und alles laufen lassen**

```bash
pnpm exec supabase db reset
pnpm typecheck
pnpm test:integration
pnpm test:e2e
```

Erwartet: alles PASS.

- [x] **Step 6: Commit**

```bash
git add supabase/migrations/0027_tag_chargen.sql tests/integration/tag-chargen.test.ts tests/helpers/tags.ts
git commit -m "feat(db): Chargen, Lieferungen und die Halde"
```

---

### Task 5: Migration `0028` — `inspect_tag` und `bind_tag_to_machine`

**Files:**
- Create: `supabase/migrations/0028_tag_binden.sql`, `tests/integration/tag-binden.test.ts`

**Interfaces:**
- Consumes: `machine_tags.token`, `machine_tags.batch_id`, `tag_batches.scrapped_at`, `public.is_studio_staff`.
- Produces:
  - `public.inspect_tag(p_token text, p_studio_id uuid)` → `table (verdict text, batch_code text, batch_index integer, machine_id uuid, machine_label text)`, ausführbar nur für `authenticated`.
  - `public.bind_tag_to_machine(p_token text, p_machine_id uuid)` → `table (verdict text, tag_id uuid)`, ausführbar nur für `authenticated`.
  - Vokabular beider Funktionen: `frei`, `vergeben`, `gesperrt`, `aushangschild`, `unbekannt`, dazu `gebunden` nur beim Binden. Aufgabe 7 zeigt genau diese Wörter an.

**Eine Festlegung, die die Spec offen lässt.** Die Antworttabelle in `2026-09-01-einrichtung-am-geraet-design.md` §4 sagt nichts über ein **gesperrtes Aushangschild des eigenen Studios** — sie kennt für Schilder nur `aushangschild` (aktiv, eigenes Studio) und `unbekannt`. Dieser Plan legt fest: **`gesperrt`.** Der Trainer hält ein Schild in der Hand, das nicht mehr gilt; *„Gesperrt bleibt gesperrt"* sagt ihm, was er wissen muss, *„melde dich beim Betreiber"* schickt ihn telefonieren.

- [x] **Step 1: Den fehlschlagenden Test schreiben**

`tests/integration/tag-binden.test.ts`:

```ts
import { beforeAll, describe, expect, it } from "vitest";
import { createTagToken } from "@fitretro/domain";
import {
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";
import { chargeFuerTest, tagAnlegen } from "../helpers/tags.js";

type Befund = {
  verdict: string;
  batch_code: string | null;
  batch_index: number | null;
  machine_id: string | null;
  machine_label: string | null;
};

let studioA: string;
let studioB: string;
let trainerA: string;
let geraetA: string;
let geraetB: string;

async function befund(email: string, token: string, studioId: string): Promise<Befund> {
  const client = await userClient(email);
  const { data, error } = await client.rpc("inspect_tag", {
    p_token: token,
    p_studio_id: studioId,
  });
  if (error) throw error;
  return (data as Befund[])[0]!;
}

async function binden(email: string, token: string, machineId: string) {
  const client = await userClient(email);
  const { data, error } = await client.rpc("bind_tag_to_machine", {
    p_token: token,
    p_machine_id: machineId,
  });
  if (error) throw error;
  return (data as Array<{ verdict: string; tag_id: string | null }>)[0]!;
}

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioFehler } = await admin
    .from("studios")
    .insert([{ name: "Binden Studio A" }, { name: "Binden Studio B" }])
    .select("id");
  if (studioFehler) throw studioFehler;
  studioA = studios[0]!.id;
  studioB = studios[1]!.id;

  trainerA = uniqueEmail("binden-trainer-a");
  const nutzer = await createTestUser(trainerA);
  const { error: mitgliedFehler } = await admin
    .from("studio_memberships")
    .insert({ studio_id: studioA, user_id: nutzer, role: "trainer" });
  if (mitgliedFehler) throw mitgliedFehler;

  const { data: modelle, error: modellFehler } = await admin
    .from("equipment_models")
    .insert([
      { studio_id: studioA, name: "Binden-Modell A", weight_step_kg: 5 },
      { studio_id: studioB, name: "Binden-Modell B", weight_step_kg: 5 },
    ])
    .select("id");
  if (modellFehler) throw modellFehler;

  const { data: geraete, error: geraetFehler } = await admin
    .from("machines")
    .insert([
      { studio_id: studioA, equipment_model_id: modelle[0]!.id, label: "Beinpresse 7" },
      { studio_id: studioB, equipment_model_id: modelle[1]!.id, label: "Fremdgeraet" },
    ])
    .select("id");
  if (geraetFehler) throw geraetFehler;
  geraetA = geraete[0]!.id;
  geraetB = geraete[1]!.id;
});

describe("inspect_tag", () => {
  it("nennt einen studiolosen Geraetetag frei, mit Charge und Nummer", async () => {
    const { token } = await tagAnlegen(serviceClient(), { studioId: null });
    const ergebnis = await befund(trainerA, token, studioA);
    expect(ergebnis.verdict).toBe("frei");
    expect(ergebnis.batch_code).toBeTruthy();
    expect(ergebnis.batch_index).toBeGreaterThan(0);
  });

  it("nennt einen gebundenen Tag vergeben, mit dem Geraet", async () => {
    const { token } = await tagAnlegen(serviceClient(), {
      studioId: studioA,
      machineId: geraetA,
      status: "active",
    });
    const ergebnis = await befund(trainerA, token, studioA);
    expect(ergebnis.verdict).toBe("vergeben");
    expect(ergebnis.machine_label).toBe("Beinpresse 7");
  });

  it("nennt einen gesperrten Tag gesperrt", async () => {
    const { token } = await tagAnlegen(serviceClient(), {
      studioId: studioA,
      status: "revoked",
    });
    expect((await befund(trainerA, token, studioA)).verdict).toBe("gesperrt");
  });

  it("nennt einen Tag aus verschrotteter Charge gesperrt", async () => {
    const admin = serviceClient();
    const { data: charge, error: chargeFehler } = await admin
      .from("tag_batches")
      .insert({
        code: `verschrottet-${crypto.randomUUID()}`,
        kind: "machine",
        quantity: 1,
        scrapped_at: new Date().toISOString(),
      })
      .select("id")
      .single();
    if (chargeFehler) throw chargeFehler;

    const token = createTagToken();
    const { error } = await admin.from("machine_tags").insert({
      studio_id: null,
      kind: "machine",
      status: "unassigned",
      token,
      batch_id: charge.id,
      batch_index: 1,
    });
    if (error) throw error;

    expect((await befund(trainerA, token, studioA)).verdict).toBe("gesperrt");
  });

  it("nennt ein aktives Aushangschild des eigenen Studios beim Namen", async () => {
    const { token } = await tagAnlegen(serviceClient(), {
      studioId: studioA,
      kind: "studio",
      status: "active",
    });
    expect((await befund(trainerA, token, studioA)).verdict).toBe("aushangschild");
  });

  it("verraet nichts ueber ein fremdes Studio", async () => {
    const { token } = await tagAnlegen(serviceClient(), {
      studioId: studioB,
      machineId: geraetB,
      status: "active",
    });
    const ergebnis = await befund(trainerA, token, studioA);
    expect(ergebnis.verdict).toBe("unbekannt");
    expect(ergebnis.machine_label).toBeNull();
  });

  it("verraet nichts ueber ein noch nicht geliefertes Schild", async () => {
    const { token } = await tagAnlegen(serviceClient(), {
      studioId: null,
      kind: "studio",
    });
    expect((await befund(trainerA, token, studioA)).verdict).toBe("unbekannt");
  });

  it("antwortet unbekannt auf einen Token, den es nicht gibt", async () => {
    expect((await befund(trainerA, createTagToken(), studioA)).verdict).toBe("unbekannt");
  });

  it("antwortet unbekannt, wenn der Fragende nicht zum Studio gehoert", async () => {
    const { token } = await tagAnlegen(serviceClient(), { studioId: null });
    expect((await befund(trainerA, token, studioB)).verdict).toBe("unbekannt");
  });
});

describe("bind_tag_to_machine", () => {
  it("bindet einen studiolosen Tag und vergibt dabei das Studio", async () => {
    const admin = serviceClient();
    const { token, id } = await tagAnlegen(admin, { studioId: null });

    const ergebnis = await binden(trainerA, token, geraetA);
    expect(ergebnis.verdict).toBe("gebunden");
    expect(ergebnis.tag_id).toBe(id);

    const { data } = await admin
      .from("machine_tags")
      .select("studio_id, machine_id, status")
      .eq("id", id)
      .single<{ studio_id: string; machine_id: string; status: string }>();
    expect(data?.studio_id).toBe(studioA);
    expect(data?.machine_id).toBe(geraetA);
    expect(data?.status).toBe("active");
  });

  it("bindet keinen Tag an ein fremdes Geraet", async () => {
    const { token } = await tagAnlegen(serviceClient(), { studioId: null });
    expect((await binden(trainerA, token, geraetB)).verdict).toBe("unbekannt");
  });

  it("bindet einen bereits gebundenen Tag nicht noch einmal", async () => {
    const { token } = await tagAnlegen(serviceClient(), { studioId: null });
    expect((await binden(trainerA, token, geraetA)).verdict).toBe("gebunden");
    expect((await binden(trainerA, token, geraetA)).verdict).toBe("vergeben");
  });

  it("bindet kein Aushangschild", async () => {
    const { token } = await tagAnlegen(serviceClient(), {
      studioId: studioA,
      kind: "studio",
      status: "active",
    });
    expect((await binden(trainerA, token, geraetA)).verdict).toBe("aushangschild");
  });

  it("bindet keinen gesperrten Tag", async () => {
    const { token } = await tagAnlegen(serviceClient(), {
      studioId: null,
      status: "revoked",
    });
    expect((await binden(trainerA, token, geraetA)).verdict).toBe("gesperrt");
  });
});
```

- [x] **Step 2: Test laufen lassen, Fehlschlag bestätigen**

```bash
pnpm test:integration -- tag-binden
```

Erwartet: FAIL — `Could not find the function public.inspect_tag`.

- [x] **Step 3: Die Migration schreiben**

`supabase/migrations/0028_tag_binden.sql`:

```sql
-- Ein studioloser Tag ist per RLS fuer jedes authenticated-Konto unsichtbar.
-- Der Sucher des Trainers saehe bei "frischer Tag aus eurer Lieferung" und bei
-- "fremder QR-Code" deshalb dasselbe: nichts. Das sind aber Zeile 1 und Zeile 5
-- der Antworttabelle -- die eine fuehrt zu Verbinden, die andere zu "melde dich
-- beim Betreiber". Ohne Lesefunktion ist die Tabelle nicht baubar.
--
-- Spec: docs/superpowers/specs/2026-09-01-tag-lieferung-design.md, Abschnitt 3.
-- Antworttabelle: 2026-09-01-einrichtung-am-geraet-design.md, Abschnitt 4.

create function public.inspect_tag(p_token text, p_studio_id uuid)
returns table (
  verdict       text,
  batch_code    text,
  batch_index   integer,
  machine_id    uuid,
  machine_label text
)
language plpgsql
security definer
set search_path = public, pg_temp
stable
as $$
declare
  t record;
begin
  -- Kein unauthorized, kein Fehler: wer nicht zum Studio gehoert, bekommt
  -- dieselbe Antwort wie auf einen Token, den es nicht gibt.
  if not public.is_studio_staff(p_studio_id) then
    return query select 'unbekannt'::text, null::text, null::integer, null::uuid, null::text;
    return;
  end if;

  select mt.id, mt.kind, mt.status, mt.studio_id, mt.machine_id, mt.batch_index,
         b.code as batch_code, b.scrapped_at, m.label as machine_label
    into t
    from public.machine_tags mt
    join public.tag_batches   b on b.id = mt.batch_id
    left join public.machines m on m.id = mt.machine_id
   where mt.token = p_token;

  -- Die Studiozugehoerigkeit wird ZUERST geprueft, und das ist keine
  -- Geschmackssache: ein gesperrter Tag eines fremden Studios muss unbekannt
  -- heissen, nicht gesperrt. Sonst verraet die Antwort seine Existenz.
  if not found
     or (t.studio_id is not null and t.studio_id <> p_studio_id) then
    return query select 'unbekannt'::text, null::text, null::integer, null::uuid, null::text;
    return;
  end if;

  if t.kind = 'studio' then
    if t.studio_id = p_studio_id and t.status = 'active' then
      -- Sackgasse mit genau einem Ausgang: das Schild ist bereits gueltig und
      -- gehoert an die Wand. Nichts zu verbinden, nichts freizuschalten.
      return query select 'aushangschild'::text, t.batch_code, t.batch_index, null::uuid, null::text;
    elsif t.studio_id = p_studio_id then
      return query select 'gesperrt'::text, t.batch_code, t.batch_index, null::uuid, null::text;
    else
      -- Ein studioloses Schild ist ein Versandfehler und noch nicht gueltig.
      return query select 'unbekannt'::text, null::text, null::integer, null::uuid, null::text;
    end if;
    return;
  end if;

  -- ab hier: kind = 'machine'
  if t.scrapped_at is not null or t.status in ('revoked', 'replaced') then
    return query select 'gesperrt'::text, t.batch_code, t.batch_index, null::uuid, null::text;
    return;
  end if;

  if t.status = 'unassigned' and t.machine_id is null then
    return query select 'frei'::text, t.batch_code, t.batch_index, null::uuid, null::text;
    return;
  end if;

  if t.status = 'active' and t.machine_id is not null then
    return query select 'vergeben'::text, t.batch_code, t.batch_index, t.machine_id, t.machine_label;
    return;
  end if;

  return query select 'unbekannt'::text, null::text, null::integer, null::uuid, null::text;
end
$$;

-- Das Studio kommt aus der MASCHINE, nicht aus einem Parameter. Waere es ein
-- Parameter, koennte der Aufrufer die Zuordnung selbst waehlen -- und die
-- Update-Policy aus 0016, die sonst dagegen stuende, greift fuer eine
-- studiolose Zeile nicht (is_studio_staff(null) ist false).
create function public.bind_tag_to_machine(p_token text, p_machine_id uuid)
returns table (verdict text, tag_id uuid)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_studio uuid;
  v_tag    record;
begin
  select m.studio_id into v_studio
    from public.machines m
   where m.id = p_machine_id
     and m.status = 'active';

  if v_studio is null or not public.is_studio_staff(v_studio) then
    return query select 'unbekannt'::text, null::uuid;
    return;
  end if;

  -- for update of mt sperrt nur die machine_tags-Zeile, nicht die Charge.
  -- Ohne sie waere das Rennen zweier Trainer an derselben Packung eine
  -- Constraint-Verletzung statt einer Antwort.
  select mt.id, mt.kind, mt.status, mt.studio_id, mt.machine_id, b.scrapped_at
    into v_tag
    from public.machine_tags mt
    join public.tag_batches  b on b.id = mt.batch_id
   where mt.token = p_token
     for update of mt;

  if not found
     or (v_tag.studio_id is not null and v_tag.studio_id <> v_studio) then
    return query select 'unbekannt'::text, null::uuid;
    return;
  end if;

  if v_tag.kind = 'studio' then
    if v_tag.studio_id = v_studio and v_tag.status = 'active' then
      return query select 'aushangschild'::text, null::uuid;
    elsif v_tag.studio_id = v_studio then
      return query select 'gesperrt'::text, null::uuid;
    else
      return query select 'unbekannt'::text, null::uuid;
    end if;
    return;
  end if;

  if v_tag.scrapped_at is not null or v_tag.status in ('revoked', 'replaced') then
    return query select 'gesperrt'::text, null::uuid;
    return;
  end if;

  if v_tag.machine_id is not null then
    return query select 'vergeben'::text, null::uuid;
    return;
  end if;

  update public.machine_tags
     set studio_id  = v_studio,
         machine_id = p_machine_id,
         status     = 'active'
   where id = v_tag.id;

  return query select 'gebunden'::text, v_tag.id;
end
$$;

-- revoke ... from public allein genuegt auf Supabase nicht: ALTER DEFAULT
-- PRIVILEGES gewaehrt EXECUTE zusaetzlich an anon, authenticated und
-- service_role. Ohne den ausdruecklichen Entzug waere jede dieser Funktionen
-- fuer alle drei aufrufbar. Die Lehre aus 0009.
revoke all on function public.inspect_tag(text, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.inspect_tag(text, uuid) to authenticated;

revoke all on function public.bind_tag_to_machine(text, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.bind_tag_to_machine(text, uuid) to authenticated;
```

- [x] **Step 4: Zurücksetzen und Test laufen lassen**

```bash
pnpm exec supabase db reset
pnpm test:integration -- tag-binden
```

Erwartet: PASS, alle vierzehn Fälle.

**Wenn „bindet keinen Tag an ein fremdes Geraet" fehlschlägt und `gebunden` liefert**, steht die Studioprüfung an der falschen Stelle: `is_studio_staff` muss gegen das Studio der *Maschine* laufen, nicht gegen das des Tags.

- [x] **Step 5: Den ganzen Bestand laufen lassen**

```bash
pnpm typecheck
pnpm test:integration
pnpm test:e2e
```

Erwartet: alles PASS.

- [x] **Step 6: Commit**

```bash
git add supabase/migrations/0028_tag_binden.sql tests/integration/tag-binden.test.ts
git commit -m "feat(db): inspect_tag und bind_tag_to_machine"
```

---

### Task 6: Die Betreiber-Fachschicht und die CLI-Schale

**Files:**
- Create: `packages/domain/src/chargen.ts`, `scripts/tags.ts`
- Modify: `packages/domain/package.json` (`exports`), `package.json` (Wurzel: `tsx`-devDependency und Skript)
- Test: `tests/integration/tag-chargen.test.ts` (ergänzen, nicht ersetzen)

**Interfaces:**
- Consumes: `createTagToken` aus `./tags.js`, `DomainError` aus `./errors.js`, die Tabellen aus `0027`.
- Produces, alle aus `@fitretro/domain/chargen`:
  - `chargeAnlegen(admin, { code, kind, menge, lieferant?, bestelltAm? })` → `Promise<Charge>`
  - `chargeLesen(admin, code)` → `Promise<Charge>`
  - `chargeZeilen(admin, code)` → `Promise<{ charge: Charge; zeilen: Array<{ nummer: number; token: string }> }>`
  - `chargeVerschrotten(admin, code)` → `Promise<void>`
  - `lieferungAnlegen(admin, { chargeCode, studioId, menge?, nummern? })` → `Promise<{ id: string; menge: number }>`
  - `bestand(admin, studioId)` → `Promise<{ geliefert: number; verbraucht: number; vorraetig: number }>`
  - `studioAufloesen(admin, bezeichnung)` → `Promise<string>`
  - Typ `Charge = { id: string; code: string; kind: TagSorte; quantity: number; scrappedAt: string | null }`, Typ `TagSorte = "machine" | "studio"`

**Warum nicht über `index.ts` exportiert.** Diese Funktionen ergeben nur mit einem Service-Client Sinn. Über den Unterpfad `@fitretro/domain/chargen` bleiben sie aus der Importfläche der Web-App heraus — dieselbe Bauart, die `media.ts` in der `exports`-Karte schon hat.

- [x] **Step 1: Den fehlschlagenden Test an `tag-chargen.test.ts` anhängen**

```ts
import {
  bestand,
  chargeAnlegen,
  chargeVerschrotten,
  chargeZeilen,
  lieferungAnlegen,
  studioAufloesen,
} from "@fitretro/domain/chargen";

describe("chargen.ts", () => {
  it("legt eine Charge samt studioloser Zeilen an", async () => {
    const admin = serviceClient();
    const code = `anlegen-${crypto.randomUUID()}`;
    const charge = await chargeAnlegen(admin, { code, kind: "machine", menge: 12 });
    expect(charge.quantity).toBe(12);

    const { data } = await admin
      .from("machine_tags")
      .select("batch_index, studio_id, status, kind")
      .eq("batch_id", charge.id)
      .order("batch_index", { ascending: true });
    expect(data).toHaveLength(12);
    expect(data?.[0]?.batch_index).toBe(1);
    expect(data?.[11]?.batch_index).toBe(12);
    expect(data?.every((zeile) => zeile.studio_id === null)).toBe(true);
    expect(data?.every((zeile) => zeile.status === "unassigned")).toBe(true);
  });

  it("lehnt eine zweite Charge mit demselben Code ab", async () => {
    const admin = serviceClient();
    const code = `doppelt-${crypto.randomUUID()}`;
    await chargeAnlegen(admin, { code, kind: "machine", menge: 1 });
    await expect(
      chargeAnlegen(admin, { code, kind: "machine", menge: 1 }),
    ).rejects.toMatchObject({ code: "conflict" });
  });

  it("liefert alle Zeilen einer Charge ueber die PostgREST-Grenze hinaus", async () => {
    const admin = serviceClient();
    const code = `blaettern-${crypto.randomUUID()}`;
    await chargeAnlegen(admin, { code, kind: "machine", menge: 1200 });

    const { zeilen } = await chargeZeilen(admin, code);
    expect(zeilen).toHaveLength(1200);
    expect(zeilen[0]?.nummer).toBe(1);
    expect(zeilen[1199]?.nummer).toBe(1200);
    expect(new Set(zeilen.map((zeile) => zeile.token)).size).toBe(1200);
    expect(zeilen[0]?.token).toMatch(/^[A-Za-z0-9_-]{22}$/);
  });

  it("schreibt fuer Geraetetags nur eine Lieferzeile und fasst keinen Token an", async () => {
    const admin = serviceClient();
    const code = `liefern-machine-${crypto.randomUUID()}`;
    const charge = await chargeAnlegen(admin, { code, kind: "machine", menge: 10 });

    const lieferung = await lieferungAnlegen(admin, {
      chargeCode: code,
      studioId: studioA,
      menge: 4,
    });
    expect(lieferung.menge).toBe(4);

    const { data } = await admin
      .from("machine_tags")
      .select("studio_id")
      .eq("batch_id", charge.id);
    expect(data?.every((zeile) => zeile.studio_id === null)).toBe(true);
  });

  it("aktiviert bei Aushangschildern genau die genannten Nummern", async () => {
    const admin = serviceClient();
    const code = `liefern-studio-${crypto.randomUUID()}`;
    const charge = await chargeAnlegen(admin, { code, kind: "studio", menge: 10 });

    const lieferung = await lieferungAnlegen(admin, {
      chargeCode: code,
      studioId: studioA,
      nummern: [3, 4, 5],
    });
    expect(lieferung.menge).toBe(3);

    const { data } = await admin
      .from("machine_tags")
      .select("batch_index, studio_id, status")
      .eq("batch_id", charge.id)
      .order("batch_index", { ascending: true });

    const aktiv = data?.filter((zeile) => zeile.status === "active") ?? [];
    expect(aktiv.map((zeile) => zeile.batch_index)).toEqual([3, 4, 5]);
    expect(aktiv.every((zeile) => zeile.studio_id === studioA)).toBe(true);
  });

  it("lehnt Menge bei Schildern und Nummern bei Geraetetags ab", async () => {
    const admin = serviceClient();
    const schilder = `falsch-studio-${crypto.randomUUID()}`;
    const geraete = `falsch-machine-${crypto.randomUUID()}`;
    await chargeAnlegen(admin, { code: schilder, kind: "studio", menge: 5 });
    await chargeAnlegen(admin, { code: geraete, kind: "machine", menge: 5 });

    await expect(
      lieferungAnlegen(admin, { chargeCode: schilder, studioId: studioA, menge: 2 }),
    ).rejects.toMatchObject({ code: "validation_failed" });

    await expect(
      lieferungAnlegen(admin, { chargeCode: geraete, studioId: studioA, nummern: [1] }),
    ).rejects.toMatchObject({ code: "validation_failed" });
  });

  it("laesst nicht mehr ausliefern als die Charge gross ist", async () => {
    const admin = serviceClient();
    const code = `zuviel-${crypto.randomUUID()}`;
    await chargeAnlegen(admin, { code, kind: "machine", menge: 10 });
    await lieferungAnlegen(admin, { chargeCode: code, studioId: studioA, menge: 8 });
    await expect(
      lieferungAnlegen(admin, { chargeCode: code, studioId: studioB, menge: 3 }),
    ).rejects.toMatchObject({ code: "conflict" });
  });

  it("liefert aus einer verschrotteten Charge nichts mehr", async () => {
    const admin = serviceClient();
    const code = `schrott-${crypto.randomUUID()}`;
    await chargeAnlegen(admin, { code, kind: "machine", menge: 5 });
    await chargeVerschrotten(admin, code);
    await expect(
      lieferungAnlegen(admin, { chargeCode: code, studioId: studioA, menge: 1 }),
    ).rejects.toMatchObject({ code: "conflict" });
  });

  it("rechnet den Bestand aus Lieferung minus gebundenen Tags", async () => {
    const admin = serviceClient();

    const { data: studio, error: studioFehler } = await admin
      .from("studios")
      .insert({ name: `Bestand ${crypto.randomUUID()}` })
      .select("id")
      .single();
    if (studioFehler) throw studioFehler;

    const code = `bestand-${crypto.randomUUID()}`;
    await chargeAnlegen(admin, { code, kind: "machine", menge: 100 });
    await lieferungAnlegen(admin, { chargeCode: code, studioId: studio.id, menge: 100 });

    const vorher = await bestand(admin, studio.id);
    expect(vorher).toEqual({ geliefert: 100, verbraucht: 0, vorraetig: 100 });

    await tagAnlegen(admin, { studioId: studio.id, kind: "machine", status: "unassigned" });
    const nachher = await bestand(admin, studio.id);
    expect(nachher.verbraucht).toBe(1);
    expect(nachher.vorraetig).toBe(99);
  });

  it("loest ein Studio ueber seinen Namen auf", async () => {
    const admin = serviceClient();
    const name = `Aufloesbar ${crypto.randomUUID()}`;
    const { data: studio, error } = await admin
      .from("studios")
      .insert({ name })
      .select("id")
      .single();
    if (error) throw error;

    expect(await studioAufloesen(admin, name)).toBe(studio.id);
    expect(await studioAufloesen(admin, studio.id)).toBe(studio.id);
    await expect(studioAufloesen(admin, "Gibt es nicht")).rejects.toMatchObject({
      code: "not_found",
    });
  });
});
```

- [x] **Step 2: Test laufen lassen, Fehlschlag bestätigen**

```bash
pnpm test:integration -- tag-chargen
```

Erwartet: FAIL beim Übersetzen — `Cannot find module '@fitretro/domain/chargen'`.

- [x] **Step 3: Den Unterpfad in der Paketkarte eintragen**

`packages/domain/package.json`:

```json
  "exports": {
    ".": "./src/index.ts",
    "./media": "./src/media.ts",
    "./chargen": "./src/chargen.ts"
  }
```

- [x] **Step 4: `chargen.ts` schreiben**

`packages/domain/src/chargen.ts`:

```ts
import type { SupabaseClient } from "@supabase/supabase-js";
import { DomainError } from "./errors.js";
import { createTagToken } from "./tags.js";

/**
 * Die Betreiberseite des Tokenraums: Chargen herstellen, an Studios ausliefern,
 * Bestand nachrechnen. Kein Bildschirm, kein Portal-Aufruf -- diese Funktionen
 * ergeben nur mit einem Service-Client Sinn und sind deshalb ueber den
 * Unterpfad "@fitretro/domain/chargen" erreichbar, nicht ueber den Hauptexport.
 *
 * Spec: docs/superpowers/specs/2026-09-01-tag-lieferung-design.md, Abschnitt 4.
 */

export type TagSorte = "machine" | "studio";

export type Charge = {
  id: string;
  code: string;
  kind: TagSorte;
  quantity: number;
  scrappedAt: string | null;
};

type ChargenZeile = {
  id: string;
  code: string;
  kind: TagSorte;
  quantity: number;
  scrapped_at: string | null;
};

/**
 * PostgREST liefert hoechstens max_rows Zeilen (1000, supabase/config.toml).
 * Eine Tausendercharge traefe die Grenze exakt und waere still abgeschnitten,
 * also wird in kleineren Bloecken gelesen und geschrieben.
 */
const BLOCK = 500;

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function zuCharge(zeile: ChargenZeile): Charge {
  return {
    id: zeile.id,
    code: zeile.code,
    kind: zeile.kind,
    quantity: zeile.quantity,
    scrappedAt: zeile.scrapped_at,
  };
}

export async function chargeLesen(
  admin: SupabaseClient,
  code: string,
): Promise<Charge> {
  const { data, error } = await admin
    .from("tag_batches")
    .select("id, code, kind, quantity, scrapped_at")
    .eq("code", code)
    .maybeSingle<ChargenZeile>();
  if (error) throw new DomainError("internal", error.message);
  if (!data) throw new DomainError("not_found", `Die Charge ${code} gibt es nicht.`);
  return zuCharge(data);
}

export async function chargeAnlegen(
  admin: SupabaseClient,
  eingabe: {
    code: string;
    kind: TagSorte;
    menge: number;
    lieferant?: string | null | undefined;
    bestelltAm?: string | null | undefined;
  },
): Promise<Charge> {
  if (!Number.isInteger(eingabe.menge) || eingabe.menge < 1) {
    throw new DomainError("validation_failed", "Die Menge ist eine ganze Zahl ab 1.");
  }
  if (eingabe.code.trim() === "") {
    throw new DomainError("validation_failed", "Die Charge braucht einen Code.");
  }

  const { data, error } = await admin
    .from("tag_batches")
    .insert({
      code: eingabe.code,
      kind: eingabe.kind,
      quantity: eingabe.menge,
      supplier: eingabe.lieferant ?? null,
      ordered_on: eingabe.bestelltAm ?? null,
    })
    .select("id, code, kind, quantity, scrapped_at")
    .single<ChargenZeile>();

  if (error?.code === "23505") {
    throw new DomainError("conflict", `Die Charge ${eingabe.code} gibt es schon.`);
  }
  if (error || !data) {
    throw new DomainError("internal", error?.message ?? "Charge nicht angelegt.");
  }

  for (let von = 1; von <= eingabe.menge; von += BLOCK) {
    const bis = Math.min(von + BLOCK - 1, eingabe.menge);
    await blockSchreiben(admin, data.id, eingabe.kind, von, bis);
  }

  return zuCharge(data);
}

/**
 * Ein Kollisionstreffer auf token ist bei 128 Bit astronomisch unwahrscheinlich
 * -- aber ein Abbruch mitten in einer Tausendercharge waere teurer als diese
 * vier Zeilen, weil die halb geschriebene Charge von Hand aufzuraeumen waere.
 */
async function blockSchreiben(
  admin: SupabaseClient,
  batchId: string,
  kind: TagSorte,
  von: number,
  bis: number,
): Promise<void> {
  for (let versuch = 0; versuch < 5; versuch += 1) {
    const zeilen = [];
    for (let nummer = von; nummer <= bis; nummer += 1) {
      zeilen.push({
        batch_id: batchId,
        batch_index: nummer,
        kind,
        token: createTagToken(),
        status: "unassigned",
        studio_id: null,
      });
    }
    const { error } = await admin.from("machine_tags").insert(zeilen);
    if (!error) return;
    if (error.code !== "23505") throw new DomainError("internal", error.message);
  }
  throw new DomainError(
    "internal",
    `Block ${von}-${bis} liess sich nach fuenf Versuchen nicht schreiben.`,
  );
}

export async function chargeZeilen(
  admin: SupabaseClient,
  code: string,
): Promise<{ charge: Charge; zeilen: Array<{ nummer: number; token: string }> }> {
  const charge = await chargeLesen(admin, code);
  const zeilen: Array<{ nummer: number; token: string }> = [];

  for (let versatz = 0; ; versatz += BLOCK) {
    const { data, error } = await admin
      .from("machine_tags")
      .select("batch_index, token")
      .eq("batch_id", charge.id)
      .order("batch_index", { ascending: true })
      .range(versatz, versatz + BLOCK - 1);
    if (error) throw new DomainError("internal", error.message);

    const block = (data ?? []) as Array<{ batch_index: number; token: string }>;
    for (const reihe of block) {
      zeilen.push({ nummer: reihe.batch_index, token: reihe.token });
    }
    if (block.length < BLOCK) break;
  }

  return { charge, zeilen };
}

export async function chargeVerschrotten(
  admin: SupabaseClient,
  code: string,
): Promise<void> {
  const charge = await chargeLesen(admin, code);
  if (charge.scrappedAt) {
    throw new DomainError("conflict", `Die Charge ${code} ist bereits verschrottet.`);
  }
  const { error } = await admin
    .from("tag_batches")
    .update({ scrapped_at: new Date().toISOString() })
    .eq("id", charge.id);
  if (error) throw new DomainError("internal", error.message);
}

export async function lieferungAnlegen(
  admin: SupabaseClient,
  eingabe: {
    chargeCode: string;
    studioId: string;
    menge?: number | undefined;
    nummern?: number[] | undefined;
  },
): Promise<{ id: string; menge: number }> {
  const charge = await chargeLesen(admin, eingabe.chargeCode);
  if (charge.scrappedAt) {
    throw new DomainError(
      "conflict",
      `Die Charge ${charge.code} ist verschrottet und liefert nichts mehr.`,
    );
  }

  const hatMenge = eingabe.menge !== undefined;
  const hatNummern = eingabe.nummern !== undefined && eingabe.nummern.length > 0;
  if (hatMenge === hatNummern) {
    throw new DomainError(
      "validation_failed",
      "Entweder eine Menge oder eine Nummernliste, nie beides.",
    );
  }
  if (charge.kind === "machine" && !hatMenge) {
    throw new DomainError(
      "validation_failed",
      "Geraetetags werden mit einer Menge geliefert, nicht mit Nummern -- sie lernen ihr Studio erst beim Scan.",
    );
  }
  if (charge.kind === "studio" && !hatNummern) {
    throw new DomainError(
      "validation_failed",
      "Aushangschilder werden mit ihren aufgedruckten Nummern geliefert, nicht mit einer Menge.",
    );
  }

  const menge = hatMenge ? eingabe.menge! : eingabe.nummern!.length;
  if (!Number.isInteger(menge) || menge < 1) {
    throw new DomainError("validation_failed", "Die Menge ist eine ganze Zahl ab 1.");
  }

  const { data: bisher, error: bisherFehler } = await admin
    .from("tag_shipments")
    .select("quantity")
    .eq("batch_id", charge.id);
  if (bisherFehler) throw new DomainError("internal", bisherFehler.message);

  const schonGeliefert = (bisher ?? []).reduce(
    (summe: number, zeile: { quantity: number }) => summe + zeile.quantity,
    0,
  );
  if (schonGeliefert + menge > charge.quantity) {
    throw new DomainError(
      "conflict",
      `Die Charge ${charge.code} hat ${charge.quantity} Tags, davon sind ${schonGeliefert} ausgeliefert. ${menge} passen nicht mehr hinein.`,
    );
  }

  // Erst die Schilder aktivieren, dann die Lieferzeile schreiben. Bricht der
  // zweite Schritt ab, fehlen sie in der Vorratsanzeige -- sie funktionieren
  // aber. Andersherum verspraeche der Vorrat Schilder, die nicht gelten.
  if (charge.kind === "studio") {
    await schilderAktivieren(admin, charge, eingabe.studioId, eingabe.nummern!);
  }

  const { data, error } = await admin
    .from("tag_shipments")
    .insert({ batch_id: charge.id, studio_id: eingabe.studioId, quantity: menge })
    .select("id")
    .single<{ id: string }>();
  if (error || !data) {
    throw new DomainError("internal", error?.message ?? "Lieferung nicht angelegt.");
  }

  return { id: data.id, menge };
}

async function schilderAktivieren(
  admin: SupabaseClient,
  charge: Charge,
  studioId: string,
  nummern: number[],
): Promise<void> {
  const { data, error } = await admin
    .from("machine_tags")
    .select("batch_index, studio_id, status")
    .eq("batch_id", charge.id)
    .in("batch_index", nummern);
  if (error) throw new DomainError("internal", error.message);

  const gefunden = (data ?? []) as Array<{
    batch_index: number;
    studio_id: string | null;
    status: string;
  }>;

  const untauglich = [
    ...nummern.filter((nummer) => !gefunden.some((zeile) => zeile.batch_index === nummer)),
    ...gefunden
      .filter((zeile) => zeile.studio_id !== null || zeile.status !== "unassigned")
      .map((zeile) => zeile.batch_index),
  ].sort((a, b) => a - b);

  if (untauglich.length > 0) {
    throw new DomainError(
      "conflict",
      `Diese Nummern sind in Charge ${charge.code} nicht lieferbar: ${untauglich.join(", ")}.`,
    );
  }

  const { error: schreibFehler } = await admin
    .from("machine_tags")
    .update({ studio_id: studioId, status: "active" })
    .eq("batch_id", charge.id)
    .in("batch_index", nummern);
  if (schreibFehler) throw new DomainError("internal", schreibFehler.message);
}

export async function bestand(
  admin: SupabaseClient,
  studioId: string,
): Promise<{ geliefert: number; verbraucht: number; vorraetig: number }> {
  const { data: lieferungen, error: lieferFehler } = await admin
    .from("tag_shipments")
    .select("quantity, tag_batches!inner (kind)")
    .eq("studio_id", studioId)
    .eq("tag_batches.kind", "machine");
  if (lieferFehler) throw new DomainError("internal", lieferFehler.message);

  const geliefert = (lieferungen ?? []).reduce(
    (summe: number, zeile: { quantity: number }) => summe + zeile.quantity,
    0,
  );

  const { count, error: zaehlFehler } = await admin
    .from("machine_tags")
    .select("id", { count: "exact", head: true })
    .eq("studio_id", studioId)
    .eq("kind", "machine");
  if (zaehlFehler) throw new DomainError("internal", zaehlFehler.message);

  const verbraucht = count ?? 0;
  return { geliefert, verbraucht, vorraetig: geliefert - verbraucht };
}

export async function studioAufloesen(
  admin: SupabaseClient,
  bezeichnung: string,
): Promise<string> {
  if (UUID.test(bezeichnung)) {
    const { data, error } = await admin
      .from("studios")
      .select("id")
      .eq("id", bezeichnung)
      .maybeSingle<{ id: string }>();
    if (error) throw new DomainError("internal", error.message);
    if (!data) throw new DomainError("not_found", "Dieses Studio gibt es nicht.");
    return data.id;
  }

  const { data, error } = await admin
    .from("studios")
    .select("id, name")
    .eq("name", bezeichnung);
  if (error) throw new DomainError("internal", error.message);

  const treffer = (data ?? []) as Array<{ id: string; name: string }>;
  if (treffer.length === 0) {
    throw new DomainError("not_found", `Kein Studio heisst "${bezeichnung}".`);
  }
  if (treffer.length > 1) {
    throw new DomainError(
      "conflict",
      `Mehrere Studios heissen "${bezeichnung}": ${treffer.map((zeile) => zeile.id).join(", ")}. Nimm die UUID.`,
    );
  }
  return treffer[0]!.id;
}
```

- [x] **Step 5: Tests laufen lassen**

```bash
pnpm test:integration -- tag-chargen
```

Erwartet: PASS.

**Wenn „liefert alle Zeilen einer Charge ueber die PostgREST-Grenze hinaus" nur 1000 Zeilen findet**, fehlt das `.range()` — nicht die Blockgröße vergrößern, sondern blättern. `max_rows` ist eine Servergrenze und lässt sich vom Client nicht überschreiben.

- [x] **Step 6: Die CLI-Schale schreiben**

`scripts/tags.ts`:

```ts
#!/usr/bin/env tsx
import { writeFileSync } from "node:fs";
import { parseArgs } from "node:util";
import { createClient } from "@supabase/supabase-js";
import "dotenv/config";
import { DomainError } from "@fitretro/domain";
import {
  bestand,
  chargeAnlegen,
  chargeVerschrotten,
  chargeZeilen,
  lieferungAnlegen,
  studioAufloesen,
  type TagSorte,
} from "@fitretro/domain/chargen";

/**
 * Das Betreiberwerkzeug. Es schreibt mit dem Service-Role-Schluessel und laeuft
 * irgendwann gegen das echte Projekt -- deshalb nennt es vor jeder schreibenden
 * Handlung sein Ziel und verlangt ausserhalb von 127.0.0.1 ein zusaetzliches
 * --ja.
 *
 * Tokens erscheinen nie auf stdout. Das einzige Erzeugnis, das sie im Klartext
 * zeigt, ist die CSV-Datei fuer den Lieferanten.
 */

const HILFE = `Aufruf: pnpm tags <befehl> [optionen]

  charge:anlegen      --code <text> --sorte machine|studio --menge <zahl>
                      [--lieferant <text>] [--bestellt <JJJJ-MM-TT>]
  charge:csv          --code <text> [--basis <url>] [--datei <pfad>]
  charge:verschrotten --code <text>
  lieferung           --charge <text> --studio <uuid|name>
                      (--menge <zahl> | --nummern 3-7,9)
  bestand             --studio <uuid|name>

  --ja                bestaetigt eine Schreibhandlung gegen ein nicht-lokales Ziel
`;

function pflicht(werte: Record<string, unknown>, name: string): string {
  const wert = werte[name];
  if (typeof wert !== "string" || wert === "") {
    throw new DomainError("validation_failed", `--${name} fehlt.`);
  }
  return wert;
}

function zahl(werte: Record<string, unknown>, name: string): number | undefined {
  const wert = werte[name];
  if (typeof wert !== "string") return undefined;
  const geparst = Number(wert);
  if (!Number.isInteger(geparst)) {
    throw new DomainError("validation_failed", `--${name} ist keine ganze Zahl.`);
  }
  return geparst;
}

/** "3-7,9" wird zu [3,4,5,6,7,9]. Bereiche und Aufzaehlungen gemischt. */
function nummern(werte: Record<string, unknown>): number[] | undefined {
  const wert = werte["nummern"];
  if (typeof wert !== "string") return undefined;

  const ergebnis = new Set<number>();
  for (const teil of wert.split(",")) {
    const bereich = teil.trim().match(/^(\d+)\s*-\s*(\d+)$/);
    if (bereich) {
      const von = Number(bereich[1]);
      const bis = Number(bereich[2]);
      if (bis < von) {
        throw new DomainError("validation_failed", `Der Bereich ${teil} laeuft rueckwaerts.`);
      }
      for (let n = von; n <= bis; n += 1) ergebnis.add(n);
      continue;
    }
    const einzeln = Number(teil.trim());
    if (!Number.isInteger(einzeln) || einzeln < 1) {
      throw new DomainError("validation_failed", `"${teil}" ist keine Nummer.`);
    }
    ergebnis.add(einzeln);
  }
  return [...ergebnis].sort((a, b) => a - b);
}

function sorte(werte: Record<string, unknown>): TagSorte {
  const wert = pflicht(werte, "sorte");
  if (wert !== "machine" && wert !== "studio") {
    throw new DomainError("validation_failed", "--sorte ist machine oder studio.");
  }
  return wert;
}

function umgebung(name: string): string {
  const wert = process.env[name];
  if (!wert) throw new DomainError("validation_failed", `Umgebungsvariable ${name} fehlt.`);
  return wert;
}

function zielPruefen(url: string, ja: boolean): void {
  console.log(`Ziel: ${url}`);
  const lokal = url.includes("127.0.0.1") || url.includes("localhost");
  if (!lokal && !ja) {
    throw new DomainError(
      "validation_failed",
      "Das ist kein lokales Ziel. Wiederhole den Aufruf mit --ja, wenn du das willst.",
    );
  }
}

async function main(): Promise<void> {
  const befehl = process.argv[2];
  if (!befehl || befehl === "--help" || befehl === "-h") {
    console.log(HILFE);
    return;
  }

  const { values } = parseArgs({
    args: process.argv.slice(3),
    options: {
      code: { type: "string" },
      sorte: { type: "string" },
      menge: { type: "string" },
      lieferant: { type: "string" },
      bestellt: { type: "string" },
      basis: { type: "string" },
      datei: { type: "string" },
      charge: { type: "string" },
      studio: { type: "string" },
      nummern: { type: "string" },
      ja: { type: "boolean", default: false },
    },
    strict: true,
  });

  const url = umgebung("SUPABASE_URL");
  const admin = createClient(url, umgebung("SUPABASE_SERVICE_ROLE_KEY"), {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  switch (befehl) {
    case "charge:anlegen": {
      zielPruefen(url, values.ja === true);
      const menge = zahl(values, "menge");
      if (menge === undefined) throw new DomainError("validation_failed", "--menge fehlt.");
      const charge = await chargeAnlegen(admin, {
        code: pflicht(values, "code"),
        kind: sorte(values),
        menge,
        lieferant: values.lieferant ?? null,
        bestelltAm: values.bestellt ?? null,
      });
      console.log(`Charge ${charge.code} angelegt: ${charge.quantity} Tags der Sorte ${charge.kind}.`);
      return;
    }

    case "charge:csv": {
      const code = pflicht(values, "code");
      const basis = values.basis ?? process.env["TAG_URL_BASE"];
      if (!basis) {
        throw new DomainError(
          "validation_failed",
          "--basis fehlt und TAG_URL_BASE ist nicht gesetzt. Eine CSV mit halben URLs ist beim Lieferanten nicht mehr zu reparieren.",
        );
      }
      const { charge, zeilen } = await chargeZeilen(admin, code);
      const ziel = values.datei ?? `charge-${charge.code}.csv`;
      const inhalt = [
        "nummer,charge,sorte,token,url",
        ...zeilen.map(
          (zeile) =>
            `${zeile.nummer},${charge.code},${charge.kind},${zeile.token},${basis.replace(/\/$/, "")}/t/${zeile.token}`,
        ),
      ].join("\n");
      writeFileSync(ziel, `${inhalt}\n`, "utf8");
      console.log(`${zeilen.length} Zeilen nach ${ziel} geschrieben.`);
      return;
    }

    case "charge:verschrotten": {
      zielPruefen(url, values.ja === true);
      const code = pflicht(values, "code");
      await chargeVerschrotten(admin, code);
      console.log(`Charge ${code} verschrottet. Sie liefert nichts mehr.`);
      return;
    }

    case "lieferung": {
      zielPruefen(url, values.ja === true);
      const studioId = await studioAufloesen(admin, pflicht(values, "studio"));
      const ergebnis = await lieferungAnlegen(admin, {
        chargeCode: pflicht(values, "charge"),
        studioId,
        menge: zahl(values, "menge"),
        nummern: nummern(values),
      });
      console.log(`Lieferung angelegt: ${ergebnis.menge} Tags an ${studioId}.`);
      return;
    }

    case "bestand": {
      const studioId = await studioAufloesen(admin, pflicht(values, "studio"));
      const zahlen = await bestand(admin, studioId);
      console.log(
        `geliefert ${zahlen.geliefert} - verbraucht ${zahlen.verbraucht} = vorraetig ${zahlen.vorraetig}`,
      );
      return;
    }

    default:
      throw new DomainError("validation_failed", `Unbekannter Befehl "${befehl}".\n\n${HILFE}`);
  }
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

- [x] **Step 7: `tsx` und das Skript eintragen**

```bash
pnpm add -Dw tsx
```

In `package.json` (Wurzel) bei `scripts` ergänzen:

```json
    "tags": "tsx scripts/tags.ts",
```

- [x] **Step 8: Die Schale von Hand ausprobieren**

```bash
pnpm tags charge:anlegen --code probe-01 --sorte machine --menge 5
pnpm tags charge:csv --code probe-01 --basis https://example.test --datei /tmp/probe-01.csv
head -3 /tmp/probe-01.csv
pnpm tags charge:verschrotten --code probe-01
```

Erwartet: die CSV hat sechs Zeilen (Kopf plus fünf), die `url`-Spalte endet auf denselben Token wie die `token`-Spalte, und **kein Token steht in der Terminalausgabe**.

- [x] **Step 9: Alles laufen lassen**

```bash
pnpm typecheck
pnpm test:integration
```

Erwartet: PASS.

- [x] **Step 10: Commit**

```bash
git add packages/domain/src/chargen.ts packages/domain/package.json scripts/tags.ts package.json pnpm-lock.yaml tests/integration/tag-chargen.test.ts
git commit -m "feat(chargen): Betreiberwerkzeug fuer Chargen, Lieferungen und Bestand"
```

---

### Task 7: `TagZuweisen` wird zum Rückfallweg

**Files:**
- Create: `apps/web/app/portal/[studioId]/tags/TagBinden.tsx`
- Delete: `apps/web/app/portal/[studioId]/tags/TagZuweisen.tsx`
- Modify: `apps/web/app/portal/actions.ts`, `apps/web/app/portal/[studioId]/tags/page.tsx`, `e2e/trainerportal.spec.ts`

**Interfaces:**
- Consumes: `bind_tag_to_machine` aus `0028`.
- Produces: Server Action `tagBinden(studioId, pfad, token, machineId)` → `{ ok: true; verdict: string } | { ok: false; error: string }`, und die Komponente `TagBinden`.

**Warum das nicht ersatzlos entfällt.** `TagZuweisen` ist heute der einzige Weg im Portal, einen Tag an ein Gerät zu binden, und sein Mittel — ein Dropdown über die Tags des Studios — hat nichts mehr zu listen: Haldenzeilen sind per RLS unsichtbar. Ein Feld zum Eintippen des Tokens ist derselbe Weg ohne Kamera. Der Sucher setzt später die Kamera davor, statt bei null anzufangen, und `2026-09-01-einrichtung-am-geraet-design.md` §7 verliert seinen Punkt *„einziger Ausfallpunkt ohne Rückfallweg"*.

- [x] **Step 1: Die Server Action ersetzen**

In `apps/web/app/portal/actions.ts` `tagZuweisen` löschen und dafür einsetzen:

```ts
const BINDE_TEXT: Record<string, string> = {
  vergeben: "Dieser Tag hängt schon an einem Gerät.",
  gesperrt: "Gesperrt bleibt gesperrt.",
  aushangschild: "Das ist ein Aushangschild — es gehört an die Wand, nicht an ein Gerät.",
  unbekannt: "Neue Lieferung? Melde dich beim Betreiber.",
};

/**
 * Einen gelieferten Tag an ein Geraet binden. Das Studio kommt aus dem Geraet,
 * nicht von hier -- die Funktion in 0028 leitet es selbst ab und prueft den
 * Aufrufer dagegen.
 */
export async function tagBinden(
  studioId: string,
  pfad: string,
  token: string,
  machineId: string,
): Promise<{ ok: true } | { ok: false; error: string }> {
  const client = await createServerSupabaseClient();
  const { data, error } = await client.rpc("bind_tag_to_machine", {
    p_token: token.trim(),
    p_machine_id: machineId,
  });

  if (error) {
    console.error("Tag nicht gebunden:", error);
    return { ok: false, error: "Der Tag liess sich nicht binden." };
  }

  const verdict = (data as Array<{ verdict: string }> | null)?.[0]?.verdict ?? "unbekannt";
  if (verdict === "gebunden") {
    revalidatePath(pfad);
    return { ok: true };
  }
  return { ok: false, error: BINDE_TEXT[verdict] ?? BINDE_TEXT["unbekannt"]! };
}
```

- [x] **Step 2: Die Komponente schreiben**

`apps/web/app/portal/[studioId]/tags/TagBinden.tsx`:

```tsx
"use client";

import { useState, useTransition } from "react";
import { tagBinden } from "../../actions";
import styles from "../../portal.module.css";

/**
 * Der Sucher ohne Kamera. Tags kommen als Lieferung und sind vor dem Scan
 * nicht benennbar -- ein Dropdown haette nichts zu listen, weil eine
 * Haldenzeile per RLS unsichtbar ist. Bis der Sucher steht, ist dies der Weg;
 * danach bleibt es der Rueckfallweg fuer eine verweigerte Kamerafreigabe.
 */
export function TagBinden({
  studioId,
  pfad,
  geraete,
}: {
  studioId: string;
  pfad: string;
  geraete: Array<{ id: string; label: string; modell: string }>;
}) {
  const [token, setToken] = useState("");
  const [machineId, setMachineId] = useState("");
  const [fehler, setFehler] = useState<string | null>(null);
  const [laeuft, starte] = useTransition();

  if (geraete.length === 0) {
    return (
      <span className={styles.hint}>
        Kein Gerät in Betrieb, an das ein Tag gehören könnte.
      </span>
    );
  }

  return (
    <div className={styles.field}>
      {fehler ? (
        <span className={styles.error} role="alert">
          {fehler}
        </span>
      ) : null}
      <label className={styles.label} htmlFor="tag-token">
        Token vom Tag
      </label>
      <input
        id="tag-token"
        className={styles.input}
        value={token}
        placeholder="22 Zeichen"
        onChange={(ereignis) => setToken(ereignis.target.value)}
      />
      <select
        className={styles.select}
        value={machineId}
        aria-label="Gerät auswählen"
        onChange={(ereignis) => setMachineId(ereignis.target.value)}
      >
        <option value="">Gerät wählen …</option>
        {geraete.map((geraet) => (
          <option key={geraet.id} value={geraet.id}>
            {geraet.label} — {geraet.modell}
          </option>
        ))}
      </select>
      <button
        type="button"
        className={styles.secondary}
        disabled={laeuft || token.trim() === "" || machineId === ""}
        onClick={() => {
          setFehler(null);
          starte(async () => {
            const antwort = await tagBinden(studioId, pfad, token, machineId);
            if (antwort.ok) setToken("");
            else setFehler(antwort.error);
          });
        }}
      >
        {laeuft ? "Wird verbunden …" : "Verbinden"}
      </button>
    </div>
  );
}
```

*Die Klassen `field`, `label`, `input`, `select`, `secondary`, `error` und `hint` stehen alle in `apps/web/app/portal/portal.module.css` — der Import `styles from "../../portal.module.css"` zeigt aus `tags/` zwei Ebenen hoch auf genau diese Datei, wie schon in `TagZuweisen.tsx`.*

- [x] **Step 3: Die Tags-Seite umstellen**

In `apps/web/app/portal/[studioId]/tags/page.tsx`:

- Import `TagZuweisen` durch `TagBinden` ersetzen.
- Den Block, der je Zeile `<TagZuweisen … />` rendert (die Bedingung `tag.status === "unassigned"`), ersatzlos entfernen — eine vorrätige Zeile erscheint gar nicht mehr in der Liste, weil ein studioloser Tag für den Trainer unsichtbar ist.
- Über der Liste einen eigenen Abschnitt einsetzen:

```tsx
      <section className={styles.section}>
        <div className={styles.sectionHead}>
          <h2 className={styles.sectionTitle}>Tag verbinden</h2>
          <span className={styles.sectionNote}>
            Token vom Aufkleber abtippen, Gerät wählen.
          </span>
        </div>
        <div className={styles.sectionBody}>
          <TagBinden studioId={studioId} pfad={pfad} geraete={freieGeraete} />
        </div>
      </section>
```

`TagZuweisen.tsx` löschen.

- [x] **Step 4: Den E2E-Gang wieder auf die Oberfläche drehen**

In `e2e/trainerportal.spec.ts` den in Aufgabe 2 eingesetzten Block ersetzen. Statt einen fertig gebundenen Tag zu seeden, entsteht jetzt eine Haldenzeile, die über die Oberfläche gebunden wird:

```ts
  // 5. Tag -- er kommt aus der Lieferung und wird vor dem Geraet verbunden.
  const { token } = await tagAnlegen(admin, { studioId: null });

  await page.goto(`/portal/${studio.id}/tags`);
  await page.getByLabel("Token vom Tag").fill(token);
  await page.getByLabel("Gerät auswählen").selectOption({ label: /^12 — / });
  await page.getByRole("button", { name: "Verbinden" }).click();
  await expect(page.getByText("aktiv")).toBeVisible();
```

- [x] **Step 5: Alles laufen lassen**

```bash
pnpm typecheck
pnpm test:integration
pnpm test:e2e
```

Erwartet: alles PASS.

- [x] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(portal): Tag ueber den Token binden statt ueber ein Dropdown"
```

---

### Task 8: Die Vorratszeile auf der Tags-Seite

**Files:**
- Modify: `packages/domain/src/catalog.ts` (`CatalogTag`, `StudioCatalog`, `getStudioCatalog`), `packages/domain/src/index.ts`, `apps/web/app/portal/[studioId]/tags/page.tsx`
- Test: `tests/integration/domain-catalog.test.ts` (ergänzen, nicht ersetzen)

**Interfaces:**
- Consumes: `tag_shipments` und `tag_batches` aus `0027`, `machine_tags.batch_id`/`batch_index`.
- Produces: `CatalogTag` um `batchCode: string` und `batchIndex: number` erweitert; `StudioCatalog` um `shipments: CatalogShipment[]` erweitert, mit `CatalogShipment = { id: string; batchCode: string; kind: "machine" | "studio"; quantity: number; shippedOn: string }`.

**Was die Seite danach zeigt.** `Tags.dc.html` zeichnet *„Lieferung vom 12. August · 100 Tags · 97 vorrätig"* und je Tag *„Charge 7"* bereits. Diese Aufgabe gibt beidem seine Quelle.

- [x] **Step 1: Den fehlschlagenden Test an `domain-catalog.test.ts` anhängen**

```ts
describe("Lieferungen im Katalog", () => {
  it("liefert Charge und Nummer je Tag", async () => {
    const client = await userClient(trainerEmail);
    const katalog = await getStudioCatalog(client, studioA);
    expect(katalog.tags.length).toBeGreaterThan(0);
    expect(katalog.tags.every((tag) => typeof tag.batchCode === "string")).toBe(true);
    expect(katalog.tags.every((tag) => tag.batchIndex >= 1)).toBe(true);
  });

  it("liefert die Lieferungen des Studios mit", async () => {
    const admin = serviceClient();
    const code = `katalog-${crypto.randomUUID()}`;
    await chargeAnlegen(admin, { code, kind: "machine", menge: 100 });
    await lieferungAnlegen(admin, { chargeCode: code, studioId: studioA, menge: 100 });

    const client = await userClient(trainerEmail);
    const katalog = await getStudioCatalog(client, studioA);
    const lieferung = katalog.shipments.find((zeile) => zeile.batchCode === code);
    expect(lieferung?.quantity).toBe(100);
    expect(lieferung?.kind).toBe("machine");
  });
});
```

Am Dateikopf ergänzen:

```ts
import { chargeAnlegen, lieferungAnlegen } from "@fitretro/domain/chargen";
```

*Die Namen `trainerEmail`, `studioA`, `userClient`, `serviceClient` und `getStudioCatalog` stehen in dieser Datei bereits — vor dem Anhängen die vorhandenen Bezeichner am Dateikopf ablesen und übernehmen, sie können abweichend heißen.*

- [x] **Step 2: Test laufen lassen, Fehlschlag bestätigen**

```bash
pnpm test:integration -- domain-catalog
```

Erwartet: FAIL beim Übersetzen — `batchCode` ist kein bekanntes Feld von `CatalogTag`, `shipments` keines von `StudioCatalog`.

- [x] **Step 3: Die Typen und die Abfrage erweitern**

In `packages/domain/src/catalog.ts`:

```ts
export type CatalogTag = {
  id: string;
  status: string;
  kind: "machine" | "studio";
  machineId: string | null;
  batchCode: string;
  batchIndex: number;
  createdAt: string;
};

export type CatalogShipment = {
  id: string;
  batchCode: string;
  kind: "machine" | "studio";
  quantity: number;
  shippedOn: string;
};

export type StudioCatalog = {
  studioId: string;
  studioName: string;
  models: CatalogModel[];
  tags: CatalogTag[];
  shipments: CatalogShipment[];
};
```

Die Tag-Abfrage in `getStudioCatalog` — der eingebettete Chargenkopf kommt über den Fremdschlüssel:

```ts
  const { data: tags } = await client
    .from("machine_tags")
    .select("id, status, kind, machine_id, batch_index, created_at, tag_batches (code)")
    .eq("studio_id", studioId)
    .order("created_at", { ascending: false });
```

Und daneben die Lieferungen:

```ts
  const { data: lieferungen } = await client
    .from("tag_shipments")
    .select("id, quantity, shipped_on, tag_batches (code, kind)")
    .eq("studio_id", studioId)
    .order("shipped_on", { ascending: false });
```

In der Zuordnung, die aus den Tag-Zeilen `CatalogTag`-Objekte baut, **an der Stelle, wo `machineId: ...` gesetzt wird**, ergänzen:

```ts
      batchCode: zeile.tag_batches?.code ?? "",
      batchIndex: zeile.batch_index,
```

und den Zeilentyp weiter unten in der Datei um `batch_index: number` und `tag_batches: { code: string } | null` erweitern. Die Lieferungen:

```ts
  const shipments: CatalogShipment[] = (lieferungen ?? []).map((zeile) => ({
    id: zeile.id,
    batchCode: zeile.tag_batches?.code ?? "",
    kind: zeile.tag_batches?.kind ?? "machine",
    quantity: zeile.quantity,
    shippedOn: zeile.shipped_on,
  }));
```

und `shipments` in das zurückgegebene Objekt aufnehmen.

In `packages/domain/src/index.ts` den Typexport ergänzen:

```ts
  CatalogShipment,
```

im bestehenden `export type { ... } from "./catalog.js"`-Block.

- [x] **Step 4: Tests und Typprüfung laufen lassen**

```bash
pnpm typecheck
pnpm test:integration -- domain-catalog
```

Erwartet: beides PASS. `typecheck` deckt auf, wenn `shipments` im Rückgabeobjekt vergessen wurde.

- [x] **Step 5: Die Seite die Zahlen zeigen lassen**

In `apps/web/app/portal/[studioId]/tags/page.tsx` oberhalb der Rückgabe die Rechnung aus der Spec:

```tsx
  const geliefert = katalog.shipments
    .filter((lieferung) => lieferung.kind === "machine")
    .reduce((summe, lieferung) => summe + lieferung.quantity, 0);
  const verbraucht = katalog.tags.filter((tag) => tag.kind === "machine").length;
  const vorraetig = geliefert - verbraucht;
```

Und einen Lieferungsabschnitt über *„Tag verbinden"*:

```tsx
      <section className={styles.section}>
        <div className={styles.sectionHead}>
          <h2 className={styles.sectionTitle}>Lieferungen</h2>
          <span className={styles.sectionNote}>
            {geliefert === 0 ? "Noch keine Lieferung." : `${vorraetig} vorrätig`}
          </span>
        </div>
        {katalog.shipments.length > 0 ? (
          <ul className={styles.rows}>
            {katalog.shipments.map((lieferung) => (
              <li key={lieferung.id} className={styles.row}>
                <div className={styles.rowMain}>
                  <div className={styles.rowTitle}>
                    Charge {lieferung.batchCode} · {lieferung.quantity}{" "}
                    {lieferung.kind === "studio" ? "Aushangschilder" : "Tags"}
                  </div>
                  <div className={styles.rowMeta}>
                    Geliefert {datum(lieferung.shippedOn)}
                  </div>
                </div>
              </li>
            ))}
          </ul>
        ) : null}
      </section>
```

In der Tag-Liste die Chargenangabe an die Meta-Zeile hängen:

```tsx
                    <div className={styles.rowMeta}>
                      Charge {tag.batchCode} · {tag.batchIndex} · angelegt{" "}
                      {datum(tag.createdAt)}
                      {tag.status === "revoked" ? " · bleibt als Nachweis stehen" : ""}
                    </div>
```

*`datum()` steht in dieser Datei bereits und nimmt einen ISO-String. `shippedOn` ist ein `date`, PostgREST liefert ihn als `JJJJ-MM-TT` — `new Date("2026-08-12")` ist gültig.*

- [x] **Step 6: Alles laufen lassen**

```bash
pnpm typecheck
pnpm test:integration
pnpm test:e2e
```

Erwartet: alles PASS.

- [x] **Step 7: Von Hand nachsehen**

```bash
pnpm tags charge:anlegen --code sicht-01 --sorte machine --menge 100
pnpm tags lieferung --charge sicht-01 --studio "<Name eines Teststudios>" --menge 100
pnpm tags bestand --studio "<derselbe Name>"
```

Danach `/portal/<studioId>/tags` im Browser öffnen: die Lieferzeile muss dieselbe Zahl zeigen wie `pnpm tags bestand`. Das ist die Gegenprobe, für die `bestand` gebaut ist.

- [x] **Step 8: Commit**

```bash
git add -A
git commit -m "feat(portal): Lieferungen und Vorrat auf der Tags-Seite"
```

---

## Was dieser Plan nicht baut

**Den Sucher.** Kamera, Decoder im Browser, der Fünfschritt vor dem Gerät. Sein Backend steht nach Aufgabe 5 vollständig — `inspect_tag` liefert alle sechs Antworten, `bind_tag_to_machine` das Binden. Er bekommt einen eigenen Plan.

**Das Modell am Telefon.** Erweiterung, `2026-09-01-einrichtung-am-geraet-design.md` §5.

**Eine Ratenbegrenzung** auf `join_studio_by_tag`. Offen, `2026-09-01-scan-beitritt-design.md` §7.

**Einen Bestellweg im Portal.** Der leere Vorrat ist gezeichnet, die Nachbestellung nicht.

## Offene Punkte, die dieser Plan nicht schließt

- **`replaced` bleibt unbenutzt.** Der Status existiert seit `0002`, und kein Weg setzt ihn — auch `bind_tag_to_machine` nicht, das ihn nur als „gesperrt" liest. Ein ersetzter Tag wird `revoked`, der neue frisch gebunden.
- **Kein Weg zurück in die Halde.** Ein an das falsche Gerät gebundener Tag lässt sich nur sperren, nicht lösen.
- **`lieferungAnlegen` ist nicht atomar.** Aktivierte Schilder und die Lieferzeile entstehen in zwei Schritten; bricht der zweite ab, gelten die Schilder, erscheinen aber nicht im Vorrat. Die Reihenfolge ist bewusst so gewählt — andersherum verspräche der Vorrat Schilder, die nicht gelten. Eine `SECURITY DEFINER`-Funktion würde es zusammenfassen, ist aber für ein Werkzeug mit einem einzigen Benutzer nicht bezahlt.
