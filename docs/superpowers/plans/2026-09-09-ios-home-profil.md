# iOS Member-App — Home & Profil: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Die letzten vier Screens der Member-App bauen — Home, Session-Detail, Übungsfortschritt, Profil —, den Mitgliedsnamen von der Registrierung bis zur Anzeige führen und die zwei ungetesteten Domänenmodule absichern, auf denen alles davon aufsetzt.

**Architecture:** Zwei Hälften. *Verlauf* liest zwei fertige Endpoints, cacht sie vollständig auf Platte und rechnet nichts nach, was der Server schon rechnet — anders als bei Kursen veraltet ein Verlauf nicht von selbst, weil er sich nur durch eigenes Tun ändert. *Profil & Name* baut den letzten Screen aus und schließt die Lücke, dass `profiles` seit Migration 0001 existiert, aber für kein Mitglied eine Zeile trägt. Vier additive Server-Änderungen, eine Migration, keine neue Abhängigkeit.

**Teststrategie** (Spec 3.1): `getSessions` und `getProgress` sind über `tests/integration/` gegen echtes Postgres geprüft, nicht über Attrappen. Die neuen Felder werden **dort** erweitert, wo ihre Nachbarn schon geprüft sind. Unit-Tests in `packages/domain` bekommt nur, was rein ist: die Wochenzählung und die Namensprüfung.

**Tech Stack:** Swift 6.0, SwiftUI (iOS 17), Swift Charts, Swift Testing, XcodeGen. Backend: TypeScript, Next.js App Router, Zod, Vitest, Postgres/Supabase.

**Spec:** `docs/superpowers/specs/2026-09-09-ios-home-profil-design.md` — dieser Plan setzt sie um; Ausführende lesen beide Dokumente. Referenziert außerdem `docs/superpowers/specs/2026-08-28-fitness-retrofit-m1-design.md` (Produktverhalten) und `docs/superpowers/specs/2026-08-30-designsystem.md` (Aussehen, Bewegung, Zustände).

**Artboards:** `docs/superpowers/design/member/{Home,HomeLeer,SessionDetail,Uebungsfortschritt,Profil}.dc.html`. **Sie werden gegen die Abweichungstabelle in Abschnitt 6 der Spec gelesen, nicht wörtlich** — sie tragen sechs dokumentierte Regelbrüche.

## Global Constraints

- iOS-Deployment-Ziel 17.0, Swift 6.0 (`apps/ios-member/project.yml`) — nicht ändern. **Keine neue SPM-Abhängigkeit** (Swift Charts ist Teil des SDK, kein Paket).
- **Kein Direktzugriff aus Swift auf Postgres/PostgREST** — jede Fachfunktion läuft über `/api/v1` (M1-Spec §6.1/§6.2).
- **Alle Ziffern tabellarisch** (`.monospacedDigit()`). **Gewichte immer mit einer Nachkommastelle und Dezimalkomma** über `Zahlformat`, nie selbst formatiert (§3).
- **Trefferflächen ≥ 44 pt. Hauptaktion exakt 64 pt hoch**, Nebenaktion 46–52 pt. Radius 16 Hauptaktion / 14 Nebenaktion / 12 Karten / Pille für Chips. Abstandsskala ausschließlich 4 · 8 · 12 · 16 · 24 · 32 · 48. Seitenrand 20 pt (§4).
- **Genau eine Akzentfläche je Screen** (§2, nicht verhandelbar). Wo es keine Hauptaktion gibt, markiert der Akzent den aktiven Wert.
- **`warn` (`#FFB020`) nur als Umriss, nie als Fläche** (§2, nicht verhandelbar).
- **`text-faint` nur für Text ≥ 15 pt oder nicht-tragende Information** (§2).
- **Fünf Zustände, überall gleich** (§5): Skelett **nur für Medien**, nie über einer Zahl · Leer erklärt den nächsten Schritt, **nie eine leere Statistik mit Nullen** · Offline heißt „gespeichert, wird gesendet", nie „fehlgeschlagen" · Fehler sagt, was falsch ist **und** was gilt · Deaktiviert ist nie stumm.
- **Haptik nie als einzige Rückmeldung** (§6, M1-Spec §5.9).
- **Reduce Motion ersetzt jede Animation durch einen Zustandswechsel**, nie durch Weglassen von Information (§6).
- **Bewegungswerte** aus `DesignSystem.Motion`: `.oeffnen`, `.pause`, `.press` — keine neuen erfinden.
- **Diagramme** (§13): eine Serie in `accent`, keine Legende, Linie 2 pt, Messpunkte ≥ 8 pt, Gitter in `line`, Achsen in `text-faint`, **Achse beginnt nicht bei null**, direkte Beschriftung nur an Anfang und Ende, **Rohwerte unter dem Diagramm**.
- **Kein Freitext zu Gesundheit, nirgends** (§10).
- **Kein Text verspricht eine Benachrichtigung.** Push existiert nicht (§11).
- **Durchgehend Deutsch, Du-Form, keine Ausrufezeichen, kein Motivationston** (§10).
- **Backend-Fehlerhülle:** `{ "error": { "code": "...", "message": "..." } }`, Status fest: `validation_failed`→422, `unauthorized`→401, `not_found`→404, `conflict`→409, `internal`→500 (`apps/web/lib/api/respond.ts` — nicht ändern).
- Neue Web-Routen folgen dem Muster der bestehenden `/api/v1`-Handler: `bearerClientFrom(request)`, `fromDomainError`/`errorResponse`, `export const dynamic = "force-dynamic"`.
- Deutsche Bezeichner in neuem Fachcode; englische nur, wo sie einen API-Vertrag oder eine Datenbankspalte abbilden.
- **Kommentare erklären, warum — nicht was.** Die bestehenden Dateien sind das Vorbild.
- **Jede Verifikation läuft als Kaltbau** mit isoliertem `-derivedDataPath`, und das Verzeichnis wird danach gelöscht. In Sub-Projekt 2 verdeckten warme Builds einen Übersetzungsfehler und sieben Warnungen; die stehengebliebenen Verzeichnisse belegten am Ende 5,2 GB.
- **Vier vorbestehende Warnungen** (`QRScannerController.swift` dreimal, `SupabaseAuthBackend.swift` einmal) sind bekannt und gehören nicht zu diesem Sub-Projekt. Nicht beheben, aber auch nicht vermehren: **jede Warnung in einer Datei, die du schreibst, ist deine.**
- **Neue Swift-Dateien brauchen `xcodegen generate`**, bevor `xcodebuild` sie sieht (`sources:` globbt das Verzeichnis).

## Dateistruktur

**Neu, Server:**

| Datei | Verantwortung |
| --- | --- |
| `packages/domain/src/sessions.test.ts` | **nur** `zaehleDieseWoche` — reine Rechnung mit Zeitzonengrenze |
| `packages/domain/src/profil.ts` | `setDisplayName` — der einzige Schreibweg des Namens |
| `packages/domain/src/profil.test.ts` | Prüfung der Eingabe |
| `apps/web/app/api/v1/me/profile/route.ts` | `PUT /me/profile` |
| `tests/integration/api-profil.test.ts` | Schreibweg, Insert-Policy, Bootstrap-Lesepfad |
| `supabase/migrations/0039_profiles_insert_own.sql` | die fehlende Insert-Policy |

**Neu, iOS:**

| Datei | Verantwortung |
| --- | --- |
| `FitnessMember/Verlauf/VerlaufHerkunft.swift` | drei Zustände, datierter Satz |
| `FitnessMember/Verlauf/VerlaufFileStore.swift` | Verlauf und Fortschritt auf Platte |
| `FitnessMember/Verlauf/VerlaufStore.swift` | Laden, Cache, Ladezustand |
| `FitnessMember/Verlauf/HomeZeilen.swift` | reine Ableitungen für Home (Dauer, laufende Einheit, Initialen) |
| `FitnessMember/Verlauf/Fortschrittsfenster.swift` | Zeitraumfilter und Achsenbereich des Diagramms |
| `FitnessMember/Screens/Home/HomeRootView.swift` | `Home` und `HomeLeer` |
| `FitnessMember/Screens/Home/SessionDetailView.swift` | `SessionDetail` |
| `FitnessMember/Screens/Home/UebungsfortschrittView.swift` | `Uebungsfortschritt` |
| `FitnessMember/Navigation/HomeRoute.swift` | typisierter Pfad des Home-Tabs |
| `FitnessMember/Einstellungen.swift` | die drei Schalter an einer Stelle |
| `FitnessMember/Screens/Profil/NameSheet.swift` | ein Feld, ein Knopf |

**Geändert:**

| Datei | Änderung |
| --- | --- |
| `packages/domain/src/sessions.ts` | `summary`, `studioId`-Option, `zaehleDieseWoche` |
| `packages/domain/src/progress.ts` | `machineLabel` aus dem jüngsten Satz |
| `tests/integration/domain-sessions.test.ts` | Fälle für `summary` |
| `tests/integration/domain-progress.test.ts` | Fall für `machineLabel` |
| `tests/integration/api-me.test.ts` | `?studio=` an der Route |
| `packages/domain/src/bootstrap.ts` | `member: { displayName }` |
| `packages/domain/src/index.ts` | neue Exporte |
| `apps/web/app/api/v1/me/sessions/route.ts` | `?studio=` |
| `FitnessMember/Networking/DTOs/SessionSummary.swift` | `summary` |
| `FitnessMember/Networking/DTOs/ExerciseProgress.swift` | `machineLabel` |
| `FitnessMember/Networking/DTOs/BootstrapResponse.swift` | `member` |
| `FitnessMember/Networking/APIClient.swift` | `sessions(studio:)`, `setDisplayName` |
| `FitnessMember/Navigation/MainTabView.swift` | Home-Tab statt Platzhalter |
| `FitnessMember/FitnessMemberApp.swift` | `VerlaufStore` in die Umgebung |
| `FitnessMember/Screens/Profil/ProfilRootView.swift` | Vollausbau |
| `FitnessMember/Screens/Zugang/MemberRegistrierenView.swift` | Vorname |
| `FitnessMember/Screens/Geraet/GeraetView.swift` | Haptik beim Sichern, `Einstellungen` statt eigenem `@AppStorage` |
| `FitnessMember/Workout/Resttimer.swift` | Vorgabe statt Konstante |
| `FitnessMember/AppConfig.swift` | optionaler Schlüssel für die Datenschutz-URL |
| `apps/ios-member/Config.xcconfig.example`, `FitnessMember/Info-Additions.plist` | derselbe Schlüssel |

---
## Aufgaben-Übersicht

| # | Aufgabe | Hälfte |
| --- | --- | --- |
| 1 | Die Kopfzeile: `summary` und `?studio=` | Server |
| 2 | Das Gerätelabel im Fortschritt | Server |
| 3 | Der Name: Migration, `PUT /me/profile`, Bootstrap | Server |
| 4 | `VerlaufHerkunft` und der gemeinsame Satzbau | iOS |
| 5 | `VerlaufFileStore` und `VerlaufStore` | iOS |
| 6 | `HomeRootView` — beide Zustände | iOS |
| 7 | `SessionDetailView` | iOS |
| 8 | `UebungsfortschrittView` mit Swift Charts | iOS |
| 9 | `Einstellungen`, Resttimer-Vorgabe, Haptik beim Sichern | iOS |
| 10 | `ProfilRootView` — Vollausbau | iOS |
| 11 | Der Vorname bei der Registrierung | iOS |

Aufgaben 1–3 sind untereinander unabhängig. 4–8 hängen an 1 und 2, 10–11 an 3. Aufgabe 9 hängt an nichts und kann jederzeit dazwischen laufen.

---

### Aufgabe 1: Die Kopfzeile — `summary` und `?studio=`

Home zeigt „2 diese Woche · 34 gesamt · 3 Tage her". `SESSION_LIMIT = 50` deckelt die Liste; „gesamt" darf davon nicht abhängen. Die Wochengrenze fällt in die Studio-Zeitzone — welches Studio aktiv ist, weiß nur der Client.

**Files:**
- Create: `packages/domain/src/sessions.test.ts`
- Modify: `packages/domain/src/sessions.ts`
- Modify: `packages/domain/src/index.ts`
- Modify: `apps/web/app/api/v1/me/sessions/route.ts`
- Modify: `tests/integration/domain-sessions.test.ts`
- Modify: `tests/integration/api-me.test.ts`
- Modify: `apps/ios-member/FitnessMember/Networking/DTOs/SessionSummary.swift`
- Modify: `apps/ios-member/FitnessMember/Networking/APIClient.swift`
- Modify: `apps/ios-member/FitnessMemberTests/DTOTests.swift`

**Interfaces:**
- Produces: `export function zaehleDieseWoche(startsAt: string[], jetzt: Date, zeitzone: string): number`; `export type SessionsSummary = { totalCount: number; thisWeekCount: number | null; lastSessionAt: string | null }`; `export type SessionsOptions = { studioId?: string }`; `getSessions(client, optionen?: SessionsOptions): Promise<{ sessions: SessionSummary[]; summary: SessionsSummary }>`; Swift: `SessionsResponse.summary`, `APIClient.sessions(studio: String?) -> SessionsResponse`
- Consumes: `ortszeitTeile` aus `serie.ts`

- [ ] **Step 1: Den Unit-Test für die Wochenzählung schreiben**

Create `packages/domain/src/sessions.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { zaehleDieseWoche } from "./sessions.js";

const BERLIN = "Europe/Berlin";
/** Mittwoch, 9. September 2026, 12:00 Ortszeit (MESZ = UTC+2). */
const mittwoch = new Date("2026-09-09T10:00:00.000Z");

describe("zaehleDieseWoche", () => {
  it("zaehlt eine Einheit von heute", () => {
    expect(zaehleDieseWoche(["2026-09-09T08:00:00.000Z"], mittwoch, BERLIN)).toBe(1);
  });

  it("zaehlt ab Montag, nicht ab Sonntag", () => {
    const montag = "2026-09-07T08:00:00.000Z";
    const sonntagDavor = "2026-09-06T08:00:00.000Z";

    expect(zaehleDieseWoche([montag, sonntagDavor], mittwoch, BERLIN)).toBe(1);
  });

  // Der eigentliche Grund fuer den Zeitzonen-Parameter: 00:30 MESZ am
  // Montag ist noch Sonntag 22:30 UTC. Ohne die Zeitzone faellt diese
  // Einheit in die vorige Woche -- und das Mitglied saehe eine andere
  // Woche als sein Studio.
  it("legt die Wochengrenze in die Studio-Zeitzone", () => {
    const montagKurzNachMitternacht = "2026-09-06T22:30:00.000Z";

    expect(zaehleDieseWoche([montagKurzNachMitternacht], mittwoch, BERLIN)).toBe(1);
    expect(zaehleDieseWoche([montagKurzNachMitternacht], mittwoch, "UTC")).toBe(0);
  });

  it("zaehlt am Sonntag noch die ablaufende Woche", () => {
    const sonntag = new Date("2026-09-13T10:00:00.000Z");

    expect(zaehleDieseWoche(["2026-09-07T08:00:00.000Z"], sonntag, BERLIN)).toBe(1);
  });

  it("zaehlt eine leere Liste als null", () => {
    expect(zaehleDieseWoche([], mittwoch, BERLIN)).toBe(0);
  });
});
```

- [ ] **Step 2: Testlauf, der fehlschlagen muss**

```bash
cd packages/domain && pnpm vitest run src/sessions.test.ts
```

Erwartet: FAIL — `zaehleDieseWoche` ist nicht exportiert.

- [ ] **Step 3: `zaehleDieseWoche` schreiben**

In `packages/domain/src/sessions.ts`, mit `import { ortszeitTeile } from "./serie.js";` am Kopf:

```ts
/** Die Tagesnummer dieses Augenblicks in dieser Zeitzone. */
function tagNummer(zeitpunkt: Date, zeitzone: string): number {
  const teile = ortszeitTeile(zeitpunkt, zeitzone);
  return Math.floor(Date.UTC(teile.jahr, teile.monat - 1, teile.tag) / 86_400_000);
}

/**
 * Wie viele Einheiten in die laufende Woche fallen -- Woche ab Montag,
 * Grenze in der Zeitzone des Studios.
 *
 * Die Zeitzone ist kein Beiwerk: 00:30 MESZ am Montag ist Sonntag 22:30
 * UTC. Ohne sie faellt eine Einheit von Montagnacht in die vorige Woche,
 * und das Mitglied saehe eine andere Woche als sein Studio.
 *
 * Die Deckelung der Liste auf SESSION_LIMIT ist hier unkritisch: eine
 * Woche mit mehr als 50 Einheiten gibt es nicht.
 */
export function zaehleDieseWoche(
  startsAt: string[],
  jetzt: Date,
  zeitzone: string,
): number {
  const heute = tagNummer(jetzt, zeitzone);
  // getUTCDay auf der reinen Tagesnummer: 0 = Sonntag.
  const wochentag = new Date(heute * 86_400_000).getUTCDay();
  const montag = heute - ((wochentag + 6) % 7);

  return startsAt.filter((iso) => tagNummer(new Date(iso), zeitzone) >= montag).length;
}
```

- [ ] **Step 4: Testlauf, der bestehen muss**

```bash
cd packages/domain && pnpm vitest run src/sessions.test.ts
```

Erwartet: PASS, 5 Tests.

- [ ] **Step 5: `summary` in `getSessions`**

Typen erweitern:

```ts
export type SessionsSummary = {
  /** Alle Einheiten, nicht nur die gelieferten (SESSION_LIMIT). */
  totalCount: number;
  /** `null`, wenn kein Studio genannt wurde -- ohne Zeitzone keine Woche. */
  thisWeekCount: number | null;
  lastSessionAt: string | null;
};

export type Sessions = { sessions: SessionSummary[]; summary: SessionsSummary };

export type SessionsOptions = { studioId?: string };
```

`getSessions` bekommt den zweiten Parameter und rechnet die Kennzahlen **vor** dem frühen Rücksprung:

```ts
export async function getSessions(
  client: SupabaseClient,
  optionen: SessionsOptions = {},
): Promise<Sessions> {
  const userId = await requireUserId(client);

  // Die Gesamtzahl kommt aus einem COUNT, nicht aus der Laenge der Liste:
  // die ist auf SESSION_LIMIT gedeckelt, und "34 gesamt" waere ab der 51.
  // Einheit still falsch -- fuer genau die treuesten Mitglieder.
  const { count } = await client
    .from("workout_sessions")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId);

  const zeitzone = await zeitzoneDesStudios(client, optionen.studioId);

  const { data: sessionRows } = await client
    .from("workout_sessions")
    .select("id, started_at, completed_at, completed_reason")
    .eq("user_id", userId)
    .order("started_at", { ascending: false })
    .limit(SESSION_LIMIT);

  const sessions = (sessionRows ?? []) as SessionRow[];
  const summary: SessionsSummary = {
    totalCount: count ?? 0,
    thisWeekCount: zeitzone
      ? zaehleDieseWoche(sessions.map((session) => session.started_at), new Date(), zeitzone)
      : null,
    // Die Liste kommt absteigend -- die erste Zeile ist die juengste. Eine
    // noch laufende Einheit zaehlt mit: wer gerade trainiert, hat heute
    // trainiert.
    lastSessionAt: sessions[0]?.started_at ?? null,
  };

  if (sessions.length === 0) return { sessions: [], summary };
```

Der Rücksprung am Ende der Funktion wird zu `return { sessions: summaries, summary };`.

Dazu die Zeitzonen-Abfrage, unterhalb von `getSessions`:

```ts
/**
 * Die Zeitzone des Studios, aus dessen Sicht die Woche gezaehlt wird.
 *
 * `null` statt einer Vorgabe: eine erfundene Zeitzone ergaebe eine Zahl,
 * die aussieht wie eine Auskunft. Ohne Studio faellt die Wochenzahl weg,
 * und der Screen zeigt sie nicht an.
 *
 * RLS entscheidet mit: wer nicht Mitglied ist, sieht die Zeile nicht und
 * bekommt damit ebenfalls `null`.
 */
async function zeitzoneDesStudios(
  client: SupabaseClient,
  studioId: string | undefined,
): Promise<string | null> {
  if (!studioId) return null;

  const { data } = await client
    .from("studios")
    .select("timezone")
    .eq("id", studioId)
    .maybeSingle();

  return (data as { timezone: string } | null)?.timezone ?? null;
}
```

In `packages/domain/src/index.ts` die Exporte nachziehen:

```ts
export { getSessions, zaehleDieseWoche } from "./sessions.js";
export type {
  SessionBlock,
  SessionSummary,
  Sessions,
  SessionsOptions,
  SessionsSummary,
} from "./sessions.js";
```

- [ ] **Step 6: Die Route nimmt `?studio=`**

`apps/web/app/api/v1/me/sessions/route.ts` — nach dem Muster von `me/courses`, aber **optional**. Der bestehende Kommentarkopf der Datei bleibt erhalten:

```ts
import { z } from "zod";
import { getSessions } from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

/**
 * studio geht ungeprueft an PostgREST durch, sobald es den Router
 * verlaesst -- ein "?studio=abc" kaeme dort als "invalid input syntax for
 * type uuid" zurueck. Deshalb hier, an der Systemgrenze, wie in
 * me/courses.
 *
 * Optional, anders als dort: der Verlauf gehoert dem Mitglied, nicht dem
 * Studio. Ohne den Parameter faellt nur die Wochenzahl weg -- wer sein
 * letztes Studio verlassen hat, behaelt Verlauf und Gesamtzahl.
 */
const parameterSchema = z.object({
  studio: z.string().uuid("Der Parameter studio ist keine gueltige UUID.").optional(),
});

export async function GET(request: Request): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) {
    return errorResponse("unauthorized", "Anmeldung erforderlich.");
  }

  const geprueft = parameterSchema.safeParse({
    studio: new URL(request.url).searchParams.get("studio") ?? undefined,
  });
  if (!geprueft.success) {
    return errorResponse("validation_failed", geprueft.error.issues[0]!.message);
  }

  try {
    const sessions = await getSessions(client, { studioId: geprueft.data.studio });
    return Response.json(sessions, {
      status: 200,
      headers: { "cache-control": "private, no-store" },
    });
  } catch (error) {
    return fromDomainError(error);
  }
}
```

- [ ] **Step 7: Die Integrationstests erweitern**

An `tests/integration/domain-sessions.test.ts` anhängen. Der Block legt sein **eigenes** Mitglied an — die bestehenden Tests teilen sich `memberAId` und seeden fortlaufend, eine exakte Gesamtzahl wäre dort nicht stabil:

```ts
describe("getSessions -- summary", () => {
  it("zaehlt auch, was jenseits der gelieferten 50 liegt", async () => {
    const email = uniqueEmail("summary-viel");
    const userId = await createTestUser(email);
    const admin = serviceClient();

    const { error: membershipError } = await admin
      .from("studio_memberships")
      .insert({ studio_id: studioA, user_id: userId, role: "member" });
    if (membershipError) throw membershipError;

    // 51 Einheiten in einem Insert -- SESSION_LIMIT liefert 50 davon aus.
    const { error } = await admin.from("workout_sessions").insert(
      Array.from({ length: 51 }, (_, index) => ({
        id: newId(),
        studio_id: studioA,
        user_id: userId,
        started_at: isoAgo(100 + index),
        completed_at: isoAgo(99.5 + index),
        completed_reason: "manual" as const,
      })),
    );
    if (error) throw error;

    const client = await userClient(email);
    const { sessions, summary } = await getSessions(client);

    expect(sessions).toHaveLength(50);
    expect(summary.totalCount).toBe(51);
  });

  it("laesst die Wochenzahl ohne Studio weg", async () => {
    const client = await userClient(memberAEmail);
    const { summary } = await getSessions(client);

    expect(summary.thisWeekCount).toBeNull();
    // Die Gesamtzahl bleibt: der Verlauf gehoert dem Mitglied, nicht dem
    // Studio -- wer sein letztes Studio verlaesst, behaelt ihn.
    expect(summary.totalCount).toBeGreaterThan(0);
  });

  it("zaehlt mit Studio die laufende Woche", async () => {
    const email = uniqueEmail("summary-woche");
    const userId = await createTestUser(email);
    const admin = serviceClient();

    const { error: membershipError } = await admin
      .from("studio_memberships")
      .insert({ studio_id: studioA, user_id: userId, role: "member" });
    if (membershipError) throw membershipError;

    // Eine Einheit von vor einer Stunde und eine von vor 30 Tagen: die
    // erste liegt immer in der laufenden Woche, die zweite nie.
    const { error } = await admin.from("workout_sessions").insert([
      {
        id: newId(),
        studio_id: studioA,
        user_id: userId,
        started_at: isoAgo(1),
        completed_at: isoAgo(0.5),
        completed_reason: "manual" as const,
      },
      {
        id: newId(),
        studio_id: studioA,
        user_id: userId,
        started_at: isoAgo(24 * 30),
        completed_at: isoAgo(24 * 30 - 1),
        completed_reason: "manual" as const,
      },
    ]);
    if (error) throw error;

    const client = await userClient(email);
    const { summary } = await getSessions(client, { studioId: studioA });

    expect(summary.thisWeekCount).toBe(1);
    expect(summary.totalCount).toBe(2);
    expect(summary.lastSessionAt).not.toBeNull();
  });

  it("liefert ohne Historie eine leere Kopfzeile", async () => {
    const email = uniqueEmail("summary-leer");
    const userId = await createTestUser(email);
    const { error } = await serviceClient()
      .from("studio_memberships")
      .insert({ studio_id: studioA, user_id: userId, role: "member" });
    if (error) throw error;

    const client = await userClient(email);
    const { sessions, summary } = await getSessions(client, { studioId: studioA });

    expect(sessions).toEqual([]);
    expect(summary.totalCount).toBe(0);
    expect(summary.thisWeekCount).toBe(0);
    expect(summary.lastSessionAt).toBeNull();
  });
});
```

Und in `tests/integration/api-me.test.ts`, im bestehenden `describe` für `/me/sessions`:

```ts
  it("weist ein studio zurueck, das keine UUID ist", async () => {
    const response = await sessionsGET(
      request("http://localhost/api/v1/me/sessions?studio=abc", bearer),
    );

    expect(response.status).toBe(422);
    const payload = (await response.json()) as { error: { code: string } };
    expect(payload.error.code).toBe("validation_failed");
  });

  it("liefert die Kopfzeile mit", async () => {
    const response = await sessionsGET(
      request("http://localhost/api/v1/me/sessions", bearer),
    );

    expect(response.status).toBe(200);
    const payload = (await response.json()) as {
      summary: { totalCount: number; thisWeekCount: number | null };
    };
    expect(payload.summary.totalCount).toBeGreaterThan(0);
    expect(payload.summary.thisWeekCount).toBeNull();
  });
```

- [ ] **Step 8: Beide Testebenen laufen lassen**

```bash
cd packages/domain && pnpm vitest run && cd ../..
npx --no-install supabase migration list --local
pnpm vitest run tests/integration/domain-sessions.test.ts tests/integration/api-me.test.ts
pnpm typecheck 2>&1 | tail -6
```

Erwartet: Domänentests grün, Integrationstests grün, `typecheck` fehlerfrei. Läuft die lokale Datenbank nicht, ist das ein Grund anzuhalten — nicht, den Schritt zu überspringen.

- [ ] **Step 9: Die iOS-Seite — DTO und Client**

In `FitnessMember/Networking/DTOs/SessionSummary.swift`, oben:

```swift
struct SessionsResponse: Decodable, Equatable {
    let sessions: [SessionSummary]
    let summary: SessionsSummary
}

/// Die Kopfzeile von Home.dc.html. Serverseitig gerechnet: die
/// Gesamtzahl steht ueber der gedeckelten Liste, und die Wochengrenze
/// faellt in die Studio-Zeitzone -- beides kann der Client nicht.
struct SessionsSummary: Decodable, Equatable {
    let totalCount: Int
    /// `nil` ohne aktives Studio -- dann zeigt Home die Wochenzahl nicht.
    let thisWeekCount: Int?
    let lastSessionAt: String?
}
```

In `FitnessMember/Networking/APIClient.swift` ersetzt die neue Fassung die bisherige `sessions()`:

```swift
    /// Liefert die volle Antwort statt nur der Liste: die Kopfzeile von
    /// Home braucht `summary`, und ein zweiter Abruf dafuer waere
    /// derselbe Abruf.
    ///
    /// `studio` ist optional -- ohne aktives Studio faellt serverseitig
    /// nur die Wochenzahl weg (siehe me/sessions/route.ts).
    func sessions(studio: String?) async throws(APIError) -> SessionsResponse {
        guard let studio else { return try await get("me/sessions", as: SessionsResponse.self) }

        var components = URLComponents(
            url: baseURL.appendingPathComponent("me/sessions"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "studio", value: studio)]
        guard let url = components.url else { throw APIError.encodingFailed }
        return try await execute(url: url, method: "GET", bodyData: nil)
    }
```

- [ ] **Step 10: Den bestehenden DTO-Test nachziehen und erweitern**

`decodesSessions` in `apps/ios-member/FitnessMemberTests/DTOTests.swift` scheitert jetzt, weil `summary` fehlt:

```swift
    @Test("dekodiert eine SessionsResponse mit einem Block")
    func decodesSessions() throws {
        let json = """
        {"sessions":[{"id":"sess1","startedAt":"2026-09-01T10:00:00Z","completedAt":null,"completedReason":null,"machineCount":1,"setCount":1,"blocks":[{"machineId":"m1","machineLabel":"07","exerciseId":"ex1","exerciseName":"Beidbeinig","sets":[{"setIndex":1,"weightKg":80,"reps":10,"rir":null,"problemFlag":false,"problemReason":null,"performedAt":"2026-09-01T10:05:00Z"}]}]}],"summary":{"totalCount":34,"thisWeekCount":2,"lastSessionAt":"2026-09-01T10:00:00Z"}}
        """
        let response = try JSONDecoder().decode(SessionsResponse.self, from: Data(json.utf8))
        #expect(response.sessions[0].blocks[0].sets[0].weightKg == 80)
        #expect(response.summary.totalCount == 34)
    }

    @Test("eine Kopfzeile ohne aktives Studio traegt keine Wochenzahl")
    func decodesSummaryOhneWoche() throws {
        let json = #"{"sessions":[],"summary":{"totalCount":0,"thisWeekCount":null,"lastSessionAt":null}}"#
        let response = try JSONDecoder().decode(SessionsResponse.self, from: Data(json.utf8))

        #expect(response.summary.thisWeekCount == nil)
        #expect(response.summary.lastSessionAt == nil)
    }
```

- [ ] **Step 11: Kaltbau**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -derivedDataPath /tmp/dd-sp4-t1 test 2>&1 | grep -E "warning:|error:|TEST SUCCEEDED|TEST FAILED"
rm -rf /tmp/dd-sp4-t1
```

Erwartet: `TEST SUCCEEDED`, nur die vier vorbestehenden Warnungen.

- [ ] **Step 12: Commit**

```bash
git add packages/domain apps/web/app/api/v1/me/sessions/route.ts tests/integration \
        apps/ios-member/FitnessMember/Networking apps/ios-member/FitnessMemberTests/DTOTests.swift
git commit -m "feat(api): die Kopfzeile von Home kommt vom Server

'34 gesamt' aus der Liste zu zaehlen waere ab der 51. Einheit still
falsch gewesen -- SESSION_LIMIT deckelt sie auf 50. Die Gesamtzahl kommt
jetzt aus einem COUNT, die Wochenzahl aus einer Zaehlung mit der Zeitzone
des Studios: 00:30 MESZ am Montag ist Sonntag 22:30 UTC, und ohne die
Zeitzone saehe das Mitglied eine andere Woche als sein Studio.

?studio ist optional -- der Verlauf gehoert dem Mitglied, nicht dem
Studio. Ohne den Parameter faellt nur die Wochenzahl weg, statt dass der
ganze Screen an einer verlorenen Mitgliedschaft haengt."
```

---

### Aufgabe 2: Das Gerätelabel im Fortschritt

„Beidbeinig" allein sagt nichts — die Übung trägt ihre Bedeutung erst mit dem Gerät davor, und `exercises` hängt am Studio, nicht am Gerätemodell (`0005_exercises.sql`). Gruppiert wird weiter nach Übung: die Steigerung gehört der Übung, nicht dem Gerätegehäuse.

**Files:**
- Modify: `packages/domain/src/progress.ts`
- Modify: `tests/integration/domain-progress.test.ts`
- Modify: `apps/ios-member/FitnessMember/Networking/DTOs/ExerciseProgress.swift`
- Modify: `apps/ios-member/FitnessMemberTests/DTOTests.swift`

**Interfaces:**
- Produces: `ExerciseProgress.machineLabel: string`; Swift: `ExerciseProgress.machineLabel`

- [ ] **Step 1: Den Integrationstest schreiben**

An das bestehende `describe("getProgress")` in `tests/integration/domain-progress.test.ts` anhängen. Die Datei hat bereits Seed-Helfer und zwei Geräte im `beforeAll` — falls dort nur eines existiert, ein zweites nach dem Muster des ersten anlegen und `machineB` als Modul-Variable ergänzen:

```ts
  // Das Label kommt vom JUENGSTEN Satz: wer an zwei baugleichen Geraeten
  // trainiert, hat trotzdem eine durchgehende Kurve -- die Steigerung
  // gehoert der Uebung, nicht dem Geraetegehaeuse.
  it("beschriftet eine Uebung mit dem Geraet des juengsten Satzes", async () => {
    const sessionId = await seedSession({ userId: memberAId, startedAt: isoAgo(80) });
    await seedSet({
      sessionId,
      userId: memberAId,
      machineId: machineA,
      exerciseId: breitId,
      setIndex: 1,
      performedAt: isoAgo(80),
      weightKg: 70,
    });
    await seedSet({
      sessionId,
      userId: memberAId,
      machineId: machineB,
      exerciseId: breitId,
      setIndex: 2,
      performedAt: isoAgo(2),
      weightKg: 75,
    });

    const client = await userClient(memberAEmail);
    const { exercises } = await getProgress(client);
    const uebung = exercises.find((eintrag) => eintrag.exerciseId === breitId);

    expect(uebung?.machineLabel).toBe(labelVon(machineB));
    // Ein Geraetewechsel spaltet die Kurve nicht.
    expect(uebung!.points.length).toBeGreaterThanOrEqual(2);
  });
```

`labelVon(machineB)` ist keine vorhandene Hilfsfunktion: die Datei legt ihre Geräte im `beforeAll` mit einem festen `label` an — dieses Label wörtlich einsetzen (z. B. `expect(uebung?.machineLabel).toBe("Kabelzug B")`), statt eine Hilfsfunktion zu erfinden.

- [ ] **Step 2: Testlauf, der fehlschlagen muss**

```bash
pnpm vitest run tests/integration/domain-progress.test.ts
```

Erwartet: FAIL — `machineLabel` existiert im Ergebnis nicht.

- [ ] **Step 3: Das Feld ergänzen**

In `packages/domain/src/progress.ts` der Typ:

```ts
export type ExerciseProgress = {
  exerciseId: string;
  exerciseName: string;
  /**
   * Das Geraet des juengsten Satzes. Die Uebung allein ("Beidbeinig")
   * traegt keine Bedeutung -- exercises haengt am Studio, nicht am
   * Geraetemodell (0005_exercises.sql).
   */
  machineLabel: string;
  firstWeightKg: number;
  currentWeightKg: number;
  changeKg: number;
  points: ProgressPoint[];
};
```

Die Zeilenform und die Abfrage holen das Gerät mit:

```ts
type SetRow = {
  exercise_id: string;
  weight_kg: number | string;
  reps: number;
  performed_at: string;
  exercises: { name: string };
  machines: { label: string };
};
```

```ts
  let query = client
    .from("workout_sets")
    .select(
      "exercise_id, weight_kg, reps, performed_at, exercises (name), machines (label)",
    )
    .eq("user_id", userId)
    .order("performed_at", { ascending: true })
    .limit(SET_SCAN_LIMIT);
```

Der Sammel-Map ein Feld geben und es bei jeder Zeile überschreiben — die Abfrage kommt aufsteigend, also gewinnt die jüngste:

```ts
  const byExercise = new Map<
    string,
    { name: string; machineLabel: string; days: Map<string, ProgressPoint> }
  >();
  for (const row of (setRows ?? []) as unknown as SetRow[]) {
    const entry = byExercise.get(row.exercise_id) ?? {
      name: row.exercises.name,
      machineLabel: row.machines.label,
      days: new Map<string, ProgressPoint>(),
    };
    // Aufsteigend sortiert -- die letzte Zeile ist die juengste.
    entry.machineLabel = row.machines.label;
    byExercise.set(row.exercise_id, entry);
```

und im Aufbau des Ergebnisses:

```ts
    exercises.push({
      exerciseId,
      exerciseName: entry.name,
      machineLabel: entry.machineLabel,
      firstWeightKg: first.topWeightKg,
      currentWeightKg: last.topWeightKg,
      changeKg: last.topWeightKg - first.topWeightKg,
      points,
    });
```

- [ ] **Step 4: Testlauf, der bestehen muss**

```bash
pnpm vitest run tests/integration/domain-progress.test.ts && pnpm typecheck 2>&1 | tail -6
```

Erwartet: PASS, `typecheck` fehlerfrei.

- [ ] **Step 5: Die iOS-Seite**

In `FitnessMember/Networking/DTOs/ExerciseProgress.swift` — die `CodingKeys` müssen mitgezogen werden, sonst dekodiert das Feld nicht:

```swift
    let id: String
    let exerciseName: String
    let machineLabel: String
    let firstWeightKg: Double
    let currentWeightKg: Double
    let changeKg: Double
    let points: [Point]

    private enum CodingKeys: String, CodingKey {
        case id = "exerciseId", exerciseName, machineLabel, firstWeightKg, currentWeightKg,
             changeKg, points
    }
```

Und in `DTOTests.swift`:

```swift
    @Test("dekodiert eine ProgressResponse mit Geraetelabel")
    func decodesProgress() throws {
        let json = """
        {"exercises":[{"exerciseId":"u1","exerciseName":"Beidbeinig","machineLabel":"Beinpresse","firstWeightKg":65,"currentWeightKg":80,"changeKg":15,"points":[{"performedOn":"2026-07-09","topWeightKg":65,"reps":12},{"performedOn":"2026-08-27","topWeightKg":80,"reps":10}]}]}
        """
        let response = try JSONDecoder().decode(ProgressResponse.self, from: Data(json.utf8))

        #expect(response.exercises[0].machineLabel == "Beinpresse")
        #expect(response.exercises[0].changeKg == 15)
        #expect(response.exercises[0].points.count == 2)
    }
```

- [ ] **Step 6: Kaltbau**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -derivedDataPath /tmp/dd-sp4-t2 test 2>&1 | grep -E "warning:|error:|TEST SUCCEEDED|TEST FAILED"
rm -rf /tmp/dd-sp4-t2
```

Erwartet: `TEST SUCCEEDED`, nur die vier vorbestehenden Warnungen.

- [ ] **Step 7: Commit**

```bash
git add packages/domain/src/progress.ts tests/integration/domain-progress.test.ts \
        apps/ios-member/FitnessMember/Networking/DTOs/ExerciseProgress.swift \
        apps/ios-member/FitnessMemberTests/DTOTests.swift
git commit -m "feat(api): der Fortschritt traegt das Geraet, das ihn beschriftet

'Beidbeinig' allein ist keine Auskunft -- exercises haengt am Studio,
nicht am Geraetemodell, und erst 'Beinpresse - Beidbeinig' ist eine
Zeile, die jemand zuordnen kann.

Gruppiert wird weiter nach Uebung: zwei baugleiche Beinpressen wuerden
dieselbe Steigerung sonst in zwei kurze Kurven zerlegen. Das Label kommt
vom juengsten Satz."
```

---
### Aufgabe 3: Der Name — Migration, `PUT /me/profile`, Bootstrap

`profiles` existiert seit `0001_tenancy.sql`, hat `select_own` und `update_own` — aber **keine Insert-Policy**, und `0035_kurse.sql` hält fest: „keine Zeile Produktivcode füllt die Spalte". Für kein Mitglied gibt es eine Zeile.

**Files:**
- Create: `supabase/migrations/0039_profiles_insert_own.sql`
- Create: `packages/domain/src/profil.ts`
- Create: `packages/domain/src/profil.test.ts`
- Create: `apps/web/app/api/v1/me/profile/route.ts`
- Create: `tests/integration/api-profil.test.ts`
- Modify: `packages/domain/src/bootstrap.ts`
- Modify: `packages/domain/src/index.ts`
- Modify: `apps/ios-member/FitnessMember/Networking/DTOs/BootstrapResponse.swift`
- Modify: `apps/ios-member/FitnessMember/Networking/APIClient.swift`
- Modify: `apps/ios-member/FitnessMemberTests/DTOTests.swift`

**Interfaces:**
- Produces: `export const anzeigenameSchema`, `export function pruefeAnzeigename(roh: unknown): string`, `export async function setDisplayName(client, payload: unknown): Promise<{ displayName: string }>`; `Bootstrap.member: { displayName: string | null }`; Swift: `BootstrapResponse.member`, `APIClient.setDisplayName(_:) -> ProfilAntwort`

- [ ] **Step 1: Die Migration**

Create `supabase/migrations/0039_profiles_insert_own.sql`:

```sql
-- profiles traegt display_name seit 0001, aber es gibt weder eine
-- Insert-Policy noch einen Trigger, der die Zeile anlegt -- fuer kein
-- Mitglied existiert eine (0035_kurse.sql haelt das ausdruecklich fest).
--
-- Kein SECURITY DEFINER-Trigger auf auth.users: der deckte nur
-- Neuregistrierungen ab, und jedes Bestandsmitglied braeuchte trotzdem
-- den Schreibweg aus dem Profil. Ein Mechanismus, der zwei Wege ersetzt,
-- ist besser als ein zweiter neben ihnen.
create policy profiles_insert_own on public.profiles
  for insert to authenticated
  with check (id = auth.uid());
```

- [ ] **Step 2: Den Unit-Test für die Eingabeprüfung schreiben**

Create `packages/domain/src/profil.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { DomainError } from "./errors.js";
import { pruefeAnzeigename } from "./profil.js";

describe("pruefeAnzeigename", () => {
  it("nimmt einen gewoehnlichen Vornamen an", () => {
    expect(pruefeAnzeigename({ displayName: "Lena" })).toBe("Lena");
  });

  it("schneidet Leerzeichen ab", () => {
    expect(pruefeAnzeigename({ displayName: "  Lena  " })).toBe("Lena");
  });

  it("weist einen leeren Namen ab", () => {
    expect(() => pruefeAnzeigename({ displayName: "   " })).toThrow(DomainError);
  });

  it("weist einen zu langen Namen ab", () => {
    expect(() => pruefeAnzeigename({ displayName: "L".repeat(61) })).toThrow(DomainError);
  });

  it("weist einen fehlenden Rumpf ab", () => {
    expect(() => pruefeAnzeigename({})).toThrow(DomainError);
  });

  // Der Name steht auf einem Screen, nicht in einem Log --
  // Zeilenumbrueche haetten dort nichts zu suchen.
  it("weist einen Zeilenumbruch ab", () => {
    expect(() => pruefeAnzeigename({ displayName: "Lena\nWagner" })).toThrow(DomainError);
  });
});
```

- [ ] **Step 3: Testlauf, der fehlschlagen muss**

```bash
cd packages/domain && pnpm vitest run src/profil.test.ts
```

Erwartet: FAIL — `./profil.js` existiert nicht.

- [ ] **Step 4: `profil.ts` schreiben**

Create `packages/domain/src/profil.ts`:

```ts
import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";
import { requireUserId } from "./auth.js";
import { DomainError } from "./errors.js";

/**
 * Der Anzeigename eines Mitglieds. Sechzig Zeichen sind grosszuegig fuer
 * einen Vornamen und knapp genug, dass die Kopfkarte im Profil ihn nicht
 * umbrechen muss.
 */
export const anzeigenameSchema = z.object({
  displayName: z
    .string()
    .trim()
    .min(1, "Der Name darf nicht leer sein.")
    .max(60, "Der Name ist zu lang -- hoechstens 60 Zeichen.")
    .refine((wert) => !/[\r\n]/.test(wert), "Der Name darf keinen Zeilenumbruch enthalten."),
});

/** Wirft `DomainError("validation_failed")`, sonst der geputzte Name. */
export function pruefeAnzeigename(roh: unknown): string {
  const geprueft = anzeigenameSchema.safeParse(roh);
  if (!geprueft.success) {
    throw new DomainError("validation_failed", geprueft.error.issues[0]!.message);
  }
  return geprueft.data.displayName;
}

/**
 * Der einzige Schreibweg des Namens -- fuer die Registrierung (Aufgabe
 * 11) und fuer das spaetere Aendern im Profil (Aufgabe 10).
 *
 * `upsert`, weil es fuer kein Bestandsmitglied eine profiles-Zeile gibt:
 * die Tabelle steht seit 0001, aber nie hat Produktivcode sie gefuellt.
 * Insert- und Update-Policy pruefen beide `id = auth.uid()`, die Zeile
 * kann also nur die eigene sein.
 */
export async function setDisplayName(
  client: SupabaseClient,
  payload: unknown,
): Promise<{ displayName: string }> {
  const displayName = pruefeAnzeigename(payload);
  const userId = await requireUserId(client);

  const { error } = await client
    .from("profiles")
    .upsert({ id: userId, display_name: displayName }, { onConflict: "id" });

  if (error) throw new DomainError("internal", error.message);

  return { displayName };
}
```

- [ ] **Step 5: Testlauf, der bestehen muss**

```bash
cd packages/domain && pnpm vitest run src/profil.test.ts
```

Erwartet: PASS, 6 Tests.

- [ ] **Step 6: Bootstrap liest den Namen mit**

In `packages/domain/src/bootstrap.ts` den Typ erweitern:

```ts
export type Bootstrap = {
  /**
   * Der Lesepfad des eigenen Namens. `null`, solange keiner gesetzt ist
   * -- Home gruesst dann nicht, und das Profil zeigt nur die
   * Mailadresse. Aus der Mailadresse Initialen abzuleiten waere geraten,
   * und geraten sieht so lange richtig aus, bis es jemanden trifft.
   */
  member: { displayName: string | null };
  studios: Array<{ id: string; name: string; timezone: string }>;
  // ... unveraendert
```

Vor dem `return` die eigene Zeile holen — RLS (`profiles_select_own`) gibt ohnehin nur sie frei; den in der Funktion bereits vorhandenen Bezeichner für die Nutzerkennung verwenden, keinen zweiten einführen:

```ts
  const { data: profilRow } = await client
    .from("profiles")
    .select("display_name")
    .eq("id", userId)
    .maybeSingle();
```

und den Rücksprung ergänzen:

```ts
  return {
    member: {
      displayName: (profilRow as { display_name: string | null } | null)?.display_name ?? null,
    },
    studios: (studioRows ?? []) as Bootstrap["studios"],
    machines,
    calibrations,
    lastSets,
  };
```

- [ ] **Step 7: Die Route**

Create `apps/web/app/api/v1/me/profile/route.ts`:

```ts
import { setDisplayName } from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

/**
 * Den eigenen Anzeigenamen setzen.
 *
 * Ausserhalb der sechs Endpoints aus M1-Spec SS6.3 -- wie schon die
 * Studio-Endpoints aus Sub-Projekt 1, der Tag-Kontext aus Sub-Projekt 2
 * und die Kurse aus Sub-Projekt 3. Die Architekturaussage dahinter
 * (screenorientiert, keine Fachlogik im Client) bleibt unberuehrt.
 *
 * PUT, nicht POST: derselbe Aufruf zweimal gesendet ergibt denselben
 * Namen -- dasselbe Muster wie beim Satz-Schreibweg.
 */
export async function PUT(request: Request): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) return errorResponse("unauthorized", "Anmeldung erforderlich.");

  let payload: unknown;
  try {
    payload = await request.json();
  } catch {
    return errorResponse("validation_failed", "Der Rumpf ist kein gueltiges JSON.");
  }

  try {
    const profil = await setDisplayName(client, payload);
    return Response.json(profil, { status: 200 });
  } catch (error) {
    return fromDomainError(error);
  }
}
```

In `packages/domain/src/index.ts`:

```ts
export { anzeigenameSchema, pruefeAnzeigename, setDisplayName } from "./profil.js";
```

- [ ] **Step 8: Der Integrationstest**

Create `tests/integration/api-profil.test.ts`:

```ts
import { beforeAll, describe, expect, it } from "vitest";
import { GET as bootstrapGET } from "@/app/api/v1/me/bootstrap/route";
import { PUT as profilePUT } from "@/app/api/v1/me/profile/route";
import {
  accessTokenFor,
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";

let email: string;
let userId: string;
let bearer: string;
let fremdeId: string;

function request(rumpf: unknown, auth?: string): Request {
  return new Request("http://localhost/api/v1/me/profile", {
    method: "PUT",
    headers: auth ? { authorization: `Bearer ${auth}` } : {},
    body: JSON.stringify(rumpf),
  });
}

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studio, error: studioError } = await admin
    .from("studios")
    .insert({ name: "Profil-API Studio" })
    .select("id")
    .single();
  if (studioError) throw studioError;

  email = uniqueEmail("profil-member");
  userId = await createTestUser(email);
  fremdeId = await createTestUser(uniqueEmail("profil-fremd"));

  const { error: membershipError } = await admin
    .from("studio_memberships")
    .insert({ studio_id: studio.id, user_id: userId, role: "member" });
  if (membershipError) throw membershipError;

  bearer = await accessTokenFor(email);
});

describe("PUT /me/profile", () => {
  it("legt die Zeile an und liefert den geputzten Namen", async () => {
    const response = await profilePUT(request({ displayName: "  Lena  " }, bearer));

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ displayName: "Lena" });
  });

  it("aendert einen bestehenden Namen", async () => {
    await profilePUT(request({ displayName: "Lena" }, bearer));
    const response = await profilePUT(request({ displayName: "Lena W." }, bearer));

    expect(response.status).toBe(200);

    const { data } = await serviceClient()
      .from("profiles")
      .select("display_name")
      .eq("id", userId)
      .single();
    expect(data?.display_name).toBe("Lena W.");
  });

  it("weist einen leeren Namen ab", async () => {
    const response = await profilePUT(request({ displayName: "   " }, bearer));

    expect(response.status).toBe(422);
    const payload = (await response.json()) as { error: { code: string } };
    expect(payload.error.code).toBe("validation_failed");
  });

  it("weist einen Aufruf ohne Anmeldung ab", async () => {
    const response = await profilePUT(request({ displayName: "Lena" }));
    expect(response.status).toBe(401);
  });
});

describe("profiles_insert_own", () => {
  // Die Policy prueft id = auth.uid(). Ohne diese Pruefung koennte
  // jemand eine Zeile fuer ein fremdes Konto anlegen -- und der naechste
  // Bootstrap dieses Kontos truege einen fremden Namen.
  it("laesst keine Zeile fuer ein fremdes Konto zu", async () => {
    const client = await userClient(email);

    const { error } = await client
      .from("profiles")
      .insert({ id: fremdeId, display_name: "Fremd" });

    expect(error).not.toBeNull();
  });
});

describe("GET /me/bootstrap -- member", () => {
  it("liefert den gesetzten Namen", async () => {
    await profilePUT(request({ displayName: "Lena" }, bearer));

    const response = await bootstrapGET(
      new Request("http://localhost/api/v1/me/bootstrap", {
        headers: { authorization: `Bearer ${bearer}` },
      }),
    );

    expect(response.status).toBe(200);
    const payload = (await response.json()) as { member: { displayName: string | null } };
    expect(payload.member.displayName).toBe("Lena");
  });

  it("liefert null fuer ein Mitglied ohne Zeile", async () => {
    const ohneName = uniqueEmail("profil-ohne-name");
    await createTestUser(ohneName);
    const anderesBearer = await accessTokenFor(ohneName);

    const response = await bootstrapGET(
      new Request("http://localhost/api/v1/me/bootstrap", {
        headers: { authorization: `Bearer ${anderesBearer}` },
      }),
    );

    const payload = (await response.json()) as { member: { displayName: string | null } };
    expect(payload.member.displayName).toBeNull();
  });
});
```

- [ ] **Step 9: Migration anwenden, beide Testebenen laufen lassen**

```bash
npx --no-install supabase migration list --local
npx --no-install supabase migration up --local
cd packages/domain && pnpm vitest run && cd ../..
pnpm vitest run tests/integration/api-profil.test.ts tests/integration/domain-bootstrap.test.ts tests/integration/api-me.test.ts
pnpm typecheck 2>&1 | tail -6
```

Erwartet: `0039` angewendet, alle Läufe grün. Die bestehenden Bootstrap-Tests zeigen, ob irgendwo eine feste Antwortform verglichen wird, der jetzt `member` fehlt — solche Stellen mit dem Feld ergänzen, nicht die Prüfung lockern.

- [ ] **Step 10: Die iOS-Seite**

In `BootstrapResponse.swift` der neue Typ, das Feld und die zwei DTOs des Schreibwegs:

```swift
    struct Member: Decodable, Equatable, Sendable {
        let displayName: String?
    }
```

```swift
    let member: Member
    let studios: [Studio]
```

Am Dateiende:

```swift
struct AnzeigenameWrite: Encodable { let displayName: String }

struct ProfilAntwort: Decodable, Equatable { let displayName: String }
```

In `APIClient.swift`:

```swift
    /// Der einzige Schreibweg des Namens -- Registrierung wie spaeteres
    /// Aendern. Die Antwort traegt den geputzten Namen zurueck.
    func setDisplayName(_ name: String) async throws(APIError) -> ProfilAntwort {
        try await send("me/profile", method: "PUT", body: AnzeigenameWrite(displayName: name))
    }
```

- [ ] **Step 11: Der DTO-Test**

In `DTOTests.swift`:

```swift
    @Test("dekodiert ein Bootstrap ohne gesetzten Namen")
    func decodesMemberOhneNamen() throws {
        let json = #"{"member":{"displayName":null},"studios":[],"machines":[],"calibrations":[],"lastSets":[]}"#
        let response = try JSONDecoder().decode(BootstrapResponse.self, from: Data(json.utf8))

        #expect(response.member.displayName == nil)
    }
```

Bestehende Bootstrap-JSONs in `DTOTests.swift` und `CatalogStoreTests.swift` brauchen jetzt ebenfalls das `member`-Feld — der Kaltbau zeigt, welche.

- [ ] **Step 12: Kaltbau**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -derivedDataPath /tmp/dd-sp4-t3 test 2>&1 | grep -E "warning:|error:|TEST SUCCEEDED|TEST FAILED"
rm -rf /tmp/dd-sp4-t3
```

Erwartet: `TEST SUCCEEDED`, nur die vier vorbestehenden Warnungen.

- [ ] **Step 13: Commit**

```bash
git add supabase/migrations/0039_profiles_insert_own.sql packages/domain \
        apps/web/app/api/v1/me/profile tests/integration/api-profil.test.ts \
        apps/ios-member
git commit -m "feat(api): der Anzeigename bekommt einen Schreibweg

profiles traegt display_name seit Migration 0001, hatte aber weder
Insert-Policy noch Trigger -- fuer kein Mitglied existierte eine Zeile.

Eine Insert-Policy plus PUT /me/profile statt eines SECURITY
DEFINER-Triggers auf auth.users: der Trigger deckte nur
Neuregistrierungen ab, und jedes Bestandsmitglied braeuchte trotzdem den
Schreibweg aus dem Profil. Ein Mechanismus, der zwei Wege ersetzt, ist
besser als ein zweiter neben ihnen.

Gelesen wird der Name im Bootstrap -- dem Abruf, der ohnehin bei jedem
Start laeuft."
```

---
### Aufgabe 4: `VerlaufHerkunft` und der gemeinsame Satzbau

`KurseHerkunft` beantwortet für Kurse die Frage „wie alt ist das hier". Der Verlauf braucht dieselbe Frage mit anderer Antwort — und **denselben Satz**: zwei Formulierungen für denselben Sachverhalt wären für das Mitglied zwei Sachverhalte.

**Files:**
- Create: `apps/ios-member/FitnessMember/Herkunftssatz.swift`
- Create: `apps/ios-member/FitnessMember/Verlauf/VerlaufHerkunft.swift`
- Create: `apps/ios-member/FitnessMemberTests/VerlaufHerkunftTests.swift`
- Modify: `apps/ios-member/FitnessMember/Kurse/KurseHerkunft.swift`

**Interfaces:**
- Produces: `enum Herkunftssatz { static func bilden(ohneEmpfang: Bool, stand: Date?, zusatz: String?) -> String }`; `enum VerlaufLadeZustand { case bereit, laedt, geladen, fehlgeschlagen(APIError) }`; `enum VerlaufHerkunft { case frisch, ohneEmpfang, serverfehler }` mit `static func bilden(ladeZustand:) -> VerlaufHerkunft`, `var symbol: String?`, `func satz(stand: Date?) -> String?`

- [ ] **Step 1: Den Test schreiben**

Create `apps/ios-member/FitnessMemberTests/VerlaufHerkunftTests.swift`:

```swift
import Foundation
import Testing
@testable import FitnessMember

/// Der Verlauf veraltet anders als eine Belegungszahl -- er aendert sich
/// ausschliesslich durch das eigene Tun. Deshalb hat dieser Typ keine
/// Frischegrenze und keinen Zustand `veraltet`.
struct VerlaufHerkunftTests {
    private let stand = Date(timeIntervalSince1970: 1_757_000_000)

    @Test func einGelungenerAbrufIstFrisch() {
        #expect(VerlaufHerkunft.bilden(ladeZustand: .geladen) == .frisch)
    }

    @Test func einAlterStandOhneFehlschlagBleibtFrisch() {
        // Kein Gegenstueck zu KurseHerkunft.veraltet: ein Training von
        // gestern ist morgen noch genau so gewesen.
        #expect(VerlaufHerkunft.bilden(ladeZustand: .geladen).satz(stand: stand) == nil)
    }

    @Test func waehrendDesErstenLadensStehtKeinHinweis() {
        #expect(VerlaufHerkunft.bilden(ladeZustand: .laedt) == .frisch)
        #expect(VerlaufHerkunft.bilden(ladeZustand: .bereit) == .frisch)
    }

    @Test func ohneEmpfangIstNichtDasselbeWieEinServerfehler() {
        #expect(VerlaufHerkunft.bilden(ladeZustand: .fehlgeschlagen(.offline)) == .ohneEmpfang)
        #expect(VerlaufHerkunft.bilden(ladeZustand: .fehlgeschlagen(.server)) == .serverfehler)
    }

    @Test func derSatzNenntDenStand() {
        let satz = VerlaufHerkunft.ohneEmpfang.satz(stand: stand)

        #expect(satz?.hasPrefix("Ohne Empfang.") == true)
        #expect(satz?.contains(Zahlformat.stand(stand)) == true)
    }

    /// "Kein Empfang" waere hier eine falsche Aussage ueber das Geraet --
    /// dieselbe Unterscheidung wie bei den Kursen.
    @Test func einServerfehlerSchicktNiemandenWLANSuchen() {
        let satz = VerlaufHerkunft.serverfehler.satz(stand: stand)

        #expect(satz?.contains("Ohne Empfang") == false)
        #expect(satz?.hasPrefix("Diese Angaben stammen vom letzten Abruf.") == true)
    }
}
```

Der Fehlerfall `.server` muss zum tatsächlichen `APIError`-Fall passen — `APIError.swift` nennt die Fälle; falls dort kein `.server` steht, den vorhandenen Nicht-Offline-Fall einsetzen.

- [ ] **Step 2: Testlauf, der fehlschlagen muss**

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -derivedDataPath /tmp/dd-sp4-t4 test -only-testing:FitnessMemberTests/VerlaufHerkunftTests 2>&1 | tail -20
```

Erwartet: Übersetzungsfehler — `VerlaufHerkunft` existiert nicht.

- [ ] **Step 3: Den gemeinsamen Satzbau herausziehen**

Create `apps/ios-member/FitnessMember/Herkunftssatz.swift`:

```swift
import Foundation

/// Der Satz ueber einem Inhalt, der nicht aus einem frischen Abruf
/// stammt -- eine Stelle fuer Kurse und Verlauf.
///
/// Getrennt von beiden Herkunftstypen, weil deren ZUSTAENDE sich
/// unterscheiden (eine Belegungszahl veraltet von selbst, ein Verlauf
/// nicht), der SATZ aber derselbe sein muss: zwei Formulierungen fuer
/// denselben Sachverhalt waeren fuer das Mitglied zwei Sachverhalte.
enum Herkunftssatz {
    static func bilden(ohneEmpfang: Bool, stand: Date?, zusatz: String? = nil) -> String {
        let anfang = ohneEmpfang
            ? "Ohne Empfang."
            : "Diese Angaben stammen vom letzten Abruf."
        let datum = stand.map { " Stand: \(Zahlformat.stand($0))." } ?? ""
        let rest = zusatz.map { " \($0)" } ?? ""
        return anfang + datum + rest
    }
}
```

In `KurseHerkunft.swift` wird `satz(stand:zusatz:)` zum Weiterreicher — der bestehende Dokumentationskommentar über der Methode bleibt:

```swift
    func satz(stand: Date?, zusatz: String? = nil) -> String? {
        guard self != .frisch else { return nil }
        return Herkunftssatz.bilden(
            ohneEmpfang: self == .ohneEmpfang, stand: stand, zusatz: zusatz)
    }
```

- [ ] **Step 4: `VerlaufHerkunft` schreiben**

Create `apps/ios-member/FitnessMember/Verlauf/VerlaufHerkunft.swift`:

```swift
import Foundation

/// Ladezustand des Verlaufs. Spiegelt `KurseLadeZustand`, ist aber ein
/// eigener Typ: dort entscheidet der Zustand zusaetzlich darueber, ob
/// eine Belegungszahl ueberhaupt gezeigt werden darf. Hier gibt es
/// nichts, was so schnell unwahr wird.
enum VerlaufLadeZustand: Equatable {
    case bereit
    case laedt
    case geladen
    /// Traegt den tatsaechlichen Fehler: "offline" darf projektweit nie
    /// als "fehlgeschlagen" erscheinen (designsystem.md SS5).
    case fehlgeschlagen(APIError)
}

/// Wie das zustande kam, was der Home-Tab gerade zeigt.
///
/// Bewusst OHNE `veraltet` und ohne Frischegrenze -- das ist der
/// Unterschied zu `KurseHerkunft`, und er ist keine Nachlaessigkeit: eine
/// Belegungszahl veraltet binnen Minuten, ohne dass jemand etwas tut. Ein
/// Verlauf aendert sich ausschliesslich durch das eigene Tun; ein
/// Training von gestern ist morgen noch genau so gewesen. Die
/// Fuenf-Minuten-Grenze der Kurse setzte hier ein Datum ueber etwas, das
/// noch stimmt.
enum VerlaufHerkunft: Equatable {
    case frisch
    case ohneEmpfang
    case serverfehler

    static func bilden(ladeZustand: VerlaufLadeZustand) -> VerlaufHerkunft {
        guard case .fehlgeschlagen(let fehler) = ladeZustand else { return .frisch }
        return fehler == .offline ? .ohneEmpfang : .serverfehler
    }

    var symbol: String? {
        switch self {
        case .frisch: nil
        case .ohneEmpfang: "wifi.slash"
        case .serverfehler: "clock.arrow.circlepath"
        }
    }

    /// `nil`, solange der letzte Abruf durchging -- ein Datum ueber
    /// frischen Zahlen waere Rauschen.
    func satz(stand: Date?) -> String? {
        guard self != .frisch else { return nil }
        return Herkunftssatz.bilden(ohneEmpfang: self == .ohneEmpfang, stand: stand)
    }
}
```

- [ ] **Step 5: Testlauf, der bestehen muss**

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -derivedDataPath /tmp/dd-sp4-t4 test 2>&1 | grep -E "warning:|error:|TEST SUCCEEDED|TEST FAILED"
rm -rf /tmp/dd-sp4-t4
```

Erwartet: `TEST SUCCEEDED` — inklusive der unveränderten `KurseHerkunftTests`, die den Satzbau jetzt über den gemeinsamen Weg bekommen.

- [ ] **Step 6: Commit**

```bash
git add apps/ios-member/FitnessMember/Herkunftssatz.swift \
        apps/ios-member/FitnessMember/Verlauf apps/ios-member/FitnessMember/Kurse/KurseHerkunft.swift \
        apps/ios-member/FitnessMemberTests/VerlaufHerkunftTests.swift \
        apps/ios-member/FitnessMember.xcodeproj
git commit -m "feat(ios): der Verlauf bekommt seine eigene Herkunft

Ohne veraltet-Zustand und ohne Frischegrenze, anders als bei den Kursen:
eine Belegungszahl veraltet binnen Minuten von selbst, ein Verlauf
aendert sich nur durch eigenes Tun. Eine Fuenf-Minuten-Regel setzte hier
ein Datum ueber etwas, das noch stimmt.

Der Satz darueber ist derselbe und liegt jetzt an einer Stelle -- zwei
Formulierungen fuer denselben Sachverhalt waeren fuer das Mitglied zwei
Sachverhalte."
```

---

### Aufgabe 5: `VerlaufFileStore` und `VerlaufStore`

Der erste Screen der App darf im Keller nicht leer sein. Anders als bei den Kursen darf hier **alles** auf die Platte: es gibt keine Zahl, die ohne Netz unwahr würde.

**Files:**
- Create: `apps/ios-member/FitnessMember/Verlauf/VerlaufFileStore.swift`
- Create: `apps/ios-member/FitnessMember/Verlauf/VerlaufStore.swift`
- Create: `apps/ios-member/FitnessMemberTests/VerlaufStoreTests.swift`
- Modify: `apps/ios-member/FitnessMember/Networking/DTOs/SessionSummary.swift`
- Modify: `apps/ios-member/FitnessMember/Networking/DTOs/ExerciseProgress.swift`
- Modify: `apps/ios-member/FitnessMember/FitnessMemberApp.swift`

**Interfaces:**
- Consumes: `VerlaufHerkunft`, `VerlaufLadeZustand` (Aufgabe 4), `APIClient.sessions(studio:)` (Aufgabe 1)
- Produces: `protocol VerlaufLoading`; `struct GespeicherterVerlauf: Codable`; `final class VerlaufFileStore` mit `load() -> GespeicherterVerlauf?` und `save(_:)`; `@MainActor @Observable final class VerlaufStore` mit `sessions`, `summary`, `fortschritt`, `stand`, `ladeZustand`, `herkunft`, `func laden(studioId: String?) async`, `func reset()`

- [ ] **Step 1: Die DTOs schreibbar machen**

`SessionSummary`, `SessionsSummary`, `ExerciseProgress` und ihre verschachtelten Typen werden von `Decodable` auf `Codable` gehoben — sonst lässt sich der Cache nicht schreiben. `ProblemReason` ist bereits `Codable`.

- [ ] **Step 2: Den Test schreiben**

Create `apps/ios-member/FitnessMemberTests/VerlaufStoreTests.swift`:

```swift
import Foundation
import Testing
@testable import FitnessMember

/// Dateiweit, nicht als statische Eigenschaft der Suite: die
/// Attrappe unten ist ein verschachtelter Typ und kaeme an eine
/// Eigenschaft der aeusseren Struktur nicht heran.
private let leereKopfzeile = SessionsSummary(
    totalCount: 0, thisWeekCount: nil, lastSessionAt: nil)

@MainActor
struct VerlaufStoreTests {
    /// Eine Attrappe, deren naechste Antwort der Test setzt -- dasselbe
    /// Muster wie in KurseStoreTests.
    final class FakeLoader: VerlaufLoading, @unchecked Sendable {
        var antwort: SessionsResponse?
        var fortschritt: [ExerciseProgress] = []
        var fehler: APIError?
        var abrufe = 0

        func sessions(studio: String?) async throws(APIError) -> SessionsResponse {
            abrufe += 1
            if let fehler { throw fehler }
            return antwort ?? SessionsResponse(sessions: [], summary: leereKopfzeile)
        }

        func progress() async throws(APIError) -> [ExerciseProgress] {
            if let fehler { throw fehler }
            return fortschritt
        }
    }

    private func store(
        _ loader: FakeLoader, verzeichnis: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
    ) -> VerlaufStore {
        VerlaufStore(loader: loader, fileStore: VerlaufFileStore(directory: verzeichnis))
    }

    private func einheit(id: String = "s1") -> SessionSummary {
        SessionSummary(
            id: id, startedAt: "2026-09-08T16:04:00Z", completedAt: "2026-09-08T16:51:00Z",
            completedReason: "manual", machineCount: 3, setCount: 8, blocks: [])
    }

    @Test func einGelungenerAbrufFuelltDenStore() async {
        let loader = FakeLoader()
        loader.antwort = SessionsResponse(
            sessions: [einheit()],
            summary: SessionsSummary(totalCount: 34, thisWeekCount: 2, lastSessionAt: nil))
        let verlauf = store(loader)

        await verlauf.laden(studioId: "st1")

        #expect(verlauf.sessions.count == 1)
        #expect(verlauf.summary?.totalCount == 34)
        #expect(verlauf.herkunft == .frisch)
        #expect(verlauf.stand != nil)
    }

    /// Der Kern der Aufgabe: der Keller. Was einmal geladen war, bleibt
    /// stehen -- und traegt darueber ein ehrliches Datum.
    @Test func einFehlgeschlagenerAbrufLaesstDenStandStehen() async {
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let loader = FakeLoader()
        loader.antwort = SessionsResponse(
            sessions: [einheit()], summary: leereKopfzeile)
        let erster = store(loader, verzeichnis: verzeichnis)
        await erster.laden(studioId: "st1")

        let zweiterLoader = FakeLoader()
        zweiterLoader.fehler = .offline
        let zweiter = store(zweiterLoader, verzeichnis: verzeichnis)
        await zweiter.laden(studioId: "st1")

        #expect(zweiter.sessions.count == 1)
        #expect(zweiter.herkunft == .ohneEmpfang)
        #expect(zweiter.satzUeberDemInhalt?.hasPrefix("Ohne Empfang.") == true)
    }

    @Test func derCacheStehtSchonVorDemErstenAbruf() async {
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let loader = FakeLoader()
        loader.antwort = SessionsResponse(
            sessions: [einheit()], summary: leereKopfzeile)
        await store(loader, verzeichnis: verzeichnis).laden(studioId: nil)

        let neuerStart = store(FakeLoader(), verzeichnis: verzeichnis)

        #expect(neuerStart.sessions.count == 1)
        #expect(neuerStart.ladeZustand == .bereit)
    }

    /// Nach dem Abmelden darf vom vorigen Konto nichts stehen bleiben --
    /// dieselbe Regel wie in CatalogStore.reset().
    @Test func resetRaeumtSpeicherUndPlatte() async {
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let loader = FakeLoader()
        loader.antwort = SessionsResponse(
            sessions: [einheit()], summary: leereKopfzeile)
        let verlauf = store(loader, verzeichnis: verzeichnis)
        await verlauf.laden(studioId: nil)

        verlauf.reset()

        #expect(verlauf.sessions.isEmpty)
        #expect(store(FakeLoader(), verzeichnis: verzeichnis).sessions.isEmpty)
    }
}
```

- [ ] **Step 3: Testlauf, der fehlschlagen muss**

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -derivedDataPath /tmp/dd-sp4-t5 test -only-testing:FitnessMemberTests/VerlaufStoreTests 2>&1 | tail -20
```

Erwartet: Übersetzungsfehler — `VerlaufStore` existiert nicht.

- [ ] **Step 4: Den Dateispeicher schreiben**

Create `apps/ios-member/FitnessMember/Verlauf/VerlaufFileStore.swift`:

```swift
import Foundation

/// Der Verlauf auf Platte -- vollstaendig, anders als bei den Kursen.
///
/// `KurseFileStore` laesst Belegungszahlen bewusst weg: sie veralten
/// binnen Minuten, und ohne Netz waeren sie eine Unwahrheit. Hier gibt es
/// nichts dergleichen -- Einheiten, Saetze und Gewichte aendern sich
/// ausschliesslich durch das eigene Tun.
///
/// Ohne `studioId`, ebenfalls anders als bei den Kursen: der Verlauf ist
/// studioübergreifend. Wer in zwei Studios trainiert, hat einen Verlauf,
/// nicht zwei -- ein Studiowechsel macht ihn also nicht falsch, nur die
/// Wochenzahl darin gehoert zur Zeitzone des vorigen Studios, und die
/// rechnet der naechste Abruf neu.
struct GespeicherterVerlauf: Codable {
    let stand: Date
    let sessions: [SessionSummary]
    let summary: SessionsSummary
    let fortschritt: [ExerciseProgress]
}

/// Wie `KurseFileStore` und `SessionFileStore`: App-Support-Verzeichnis,
/// JSON, atomar, Fehler still -- ein fehlendes oder verderbtes File ist
/// kein Absturzgrund, nur ein leerer Cache.
final class VerlaufFileStore {
    private let fileURL: URL

    init(directory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("verlauf.json")
    }

    func load() -> GespeicherterVerlauf? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(GespeicherterVerlauf.self, from: data)
    }

    /// `nil` raeumt die Datei weg -- fuer reset() beim Abmelden.
    func save(_ verlauf: GespeicherterVerlauf?) {
        guard let verlauf else {
            try? FileManager.default.removeItem(at: fileURL)
            return
        }
        guard let data = try? JSONEncoder().encode(verlauf) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
```

- [ ] **Step 5: Den Store schreiben**

Create `apps/ios-member/FitnessMember/Verlauf/VerlaufStore.swift`:

```swift
import Foundation
import Observation

/// Was der Home-Tab vom Netz braucht -- eigene schmale Fassade, wie
/// `KurseLoading` und `BootstrapLoading`.
protocol VerlaufLoading: Sendable {
    func sessions(studio: String?) async throws(APIError) -> SessionsResponse
    func progress() async throws(APIError) -> [ExerciseProgress]
}

extension APIClient: VerlaufLoading {}

/// Haelt Verlauf, Kopfzeile und Fortschritt -- und den Zeitpunkt, an dem
/// sie zuletzt wirklich vom Server kamen.
///
/// @MainActor wie CatalogStore und KurseStore: der Store wird ueber
/// @Environment direkt in Views gelesen.
@MainActor
@Observable
final class VerlaufStore {
    private(set) var sessions: [SessionSummary] = []
    private(set) var summary: SessionsSummary?
    private(set) var fortschritt: [ExerciseProgress] = []
    private(set) var stand: Date?
    private(set) var ladeZustand: VerlaufLadeZustand = .bereit

    var herkunft: VerlaufHerkunft { VerlaufHerkunft.bilden(ladeZustand: ladeZustand) }

    /// Der Satz ueber dem ganzen Screen, nicht ueber einer einzelnen
    /// Zahl: ohne Netz driften "diese Woche" und "Tage her" mit der Uhr,
    /// waehrend die Liste darunter richtig bleibt. Ein datierter Screen
    /// ist ehrlicher als eine still wandernde Zahl.
    var satzUeberDemInhalt: String? { herkunft.satz(stand: stand) }

    #if DEBUG
    let loader: any VerlaufLoading
    #else
    private let loader: any VerlaufLoading
    #endif
    private let fileStore: VerlaufFileStore

    /// Steigt bei jedem laden(...) und bei reset(). Eine Antwort, die
    /// zurueckkommt, nachdem die Generation weitergezogen ist, ist
    /// ueberholt und wird verworfen -- sonst ueberschriebe sie einen
    /// frischeren oder kontofremden Zustand.
    private var generation = 0

    init(loader: any VerlaufLoading, fileStore: VerlaufFileStore) {
        self.loader = loader
        self.fileStore = fileStore

        if let gespeichert = fileStore.load() {
            sessions = gespeichert.sessions
            summary = gespeichert.summary
            fortschritt = gespeichert.fortschritt
            stand = gespeichert.stand
        }
    }

    /// Laedt Verlauf und Fortschritt. Scheitert einer der beiden Abrufe,
    /// bleibt der bisherige Stand vollstaendig stehen -- er ist nicht
    /// falsch geworden, nur aelter.
    func laden(studioId: String?) async {
        generation += 1
        let eigene = generation
        ladeZustand = .laedt

        do {
            // Nacheinander statt nebenlaeufig: zwei kleine Abrufe, und
            // `async let` gaebe den getippten APIError als `any Error`
            // zurueck -- der Unterschied offline/Serverfehler ginge dabei
            // verloren, und genau der traegt den Satz oben.
            let antwort = try await loader.sessions(studio: studioId)
            let punkte = try await loader.progress()
            guard eigene == generation else { return }

            let jetzt = Date()
            sessions = antwort.sessions
            summary = antwort.summary
            fortschritt = punkte
            stand = jetzt
            ladeZustand = .geladen
            fileStore.save(
                GespeicherterVerlauf(
                    stand: jetzt, sessions: antwort.sessions, summary: antwort.summary,
                    fortschritt: punkte))
        } catch {
            guard eigene == generation else { return }
            ladeZustand = .fehlgeschlagen(error)
        }
    }

    /// Nach dem Abmelden: sonst saehe das naechste Konto auf demselben
    /// Geraet den Verlauf des vorigen.
    func reset() {
        generation += 1
        sessions = []
        summary = nil
        fortschritt = []
        stand = nil
        ladeZustand = .bereit
        fileStore.save(nil)
    }
}
```

- [ ] **Step 6: In die Umgebung hängen**

In `FitnessMemberApp.swift` wird der Store wie `KurseStore` erzeugt und über `.environment(...)` weitergereicht. Beim Abmelden ruft dieselbe Stelle, die `CatalogStore.reset()` ruft, auch `VerlaufStore.reset()` — die vorhandene Aufrufstelle suchen, keine zweite anlegen.

- [ ] **Step 7: Testlauf, der bestehen muss**

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -derivedDataPath /tmp/dd-sp4-t5 test 2>&1 | grep -E "warning:|error:|TEST SUCCEEDED|TEST FAILED"
rm -rf /tmp/dd-sp4-t5
```

Erwartet: `TEST SUCCEEDED`, nur die vier vorbestehenden Warnungen.

- [ ] **Step 8: Commit**

```bash
git add apps/ios-member
git commit -m "feat(ios): der Verlauf haelt seinen Stand auf Platte

Home ist der erste Screen der App und stand im Keller leer da -- dort,
wo das Netz am schlechtesten ist. Der Cache traegt alles: Einheiten,
Kopfzeile, Fortschritt. Anders als bei den Kursen faellt nichts weg,
weil es hier keine Zahl gibt, die ohne Netz unwahr wuerde.

Scheitert ein Abruf, bleibt der Stand vollstaendig stehen und bekommt
einen Satz mit Datum darueber -- ueber den ganzen Screen, nicht ueber
eine einzelne Zahl: ohne Netz driften 'diese Woche' und 'Tage her' mit
der Uhr, waehrend die Liste darunter richtig bleibt."
```

---
### Aufgabe 6: `HomeRootView` — beide Zustände

`Home.dc.html` und `HomeLeer.dc.html` sind ein Screen mit zwei Zuständen. Die Ableitungen dahinter sind rein und werden vor dem Screen geprüft.

**Files:**
- Create: `apps/ios-member/FitnessMember/Verlauf/HomeZeilen.swift`
- Create: `apps/ios-member/FitnessMemberTests/HomeZeilenTests.swift`
- Create: `apps/ios-member/FitnessMember/Screens/Home/HomeRootView.swift`
- Create: `apps/ios-member/FitnessMember/Navigation/HomeRoute.swift`
- Modify: `apps/ios-member/FitnessMember/DesignSystem/Zahlformat.swift`
- Modify: `apps/ios-member/FitnessMemberTests/ZahlformatTests.swift`
- Modify: `apps/ios-member/FitnessMember/Catalog/CatalogStore.swift`
- Modify: `apps/ios-member/FitnessMember/Navigation/MainTabView.swift`

**Interfaces:**
- Consumes: `VerlaufStore` (Aufgabe 5), `SessionsSummary` (Aufgabe 1), `ExerciseProgress.machineLabel` (Aufgabe 2), `BootstrapResponse.member` (Aufgabe 3)
- Produces: `enum HomeZeilen` mit `abgeschlossene(_:)`, `dauerText(_:)`, `tageHer(_:jetzt:kalender:)`, `vorname(_:)`, `initialen(_:)`; `enum HomeRoute: Hashable { case sessionDetail(id: String), uebungsfortschritt(exerciseId: String) }`; `Zahlformat.wochentagDatum(_:)`, `Zahlformat.kurzerWochentagDatum(_:)`; `CatalogStore.studiohinweis`

- [ ] **Step 1: Den Test der reinen Ableitungen schreiben**

Create `apps/ios-member/FitnessMemberTests/HomeZeilenTests.swift`:

```swift
import Foundation
import Testing
@testable import FitnessMember

struct HomeZeilenTests {
    private func einheit(
        id: String = "s1",
        startedAt: String = "2026-09-08T16:04:00Z",
        completedAt: String? = "2026-09-08T16:51:00Z",
        completedReason: String? = "manual"
    ) -> SessionSummary {
        SessionSummary(
            id: id, startedAt: startedAt, completedAt: completedAt,
            completedReason: completedReason, machineCount: 3, setCount: 8, blocks: [])
    }

    /// Was heute noch laeuft, ist kein Verlauf -- die laufende Einheit
    /// steht im Training-Tab.
    @Test func dieLaufendeEinheitStehtNichtImVerlauf() {
        let zeilen = HomeZeilen.abgeschlossene([
            einheit(id: "laeuft", completedAt: nil, completedReason: nil),
            einheit(id: "fertig"),
        ])

        #expect(zeilen.map(\.id) == ["fertig"])
    }

    @Test func eineBeendeteEinheitZeigtIhreDauer() {
        #expect(HomeZeilen.dauerText(einheit()) == "47 min")
    }

    /// getSessions setzt das Ende einer vergessenen Einheit auf den
    /// letzten Satz -- die daraus gerechnete Dauer ist eine Untergrenze,
    /// keine Dauer. Das Artboard laesst sie deshalb weg.
    @Test func eineSelbsttaetigBeendeteEinheitZeigtKeineDauer() {
        #expect(HomeZeilen.dauerText(einheit(completedReason: "auto")) == nil)
    }

    @Test func tageHerZaehltKalendertage() {
        var kalender = Calendar(identifier: .gregorian)
        kalender.timeZone = TimeZone(identifier: "Europe/Berlin")!
        let jetzt = Date(timeIntervalSince1970: 1_757_500_000)
        let vorbei = jetzt.addingTimeInterval(-3 * 24 * 60 * 60)

        let iso = ISO8601DateFormatter().string(from: vorbei)
        #expect(HomeZeilen.tageHer(iso, jetzt: jetzt, kalender: kalender) == 3)
    }

    @Test func ohneEinheitGibtEsKeineTageHer() {
        #expect(HomeZeilen.tageHer(nil, jetzt: Date(), kalender: .current) == nil)
    }

    @Test func derGrussNimmtDenErstenNamensteil() {
        #expect(HomeZeilen.vorname("Lena Wagner") == "Lena")
        #expect(HomeZeilen.vorname("Lena") == "Lena")
    }

    /// Ohne gesetzten Namen wird nichts erfunden -- weder Gruss noch
    /// Initialen. Aus einer Mailadresse abgeleitet saehe beides so lange
    /// richtig aus, bis es jemanden trifft.
    @Test func ohneNamenGibtEsWederGrussNochInitialen() {
        #expect(HomeZeilen.vorname(nil) == nil)
        #expect(HomeZeilen.vorname("   ") == nil)
        #expect(HomeZeilen.initialen(nil) == nil)
    }

    @Test func initialenNehmenHoechstensZweiTeile() {
        #expect(HomeZeilen.initialen("Lena Wagner") == "LW")
        #expect(HomeZeilen.initialen("Lena") == "L")
        #expect(HomeZeilen.initialen("Lena Marie Wagner") == "LM")
    }
}
```

- [ ] **Step 2: Testlauf, der fehlschlagen muss**

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -derivedDataPath /tmp/dd-sp4-t6 test -only-testing:FitnessMemberTests/HomeZeilenTests 2>&1 | tail -20
```

Erwartet: Übersetzungsfehler — `HomeZeilen` existiert nicht.

- [ ] **Step 3: `KursZeitpunkt` wird zu `Zeitpunkt`**

Der ISO-Parser trägt heute den Namen des Kurse-Moduls, wird aber schon im nächsten Schritt vom Verlauf gebraucht — deshalb vor den Ableitungen. Die Umbenennung ist mechanisch — erst die Aufrufstellen finden:

```bash
grep -rn "KursZeitpunkt" apps/ios-member
```

Dann `enum KursZeitpunkt` aus `Kurse/KursZustand.swift` in eine neue Datei `FitnessMember/Zeitpunkt.swift` verschieben, in `Zeitpunkt` umbenennen (Kommentar über dem Typ mitnehmen) und alle Fundstellen nachziehen. Keine inhaltliche Änderung.

- [ ] **Step 4: Die Ableitungen schreiben**

Create `apps/ios-member/FitnessMember/Verlauf/HomeZeilen.swift`:

```swift
import Foundation

/// Die reinen Ableitungen des Home-Tabs -- getrennt vom View, damit sie
/// pruefbar bleiben.
enum HomeZeilen {
    /// Was heute noch laeuft, ist kein Verlauf. Die laufende Einheit hat
    /// kein `completedAt` und steht im Training-Tab.
    static func abgeschlossene(_ sessions: [SessionSummary]) -> [SessionSummary] {
        sessions.filter { $0.completedAt != nil }
    }

    /// `nil` bei einer selbsttaetig beendeten Einheit: getSessions setzt
    /// deren Ende auf den letzten Satz, damit eine vergessene Einheit
    /// nicht rueckwirkend Stunden dauert. Die daraus gerechnete Dauer ist
    /// eine Untergrenze, keine Dauer.
    static func dauerText(_ session: SessionSummary) -> String? {
        guard session.completedReason != "auto",
              let endeIso = session.completedAt,
              let start = Zeitpunkt.parse(session.startedAt),
              let ende = Zeitpunkt.parse(endeIso)
        else { return nil }

        let minuten = Int((ende.timeIntervalSince(start) / 60).rounded())
        return "\(minuten) min"
    }

    /// Kalendertage, nicht 24-Stunden-Schritte: "gestern" ist gestern,
    /// auch wenn dazwischen nur zwei Stunden liegen.
    static func tageHer(_ lastSessionAt: String?, jetzt: Date, kalender: Calendar) -> Int? {
        guard let lastSessionAt, let zeitpunkt = Zeitpunkt.parse(lastSessionAt) else { return nil }

        return kalender.dateComponents(
            [.day],
            from: kalender.startOfDay(for: zeitpunkt),
            to: kalender.startOfDay(for: jetzt)
        ).day
    }

    /// Der erste Namensteil -- "Hallo Lena", nicht "Hallo Lena Wagner".
    static func vorname(_ displayName: String?) -> String? {
        geputzt(displayName)?.split(separator: " ").first.map(String.init)
    }

    /// Hoechstens zwei Buchstaben. `nil` ohne gesetzten Namen: aus einer
    /// Mailadresse abgeleitet saehen Initialen so lange richtig aus, bis
    /// sie jemanden treffen, dessen Adresse nicht sein Name ist.
    static func initialen(_ displayName: String?) -> String? {
        guard let name = geputzt(displayName) else { return nil }

        let buchstaben = name.split(separator: " ").prefix(2).compactMap(\.first)
        return buchstaben.isEmpty ? nil : String(buchstaben).uppercased()
    }

    private static func geputzt(_ name: String?) -> String? {
        guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty
        else { return nil }
        return name
    }
}
```

- [ ] **Step 5: Zwei Datumsformate ergänzen**

In `Zahlformat.swift`, neben `uhrzeit` und `stand`:

```swift
    /// "Donnerstag, 27. August" -- die Zeile ueber einer Einheit im
    /// Verlauf. Ohne Jahr: der Verlauf reicht 50 Einheiten zurueck, und
    /// eine Jahreszahl an jeder Zeile waere Rauschen.
    static func wochentagDatum(_ zeitpunkt: Date) -> String {
        let formatierer = DateFormatter()
        formatierer.locale = gebietsschema
        formatierer.setLocalizedDateFormatFromTemplate("EEEEddMMMM")
        return formatierer.string(from: zeitpunkt)
    }

    /// "Do, 27. August" -- dieselbe Angabe als Titel des Session-Details,
    /// wo daneben noch der Zeitraum steht.
    static func kurzerWochentagDatum(_ zeitpunkt: Date) -> String {
        let formatierer = DateFormatter()
        formatierer.locale = gebietsschema
        formatierer.setLocalizedDateFormatFromTemplate("EEEddMMMM")
        return formatierer.string(from: zeitpunkt)
    }
```

Dazu in `ZahlformatTests.swift`:

```swift
    @Test("das Verlaufsdatum nennt Wochentag und Monat, aber kein Jahr")
    func wochentagDatum() {
        // 27. August 2026 war ein Donnerstag.
        let zeitpunkt = ISO8601DateFormatter().date(from: "2026-08-27T10:00:00Z")!
        let text = Zahlformat.wochentagDatum(zeitpunkt)

        #expect(text.contains("Donnerstag"))
        #expect(text.contains("August"))
        #expect(!text.contains("2026"))
    }
```

- [ ] **Step 6: Die Hinweiszeile bekommt ihre Quelle**

In `CatalogStore.swift`:

```swift
    /// Was auf Home ueber allem steht, nachdem ein Scan ein Studio
    /// hinzugefuegt oder gewechselt hat (Home.dc.html).
    ///
    /// Nur im Speicher: die Zeile ist die einmalige Folge eines Scans und
    /// soll beim naechsten Start weg sein -- deshalb eine Zeile und keine
    /// Karte mit Schliessen-Kreuz.
    struct Studiohinweis: Equatable {
        let studioName: String
        /// true = neu beigetreten, false = stillschweigend gewechselt.
        let beigetreten: Bool
    }

    /// Kein Wegraeum-Aufruf: der Hinweis lebt nur im Speicher und ist
    /// beim naechsten Start ohnehin weg. Ihn beim Tabwechsel zu loeschen
    /// hiesse, dass ihn verpasst, wer nach dem Scan zuerst ins Training
    /// schaut.
    private(set) var studiohinweis: Studiohinweis?
```

`joinStudio(byCode:)` und `joinStudio(byTag:)` merken sich das Ergebnis:

```swift
    func joinStudio(byCode code: String) async throws(APIError) {
        let ergebnis = try await loader.joinStudioByCode(code)
        await load()
        merkeHinweis(fuer: ergebnis)
    }

    func joinStudio(byTag token: String) async throws(APIError) {
        let ergebnis = try await loader.joinStudioByTag(token)
        await load()
        merkeHinweis(fuer: ergebnis)
    }

    private func merkeHinweis(fuer ergebnis: JoinResult) {
        guard let name = bootstrap?.studios.first(where: { $0.id == ergebnis.studioId })?.name
        else { return }
        studiohinweis = Studiohinweis(studioName: name, beigetreten: ergebnis.joined)
    }
```

und `setActiveStudio(_:)` nur dann, wenn wirklich gewechselt wird — nicht bei der Reparatur eines fehlenden Werts in `load()`:

```swift
    func setActiveStudio(_ id: String) {
        let wechsel = activeStudioId != nil && activeStudioId != id
        activeStudioId = id
        defaults.set(id, forKey: Self.activeStudioDefaultsKey)

        if wechsel, let name = bootstrap?.studios.first(where: { $0.id == id })?.name {
            studiohinweis = Studiohinweis(studioName: name, beigetreten: false)
        }
    }
```

- [ ] **Step 7: Der Screen**

Create `apps/ios-member/FitnessMember/Navigation/HomeRoute.swift`:

```swift
import Foundation

/// Der typisierte Pfad des Home-Tabs -- wie `KursRoute`: beide Ziele sind
/// Pushes und behalten die Tab-Leiste.
enum HomeRoute: Hashable {
    case sessionDetail(id: String)
    case uebungsfortschritt(exerciseId: String)
}
```

Create `apps/ios-member/FitnessMember/Screens/Home/HomeRootView.swift`:

```swift
import SwiftUI

/// Home.dc.html und HomeLeer.dc.html -- ein Screen, zwei Zustaende.
///
/// Der Leerzustand erklaert den naechsten Schritt, statt eine Statistik
/// mit Nullen zu zeigen (designsystem.md SS5).
struct HomeRootView: View {
    @Environment(VerlaufStore.self) private var verlauf
    @Environment(CatalogStore.self) private var katalog

    @State private var pfad: [HomeRoute] = []
    @State private var scannerOffen = false

    private var studioName: String? {
        katalog.bootstrap?.studios.first { $0.id == katalog.activeStudioId }?.name
    }

    var body: some View {
        NavigationStack(path: $pfad) {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
                    kopf
                    if let hinweis = katalog.studiohinweis { hinweisZeile(hinweis) }
                    if let satz = verlauf.satzUeberDemInhalt { standZeile(satz) }

                    if HomeZeilen.abgeschlossene(verlauf.sessions).isEmpty {
                        leer
                    } else {
                        kennzahlen
                        letzteTrainings
                        fortschritt
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, DesignSystem.Spacing.s24)
            }
            .background(DesignSystem.Color.bg)
            .scrollContentBackground(.hidden)
            .refreshable { await verlauf.laden(studioId: katalog.activeStudioId) }
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .sessionDetail(let id):
                    SessionDetailView(sessionId: id)
                case .uebungsfortschritt(let exerciseId):
                    UebungsfortschrittView(exerciseId: exerciseId)
                }
            }
            .sheet(isPresented: $scannerOffen) {
                ScannerSheet(
                    titel: "Erstes Gerät",
                    hinweis: "Halte dein iPhone an den Aufkleber am Gerät.",
                    beiTreffer: { _ in scannerOffen = false }
                )
            }
        }
        .task { await verlauf.laden(studioId: katalog.activeStudioId) }
    }
}
```

Die `ScannerSheet`-Aufrufstelle folgt der Signatur aus Sub-Projekt 3 — vor dem Schreiben in `DesignSystem/Components/ScannerSheet.swift` nachsehen und die dort tatsächlich vorhandenen Parameter verwenden, statt diese zu übernehmen.

Die Unteransichten in derselben Datei, als `private var`:

```swift
private extension HomeRootView {
    @ViewBuilder var kopf: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
            if let vorname = HomeZeilen.vorname(katalog.bootstrap?.member.displayName) {
                Text("Hallo \(vorname)")
                    .font(DesignSystem.Typography.screentitel)
                    .foregroundStyle(DesignSystem.Color.text)
            }
            if let studioName {
                Text(studioName)
                    .font(DesignSystem.Typography.label)
                    .kerning(1.5)
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }
        }
    }

    func hinweisZeile(_ hinweis: CatalogStore.Studiohinweis) -> some View {
        Text(
            hinweis.beigetreten
                ? "Du gehörst jetzt zu \(hinweis.studioName)."
                : "\(hinweis.studioName) ist jetzt aktiv."
        )
        .font(DesignSystem.Typography.fliesstext)
        .foregroundStyle(DesignSystem.Color.textMuted)
    }

    func standZeile(_ satz: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.s8) {
            if let symbol = verlauf.herkunft.symbol { Image(systemName: symbol) }
            Text(satz)
        }
        .font(DesignSystem.Typography.fliesstext)
        .foregroundStyle(DesignSystem.Color.textMuted)
    }

    var kennzahlen: some View {
        HStack(spacing: DesignSystem.Spacing.s24) {
            // "diese Woche" faellt ohne aktives Studio weg -- ohne
            // Zeitzone gibt es keine Woche, auf die sie sich bezoege.
            if let woche = verlauf.summary?.thisWeekCount {
                kennzahl("\(woche)", "diese Woche")
            }
            if let gesamt = verlauf.summary?.totalCount {
                kennzahl("\(gesamt)", "gesamt")
            }
            if let tage = HomeZeilen.tageHer(
                verlauf.summary?.lastSessionAt, jetzt: Date(), kalender: .current) {
                kennzahl("\(tage)", tage == 1 ? "Tag her" : "Tage her")
            }
        }
    }

    func kennzahl(_ wert: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
            Text(wert)
                .font(DesignSystem.Typography.wertSekundaer)
                .foregroundStyle(DesignSystem.Color.text)
            Text(label)
                .font(DesignSystem.Typography.label)
                .foregroundStyle(DesignSystem.Color.textMuted)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(wert) \(label)")
    }

    var letzteTrainings: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            Text("LETZTE TRAININGS")
                .font(DesignSystem.Typography.label)
                .kerning(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)

            ForEach(HomeZeilen.abgeschlossene(verlauf.sessions)) { einheit in
                Button {
                    pfad.append(.sessionDetail(id: einheit.id))
                } label: {
                    trainingsZeile(einheit)
                }
                .buttonStyle(PressButtonStyle())
            }
        }
    }

    func trainingsZeile(_ einheit: SessionSummary) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
            Text(Zeitpunkt.parse(einheit.startedAt).map(Zahlformat.wochentagDatum) ?? "")
                .font(DesignSystem.Typography.uebungsname)
                .foregroundStyle(DesignSystem.Color.text)

            HStack(spacing: DesignSystem.Spacing.s8) {
                if einheit.completedReason == "auto" {
                    Text("AUTO BEENDET")
                        .font(DesignSystem.Typography.label)
                        .foregroundStyle(DesignSystem.Color.warn)
                        .padding(.horizontal, DesignSystem.Spacing.s8)
                        .padding(.vertical, DesignSystem.Spacing.s4)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.pille)
                                .stroke(DesignSystem.Color.warn, lineWidth: 1))
                }
                Text(zeilenText(einheit))
                    .font(DesignSystem.Typography.fliesstext)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.s16)
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
    }

    func zeilenText(_ einheit: SessionSummary) -> String {
        let geraete = "\(einheit.machineCount) \(einheit.machineCount == 1 ? "Gerät" : "Geräte")"
        let saetze = "\(einheit.setCount) \(einheit.setCount == 1 ? "Satz" : "Sätze")"
        return [HomeZeilen.dauerText(einheit), geraete, saetze]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    var fortschritt: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            Text("ÜBUNGSFORTSCHRITT")
                .font(DesignSystem.Typography.label)
                .kerning(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)

            ForEach(verlauf.fortschritt) { uebung in
                Button {
                    pfad.append(.uebungsfortschritt(exerciseId: uebung.id))
                } label: {
                    fortschrittsZeile(uebung)
                }
                .buttonStyle(PressButtonStyle())
            }
        }
    }

    func fortschrittsZeile(_ uebung: ExerciseProgress) -> some View {
        HStack {
            Text("\(uebung.machineLabel) · \(uebung.exerciseName)")
                .font(DesignSystem.Typography.uebungsname)
                .foregroundStyle(DesignSystem.Color.text)
            Spacer()
            Text(Zahlformat.gewichtMitEinheit(uebung.currentWeightKg))
                .font(DesignSystem.Typography.wertSekundaer)
                .foregroundStyle(DesignSystem.Color.text)
            Text(veraenderung(uebung.changeKg))
                .font(DesignSystem.Typography.fliesstext)
                .foregroundStyle(DesignSystem.Color.textMuted)
                .monospacedDigit()
        }
        .padding(DesignSystem.Spacing.s16)
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(uebung.machineLabel), \(uebung.exerciseName), \(Zahlformat.gewichtGesprochen(uebung.currentWeightKg))")
    }

    /// "+15,0" / "±0" -- eine Rechnung, keine Empfehlung (designsystem.md SS10).
    func veraenderung(_ kg: Double) -> String {
        guard kg != 0 else { return "±0" }
        return (kg > 0 ? "+" : "-") + Zahlformat.gewicht(abs(kg))
    }

    var leer: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
            Text("Hier wird dein Verlauf stehen.")
                .font(DesignSystem.Typography.uebungsname)
                .foregroundStyle(DesignSystem.Color.text)
            Text("Noch ist nichts da — das ändert sich mit deinem ersten Satz.")
                .font(DesignSystem.Typography.fliesstext)
                .foregroundStyle(DesignSystem.Color.textMuted)

            schritt(1, "iPhone an den Aufkleber halten", "Auf jedem Gerät klebt einer. QR-Code geht genauso.")
            schritt(2, "Einweisung ansehen, Gerät einstellen", "Einmal. Danach stehen deine Werte jedes Mal da.")
            schritt(3, "Sätze sichern", "Meistens reicht ein Antippen. Das Training startet dabei von selbst.")

            PrimaryButton(title: "Erstes Gerät") { scannerOffen = true }

            Text("gymodo misst nichts. Es zeigt, was du bestätigst.")
                .font(DesignSystem.Typography.fliesstext)
                .foregroundStyle(DesignSystem.Color.textFaint)
        }
    }

    func schritt(_ nummer: Int, _ titel: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.s12) {
            Text("\(nummer)")
                .font(DesignSystem.Typography.label)
                .foregroundStyle(DesignSystem.Color.textMuted)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                Text(titel)
                    .font(DesignSystem.Typography.uebungsname)
                    .foregroundStyle(DesignSystem.Color.text)
                Text(text)
                    .font(DesignSystem.Typography.fliesstext)
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }
        }
    }
}
```

`PrimaryButton` und `PressButtonStyle` haben feste Signaturen — vor dem Schreiben in `DesignSystem/Components/` nachsehen und sie genau so aufrufen.

- [ ] **Step 8: Den Tab einhängen**

In `MainTabView.swift` ersetzt `HomeRootView()` den Platzhalter:

```swift
            HomeRootView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(0)
```

- [ ] **Step 9: Testlauf und Kaltbau**

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -derivedDataPath /tmp/dd-sp4-t6 test 2>&1 | grep -E "warning:|error:|TEST SUCCEEDED|TEST FAILED"
rm -rf /tmp/dd-sp4-t6
```

Erwartet: `TEST SUCCEEDED`, nur die vier vorbestehenden Warnungen. `SessionDetailView` und `UebungsfortschrittView` existieren noch nicht — für diesen Schritt zwei minimale Rümpfe anlegen, die in Aufgabe 7 und 8 ihre Gestalt bekommen; **keine** Platzhaltertexte, die ein Mitglied sehen könnte, sondern nur `Text(sessionId)` bzw. `Text(exerciseId)`.

- [ ] **Step 10: Commit**

```bash
git add apps/ios-member
git commit -m "feat(ios): Home zeigt Verlauf, Kennzahlen und Fortschritt

Beide Zustaende eines Screens: der leere erklaert den naechsten Schritt
und fuehrt zum Scanner, statt eine Statistik mit Nullen zu zeigen.

Die laufende Einheit steht nicht in der Liste -- was heute noch laeuft,
ist kein Verlauf, sondern der Training-Tab. Eine selbsttaetig beendete
Einheit zeigt keine Dauer: ihr Ende liegt beim letzten Satz, die
gerechnete Dauer waere eine Untergrenze.

Ohne gesetzten Namen gruesst Home nicht. Aus der Mailadresse einen
abzuleiten saehe so lange richtig aus, bis es jemanden trifft."
```

---
### Aufgabe 7: `SessionDetailView`

Die Blöcke und Sätze einer Einheit. **Kein neuer Endpoint** — `getSessions` liefert die Blöcke bereits mit, und der Store hat sie schon im Speicher.

**Files:**
- Modify: `apps/ios-member/FitnessMember/Screens/Home/SessionDetailView.swift` (Rumpf aus Aufgabe 6)

**Interfaces:**
- Consumes: `VerlaufStore.sessions`, `Zahlformat.kurzerWochentagDatum`, `Zahlformat.uhrzeit`, `HomeZeilen.dauerText`

- [ ] **Step 1: Den Screen schreiben**

```swift
import SwiftUI

/// SessionDetail.dc.html -- die Bloecke und Saetze einer Einheit.
///
/// Ohne eigenen Abruf: getSessions liefert die Bloecke mit, abgeleitet
/// aus den Saetzen und gruppiert nach (Geraet, Uebung). Ein zweiter
/// Durchgang am selben Geraet trifft denselben Block.
///
/// Ohne Vorschlaege: die gehoeren zum Abschluss. Fuer eine selbsttaetig
/// beendete Einheit existiert gar keine Vorschlagszeile (abschluss.ts),
/// ein Abschnitt dafuer bliebe hier bei jeder vergessenen Einheit leer.
struct SessionDetailView: View {
    let sessionId: String

    @Environment(VerlaufStore.self) private var verlauf

    private var einheit: SessionSummary? {
        verlauf.sessions.first { $0.id == sessionId }
    }

    var body: some View {
        ScrollView {
            if let einheit {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
                    kopf(einheit)
                    ForEach(Array(einheit.blocks.enumerated()), id: \.offset) { _, block in
                        blockKarte(block)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, DesignSystem.Spacing.s24)
            } else {
                // Der Verlauf wurde zwischenzeitlich geleert (Abmelden,
                // Kontowechsel). Kein Fehler, kein leerer Screen ohne Wort.
                Text("Diese Einheit steht nicht mehr im Verlauf.")
                    .font(DesignSystem.Typography.fliesstext)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .padding(.horizontal, 20)
                    .padding(.top, DesignSystem.Spacing.s48)
            }
        }
        .background(DesignSystem.Color.bg)
        .scrollContentBackground(.hidden)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func kopf(_ einheit: SessionSummary) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
            Text(Zeitpunkt.parse(einheit.startedAt).map(Zahlformat.kurzerWochentagDatum) ?? "")
                .font(DesignSystem.Typography.detailScreentitel)
                .foregroundStyle(DesignSystem.Color.text)

            Text(untertitel(einheit))
                .font(DesignSystem.Typography.fliesstext)
                .foregroundStyle(DesignSystem.Color.textMuted)
                .monospacedDigit()
        }
    }

    /// "18:04 – 18:51 · 47 min · 3 Geräte · 8 Sätze". Bei einer
    /// selbsttaetig beendeten Einheit entfallen Zeitraum und Dauer: ihr
    /// Ende liegt beim letzten Satz, nicht beim Ende des Trainings.
    private func untertitel(_ einheit: SessionSummary) -> String {
        var teile: [String] = []

        if einheit.completedReason != "auto",
           let start = Zeitpunkt.parse(einheit.startedAt),
           let endeIso = einheit.completedAt,
           let ende = Zeitpunkt.parse(endeIso) {
            teile.append("\(Zahlformat.uhrzeit(start)) – \(Zahlformat.uhrzeit(ende))")
        }
        if let dauer = HomeZeilen.dauerText(einheit) { teile.append(dauer) }
        teile.append("\(einheit.machineCount) \(einheit.machineCount == 1 ? "Gerät" : "Geräte")")
        teile.append("\(einheit.setCount) \(einheit.setCount == 1 ? "Satz" : "Sätze")")

        return teile.joined(separator: " · ")
    }

    private func blockKarte(_ block: SessionSummary.Block) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            HStack {
                Text("\(block.machineLabel) · \(block.exerciseName)")
                    .font(DesignSystem.Typography.uebungsname)
                    .foregroundStyle(DesignSystem.Color.text)
                Spacer()
                Text("\(block.sets.count) \(block.sets.count == 1 ? "SATZ" : "SÄTZE")")
                    .font(DesignSystem.Typography.label)
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }

            ForEach(block.sets, id: \.setIndex) { satz in
                satzZeile(satz)
            }
        }
        .padding(DesignSystem.Spacing.s16)
        .background(DesignSystem.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.card))
    }

    private func satzZeile(_ satz: SessionSummary.Block.Set) -> some View {
        HStack(spacing: DesignSystem.Spacing.s12) {
            Text("\(satz.setIndex)")
                .font(DesignSystem.Typography.label)
                .foregroundStyle(DesignSystem.Color.textFaint)
                .frame(width: 16, alignment: .leading)

            Text(Zahlformat.gewichtMitEinheit(satz.weightKg))
                .font(DesignSystem.Typography.fliesstext)
                .foregroundStyle(DesignSystem.Color.text)
                .monospacedDigit()

            Text("× \(satz.reps)")
                .font(DesignSystem.Typography.fliesstext)
                .foregroundStyle(DesignSystem.Color.textMuted)
                .monospacedDigit()

            // Nur wo eine Reserve erfasst wurde -- der Schalter im Profil
            // entscheidet ueber die ERFASSUNG, nicht rueckwirkend ueber
            // die Anzeige dessen, was schon gespeichert ist.
            if let rir = satz.rir {
                Text("RIR \(Int(rir))")
                    .font(DesignSystem.Typography.fliesstext)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .monospacedDigit()
            }

            if satz.problemFlag {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(DesignSystem.Color.warn)
                    .accessibilityLabel("Problem gemeldet")
            }

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Satz \(satz.setIndex), \(Zahlformat.gewichtGesprochen(satz.weightKg)), \(Zahlformat.wiederholungenGesprochen(satz.reps))")
    }
}
```

- [ ] **Step 2: Kaltbau**

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -derivedDataPath /tmp/dd-sp4-t7 test 2>&1 | grep -E "warning:|error:|TEST SUCCEEDED|TEST FAILED"
rm -rf /tmp/dd-sp4-t7
```

Erwartet: `TEST SUCCEEDED`, nur die vier vorbestehenden Warnungen.

- [ ] **Step 3: Commit**

```bash
git add apps/ios-member
git commit -m "feat(ios): das Session-Detail zeigt Bloecke und Saetze

Ohne eigenen Endpoint: getSessions liefert die Bloecke mit. Ohne
Vorschlaege: die gehoeren zum Abschluss, und fuer eine selbsttaetig
beendete Einheit existiert gar keine Vorschlagszeile -- ein Abschnitt
dafuer bliebe hier bei jeder vergessenen Einheit leer.

Bei einer selbsttaetig beendeten Einheit entfallen Zeitraum und Dauer:
ihr Ende liegt beim letzten Satz, nicht beim Ende des Trainings."
```

---

### Aufgabe 8: `UebungsfortschrittView` mit Swift Charts

Das einzige Diagramm in M1 (§13). Der Zeitraum-Umschalter filtert **lokal** aus einem Abruf ohne `since` — drei Umschaltungen wären sonst drei Netzabrufe, und ohne Netz wären zwei der drei Knöpfe tot.

**Files:**
- Create: `apps/ios-member/FitnessMember/Verlauf/Fortschrittsfenster.swift`
- Create: `apps/ios-member/FitnessMemberTests/FortschrittsfensterTests.swift`
- Modify: `apps/ios-member/FitnessMember/Screens/Home/UebungsfortschrittView.swift` (Rumpf aus Aufgabe 6)

**Interfaces:**
- Produces: `enum Fortschrittsfenster: CaseIterable` mit `titel`, `func punkte(_:jetzt:) -> [ExerciseProgress.Point]`, `static func achsenbereich(_:) -> ClosedRange<Double>`

- [ ] **Step 1: Den Test schreiben**

Create `apps/ios-member/FitnessMemberTests/FortschrittsfensterTests.swift`:

```swift
import Foundation
import Testing
@testable import FitnessMember

struct FortschrittsfensterTests {
    private let jetzt = ISO8601DateFormatter().date(from: "2026-09-09T12:00:00Z")!

    private func punkt(_ tag: String, _ kg: Double) -> ExerciseProgress.Point {
        ExerciseProgress.Point(performedOn: tag, topWeightKg: kg, reps: 10)
    }

    private var alle: [ExerciseProgress.Point] {
        [punkt("2026-01-15", 60), punkt("2026-05-02", 70), punkt("2026-08-27", 80)]
    }

    @Test func dreiMonateSchneidetAelteresAb() {
        let gefiltert = Fortschrittsfenster.dreiMonate.punkte(alle, jetzt: jetzt)

        #expect(gefiltert.map(\.performedOn) == ["2026-08-27"])
    }

    @Test func sechsMonateNimmtMehrMit() {
        let gefiltert = Fortschrittsfenster.sechsMonate.punkte(alle, jetzt: jetzt)

        #expect(gefiltert.count == 2)
    }

    @Test func allesLaesstNichtsWeg() {
        #expect(Fortschrittsfenster.alles.punkte(alle, jetzt: jetzt).count == 3)
    }

    /// designsystem.md SS13: die Achse beginnt NICHT bei null --
    /// Trainingsgewichte bewegen sich in einem schmalen Band, und eine
    /// Nullachse macht jeden Fortschritt unsichtbar.
    @Test func dieAchseBeginntNichtBeiNull() {
        let bereich = Fortschrittsfenster.achsenbereich(alle)

        #expect(bereich.lowerBound > 0)
        #expect(bereich.lowerBound < 60)
        #expect(bereich.upperBound > 80)
    }

    /// Ein einziger Punkt darf keinen Bereich der Breite null ergeben --
    /// die Kurve verschwaende sonst in einer Linie ohne Achse.
    @Test func einEinzelnerPunktBekommtTrotzdemEinenBereich() {
        let bereich = Fortschrittsfenster.achsenbereich([punkt("2026-08-27", 80)])

        #expect(bereich.lowerBound < 80)
        #expect(bereich.upperBound > 80)
    }

    @Test func ohnePunkteGibtEsEinenUnauffaelligenBereich() {
        let bereich = Fortschrittsfenster.achsenbereich([])

        #expect(bereich.lowerBound < bereich.upperBound)
    }
}
```

- [ ] **Step 2: Testlauf, der fehlschlagen muss**

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -derivedDataPath /tmp/dd-sp4-t8 test -only-testing:FitnessMemberTests/FortschrittsfensterTests 2>&1 | tail -20
```

Erwartet: Übersetzungsfehler — `Fortschrittsfenster` existiert nicht.

- [ ] **Step 3: Die Ableitung schreiben**

Create `apps/ios-member/FitnessMember/Verlauf/Fortschrittsfenster.swift`:

```swift
import Foundation

/// Der Zeitraum-Umschalter des Diagramms -- und der Achsenbereich.
///
/// Gefiltert wird LOKAL aus einem Abruf ohne `since`: drei Umschaltungen
/// waeren sonst drei Netzabrufe, und ohne Netz waeren zwei der drei
/// Knoepfe tot.
enum Fortschrittsfenster: CaseIterable, Identifiable {
    case dreiMonate
    case sechsMonate
    case alles

    var id: Self { self }

    var titel: String {
        switch self {
        case .dreiMonate: "3 Monate"
        case .sechsMonate: "6 Monate"
        case .alles: "Alles"
        }
    }

    private var tage: Int? {
        switch self {
        case .dreiMonate: 92
        case .sechsMonate: 183
        case .alles: nil
        }
    }

    func punkte(_ alle: [ExerciseProgress.Point], jetzt: Date) -> [ExerciseProgress.Point] {
        guard let tage else { return alle }
        let grenze = jetzt.addingTimeInterval(-Double(tage) * 24 * 60 * 60)

        return alle.filter { punkt in
            guard let tag = Zeitpunkt.parse("\(punkt.performedOn)T12:00:00Z") else { return false }
            return tag >= grenze
        }
    }

    /// Die Achse beginnt nicht bei null (designsystem.md SS13):
    /// Trainingsgewichte bewegen sich in einem schmalen Band, und eine
    /// Nullachse machte jeden Fortschritt unsichtbar. Stattdessen ein
    /// Rand von einem Zehntel der Spanne -- mindestens 2,5 kg, damit auch
    /// ein einzelner Punkt eine Achse bekommt.
    static func achsenbereich(_ punkte: [ExerciseProgress.Point]) -> ClosedRange<Double> {
        let gewichte = punkte.map(\.topWeightKg)
        guard let kleinstes = gewichte.min(), let groesstes = gewichte.max() else {
            return 0 ... 10
        }

        let rand = max((groesstes - kleinstes) / 10, 2.5)
        return (kleinstes - rand) ... (groesstes + rand)
    }
}
```

- [ ] **Step 4: Testlauf, der bestehen muss**

```bash
cd apps/ios-member && xcodebuild -scheme FitnessMember \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -derivedDataPath /tmp/dd-sp4-t8 test -only-testing:FitnessMemberTests/FortschrittsfensterTests 2>&1 | tail -20
```

Erwartet: 7 Tests grün.

- [ ] **Step 5: Den Screen schreiben**

`apps/ios-member/FitnessMember/Screens/Home/UebungsfortschrittView.swift`:

```swift
import Charts
import SwiftUI

/// Uebungsfortschritt.dc.html -- das einzige Diagramm in M1
/// (designsystem.md SS13). Swift Charts, keine externe Abhaengigkeit.
struct UebungsfortschrittView: View {
    let exerciseId: String

    @Environment(VerlaufStore.self) private var verlauf
    @State private var fenster: Fortschrittsfenster = .dreiMonate

    private var uebung: ExerciseProgress? {
        verlauf.fortschritt.first { $0.id == exerciseId }
    }

    var body: some View {
        ScrollView {
            if let uebung {
                let punkte = fenster.punkte(uebung.points, jetzt: Date())

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.s24) {
                    kopf(uebung)
                    umschalter
                    diagramm(punkte)
                    rohwerte(punkte)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, DesignSystem.Spacing.s24)
            } else {
                Text("Diese Übung steht nicht mehr im Verlauf.")
                    .font(DesignSystem.Typography.fliesstext)
                    .foregroundStyle(DesignSystem.Color.textMuted)
                    .padding(.horizontal, 20)
                    .padding(.top, DesignSystem.Spacing.s48)
            }
        }
        .background(DesignSystem.Color.bg)
        .scrollContentBackground(.hidden)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func kopf(_ uebung: ExerciseProgress) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
            Text(uebung.machineLabel)
                .font(DesignSystem.Typography.detailScreentitel)
                .foregroundStyle(DesignSystem.Color.text)
            Text(uebung.exerciseName)
                .font(DesignSystem.Typography.uebungsname)
                .foregroundStyle(DesignSystem.Color.textMuted)

            HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.s8) {
                Text(Zahlformat.gewichtMitEinheit(uebung.currentWeightKg))
                    .font(DesignSystem.Typography.wertHeld)
                    .foregroundStyle(DesignSystem.Color.text)
                Text(veraenderung(uebung.changeKg))
                    .font(DesignSystem.Typography.wertSekundaer)
                    .foregroundStyle(DesignSystem.Color.textMuted)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "\(Zahlformat.gewichtGesprochen(uebung.currentWeightKg)), Veränderung \(veraenderung(uebung.changeKg)) Kilogramm")
        }
    }

    /// Der Akzent markiert hier den aktiven Wert -- der Screen hat keine
    /// Hauptaktion, und es bleibt bei genau EINER Akzentflaeche (SS2).
    private var umschalter: some View {
        HStack(spacing: DesignSystem.Spacing.s8) {
            ForEach(Fortschrittsfenster.allCases) { wahl in
                Button(wahl.titel) { fenster = wahl }
                    .font(DesignSystem.Typography.label)
                    .padding(.horizontal, DesignSystem.Spacing.s16)
                    .frame(height: 44)
                    .background(wahl == fenster ? DesignSystem.Color.accent : DesignSystem.Color.surface)
                    .foregroundStyle(wahl == fenster ? DesignSystem.Color.onAccent : DesignSystem.Color.textMuted)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.pille))
            }
        }
    }

    private func diagramm(_ punkte: [ExerciseProgress.Point]) -> some View {
        Chart(punkte, id: \.performedOn) { punkt in
            LineMark(
                x: .value("Datum", Zeitpunkt.parse("\(punkt.performedOn)T12:00:00Z") ?? Date()),
                y: .value("Gewicht", punkt.topWeightKg)
            )
            .lineStyle(StrokeStyle(lineWidth: 2))
            .foregroundStyle(DesignSystem.Color.accent)

            PointMark(
                x: .value("Datum", Zeitpunkt.parse("\(punkt.performedOn)T12:00:00Z") ?? Date()),
                y: .value("Gewicht", punkt.topWeightKg)
            )
            .symbolSize(64)
            .foregroundStyle(DesignSystem.Color.accent)
            // Direkte Beschriftung NUR an Anfang und Ende (SS13) -- an
            // jedem Punkt waere sie Rauschen, und Text traegt Textfarben,
            // nie die Serienfarbe.
            .annotation(position: .top) {
                if punkt.performedOn == punkte.first?.performedOn
                    || punkt.performedOn == punkte.last?.performedOn {
                    Text(Zahlformat.gewicht(punkt.topWeightKg))
                        .font(DesignSystem.Typography.fliesstext)
                        .foregroundStyle(DesignSystem.Color.textMuted)
                        .monospacedDigit()
                }
            }
        }
        .chartYScale(domain: Fortschrittsfenster.achsenbereich(punkte))
        .chartXAxis { AxisMarks { AxisGridLine().foregroundStyle(DesignSystem.Color.line) } }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine().foregroundStyle(DesignSystem.Color.line)
                AxisValueLabel()
                    .foregroundStyle(DesignSystem.Color.textFaint)
            }
        }
        .frame(height: 200)
        .accessibilityLabel("Gewichtsverlauf")
    }

    /// Die Plattform misst nichts -- die Kurve ist eine Zusammenfassung
    /// und muss nachpruefbar bleiben (SS13). Diese Liste ist zugleich die
    /// Wertetabelle, die VoiceOver als Alternative zur Kurve braucht
    /// (SS12).
    private func rohwerte(_ punkte: [ExerciseProgress.Point]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.s12) {
            Text("SCHWERSTER BESTÄTIGTER SATZ JE TRAININGSTAG")
                .font(DesignSystem.Typography.label)
                .kerning(1.5)
                .foregroundStyle(DesignSystem.Color.textMuted)

            ForEach(punkte.reversed(), id: \.performedOn) { punkt in
                HStack {
                    Text(punkt.performedOn)
                        .foregroundStyle(DesignSystem.Color.textMuted)
                    Spacer()
                    Text(Zahlformat.gewichtMitEinheit(punkt.topWeightKg))
                        .foregroundStyle(DesignSystem.Color.text)
                    Text("× \(punkt.reps)")
                        .foregroundStyle(DesignSystem.Color.textMuted)
                }
                .font(DesignSystem.Typography.fliesstext)
                .monospacedDigit()
            }
        }
    }

    private func veraenderung(_ kg: Double) -> String {
        guard kg != 0 else { return "±0" }
        return (kg > 0 ? "+" : "-") + Zahlformat.gewicht(abs(kg))
    }
}
```

Das Datum in der Rohwerteliste bleibt vorerst in ISO-Form (`2026-08-27`); ein eigenes Format dafür wäre ein drittes Datumsformat für dieselbe Angabe — **stattdessen** `Zahlformat.wochentagDatum` aus Aufgabe 6 verwenden, sobald der Punkt in ein `Date` geparst ist.

- [ ] **Step 6: Kaltbau**

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -derivedDataPath /tmp/dd-sp4-t8 test 2>&1 | grep -E "warning:|error:|TEST SUCCEEDED|TEST FAILED"
rm -rf /tmp/dd-sp4-t8
```

Erwartet: `TEST SUCCEEDED`, nur die vier vorbestehenden Warnungen.

- [ ] **Step 7: Commit**

```bash
git add apps/ios-member
git commit -m "feat(ios): der Uebungsfortschritt bekommt seine Kurve

Swift Charts, eine Serie, keine Legende -- und eine Achse, die nicht bei
null beginnt: Trainingsgewichte bewegen sich in einem schmalen Band, eine
Nullachse machte jeden Fortschritt unsichtbar.

Unter der Kurve stehen die Rohwerte. Die Plattform misst nichts; eine
Zusammenfassung muss nachpruefbar bleiben -- und dieselbe Liste ist die
Wertetabelle, die VoiceOver als Alternative zur Kurve braucht.

Der Zeitraum-Umschalter filtert lokal: drei Umschaltungen waeren sonst
drei Netzabrufe, und ohne Netz waeren zwei der drei Knoepfe tot."
```

---
### Aufgabe 9: `Einstellungen`, Resttimer-Vorgabe, Haptik beim Sichern

Drei Schalter, drei Zustände: `rirSichtbar` liegt seit Sub-Projekt 2 bereit, die Resttimer-Vorgabe ist heute eine Konstante, und die Vibration beim Sichern **gibt es nicht** — sie wird hier gebaut, nicht nur geschaltet.

**Files:**
- Create: `apps/ios-member/FitnessMember/Einstellungen.swift`
- Create: `apps/ios-member/FitnessMemberTests/EinstellungenTests.swift`
- Modify: `apps/ios-member/FitnessMember/Workout/Resttimer.swift`
- Modify: `apps/ios-member/FitnessMember/Screens/Geraet/GeraetModel.swift`
- Modify: `apps/ios-member/FitnessMember/Screens/Geraet/GeraetView.swift`

**Interfaces:**
- Produces: `enum Einstellungen` mit `rirSichtbarKey`, `resttimerSekundenKey`, `vibrationBeimSichernKey`, `resttimerVorgabe`, `resttimerStufen`, `static func resttimerSekunden(_:) -> Int`, `static func vibriertBeimSichern(_:) -> Bool`; `Resttimer.init(start:dauer:)`

- [ ] **Step 1: Den Test schreiben**

Create `apps/ios-member/FitnessMemberTests/EinstellungenTests.swift`:

```swift
import Foundation
import Testing
@testable import FitnessMember

struct EinstellungenTests {
    /// Der Schluessel stammt aus Sub-Projekt 2 und steht heute in
    /// GeraetView. Aendert er sich, verlieren Bestandsinstallationen ihre
    /// Einstellung -- deshalb woertlich festgehalten.
    @Test func derRIRSchluesselBleibtWoertlich() {
        #expect(Einstellungen.rirSichtbarKey == "rirSichtbar")
    }

    @Test func ohneGesetztenWertGiltDieVorgabe() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!

        #expect(Einstellungen.resttimerSekunden(defaults) == 90)
        #expect(Einstellungen.vibriertBeimSichern(defaults) == true)
    }

    @Test func eingesetzterWertSchlaegtDieVorgabe() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set(120, forKey: Einstellungen.resttimerSekundenKey)
        defaults.set(false, forKey: Einstellungen.vibrationBeimSichernKey)

        #expect(Einstellungen.resttimerSekunden(defaults) == 120)
        #expect(Einstellungen.vibriertBeimSichern(defaults) == false)
    }

    @Test func dieVorgabeStehtUnterDenStufen() {
        #expect(Einstellungen.resttimerStufen.contains(Einstellungen.resttimerVorgabe))
    }
}
```

- [ ] **Step 2: Testlauf, der fehlschlagen muss**

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -derivedDataPath /tmp/dd-sp4-t9 test -only-testing:FitnessMemberTests/EinstellungenTests 2>&1 | tail -20
```

Erwartet: Übersetzungsfehler — `Einstellungen` existiert nicht.

- [ ] **Step 3: Die Einstellungen schreiben**

Create `apps/ios-member/FitnessMember/Einstellungen.swift`:

```swift
import Foundation

/// Die drei Schalter aus Profil.dc.html an einer Stelle.
///
/// Vorher stand `@AppStorage("rirSichtbar")` mitten in GeraetView. Bei
/// drei Einstellungen, die an je zwei Stellen gelesen werden (Screen und
/// Profil), ist eine verstreute Zeichenkette ein Tippfehler mit stiller
/// Wirkung: der Screen liest dann eine Einstellung, die niemand gesetzt
/// hat.
///
/// Die Lesefunktionen nehmen `UserDefaults` entgegen, damit sie pruefbar
/// bleiben; die Views lesen dieselben Schluessel ueber @AppStorage.
enum Einstellungen {
    /// Woertlich aus Sub-Projekt 2 -- ein anderer Name hiesse, dass jede
    /// Bestandsinstallation ihre Einstellung verliert.
    static let rirSichtbarKey = "rirSichtbar"
    static let resttimerSekundenKey = "resttimerSekunden"
    static let vibrationBeimSichernKey = "vibrationBeimSichern"

    static let resttimerVorgabe = 90
    static let resttimerStufen = [45, 60, 90, 120, 180]

    /// `integer(forKey:)` liefert 0 fuer einen nie gesetzten Schluessel --
    /// 0 Sekunden Pause waere keine Einstellung, sondern ein Fehler.
    static func resttimerSekunden(_ defaults: UserDefaults = .standard) -> Int {
        let gesetzt = defaults.integer(forKey: resttimerSekundenKey)
        return gesetzt > 0 ? gesetzt : resttimerVorgabe
    }

    /// Vorgabe an: die Hauptaktion wird oft mit Blick aufs Geraet statt
    /// aufs Telefon bedient. `bool(forKey:)` liefert false fuer einen nie
    /// gesetzten Schluessel, deshalb die Umkehrung ueber object(forKey:).
    static func vibriertBeimSichern(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: vibrationBeimSichernKey) as? Bool ?? true
    }
}
```

- [ ] **Step 4: Der Resttimer nimmt eine Dauer entgegen**

In `Resttimer.swift` wird aus der festen Größe eine Vorgabe — der Kommentar wird richtiggestellt, weil die Aussage „in M1 keine Einstellung" ab jetzt nicht mehr stimmt:

```swift
    /// Die Vorgabe. Seit Sub-Projekt 4 im Profil einstellbar
    /// (Einstellungen.resttimerSekunden) -- der Wert hier gilt, solange
    /// niemand etwas anderes gewaehlt hat.
    static let dauer: TimeInterval = 90
    static let verlaengerung: TimeInterval = 30

    let start: Date
    let endetAm: Date

    init(start: Date = Date(), dauer: TimeInterval = Resttimer.dauer) {
        self.start = start
        endetAm = start.addingTimeInterval(dauer)
    }
```

Die bestehenden `ResttimerTests` bleiben unverändert gültig — der neue Parameter hat eine Vorgabe.

In `GeraetModel.swift` (Zeile 344, `pause = Resttimer()`):

```swift
        pause = Resttimer(dauer: TimeInterval(Einstellungen.resttimerSekunden()))
```

- [ ] **Step 5: Die Haptik beim Sichern**

In `GeraetView.swift` liest die View die Einstellungen über `@AppStorage` statt über einen eigenen Schlüssel:

```swift
    @AppStorage(Einstellungen.rirSichtbarKey) private var rirSichtbar = true
    @AppStorage(Einstellungen.vibrationBeimSichernKey) private var vibrationBeimSichern = true
```

Und an der Hauptaktion (`PrimaryButton(title: hauptaktion)`, Zeile 166) — die Rückmeldung hängt an der Satznummer, die beim Sichern steigt:

```swift
        .sensoryFeedback(trigger: modell.satzNummer) { alt, neu in
            // Haptik nie als einzige Rueckmeldung (designsystem.md SS6):
            // die sichtbare Bestaetigung bleibt daneben bestehen. Nur
            // beim Steigen, nicht beim Zuruecksetzen auf einen neuen
            // Block.
            vibrationBeimSichern && neu > alt ? .impact(weight: .medium) : nil
        }
```

Der Modifier gehört an die View, die den Knopf enthält — nicht an den Knopf selbst, sonst verschwindet er mit ihm, sobald die Hauptaktion in einem anderen Zustand nicht gerendert wird.

- [ ] **Step 6: Testlauf und Kaltbau**

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -derivedDataPath /tmp/dd-sp4-t9 test 2>&1 | grep -E "warning:|error:|TEST SUCCEEDED|TEST FAILED"
rm -rf /tmp/dd-sp4-t9
```

Erwartet: `TEST SUCCEEDED`, nur die vier vorbestehenden Warnungen.

- [ ] **Step 7: Commit**

```bash
git add apps/ios-member
git commit -m "feat(ios): drei Einstellungen an einer Stelle, Haptik beim Sichern

rirSichtbar stand als Zeichenkette mitten in GeraetView; bei drei
Einstellungen, die an je zwei Stellen gelesen werden, ist das ein
Tippfehler mit stiller Wirkung. Der Schluesselname bleibt woertlich --
sonst verlieren Bestandsinstallationen ihre Einstellung.

Die Vibration beim Sichern gab es bisher gar nicht: Haptik lag nur im
Rastrad und im Scanner. Sie wird gebaut, nicht nur geschaltet -- ein
Schalter fuer etwas, das es nicht gibt, waere dieselbe Unwahrheit wie
der in Sub-Projekt 3 gestrichene Link. Die sichtbare Bestaetigung bleibt
daneben bestehen."
```

---

### Aufgabe 10: `ProfilRootView` — Vollausbau

**Files:**
- Modify: `apps/ios-member/FitnessMember/Screens/Profil/ProfilRootView.swift`
- Create: `apps/ios-member/FitnessMember/Screens/Profil/NameSheet.swift`
- Modify: `apps/ios-member/FitnessMember/AppConfig.swift`
- Modify: `apps/ios-member/FitnessMemberTests/AppConfigTests.swift`
- Modify: `apps/ios-member/Config.xcconfig.example`
- Modify: `apps/ios-member/FitnessMember/Info-Additions.plist`

**Interfaces:**
- Consumes: `Einstellungen` (Aufgabe 9), `APIClient.setDisplayName` (Aufgabe 3), `HomeZeilen.initialen` (Aufgabe 6)
- Produces: `AppConfig.datenschutzURL: URL?`

- [ ] **Step 1: Die Datenschutz-URL als optionaler Wert**

`AppConfig` bricht heute bei einem fehlenden Schlüssel mit `fatalError` ab — richtig für die drei Pflichtwerte, falsch für diesen: **solange keine URL hinterlegt ist, erscheint die Zeile im Profil gar nicht.**

In `AppConfig.swift`:

```swift
    /// Optional, anders als die drei Pflichtwerte: solange hier nichts
    /// steht, zeigt das Profil die Datenschutzzeile nicht an. Ein
    /// Bedienelement ohne Ziel ist schlechter als keines -- dieselbe
    /// Regel wie beim in Sub-Projekt 3 gestrichenen Link.
    static let datenschutzURL: URL? = {
        guard let wert = Bundle.main.object(forInfoDictionaryKey: "DATENSCHUTZ_URL") as? String,
              !wert.isEmpty
        else { return nil }
        return URL(string: wert)
    }()
```

In `Info-Additions.plist`:

```xml
	<key>DATENSCHUTZ_URL</key>
	<string>$(DATENSCHUTZ_URL)</string>
```

In `Config.xcconfig.example`, mit demselben `$()`-Kniff wie bei den anderen URLs:

```
// Leer lassen, solange es keine Datenschutzerklaerung gibt -- dann zeigt
// das Profil die Zeile nicht an.
DATENSCHUTZ_URL =
```

Und ein Test in `AppConfigTests.swift`:

```swift
    @Test("eine leere Datenschutz-URL ergibt keine Zeile")
    func datenschutzURLIstOptional() {
        // Kein fatalError, egal ob der Schluessel gesetzt ist: der Wert
        // ist optional, und genau darauf verlaesst sich ProfilRootView.
        _ = AppConfig.datenschutzURL
    }
```

- [ ] **Step 2: Das Namens-Sheet**

Create `apps/ios-member/FitnessMember/Screens/Profil/NameSheet.swift`:

```swift
import SwiftUI

/// Ein Feld, ein Knopf. Der Weg zum Namen fuer alle, die sich vor
/// Sub-Projekt 4 registriert haben -- und fuer alle, die ihren aendern
/// wollen.
struct NameSheet: View {
    let bisher: String?
    let speichern: (String) async -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var fehler: String?
    @State private var laeuft = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.s16) {
                LabeledField(label: "NAME", text: $name)
                    .textContentType(.givenName)

                if let fehler {
                    InlineBanner(text: fehler, art: .fehler)
                }

                PrimaryButton(title: "Speichern") {
                    // Die Aktion eines PrimaryButton ist synchron -- der
                    // Schreibvorgang laeuft in einer Task, wie an den
                    // anderen Aufrufstellen des Projekts.
                    Task {
                        laeuft = true
                        fehler = await speichern(name)
                        laeuft = false
                        if fehler == nil { dismiss() }
                    }
                }
                .disabled(laeuft || name.trimmingCharacters(in: .whitespaces).isEmpty)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, DesignSystem.Spacing.s24)
            .background(DesignSystem.Color.bg)
            .navigationTitle("NAME")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { name = bisher ?? "" }
    }
}
```

`LabeledField`, `InlineBanner` und `PrimaryButton` haben feste Signaturen — vor dem Schreiben in `DesignSystem/Components/` nachsehen und sie genau so aufrufen (insbesondere, ob `InlineBanner` eine `art` kennt).

- [ ] **Step 3: Das Profil**

`ProfilRootView.swift` wird nach `Profil.dc.html` neu gebaut. Der Kommentarkopf („bewusst minimal … kommt mit der Home/Profil-Spec eines Folge-Sub-Projekts") entfällt — er ist jetzt eingelöst:

```swift
import SwiftUI

/// Profil.dc.html. Der letzte Screen aus der M1-Screenliste.
struct ProfilRootView: View {
    @Environment(SessionStore.self) private var sessionStore
    @Environment(CatalogStore.self) private var katalog
    @Environment(VerlaufStore.self) private var verlauf

    let apiClient: APIClient

    @AppStorage(Einstellungen.rirSichtbarKey) private var rirSichtbar = true
    @AppStorage(Einstellungen.vibrationBeimSichernKey) private var vibrationBeimSichern = true
    @AppStorage(Einstellungen.resttimerSekundenKey) private var resttimerSekunden =
        Einstellungen.resttimerVorgabe

    @State private var nameOffen = false

    private var name: String? { katalog.bootstrap?.member.displayName }
    private var studioName: String? {
        katalog.bootstrap?.studios.first { $0.id == katalog.activeStudioId }?.name
    }

    var body: some View {
        List {
            kopfkarte
            beimTraining
            deineDaten
            abmelden
            fusszeile
        }
        .scrollContentBackground(.hidden)
        .background(DesignSystem.Color.bg)
        .navigationTitle("PROFIL")
        .sheet(isPresented: $nameOffen) {
            NameSheet(bisher: name) { neuerName in
                do {
                    _ = try await apiClient.setDisplayName(neuerName)
                    await katalog.load()
                    return nil
                } catch {
                    // Der Servertext woertlich -- er sagt, was gilt
                    // (designsystem.md SS5).
                    return error.meldung
                }
            }
        }
    }

    /// Antippbar, anders als im Artboard: die Registrierung erfragt den
    /// Vornamen erst seit Sub-Projekt 4, jedes Bestandsmitglied braucht
    /// einen Weg dorthin.
    ///
    /// Ohne gesetzten Namen steht hier die Mailadresse allein -- keine
    /// Initialen aus dem Mail-Praefix.
    private var kopfkarte: some View {
        Section {
            Button { nameOffen = true } label: {
                HStack(spacing: DesignSystem.Spacing.s12) {
                    if let initialen = HomeZeilen.initialen(name) {
                        Text(initialen)
                            .font(DesignSystem.Typography.label)
                            .foregroundStyle(DesignSystem.Color.onAccent)
                            .frame(width: 44, height: 44)
                            .background(DesignSystem.Color.accent)
                            .clipShape(Circle())
                    }
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.s4) {
                        if let name {
                            Text(name)
                                .font(DesignSystem.Typography.uebungsname)
                                .foregroundStyle(DesignSystem.Color.text)
                        }
                        if let email = sessionStore.session?.email {
                            Text(email)
                                .font(DesignSystem.Typography.fliesstext)
                                .foregroundStyle(DesignSystem.Color.textMuted)
                        }
                    }
                }
            }
        }
        .listRowBackground(DesignSystem.Color.surface)
    }

    private var beimTraining: some View {
        Section("BEIM TRAINING") {
            Picker("Pause zwischen Sätzen", selection: $resttimerSekunden) {
                ForEach(Einstellungen.resttimerStufen, id: \.self) { stufe in
                    Text("\(stufe) s").tag(stufe)
                }
            }
            Toggle("Vibration beim Sichern", isOn: $vibrationBeimSichern)
            Toggle("Reserve (RIR) abfragen", isOn: $rirSichtbar)

            NavigationLink("Passwort ändern") { MemberPasswortAendernView() }
            NavigationLink("Studios") { MemberStudiosView() }
        }
        .tint(DesignSystem.Color.accent)
        .listRowBackground(DesignSystem.Color.surface)
    }

    private var deineDaten: some View {
        Section("DEINE DATEN") {
            Text(
                "gymodo misst nichts. Gespeichert wird nur, was du selbst bestätigst — Einstellwerte, Sätze, ob ein Trainer dabei war."
            )
            .font(DesignSystem.Typography.fliesstext)
            .foregroundStyle(DesignSystem.Color.textMuted)

            // Nur mit hinterlegter Adresse -- ein Bedienelement ohne Ziel
            // ist schlechter als keines.
            if let url = AppConfig.datenschutzURL {
                Link("Datenschutzerklärung", destination: url)
            }
        }
        .listRowBackground(DesignSystem.Color.surface)
    }

    private var abmelden: some View {
        Section {
            Button("Abmelden", role: .destructive) {
                Task {
                    await sessionStore.signOut()
                    verlauf.reset()
                }
            }
        }
        .listRowBackground(DesignSystem.Color.surface)
    }

    private var fusszeile: some View {
        Section {
            Text(
                [
                    "gymodo \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")",
                    studioName,
                ]
                .compactMap { $0 }
                .joined(separator: " · ")
            )
            .font(DesignSystem.Typography.fliesstext)
            .foregroundStyle(DesignSystem.Color.textFaint)
        }
        .listRowBackground(DesignSystem.Color.bg)
    }
}
```

`APIError.meldung` ist der Name aus Sub-Projekt 1/2 für den anzeigbaren Text — in `APIError.swift` nachsehen und den tatsächlichen verwenden.

`MainTabView` reicht den `apiClient` an `ProfilRootView` weiter, wie es das für `TrainingRootView` schon tut. Der `VerlaufStore.reset()` beim Abmelden hängt hier **zusätzlich** zur Stelle aus Aufgabe 5 — falls dort schon eine zentrale Abmeldestelle existiert, gilt sie, und dieser Aufruf entfällt.

- [ ] **Step 4: Kaltbau**

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -derivedDataPath /tmp/dd-sp4-t10 test 2>&1 | grep -E "warning:|error:|TEST SUCCEEDED|TEST FAILED"
rm -rf /tmp/dd-sp4-t10
```

Erwartet: `TEST SUCCEEDED`, nur die vier vorbestehenden Warnungen.

- [ ] **Step 5: Commit**

```bash
git add apps/ios-member
git commit -m "feat(ios): das Profil bekommt seine Gestalt

Der letzte Screen der M1-Screenliste: Kopfkarte, drei Einstellungen,
Produktgrenze, Abmelden.

Die Kopfkarte ist antippbar, anders als im Artboard -- die Registrierung
erfragt den Vornamen erst ab jetzt, und jedes Bestandsmitglied braucht
einen Weg dorthin. Ohne gesetzten Namen steht dort die Mailadresse
allein: aus 'lena.wagner@...' Initialen abzuleiten waere geraten.

Die Datenschutzzeile erscheint nur mit hinterlegter URL."
```

---

### Aufgabe 11: Der Vorname bei der Registrierung

**Files:**
- Modify: `apps/ios-member/FitnessMember/Screens/Zugang/MemberRegistrierenView.swift`
- Modify: `apps/ios-member/FitnessMember/Auth/SessionStore.swift`
- Modify: `apps/ios-member/FitnessMember/Screens/Zugang/LoginCodeView.swift`

**Interfaces:**
- Consumes: `APIClient.setDisplayName` (Aufgabe 3)
- Produces: `SessionStore.vorgemerkterName: String?` und `func nameVormerken(_:)`

- [ ] **Step 1: Das Feld**

In `MemberRegistrierenView.swift` **vor** dem Mailfeld — der Screen wurde in Sub-Projekt 1 abgenommen und wird hier bewusst wieder aufgemacht:

```swift
                LabeledField(label: "VORNAME", text: $vorname)
                    .textContentType(.givenName)
```

Der bestehende Hinweistext („Mindestens zehn Zeichen …") und der Satz „Danach schicken wir dir einen Code zur Bestätigung." bleiben **wörtlich** stehen.

- [ ] **Step 2: Den Namen über den Code-Schritt tragen**

Zwischen Registrierung und bestehender Sitzung liegt die Code-Bestätigung — vorher gibt es keine Sitzung, mit der sich `PUT /me/profile` aufrufen ließe. `SessionStore` merkt ihn sich so lange:

```swift
    /// Der bei der Registrierung genannte Vorname, bis eine Sitzung
    /// besteht. Nur im Speicher: er ueberlebt den Code-Schritt, aber
    /// keinen App-Neustart -- laeuft die Registrierung ins Leere, ist
    /// nichts Halbes gespeichert.
    private(set) var vorgemerkterName: String?

    func nameVormerken(_ name: String) {
        let geputzt = name.trimmingCharacters(in: .whitespacesAndNewlines)
        vorgemerkterName = geputzt.isEmpty ? nil : geputzt
    }

    func nameVerbraucht() { vorgemerkterName = nil }
```

`MemberRegistrierenView.submit()` ruft `sessionStore.nameVormerken(vorname)` vor dem `signUp`.

- [ ] **Step 3: Nach der Code-Bestätigung schreiben**

In `LoginCodeView.swift`, an der Stelle, die `verifySignupCode` erfolgreich abgeschlossen hat:

```swift
        // Der Name ist Zierde, kein Trageteil: schlaegt der Schreibvorgang
        // fehl (kein Netz im Keller), geht es ohne ihn weiter, und das
        // Profil bietet denselben Weg noch einmal an. Deshalb kein
        // Wiederholungsmechanismus und keine Warteschlange -- die ist fuer
        // Saetze da.
        if let name = sessionStore.vorgemerkterName {
            _ = try? await apiClient.setDisplayName(name)
            sessionStore.nameVerbraucht()
        }
```

Hat `LoginCodeView` heute keinen `apiClient`, wird er wie in den anderen Zugangs-Screens hereingereicht — nicht neu erzeugt.

- [ ] **Step 4: Kaltbau**

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -derivedDataPath /tmp/dd-sp4-t11 test 2>&1 | grep -E "warning:|error:|TEST SUCCEEDED|TEST FAILED"
rm -rf /tmp/dd-sp4-t11
```

Erwartet: `TEST SUCCEEDED`, nur die vier vorbestehenden Warnungen.

- [ ] **Step 5: Commit**

```bash
git add apps/ios-member
git commit -m "feat(ios): die Registrierung fragt den Vornamen

Geschrieben wird er erst nach der Code-Bestaetigung -- vorher gibt es
keine Sitzung, mit der sich PUT /me/profile aufrufen liesse. So lange
liegt er nur im Speicher: laeuft die Registrierung ins Leere, ist nichts
Halbes gespeichert.

Schlaegt der Schreibvorgang fehl, geht es ohne Namen weiter. Er ist
Zierde, kein Trageteil, und das Profil bietet denselben Weg noch einmal
an."
```

---

### Aufgabe 12: Gesamtlauf und Abnahmeliste

Alles zusammen, einmal kalt — und die Liste dessen, was `xcodebuild` **nicht** beweisen kann.

**Files:**
- Create: `docs/superpowers/plans/2026-09-XX-home-profil-abnahme.md` (Datum des Abschlusstags)

- [ ] **Step 1: Alle drei Ebenen**

```bash
cd packages/domain && pnpm vitest run && cd ../..
pnpm vitest run
pnpm typecheck
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -derivedDataPath /tmp/dd-sp4-final test 2>&1 | grep -E "warning:|error:|TEST SUCCEEDED|TEST FAILED|Test run with"
rm -rf /tmp/dd-sp4-final
```

Erwartet: Domänentests grün, Integrationstests grün, `typecheck` fehlerfrei, `TEST SUCCEEDED`, **genau die vier vorbestehenden Warnungen**.

- [ ] **Step 2: Die Abnahmeliste schreiben**

Nach dem Vorbild von `2026-09-09-training-kurse-abnahme.md`, im Repository und nicht im Arbeitsverzeichnis. Diese Punkte gehören hinein — jeder ist eine Wirkung, die kein Test dieses Sub-Projekts zeigen kann:

1. **Erste Registrierung mit Vornamen, dann Home öffnen.** Der Gruß nennt den Vornamen, das Profil zeigt Name und Initialen.
2. **Bestandskonto ohne Namen.** Home grüßt **nicht**, das Profil zeigt nur die Mailadresse und keine Initialen. Dann über die Kopfkarte einen Namen setzen: beides erscheint.
3. **Registrierung mit Vornamen im Flugmodus abschließen.** Es geht ohne Namen weiter, keine Fehlermeldung, und das Profil bietet den Weg erneut an.
4. **Flugmodus, App neu starten, Home öffnen.** Verlauf, Kennzahlen und Fortschritt stehen aus dem Cache, darüber „Ohne Empfang. Stand: …". Dann Flugmodus aus und nach unten ziehen: der Satz verschwindet.
5. **Eine Einheit über vier Stunden offen liegen lassen**, dann Home öffnen. Sie erscheint mit „AUTO BEENDET" und **ohne Dauer**.
6. **Während einer laufenden Einheit Home öffnen.** Sie steht **nicht** unter „Letzte Trainings", die Kennzahl „Tage her" zeigt 0.
7. **Studio verlassen, Home öffnen.** „diese Woche" fehlt, „gesamt" und die Liste bleiben.
8. **Ein Diagramm mit einem einzigen Punkt.** Achse und Punkt sind sichtbar, die Kurve verschwindet nicht in einer Linie.
9. **Übungsfortschritt mit VoiceOver.** Die Rohwerteliste unter der Kurve ist erreichbar und liest Datum, Gewicht und Wiederholungen.
10. **Dynamic Type auf XXL** auf Home, Session-Detail und Profil. Nichts bricht ins Layout (§12: Abnahmebedingung).
11. **Resttimer auf 45 s stellen, Satz sichern.** Der Balken läuft 45 s, nicht 90.
12. **Vibration abschalten, Satz sichern.** Keine Haptik, die sichtbare Bestätigung bleibt.
13. **RIR abschalten**, dann ein älteres Session-Detail öffnen: bereits erfasste RIR-Werte stehen weiterhin da — der Schalter regelt die Erfassung, nicht die Rückschau.
14. **Datenschutzzeile:** ohne `DATENSCHUTZ_URL` fehlt sie ganz; mit gesetztem Wert öffnet sie die Adresse.

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/plans/
git commit -m "docs: offene manuelle Abnahme fuer Sub-Projekt 4"
```

---

## Was dieser Plan bewusst nicht tut

- **Kein Auth-Trigger** für `profiles` — Begründung in Spec 3.4 und Aufgabe 3.
- **Keine Korrektur der UTC-Tagesgrenze** im Fortschritt (Spec 3.3): sie bräuchte den Zeitzonen-Parameter auch an `/me/progress` und verschöbe historische Punkte rückwirkend.
- **Kein zweiter Testunterbau** für `getSessions`/`getProgress`: sie sind über `tests/integration` gegen echtes Postgres geprüft, und eine mit Attrappen nachgebaute Ebene daneben formulierte dieselbe Regel ein zweites Mal.
- **Kein Plan-Tab**, kein Datenexport, kein Hell-Modus — außerhalb von M1.
