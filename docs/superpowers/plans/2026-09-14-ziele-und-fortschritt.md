# Ziele & Fortschritt: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persönliche Ziele und Fortschritt in die Member-App bringen — ein Onboarding nach der Registrierung (Geschlecht, Altersspanne, Größe, Gewicht, Richtung, Trainingstage, Zielgewicht), das Körpergewicht als eigener Verlauf, Ziele mit Anfang und Ende, und auf Home der Block „Deine Ziele" neben dem Kalender.

**Architecture:** Drei additive Migrationen (`0041`–`0043`), drei neue Fachmodule (`profil.ts` erweitert, `measurements.ts`, `goals.ts`), fünf Routen. Der Server rechnet weiterhin alles, was eine Zeitzone oder die ganze Geschichte braucht; der Client rechnet genau eine Sache selbst — Trainingstage gegen das Wochenziel zählen. **Die Serie bleibt unangetastet:** ein Wochenziel ist eine Zeile unter dem Streifen, kein zweiter Schwellwert in `serienstand` (Spec Abschnitt 9, Punkt 5). Körperdaten sind Gesundheitsdaten: eigene Tabelle ohne Studio-Bezug, RLS nur auf die eigene Zeile, **keine** Öffnung für Personal, auch nicht als Summe.

**Teststrategie:** Wie in Sub-Projekt 4 — Unit-Tests in `packages/domain` nur für reine Rechnung (Eingabeprüfung, `zielErreicht`), Integrationstests gegen echtes Postgres für alles, was RLS oder eine Tabelle berührt. Der wichtigste Integrationstest dieses Bauabschnitts ist ein Negativtest: **ein Trainer des eigenen Studios sieht keine Körperdaten**, und `studio_overview` trägt keinen Schlüssel dafür. iOS: reine Ableitungen ohne UI (Gate, Schrittfolge, Schreibreihenfolge, Zielzeile, Kartenwerte).

**Tech Stack:** Swift 6.0, SwiftUI (iOS 17), Swift Charts, Swift Testing, XcodeGen. Backend: TypeScript, Next.js App Router, Zod, Vitest, Postgres/Supabase.

**Spec:** `docs/superpowers/specs/2026-09-13-ziele-und-fortschritt-design.md` — dieser Plan setzt sie um; Ausführende lesen beide Dokumente. Dazu `2026-09-09-ios-home-profil-design.md` (Verlauf-Cache, Profil), `2026-08-30-designsystem.md` (Aussehen), `2026-08-28-fitness-retrofit-m1-design.md` §4.3 (Produktgrenze).

**Artboards:** `docs/superpowers/design/ziele/*.dc.html` — Onboarding1–5, Main (Home mit Zielen), HomeNachholen, HomeZielErreicht, Gewichtsverlauf, GewichtEintragen, Profil, ProfilAlter, Bausteine. Sie zeigen das Kalender-Home von `master` (Stand 13. September). Erzeugt aus `gen.py`; wer ein Artboard ändert, ändert den Generator.

## Global Constraints

- iOS-Deployment-Ziel 17.0, Swift 6.0 — nicht ändern. **Keine neue SPM-Abhängigkeit.**
- **Kein Direktzugriff aus Swift auf Postgres/PostgREST** — alles über `/api/v1`.
- **Alle Ziffern tabellarisch.** **Gewichte immer mit einer Nachkommastelle und Dezimalkomma** über `Zahlformat.gewicht` / `gewichtMitEinheit` / `gewichtGesprochen`, nie selbst formatiert.
- **Trefferflächen ≥ 44 pt. Hauptaktion 64 pt**, Nebenaktion 46–52 pt. Radius 16 / 14 / 12 / Pille. Abstände nur 4 · 8 · 12 · 16 · 24 · 32 · 48. Seitenrand 20 pt im Content, 28 pt in der Einstiegskette (Onboarding).
- **Genau eine Akzentfläche je Screen** (§2). Gewählte Chips und Kacheln tragen den Akzent nur als 1,5-pt-Strich — wie der Fokusrand der Felder.
- **Fünf Zustände** (§5): kein Skelett über Zahlen · Leer erklärt den nächsten Schritt · Offline heißt nie „fehlgeschlagen" · Fehler sagt, was falsch ist **und** was gilt · Deaktiviert ist nie stumm.
- **Kein BMI, keine Kalorien, kein „gesund", kein Trend, keine Prognose** — nirgends, auch nicht in VoiceOver-Texten oder Kommentaren als „später". Die App zeigt eingetragene Zahlen und ihre Differenz (Spec Abschnitt 6).
- **Kein Text verspricht eine Benachrichtigung.** Push existiert nicht.
- **Durchgehend Deutsch, Du-Form, keine Ausrufezeichen, kein Motivationston.** „Ziel erreicht" ist eine Zeile mit Haken, kein Konfetti.
- **Backend-Fehlerhülle** und Statuscodes aus `apps/web/lib/api/respond.ts` — nicht ändern. Neue Routen wie die bestehenden: `bearerClientFrom`, `fromDomainError`/`errorResponse`, `export const dynamic = "force-dynamic"`.
- **Postgres-Fehler nie wörtlich durchreichen** — `DomainError("internal", …)` mit eigenem Satz (siehe `profil.ts`).
- Deutsche Bezeichner in neuem Fachcode; englische nur für API-Verträge, Spalten und Enum-Werte (Schema-Regel aus `0035_kurse.sql`).
- **Kommentare erklären, warum — nicht was.**
- **Jede Verifikation läuft als Kaltbau** mit isoliertem `-derivedDataPath`, danach löschen. Die vier vorbestehenden Warnungen bleiben; jede Warnung in einer Datei, die du schreibst, ist deine.
- **Neue Swift-Dateien brauchen `xcodegen generate`.**
- **Migration vor Deploy** (`2026-09-01-gesamtfahrplan.md` §4f): der neue Bootstrap liest Spalten, die es ohne `0041` nicht gibt. Vor `db push` gilt die Frage aus §7: *ist die Datenbank hinten oder vorn?*

## Dateistruktur

**Neu, Server:**

| Datei | Verantwortung |
| --- | --- |
| `supabase/migrations/0041_profil_stammdaten.sql` | Enums `member_sex`, `age_band`, `training_goal`; fünf Spalten an `profiles` |
| `supabase/migrations/0042_body_measurements.sql` | Tabelle, RLS nur eigene Zeile, kein Studio |
| `supabase/migrations/0043_member_goals.sql` | Enums `goal_kind`, `goal_status`; Tabelle; Prüf-Funktion; `set_member_goal` |
| `packages/domain/src/measurements.ts` | `messwertSchema`, `zielErreicht`, `putMeasurement`, `deleteMeasurement`, `getMeasurements` |
| `packages/domain/src/measurements.test.ts` | Eingabeprüfung, `zielErreicht` |
| `packages/domain/src/goals.ts` | `zielSchema`, `setGoal`, `dropGoal`, `aktiveZiele` |
| `packages/domain/src/goals.test.ts` | Eingabeprüfung |
| `apps/web/app/api/v1/me/measurements/route.ts` | `GET`, `PUT` |
| `apps/web/app/api/v1/me/measurements/[measuredOn]/route.ts` | `DELETE` |
| `apps/web/app/api/v1/me/goals/route.ts` | `PUT` |
| `apps/web/app/api/v1/me/goals/[kind]/route.ts` | `DELETE` |
| `tests/integration/rls-body-measurements.test.ts` | eigene/fremde Zeilen, **Trainer sieht nichts**, Austritt ändert nichts |
| `tests/integration/rls-member-goals.test.ts` | Policies, Partial-Unique, `set_member_goal` |
| `tests/integration/api-measurements.test.ts` | Upsert je Tag, `summary`, `goalReached`, Löschen |
| `tests/integration/api-goals.test.ts` | Setzen, Ersetzen, Aufgeben, `weeklyTarget` in `/me/sessions` |

**Neu, iOS:**

| Datei | Verantwortung |
| --- | --- |
| `FitnessMember/Networking/DTOs/Messwert.swift` | `MeasurementsResponse`, `Messwert`, `MesswertWrite`, `MesswertAntwort` |
| `FitnessMember/Networking/DTOs/Ziel.swift` | `Ziel`, `ZielWrite` |
| `FitnessMember/Networking/DTOs/ProfilWrite.swift` | Teilobjekt mit „weglassen / setzen / löschen" je Feld |
| `FitnessMember/Profil/Stammdaten.swift` | `Geschlecht`, `Altersspanne`, `Trainingsrichtung` — Enum-Werte des Servers und ihre deutschen Wörter |
| `FitnessMember/Onboarding/OnboardingAntworten.swift` | die Antworten der fünf Schritte, welche Schritte es gibt |
| `FitnessMember/Onboarding/OnboardingSchreiber.swift` | die Schreibreihenfolge und ihre Teilwiederholung |
| `FitnessMember/Onboarding/OnboardingFlow.swift` | der Stack aus fünf Schritten, als Wurzel und als Sheet |
| `FitnessMember/Onboarding/OnboardingSchritte.swift` | die fünf Screens |
| `FitnessMember/Onboarding/Zielkachel.swift` | die Kachel aus Schritt 3 |
| `FitnessMember/Verlauf/HomeZiele.swift` | reine Ableitungen der Gewichtskarte und der Zielzeile |
| `FitnessMember/Screens/Home/HomeZieleView.swift` | der Block „Deine Ziele", drei Zustände |
| `FitnessMember/Screens/Home/GewichtsverlaufView.swift` | Kurve, Ziellinie, Rohwerte |
| `FitnessMember/Screens/Home/GewichtEintragenSheet.swift` | Datum, Rad, Eintragen |
| `FitnessMember/Screens/Profil/AuswahlSheet.swift` | Chips + „Angabe entfernen" — für Geschlecht, Alter, Richtung |
| `FitnessMember/Screens/Profil/GroesseSheet.swift` | Stepper + „Angabe entfernen" |
| `FitnessMember/Screens/Profil/ZielSheet.swift` | Tage pro Woche, Zielgewicht — mit „Ziel aufgeben" |
| `FitnessMemberTests/RootDestinationTests.swift` | erweitert: `onboarding` |
| `FitnessMemberTests/OnboardingAntwortenTests.swift`, `OnboardingSchreiberTests.swift`, `HomeZieleTests.swift`, `StammdatenTests.swift` | die reinen Ableitungen |

**Geändert:**

| Datei | Änderung |
| --- | --- |
| `packages/domain/src/profil.ts` | `profilSchema`, `updateProfile` (ersetzt `setDisplayName`) |
| `packages/domain/src/profil.test.ts` | die neuen Felder |
| `packages/domain/src/bootstrap.ts` | `member` mit Stammdaten, aktiven Zielen, `latestWeight` |
| `packages/domain/src/sessions.ts` | `streak.weeklyTarget` |
| `packages/domain/src/index.ts` | Exporte |
| `apps/web/app/api/v1/me/profile/route.ts` | ruft `updateProfile` |
| `tests/integration/api-profil.test.ts` | Teilobjekt, `null` löscht, `onboardingDone` |
| `tests/integration/domain-bootstrap.test.ts` | `member` vollständig |
| `tests/integration/studio-ueberblick.test.ts` | Zusicherung: kein Körperdaten-Schlüssel |
| `FitnessMember/Networking/DTOs/BootstrapResponse.swift` | `Member` erweitert |
| `FitnessMember/Networking/DTOs/SessionSummary.swift` | `Serienstand.weeklyTarget` |
| `FitnessMember/Networking/APIClient.swift` | sechs Methoden |
| `FitnessMember/Navigation/RootDestination.swift`, `RootView.swift` | das Gate |
| `FitnessMember/Navigation/HomeRoute.swift` | `.gewichtsverlauf` |
| `FitnessMember/Verlauf/VerlaufStore.swift`, `VerlaufFileStore.swift` | Messwerte im Cache |
| `FitnessMember/Verlauf/HomeSerie.swift` | `zielzeile` |
| `FitnessMember/Screens/Home/HomeSerieView.swift` | „Ziel 3 Tage" und die Zielzeile |
| `FitnessMember/Screens/Home/HomeRootView.swift` | `HomeZieleView` zwischen Kalender und Übungsfortschritt |
| `FitnessMember/Verlauf/Fortschrittsfenster.swift` | Filter über ein Protokoll statt nur `ExerciseProgress.Point` |
| `FitnessMember/Screens/Profil/ProfilRootView.swift` | Abschnitte „Über dich" und „Ziele", zweiter Produktgrenze-Satz |
| `FitnessMember/Screens/Zugang/MemberRegistrierenView.swift`, `LoginCodeView.swift` | `setDisplayName` bleibt als Aufruf — die Route nimmt das Teilobjekt entgegen |
| `FitnessMemberTests/DTOTests.swift`, `VerlaufStoreTests.swift`, `HomeSerieTests.swift` | nachgezogen |

---

## Aufgaben-Übersicht

| # | Aufgabe | Ebene |
| --- | --- | --- |
| 1 | Stammdaten: `0041`, `updateProfile`, Bootstrap | Server |
| 2 | Körpergewicht: `0042`, `measurements.ts`, zwei Routen | Server |
| 3 | Ziele: `0043`, `goals.ts`, zwei Routen, `weeklyTarget`, „Ziel erreicht" | Server |
| 4 | Die Datenschutz-Zusicherung: Trainer sieht nichts, Überblick bleibt leer | Server |
| 5 | iOS: DTOs, `APIClient`, Messwerte im `VerlaufStore` | iOS |
| 6 | iOS: das Gate und die reinen Onboarding-Ableitungen | iOS |
| 7 | iOS: `OnboardingFlow` — fünf Screens, ein Schreibweg | iOS |
| 8 | iOS: Home — Zielzeile im Kalender, `HomeZieleView` | iOS |
| 9 | iOS: Gewicht eintragen, Gewichtsverlauf | iOS |
| 10 | iOS: Profil — „Über dich", „Ziele", die Sheets | iOS |
| 11 | Gesamtlauf, Migrationen in die Cloud, Abnahmeliste | beides |

Aufgaben 1–3 bauen aufeinander auf (3 braucht die Tabelle aus 2 für „Ziel erreicht"). 4 hängt an 2 und 3. 5 hängt an 1–3. 6–10 hängen an 5; 6 und 7 vor 8, 8 vor 9, 10 unabhängig von 8/9.

---

### Aufgabe 1: Stammdaten — `0041`, `updateProfile`, Bootstrap

`profiles` bekommt fünf Spalten. `PUT /me/profile` nimmt statt `{ displayName }` ein Teilobjekt: jedes Feld optional, `null` löscht, `onboardingDone: true` setzt den Abschlusszeitpunkt serverseitig. Ein Schreibweg für Registrierung, Onboarding und Profil.

**Files:**
- Create: `supabase/migrations/0041_profil_stammdaten.sql`
- Modify: `packages/domain/src/profil.ts`, `profil.test.ts`, `bootstrap.ts`, `index.ts`
- Modify: `apps/web/app/api/v1/me/profile/route.ts`
- Modify: `tests/integration/api-profil.test.ts`, `domain-bootstrap.test.ts`

**Interfaces:**
- Produces: `profilSchema`, `pruefeProfil(roh): ProfilEingabe`, `updateProfile(client, payload): Promise<Profil>`, `type Profil = { displayName, sex, ageBand, heightCm, trainingGoal, onboardingCompletedAt }`; `Bootstrap.member` erweitert um dieselben Felder (Ziele und `latestWeight` kommen in Aufgabe 2/3)
- Consumes: `requireUserId`, `DomainError`

- [ ] **Step 1: Die Migration**

Create `supabase/migrations/0041_profil_stammdaten.sql`:

```sql
-- Stammdaten am Profil, Spec 2026-09-13-ziele-und-fortschritt-design.md
-- Abschnitt 3.1.
--
-- Alle fuenf Spalten nullable: nichts davon ist Voraussetzung fuer
-- irgendeine Funktion, und ein Mitglied, das im Onboarding fuenfmal
-- "Spaeter" tippt, nutzt die App wie bisher.
--
-- Alter als SPANNE, nicht als Jahr oder Datum: sparsamer, und sie altert
-- nicht mit -- wer 35 wird, bleibt in 25_34, bis er es selbst aendert.
-- Ehrlicher als ein Alter, das die App aus einem Jahr rechnet.
--
-- Geschlecht wird gespeichert, aber in diesem Bauabschnitt von keiner
-- Funktion gelesen (Entscheidung vom 13. September: Grundlage fuer
-- spaetere Startgewicht-Vorschlaege und Trainingsplaene). "Keine Angabe"
-- ist null, kein vierter Wert.
--
-- Was hier NICHT passiert: keine neue Policy, kein Spaltenrecht fuer
-- Personal. profiles_select_own / _update_own / _insert_own (0001, 0039)
-- decken die Spalten -- die Zeile bleibt die eigene.

create type public.member_sex as enum ('female', 'male', 'diverse');
create type public.age_band as enum
  ('under_18', '18_24', '25_34', '35_44', '45_54', '55_64', '65_plus');
create type public.training_goal as enum
  ('lose_weight', 'build_muscle', 'stay_fit', 'get_stronger');

alter table public.profiles
  add column sex                     public.member_sex,
  add column age_band                public.age_band,
  add column height_cm               smallint,
  add column training_goal           public.training_goal,
  add column onboarding_completed_at timestamptz,
  add constraint profiles_height_range
    check (height_cm is null or height_cm between 100 and 250);

comment on column public.profiles.onboarding_completed_at is
  'Gesetzt beim Abschluss ODER beim Ueberspringen -- das Onboarding erscheint nie zweimal. Wird nie vom Client geliefert, nur ueber updateProfile({ onboardingDone: true }) auf now() gesetzt. Jedes Bestandskonto traegt null und sieht das Onboarding beim naechsten Start einmal; das sind bis M2 Entwicklerkonten und synthetische Daten.';
```

- [ ] **Step 2: Den Unit-Test für die Eingabeprüfung erweitern**

In `packages/domain/src/profil.test.ts` — die bestehenden Fälle für den Namen bleiben; dazu:

```ts
import { pruefeProfil } from "./profil.js";

describe("pruefeProfil", () => {
  it("nimmt ein leeres Teilobjekt an -- nichts zu aendern ist erlaubt", () => {
    expect(pruefeProfil({})).toEqual({});
  });

  it("laesst jedes Feld einzeln setzen und mit null loeschen", () => {
    expect(pruefeProfil({ sex: "female" })).toEqual({ sex: "female" });
    expect(pruefeProfil({ ageBand: "25_34" })).toEqual({ ageBand: "25_34" });
    expect(pruefeProfil({ heightCm: 168 })).toEqual({ heightCm: 168 });
    expect(pruefeProfil({ trainingGoal: "lose_weight" })).toEqual({ trainingGoal: "lose_weight" });
    expect(pruefeProfil({ heightCm: null, sex: null })).toEqual({ heightCm: null, sex: null });
  });

  it("weist Werte ausserhalb der Listen ab", () => {
    expect(() => pruefeProfil({ ageBand: "30_35" })).toThrow(/Altersspanne/);
    expect(() => pruefeProfil({ sex: "x" })).toThrow(/Geschlecht/);
    expect(() => pruefeProfil({ trainingGoal: "run_marathon" })).toThrow(/Richtung/);
  });

  it("haelt die Groesse in 100 bis 250 cm und ganzzahlig", () => {
    expect(() => pruefeProfil({ heightCm: 99 })).toThrow(/100/);
    expect(() => pruefeProfil({ heightCm: 251 })).toThrow(/250/);
    expect(() => pruefeProfil({ heightCm: 168.5 })).toThrow();
  });

  it("nimmt onboardingDone nur als true", () => {
    expect(pruefeProfil({ onboardingDone: true })).toEqual({ onboardingDone: true });
    expect(() => pruefeProfil({ onboardingDone: false })).toThrow();
  });

  it("weist den Abschlusszeitpunkt als Feld ab -- den setzt der Server", () => {
    expect(() => pruefeProfil({ onboardingCompletedAt: "2026-09-14T10:00:00Z" })).toThrow();
  });

  it("prueft den Namen weiterhin wie bisher", () => {
    expect(pruefeProfil({ displayName: "  Lena " })).toEqual({ displayName: "Lena" });
    expect(() => pruefeProfil({ displayName: "" })).toThrow(/leer/);
  });
});
```

- [ ] **Step 3: Testlauf, der fehlschlagen muss**

```bash
cd packages/domain && pnpm vitest run src/profil.test.ts
```

Erwartet: FAIL — `pruefeProfil` ist nicht exportiert.

- [ ] **Step 4: `profil.ts` umbauen**

`profil.ts` bekommt das Teilobjekt. `anzeigenameSchema` und `pruefeAnzeigename` bleiben exportiert (der bestehende Test prüft sie), `setDisplayName` fällt weg — die Registrierung schickt weiterhin `{ displayName }`, und das ist ein gültiges Teilobjekt:

```ts
export const SEX = ["female", "male", "diverse"] as const;
export const AGE_BANDS = ["under_18", "18_24", "25_34", "35_44", "45_54", "55_64", "65_plus"] as const;
export const TRAINING_GOALS = ["lose_weight", "build_muscle", "stay_fit", "get_stronger"] as const;

/**
 * Ein Teilobjekt: was fehlt, bleibt; `null` loescht. `.strict()`, damit
 * ein mitgeschickter Abschlusszeitpunkt nicht still verschluckt wird --
 * den setzt ausschliesslich der Server ueber `onboardingDone`.
 */
export const profilSchema = z
  .object({
    displayName: anzeigenameSchema.shape.displayName.optional(),
    sex: z.enum(SEX, { message: "Kein bekanntes Geschlecht." }).nullable().optional(),
    ageBand: z.enum(AGE_BANDS, { message: "Keine bekannte Altersspanne." }).nullable().optional(),
    heightCm: z
      .number()
      .int("Die Groesse ist eine ganze Zahl in Zentimetern.")
      .min(100, "Die Groesse liegt zwischen 100 und 250 cm.")
      .max(250, "Die Groesse liegt zwischen 100 und 250 cm.")
      .nullable()
      .optional(),
    trainingGoal: z.enum(TRAINING_GOALS, { message: "Keine bekannte Richtung." }).nullable().optional(),
    onboardingDone: z.literal(true).optional(),
  })
  .strict();

export type ProfilEingabe = z.infer<typeof profilSchema>;

export type Profil = {
  displayName: string | null;
  sex: (typeof SEX)[number] | null;
  ageBand: (typeof AGE_BANDS)[number] | null;
  heightCm: number | null;
  trainingGoal: (typeof TRAINING_GOALS)[number] | null;
  onboardingCompletedAt: string | null;
};

export function pruefeProfil(roh: unknown): ProfilEingabe {
  const geprueft = profilSchema.safeParse(roh);
  if (!geprueft.success) {
    throw new DomainError("validation_failed", geprueft.error.issues[0]!.message);
  }
  return geprueft.data;
}

/**
 * Der einzige Schreibweg des Profils -- Registrierung (Name), Onboarding
 * (alles auf einmal), Profil (ein Feld, oder eins auf null).
 *
 * `upsert` wie bisher: fuer ein Bestandskonto gibt es keine Zeile. Nur die
 * gesendeten Felder landen im Update -- ein `undefined` darf keine
 * Spalte anfassen, sonst loeschte "Groesse aendern" den Namen.
 */
export async function updateProfile(client: SupabaseClient, payload: unknown): Promise<Profil> {
  const eingabe = pruefeProfil(payload);
  const userId = await requireUserId(client);

  const zeile: Record<string, unknown> = { id: userId };
  if (eingabe.displayName !== undefined) zeile.display_name = eingabe.displayName;
  if (eingabe.sex !== undefined) zeile.sex = eingabe.sex;
  if (eingabe.ageBand !== undefined) zeile.age_band = eingabe.ageBand;
  if (eingabe.heightCm !== undefined) zeile.height_cm = eingabe.heightCm;
  if (eingabe.trainingGoal !== undefined) zeile.training_goal = eingabe.trainingGoal;
  if (eingabe.onboardingDone) zeile.onboarding_completed_at = new Date().toISOString();

  const { data, error } = await client
    .from("profiles")
    .upsert(zeile, { onConflict: "id" })
    .select("display_name, sex, age_band, height_cm, training_goal, onboarding_completed_at")
    .single();

  if (error || !data) throw new DomainError("internal", "Das Profil konnte nicht gespeichert werden.");
  return zuProfil(data);
}

export function zuProfil(row: {
  display_name: string | null; sex: string | null; age_band: string | null;
  height_cm: number | null; training_goal: string | null; onboarding_completed_at: string | null;
}): Profil {
  return {
    displayName: row.display_name,
    sex: row.sex as Profil["sex"],
    ageBand: row.age_band as Profil["ageBand"],
    heightCm: row.height_cm,
    trainingGoal: row.training_goal as Profil["trainingGoal"],
    onboardingCompletedAt: row.onboarding_completed_at,
  };
}
```

**Achtung Upsert und `onboardingDone`:** ein Upsert mit nur `{ id, onboarding_completed_at }` auf eine bestehende Zeile lässt die übrigen Spalten stehen — Supabase setzt beim Konflikt nur die gesendeten Spalten. Genau das ist gewollt; der Integrationstest in Step 7 sichert es zu.

In `index.ts`: `export { anzeigenameSchema, pruefeAnzeigename, profilSchema, pruefeProfil, updateProfile, zuProfil, SEX, AGE_BANDS, TRAINING_GOALS } from "./profil.js"; export type { Profil, ProfilEingabe } from "./profil.js";` — den bisherigen `setDisplayName`-Export entfernen.

- [ ] **Step 5: Testlauf, der bestehen muss**

```bash
cd packages/domain && pnpm vitest run src/profil.test.ts
```

- [ ] **Step 6: Bootstrap liest die Stammdaten**

In `bootstrap.ts` wird `member: { displayName: string | null }` zu `member: Profil & { goals: …; latestWeight: … }` — die beiden letzten Felder kommen in Aufgabe 2 und 3, hier erst einmal:

```ts
export type Bootstrap = {
  /**
   * Das Profil als Lesepfad. Alles nullable; `onboardingCompletedAt`
   * entscheidet im Client ueber das Onboarding-Gate, deshalb haengt es am
   * Abruf, der ohnehin bei jedem Start laeuft.
   */
  member: Profil;
  …
};
```

Die `profiles`-Abfrage wählt alle sechs Spalten; das Ergebnis geht durch `zuProfil`, ohne Zeile durch `zuProfil` mit lauter `null`:

```ts
  const { data: profilRow } = await client
    .from("profiles")
    .select("display_name, sex, age_band, height_cm, training_goal, onboarding_completed_at")
    .eq("id", userId)
    .maybeSingle();
  …
  member: zuProfil(
    (profilRow as Parameters<typeof zuProfil>[0] | null) ?? {
      display_name: null, sex: null, age_band: null, height_cm: null,
      training_goal: null, onboarding_completed_at: null,
    }),
```

- [ ] **Step 7: Route und Integrationstest**

`apps/web/app/api/v1/me/profile/route.ts`: `import { updateProfile } from "@fitretro/domain";` statt `setDisplayName`; der Aufruf wird `await updateProfile(client, payload)`. Der Kommentar bleibt, ergänzt um einen Satz: *Teilobjekt — die Registrierung schickt nur den Namen, das Onboarding alles, das Profil ein Feld.*

`tests/integration/api-profil.test.ts` — die vier bestehenden Fälle bleiben; die Antwort ist jetzt das volle Profil, also `expect(await response.json()).toMatchObject({ displayName: "Lena" })` statt `toEqual`. Dazu:

```ts
describe("PUT /me/profile -- Stammdaten", () => {
  it("setzt ein Feld, ohne die anderen anzufassen", async () => {
    await profilePUT(request({ displayName: "Lena", heightCm: 168 }, bearer));
    const response = await profilePUT(request({ ageBand: "25_34" }, bearer));

    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({ displayName: "Lena", heightCm: 168, ageBand: "25_34" });
  });

  it("loescht mit null", async () => {
    await profilePUT(request({ sex: "female" }, bearer));
    const response = await profilePUT(request({ sex: null }, bearer));

    expect((await response.json()).sex).toBeNull();
  });

  it("setzt den Abschlusszeitpunkt nur ueber onboardingDone", async () => {
    const abgelehnt = await profilePUT(request({ onboardingCompletedAt: "2026-01-01T00:00:00Z" }, bearer));
    expect(abgelehnt.status).toBe(422);

    const response = await profilePUT(request({ onboardingDone: true }, bearer));
    const profil = (await response.json()) as { onboardingCompletedAt: string | null; displayName: string | null };
    expect(profil.onboardingCompletedAt).not.toBeNull();
    // Der Name aus dem vorigen Test steht noch -- der Upsert hat nur
    // die gesendete Spalte angefasst.
    expect(profil.displayName).toBe("Lena");
  });

  it("weist eine unbekannte Altersspanne ab", async () => {
    const response = await profilePUT(request({ ageBand: "30_35" }, bearer));
    expect(response.status).toBe(422);
  });
});
```

In `domain-bootstrap.test.ts`: der Fall „Mitglied ohne Zeile" prüft `member` jetzt gegen `{ displayName: null, sex: null, ageBand: null, heightCm: null, trainingGoal: null, onboardingCompletedAt: null }` (mit `toMatchObject`, damit die Felder aus Aufgabe 2/3 nicht stören); ein zweiter Fall setzt über `updateProfile` Größe und Spanne und liest sie zurück.

- [ ] **Step 8: Migration anwenden, beide Testebenen laufen lassen**

```bash
npx --no-install supabase migration list --local
npx --no-install supabase migration up --local
cd packages/domain && pnpm vitest run && cd ../..
pnpm vitest run tests/integration/api-profil.test.ts tests/integration/domain-bootstrap.test.ts
pnpm typecheck 2>&1 | tail -6
```

Erwartet: `0041` angewendet, alles grün. `typecheck` zeigt jede Stelle, die noch `setDisplayName` importiert.

- [ ] **Step 9: Commit**

```bash
git add supabase/migrations/0041_profil_stammdaten.sql packages/domain apps/web/app/api/v1/me/profile tests/integration
git commit -m "feat(profil): Stammdaten am Profil -- Geschlecht, Altersspanne, Groesse, Richtung, Onboarding-Abschluss"
```

---

### Aufgabe 2: Körpergewicht — `0042`, `measurements.ts`, zwei Routen

Ein Wert je Tag, ohne Studio, nur die eigene Zeile. `PUT` ist ein Upsert auf den Tag, `GET` liefert alle Punkte mit Kopfzeile, `DELETE` löscht einen Tag. Das Bootstrap trägt den jüngsten Wert, damit die Gewichtskarte auf Home ohne Verlaufsabruf einen Wert hat.

**Files:**
- Create: `supabase/migrations/0042_body_measurements.sql`
- Create: `packages/domain/src/measurements.ts`, `measurements.test.ts`
- Create: `apps/web/app/api/v1/me/measurements/route.ts`, `apps/web/app/api/v1/me/measurements/[measuredOn]/route.ts`
- Create: `tests/integration/rls-body-measurements.test.ts`, `tests/integration/api-measurements.test.ts`
- Modify: `packages/domain/src/bootstrap.ts`, `index.ts`

**Interfaces:**
- Produces: `messwertSchema`, `pruefeMesswert`, `zielErreicht(startKg, zielKg, neuKg): boolean`, `putMeasurement(client, payload): Promise<{ measuredOn, weightKg, goalReached: boolean }>`, `deleteMeasurement(client, measuredOn)`, `getMeasurements(client, options?): Promise<Measurements>` mit `type Measurements = { points: Messpunkt[]; summary: { first, latest, changeKg } }`; `Bootstrap.member.latestWeight`
- Consumes: `requireUserId`; in Aufgabe 3 kommt `aktiveZiele` dazu (hier noch ohne „Ziel erreicht" — `goalReached` ist bis dahin immer `false`)

- [ ] **Step 1: Die Migration**

Create `supabase/migrations/0042_body_measurements.sql`:

```sql
-- Koerpergewicht als Verlauf, Spec 2026-09-13-ziele-und-fortschritt-design.md
-- Abschnitt 3.2. Die erste Tabelle des Schemas mit Gesundheitsdaten im
-- Sinn von Art. 9 DSGVO -- und deshalb die erste mit DREI bewussten
-- Abweichungen von den Trainingstabellen:
--
--  1. KEIN studio_id. Jede Trainingstabelle seit 0012 haengt am Studio,
--     und wer austritt, verliert den Blick auf seine dortige Historie
--     (0033). Das Koerpergewicht gehoert zur Person, nicht zur Halle:
--     wer das Studio wechselt, nimmt seine Kurve mit.
--
--  2. KEINE Staff-Klausel, KEINE Mitgliedschaftspruefung -- und keine
--     Oeffnung ueber eine SECURITY-DEFINER-Funktion, auch nicht als Summe.
--     studio_overview (0034) ist die einzige Stelle, an der Personal
--     Trainingsdaten aggregiert sieht; Koerperdaten bekommen keine solche
--     Stelle. Wer das je aendert, aendert eine Entscheidung, keine
--     Kleinigkeit.
--
--  3. Ein Wert je Tag. Zwei Wiegungen am selben Tag sind keine zwei
--     Messpunkte, sondern eine Korrektur -- der Schreibweg ist ein
--     Upsert auf (user_id, measured_on). measured_on ist ein date, kein
--     Zeitpunkt: gewogen wird morgens, der Tag ist die Wahrheit, die
--     Uhrzeit Rauschen. Der Client liefert den Ortstag; der Server
--     rechnet keine Zeitzone.

create table public.body_measurements (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  measured_on date not null,
  weight_kg   numeric(5,1) not null,
  created_at  timestamptz not null default now(),
  constraint body_measurements_weight_range
    check (weight_kg between 20.0 and 400.0),
  constraint body_measurements_one_per_day
    unique (user_id, measured_on)
);

create index on public.body_measurements (user_id, measured_on desc);

alter table public.body_measurements enable row level security;
alter table public.body_measurements force  row level security;

create policy body_measurements_select_own on public.body_measurements
  for select to authenticated
  using (user_id = (select auth.uid()));

create policy body_measurements_insert_own on public.body_measurements
  for insert to authenticated
  with check (user_id = (select auth.uid()));

create policy body_measurements_update_own on public.body_measurements
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy body_measurements_delete_own on public.body_measurements
  for delete to authenticated
  using (user_id = (select auth.uid()));
```

- [ ] **Step 2: Den Unit-Test schreiben**

Create `packages/domain/src/measurements.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { pruefeMesswert, zielErreicht } from "./measurements.js";

describe("pruefeMesswert", () => {
  it("nimmt Datum und Gewicht mit einer Nachkommastelle", () => {
    expect(pruefeMesswert({ measuredOn: "2026-09-14", weightKg: 82.5 })).toEqual({
      measuredOn: "2026-09-14", weightKg: 82.5,
    });
  });

  it("rundet nicht still -- zwei Nachkommastellen sind ein Fehler", () => {
    expect(() => pruefeMesswert({ measuredOn: "2026-09-14", weightKg: 82.55 })).toThrow(/Nachkommastelle/);
  });

  it("haelt das Gewicht in 20 bis 400 kg", () => {
    expect(() => pruefeMesswert({ measuredOn: "2026-09-14", weightKg: 19.5 })).toThrow(/20/);
    expect(() => pruefeMesswert({ measuredOn: "2026-09-14", weightKg: 400.5 })).toThrow(/400/);
  });

  it("weist ein Datum in der Zukunft ab -- mit einem Tag Luft fuer die Zeitzone", () => {
    const heute = new Date("2026-09-14T12:00:00Z");
    expect(() => pruefeMesswert({ measuredOn: "2026-09-16", weightKg: 80 }, heute)).toThrow(/Zukunft/);
    expect(pruefeMesswert({ measuredOn: "2026-09-15", weightKg: 80 }, heute).measuredOn).toBe("2026-09-15");
  });

  it("weist ein Datum ausserhalb von YYYY-MM-DD ab", () => {
    expect(() => pruefeMesswert({ measuredOn: "14.09.2026", weightKg: 80 })).toThrow();
  });
});

describe("zielErreicht", () => {
  // Die Richtung ergibt sich aus dem ersten Messwert, nicht aus einem
  // eigenen Feld: lag der Start ueber dem Ziel, ist "<= Ziel" erreicht.
  it("abnehmen: erreicht, sobald der Wert das Ziel unterschreitet oder trifft", () => {
    expect(zielErreicht(82.5, 78, 78)).toBe(true);
    expect(zielErreicht(82.5, 78, 77.5)).toBe(true);
    expect(zielErreicht(82.5, 78, 78.5)).toBe(false);
  });

  it("zunehmen: erreicht, sobald der Wert das Ziel ueberschreitet oder trifft", () => {
    expect(zielErreicht(60, 65, 65)).toBe(true);
    expect(zielErreicht(60, 65, 64.5)).toBe(false);
  });

  it("Start gleich Ziel: Gleichstand zaehlt", () => {
    expect(zielErreicht(78, 78, 78)).toBe(true);
  });

  it("ohne Start nie erreicht", () => {
    expect(zielErreicht(null, 78, 78)).toBe(false);
  });
});
```

- [ ] **Step 3: Testlauf, der fehlschlagen muss**

```bash
cd packages/domain && pnpm vitest run src/measurements.test.ts
```

- [ ] **Step 4: `measurements.ts` schreiben**

```ts
import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";
import { requireUserId } from "./auth.js";
import { DomainError } from "./errors.js";

/** Drei Jahre taeglich -- mehr liest niemand auf einem Telefon. */
const MEASUREMENT_LIMIT = 1000;

const datum = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "Datum im Format YYYY-MM-DD erwartet.");

export const messwertSchema = z.object({
  measuredOn: datum,
  weightKg: z
    .number()
    .min(20, "Das Gewicht liegt zwischen 20 und 400 kg.")
    .max(400, "Das Gewicht liegt zwischen 20 und 400 kg.")
    .refine((kg) => Math.round(kg * 10) === kg * 10, "Hoechstens eine Nachkommastelle."),
});

export type MesswertEingabe = z.infer<typeof messwertSchema>;

/**
 * `jetzt` als Parameter, damit die Zukunftsgrenze pruefbar ist. Ein Tag
 * Luft: der Client liefert seinen Ortstag, der Server vergleicht in UTC
 * -- ein Mitglied in Neuseeland darf "heute" eintragen, obwohl es in UTC
 * noch gestern ist.
 */
export function pruefeMesswert(roh: unknown, jetzt: Date = new Date()): MesswertEingabe {
  const geprueft = messwertSchema.safeParse(roh);
  if (!geprueft.success) {
    throw new DomainError("validation_failed", geprueft.error.issues[0]!.message);
  }
  const spaetestens = new Date(jetzt.getTime() + 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
  if (geprueft.data.measuredOn > spaetestens) {
    throw new DomainError("validation_failed", "Das Datum liegt in der Zukunft.");
  }
  return geprueft.data;
}

/**
 * Die Richtung ergibt sich aus dem ersten Messwert: lag der Start ueber
 * dem Ziel, gilt "<= Ziel" als erreicht, sonst ">= Ziel". Kein eigenes
 * Feld "abnehmen/zunehmen" -- es waere eine zweite Wahrheit neben den
 * Zahlen.
 */
export function zielErreicht(startKg: number | null, zielKg: number, neuKg: number): boolean {
  if (startKg === null) return false;
  return startKg >= zielKg ? neuKg <= zielKg : neuKg >= zielKg;
}

export type Messpunkt = { measuredOn: string; weightKg: number };

export type Measurements = {
  points: Messpunkt[];
  summary: {
    first: Messpunkt | null;
    latest: Messpunkt | null;
    /** latest - first. Kein Trend, keine Glaettung -- eine Differenz. */
    changeKg: number | null;
  };
};

export type RecordedMeasurement = Messpunkt & {
  /** true, wenn dieser Eintrag das aktive Zielgewicht erreicht hat. */
  goalReached: boolean;
};

export async function getMeasurements(
  client: SupabaseClient,
  rawOptions: unknown = {},
): Promise<Measurements> {
  const optionen = z.object({ since: datum.optional() }).safeParse(rawOptions);
  if (!optionen.success) {
    throw new DomainError("validation_failed", optionen.error.issues[0]!.message);
  }
  const userId = await requireUserId(client);

  let query = client
    .from("body_measurements")
    .select("measured_on, weight_kg")
    .eq("user_id", userId)
    .order("measured_on", { ascending: true })
    .limit(MEASUREMENT_LIMIT);
  if (optionen.data.since) query = query.gte("measured_on", optionen.data.since);

  const { data, error } = await query;
  if (error) throw new DomainError("internal", "Der Gewichtsverlauf konnte nicht gelesen werden.");

  const points = ((data ?? []) as Array<{ measured_on: string; weight_kg: number | string }>).map(
    (row) => ({ measuredOn: row.measured_on, weightKg: Number(row.weight_kg) }),
  );
  const first = points[0] ?? null;
  const latest = points[points.length - 1] ?? null;
  return {
    points,
    summary: {
      first,
      latest,
      changeKg: first && latest ? Number((latest.weightKg - first.weightKg).toFixed(1)) : null,
    },
  };
}

/**
 * Ein Wert je Tag: der Upsert ersetzt, statt eine zweite Zeile anzulegen.
 *
 * "Ziel erreicht" wird HIER geprueft, beim Schreiben, nicht beim Lesen --
 * der Moment gehoert zu dem Eintrag, der ihn ausloest. Die Zielpruefung
 * kommt in Aufgabe 3 dazu; bis dahin ist goalReached immer false.
 */
export async function putMeasurement(
  client: SupabaseClient,
  payload: unknown,
): Promise<RecordedMeasurement> {
  const eingabe = pruefeMesswert(payload);
  const userId = await requireUserId(client);

  const { error } = await client
    .from("body_measurements")
    .upsert(
      { user_id: userId, measured_on: eingabe.measuredOn, weight_kg: eingabe.weightKg },
      { onConflict: "user_id,measured_on" },
    );
  if (error) throw new DomainError("internal", "Das Gewicht konnte nicht gespeichert werden.");

  return { ...eingabe, goalReached: false };
}

export async function deleteMeasurement(client: SupabaseClient, measuredOnRoh: unknown): Promise<void> {
  const geprueft = datum.safeParse(measuredOnRoh);
  if (!geprueft.success) throw new DomainError("validation_failed", geprueft.error.issues[0]!.message);
  const userId = await requireUserId(client);

  const { error } = await client
    .from("body_measurements")
    .delete()
    .eq("user_id", userId)
    .eq("measured_on", geprueft.data);
  if (error) throw new DomainError("internal", "Der Eintrag konnte nicht geloescht werden.");
  // Ein Tag ohne Eintrag ist nach dem Loeschen genau das -- kein 404.
}
```

`index.ts`: `export { messwertSchema, pruefeMesswert, zielErreicht, getMeasurements, putMeasurement, deleteMeasurement } from "./measurements.js"; export type { Measurements, Messpunkt, RecordedMeasurement } from "./measurements.js";`

- [ ] **Step 5: Testlauf, der bestehen muss**

- [ ] **Step 6: Bootstrap trägt den jüngsten Wert**

In `bootstrap.ts`: `member: Profil & { latestWeight: Messpunkt | null }` (die Ziele folgen in Aufgabe 3). Eine Abfrage `from("body_measurements").select("measured_on, weight_kg").eq("user_id", userId).order("measured_on", { ascending: false }).limit(1).maybeSingle()`.

- [ ] **Step 7: Die Routen**

`apps/web/app/api/v1/me/measurements/route.ts` — `GET` mit `?since=` (Muster: `me/progress/route.ts`) und `PUT` (Muster: `me/profile/route.ts`, Status 200). `apps/web/app/api/v1/me/measurements/[measuredOn]/route.ts` — `DELETE`, antwortet `204`:

```ts
export async function DELETE(
  request: Request,
  { params }: { params: Promise<{ measuredOn: string }> },
): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) return errorResponse("unauthorized", "Anmeldung erforderlich.");
  try {
    await deleteMeasurement(client, (await params).measuredOn);
    return new Response(null, { status: 204 });
  } catch (error) {
    return fromDomainError(error);
  }
}
```

(Die Signatur mit `params: Promise<…>` entspricht Next 15 — siehe `apps/web/app/api/v1/workout-sessions/[sessionId]/sets/[setId]/route.ts`.)

- [ ] **Step 8: Die Integrationstests**

`tests/integration/rls-body-measurements.test.ts` — Aufbau wie `rls-member-machine-calibrations.test.ts` (Studio A mit Mitglied A, Mitglied A2 und Trainer A; Studio B mit Mitglied B), dann:

- Mitglied A legt eine Zeile an und liest sie
- Mitglied A2 (**gleiches Studio**) sieht sie nicht — `select` liefert leer
- **Trainer A sieht sie nicht** — das ist der Kern dieses Bauabschnitts; der Test trägt den Kommentar aus der Migration
- Mitglied B sieht sie nicht
- Mitglied A kann keine Zeile mit fremder `user_id` anlegen (`insert` scheitert)
- ein zweiter Insert am selben Tag scheitert an `body_measurements_one_per_day`; ein Upsert ersetzt
- 19,5 kg und 400,5 kg scheitern am Check
- **Austritt:** Mitgliedschaft von A löschen (`service`-Client), A liest weiterhin seine Zeile — es gibt kein Studio, das mitreden könnte
- `anonClient()` liest nichts

`tests/integration/api-measurements.test.ts` — über die Route-Handler:

- `PUT` legt an, antwortet 200 mit `{ measuredOn, weightKg, goalReached: false }`
- `PUT` am selben Tag ersetzt; `GET` zeigt einen Punkt
- `GET` liefert aufsteigend, `summary.first/latest/changeKg` stimmen (drei Punkte, `changeKg` = `-2`)
- `GET ?since=` schneidet ab
- `DELETE` entfernt den Tag, ein zweites `DELETE` antwortet ebenfalls 204
- `PUT` mit Datum in zwei Tagen → 422; ohne Bearer → 401
- Bootstrap: `member.latestWeight` ist `null` ohne Eintrag und der jüngste Punkt danach

- [ ] **Step 9: Migration anwenden, Tests, Typecheck**

```bash
npx --no-install supabase migration up --local
cd packages/domain && pnpm vitest run && cd ../..
pnpm vitest run tests/integration/rls-body-measurements.test.ts tests/integration/api-measurements.test.ts tests/integration/domain-bootstrap.test.ts
pnpm typecheck 2>&1 | tail -6
```

- [ ] **Step 10: Commit**

```bash
git commit -am "feat(gewicht): Koerpergewicht als Verlauf -- ein Wert je Tag, nur die eigene Zeile, kein Studio"
```

---

### Aufgabe 3: Ziele — `0043`, `goals.ts`, zwei Routen, `weeklyTarget`, „Ziel erreicht"

Ziele mit Anfang und Ende. Genau ein aktives je Sorte, erzwungen vom Index; `set_member_goal` schließt das alte ab und legt das neue an, in einer Transaktion unter RLS (kein `security definer` — die Policies reichen). `PUT /me/measurements` prüft danach das Zielgewicht. `/me/sessions` trägt das Wochenziel in `streak`.

**Files:**
- Create: `supabase/migrations/0043_member_goals.sql`
- Create: `packages/domain/src/goals.ts`, `goals.test.ts`
- Create: `apps/web/app/api/v1/me/goals/route.ts`, `apps/web/app/api/v1/me/goals/[kind]/route.ts`
- Create: `tests/integration/rls-member-goals.test.ts`, `tests/integration/api-goals.test.ts`
- Modify: `packages/domain/src/measurements.ts`, `sessions.ts`, `bootstrap.ts`, `index.ts`
- Modify: `tests/integration/api-measurements.test.ts`, `domain-sessions.test.ts`

**Interfaces:**
- Produces: `zielSchema`, `pruefeZiel`, `setGoal(client, payload): Promise<Ziel>`, `dropGoal(client, kind)`, `aktiveZiele(client, userId): Promise<AktiveZiele>` mit `type Ziel = { id, kind, targetValue, createdAt }`, `type AktiveZiele = { weeklyDays: Ziel | null; targetWeight: Ziel | null }`; `Serienstand.weeklyTarget: number | null`; `Bootstrap.member.goals: AktiveZiele`; `RecordedMeasurement.goalReached` wird wahr
- Consumes: `zielErreicht`, `requireUserId`

- [ ] **Step 1: Die Migration**

Create `supabase/migrations/0043_member_goals.sql`:

```sql
-- Ziele mit Geschichte, Spec Abschnitt 3.3.
--
-- Eine Tabelle statt zweier Spalten an profiles: ein Ziel hat einen
-- Anfang und ein Ende. "Zielgewicht 78 kg -- erreicht am 3. November" ist
-- der Moment, fuer den das Feature gebaut wird; zwei Spalten koennten ihn
-- nicht festhalten. Wer sein Wochenziel von 2 auf 3 hebt, schliesst das
-- alte ab, statt es zu verlieren.
--
-- Genau ein aktives Ziel je Sorte, erzwungen vom Teilindex -- nicht von
-- der Fachschicht. set_member_goal wechselt altes und neues in EINER
-- Transaktion, sonst gaebe es zwischen zwei Statements einen Augenblick
-- mit zwei aktiven oder keinem.
--
-- Wie body_measurements (0042): kein studio_id, keine Staff-Klausel, keine
-- Aggregatfunktion. Keine Delete-Policy: ein Ziel wird aufgegeben
-- ('dropped'), nicht geloescht -- die Geschichte bleibt beim Mitglied bis
-- zur M3-Loeschung. exercise_id ist fuer die vierte Sorte vorgesehen
-- (Uebungsziele, Runde 2) und in dieser Runde immer null.
--
-- Die Serie (serienstand in sessions.ts) haengt NICHT an weekly_days.
-- Sie zaehlt weiter Wochen mit mindestens einer Einheit; das Wochenziel
-- ist eine eigene Aussage daneben (Spec Abschnitt 9, Punkt 5).

create type public.goal_kind   as enum ('weekly_days', 'target_weight');
create type public.goal_status as enum ('active', 'reached', 'dropped');

-- IMMUTABLE und ohne Tabellenzugriff -- nur so darf sie in einem CHECK
-- stehen. search_path leer wie in 0040: der Rumpf braucht nichts aus
-- public.
create or replace function public.is_valid_goal_value(p_kind public.goal_kind, p_value numeric)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select case p_kind
    when 'weekly_days'   then p_value = floor(p_value) and p_value between 1 and 7
    when 'target_weight' then p_value = round(p_value, 1) and p_value between 20 and 400
    else false
  end
$$;

create table public.member_goals (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  kind         public.goal_kind not null,
  target_value numeric(6,1) not null,
  exercise_id  uuid references public.exercises (id) on delete set null,
  status       public.goal_status not null default 'active',
  created_at   timestamptz not null default now(),
  reached_at   timestamptz,
  constraint member_goals_value_valid
    check (public.is_valid_goal_value(kind, target_value)),
  constraint member_goals_reached_at_only_when_reached
    check ((status = 'reached') = (reached_at is not null))
);

create unique index member_goals_one_active_per_kind
  on public.member_goals (user_id, kind)
  where status = 'active';

create index on public.member_goals (user_id, created_at desc);

alter table public.member_goals enable row level security;
alter table public.member_goals force  row level security;

create policy member_goals_select_own on public.member_goals
  for select to authenticated
  using (user_id = (select auth.uid()));

create policy member_goals_insert_own on public.member_goals
  for insert to authenticated
  with check (user_id = (select auth.uid()));

create policy member_goals_update_own on public.member_goals
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- SECURITY INVOKER, ausdruecklich: die Policies oben reichen, die
-- Funktion umgeht keine. Sie buendelt nur zwei Schreibvorgaenge in eine
-- Transaktion.
create or replace function public.set_member_goal(
  p_kind  public.goal_kind,
  p_value numeric
)
returns public.member_goals
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_neu  public.member_goals;
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;

  update public.member_goals
     set status = 'dropped'
   where user_id = v_user and kind = p_kind and status = 'active';

  insert into public.member_goals (user_id, kind, target_value)
  values (v_user, p_kind, p_value)
  returning * into v_neu;

  return v_neu;
end;
$$;

revoke all on function public.set_member_goal(public.goal_kind, numeric) from public;
grant execute on function public.set_member_goal(public.goal_kind, numeric) to authenticated;
```

- [ ] **Step 2: Unit-Test für die Eingabeprüfung**

Create `packages/domain/src/goals.test.ts`: `pruefeZiel` nimmt `{ kind: "weekly_days", targetValue: 3 }` und `{ kind: "target_weight", targetValue: 78 }`; weist `weekly_days` mit 0, 8 und 2.5 ab, `target_weight` mit 19.5, 400.5 und 78.25, und eine unbekannte Sorte.

- [ ] **Step 3: Testlauf, der fehlschlagen muss**

- [ ] **Step 4: `goals.ts` schreiben**

```ts
export const GOAL_KINDS = ["weekly_days", "target_weight"] as const;
export type GoalKind = (typeof GOAL_KINDS)[number];

export const zielSchema = z.discriminatedUnion("kind", [
  z.object({
    kind: z.literal("weekly_days"),
    targetValue: z.number().int("Tage sind ganze Zahlen.").min(1, "Zwischen 1 und 7 Tagen.").max(7, "Zwischen 1 und 7 Tagen."),
  }),
  z.object({
    kind: z.literal("target_weight"),
    targetValue: z
      .number()
      .min(20, "Das Zielgewicht liegt zwischen 20 und 400 kg.")
      .max(400, "Das Zielgewicht liegt zwischen 20 und 400 kg.")
      .refine((kg) => Math.round(kg * 10) === kg * 10, "Hoechstens eine Nachkommastelle."),
  }),
]);

export type Ziel = { id: string; kind: GoalKind; targetValue: number; createdAt: string };
export type AktiveZiele = { weeklyDays: Ziel | null; targetWeight: Ziel | null };

export function pruefeZiel(roh: unknown): z.infer<typeof zielSchema> { … }

/** Ersetzt das aktive Ziel derselben Sorte -- eine Transaktion in der Datenbank. */
export async function setGoal(client: SupabaseClient, payload: unknown): Promise<Ziel> {
  const eingabe = pruefeZiel(payload);
  await requireUserId(client);
  const { data, error } = await client.rpc("set_member_goal", {
    p_kind: eingabe.kind, p_value: eingabe.targetValue,
  });
  if (error || !data) throw new DomainError("internal", "Das Ziel konnte nicht gespeichert werden.");
  return zuZiel(data);
}

/** Aufgeben, nicht loeschen. Kein aktives Ziel ist kein Fehler. */
export async function dropGoal(client: SupabaseClient, kindRoh: unknown): Promise<void> {
  const kind = z.enum(GOAL_KINDS).safeParse(kindRoh);
  if (!kind.success) throw new DomainError("validation_failed", "Keine bekannte Zielsorte.");
  const userId = await requireUserId(client);
  const { error } = await client
    .from("member_goals")
    .update({ status: "dropped" })
    .eq("user_id", userId).eq("kind", kind.data).eq("status", "active");
  if (error) throw new DomainError("internal", "Das Ziel konnte nicht aufgegeben werden.");
}

/** Die aktiven Ziele -- fuer Bootstrap, /me/sessions und die Zielpruefung. */
export async function aktiveZiele(client: SupabaseClient, userId: string): Promise<AktiveZiele> { … }

export async function markiereErreicht(client: SupabaseClient, zielId: string): Promise<void> {
  const { error } = await client
    .from("member_goals")
    .update({ status: "reached", reached_at: new Date().toISOString() })
    .eq("id", zielId).eq("status", "active");
  if (error) throw new DomainError("internal", "Das Ziel konnte nicht abgeschlossen werden.");
}
```

`zuZiel` bildet `target_value` über `Number(…)` ab (numeric kommt als String).

- [ ] **Step 5: „Ziel erreicht" in `putMeasurement`**

Nach dem Upsert:

```ts
  const ziele = await aktiveZiele(client, userId);
  let goalReached = false;
  if (ziele.targetWeight) {
    const { data: erster } = await client
      .from("body_measurements")
      .select("weight_kg")
      .eq("user_id", userId)
      .order("measured_on", { ascending: true })
      .limit(1)
      .maybeSingle();
    const startKg = erster ? Number((erster as { weight_kg: number | string }).weight_kg) : null;
    if (zielErreicht(startKg, ziele.targetWeight.targetValue, eingabe.weightKg)) {
      await markiereErreicht(client, ziele.targetWeight.id);
      goalReached = true;
    }
  }
  return { ...eingabe, goalReached };
```

**Bekannt und akzeptiert:** Upsert und Markierung sind zwei Statements, keine Transaktion. Scheitert die Markierung, steht der Messwert, und der nächste Eintrag unter der Marke markiert nach. Ein RPC dafür wäre eine dritte Funktion für einen Fall, der nur bei einem Netzabbruch zwischen zwei Millisekunden entsteht — im Kommentar festhalten.

- [ ] **Step 6: `weeklyTarget` in `sessions.ts`**

`Serienstand` bekommt `weeklyTarget: number | null`; `serienstand(...)` selbst bleibt **unverändert** (Signatur und Rechnung). In `getSessions`, wo `streak` gebaut wird:

```ts
    streak: zeitzone
      ? {
          ...serienstand(await startsFuerDieSerie(client, userId, sessions), new Date(), zeitzone),
          // Das Ziel liegt neben der Serie, nicht in ihr: die Zeile
          // "2 von 3 Tagen" braucht trainedDays und das Ziel aus
          // DEMSELBEN Abruf, sonst zeigt ein alter Cache das eine gegen
          // das andere. Die Serie rechnet davon nichts.
          weeklyTarget: (await aktiveZiele(client, userId)).weeklyDays?.targetValue ?? null,
        }
      : null,
```

Im bestehenden `sessions.test.ts` einen Fall ergänzen, der die Unabhängigkeit festnagelt — er ruft `serienstand` mit einer Woche von zwei Tagen auf und prüft `weeks`, ohne dass es ein Ziel-Argument gäbe (der Test dokumentiert, dass es keins gibt). Und `domain-sessions.test.ts`: mit gesetztem Wochenziel 3 und einer Woche mit 2 Einheiten ist `streak.weeks` unverändert und `streak.weeklyTarget === 3`; ohne Ziel `null`.

- [ ] **Step 7: Bootstrap trägt die aktiven Ziele**

`member.goals = await aktiveZiele(client, userId)`; `Bootstrap["member"]` ist jetzt `Profil & { goals: AktiveZiele; latestWeight: Messpunkt | null }`.

- [ ] **Step 8: Die Routen**

`me/goals/route.ts`: `PUT` → `setGoal`, 200. `me/goals/[kind]/route.ts`: `DELETE` → `dropGoal`, 204.

- [ ] **Step 9: Integrationstests**

`rls-member-goals.test.ts`: eigene Zeile lesbar, fremde nicht, Trainer sieht nichts; zweiter direkter Insert derselben aktiven Sorte scheitert am Index; `set_member_goal` per `rpc` legt an, ein zweiter Aufruf setzt das erste auf `dropped` und legt ein neues an; `is_valid_goal_value` weist 8 Tage und 78,25 kg ab; `delete` scheitert (keine Policy); `anonClient` bekommt vom RPC einen Fehler.

`api-goals.test.ts`: `PUT` legt an; `PUT` ersetzt (Bootstrap zeigt das neue); `DELETE` gibt auf (Bootstrap zeigt `null`); `DELETE` ohne aktives Ziel → 204; unbekannte Sorte → 422; `/me/sessions?studio=` trägt `streak.weeklyTarget` und `streak.weeks` bleibt gleich, ob Ziel oder nicht.

`api-measurements.test.ts` ergänzen: Ziel 78 setzen, Start 82,5, Eintrag 78,0 → `goalReached: true`, Bootstrap zeigt `goals.targetWeight === null` (es ist `reached`); Eintrag 78,5 davor → `false`; Zunehm-Richtung einmal gegenprüfen.

- [ ] **Step 10: Migration anwenden, alle Tests, Typecheck**

```bash
npx --no-install supabase migration up --local
cd packages/domain && pnpm vitest run && cd ../..
pnpm vitest run
pnpm typecheck 2>&1 | tail -6
```

Der volle Integrationslauf, nicht nur die neuen Dateien: `Serienstand` hat ein Feld dazubekommen, und jeder Test mit fester Antwortform zeigt das jetzt.

- [ ] **Step 11: Commit**

```bash
git commit -am "feat(ziele): Ziele mit Geschichte -- Wochenziel neben der Serie, Zielgewicht beim Eintrag geprueft"
```

---

### Aufgabe 4: Die Datenschutz-Zusicherung

Zwei Tests, die nichts Neues bauen, aber die Grenze in Code gießen — so wie `0033` und `studio_overview` es für Trainingsdaten getan haben.

**Files:**
- Modify: `tests/integration/studio-ueberblick.test.ts`
- Modify: `tests/integration/rls-body-measurements.test.ts` (falls in Aufgabe 2 nicht schon enthalten)

- [ ] **Step 1: `studio_overview` trägt keinen Körperdaten-Schlüssel**

In `studio-ueberblick.test.ts` einen Fall ergänzen: ein Mitglied des Studios hat drei Messwerte und zwei Ziele; der Trainer ruft `studio_overview` — der Rückgabewert hat **keinen** Schlüssel, dessen Name `weight`, `measurement`, `goal`, `sex`, `age`, `height` enthält (rekursiv über das JSON). Der Kommentar nennt Spec Abschnitt 6: *Körperdaten bekommen keine Öffnung, auch nicht als Summe.*

- [ ] **Step 2: Der Trainer-Negativtest steht**

Prüfen, dass `rls-body-measurements.test.ts` und `rls-member-goals.test.ts` je einen Fall „Trainer des eigenen Studios liest die leere Menge" enthalten — mit dem Kommentar aus der Migration. Falls in Aufgabe 2/3 vergessen: jetzt.

- [ ] **Step 3: Lauf und Commit**

```bash
pnpm vitest run tests/integration/studio-ueberblick.test.ts tests/integration/rls-body-measurements.test.ts tests/integration/rls-member-goals.test.ts
git commit -am "test(datenschutz): Koerperdaten bleiben vor Personal und vor dem Ueberblick verborgen"
```

---

### Aufgabe 5: iOS — DTOs, `APIClient`, Messwerte im `VerlaufStore`

Die Netzschicht für alles Weitere. Der `VerlaufStore` trägt die Messwerte mit — sie ändern sich, wie der Verlauf, nur durch eigenes Tun, und `VerlaufHerkunft` gilt unverändert.

**Files:**
- Create: `FitnessMember/Networking/DTOs/Messwert.swift`, `Ziel.swift`, `ProfilWrite.swift`
- Create: `FitnessMember/Profil/Stammdaten.swift`
- Modify: `FitnessMember/Networking/DTOs/BootstrapResponse.swift`, `SessionSummary.swift`, `APIClient.swift`
- Modify: `FitnessMember/Verlauf/VerlaufStore.swift`, `VerlaufFileStore.swift`
- Modify: `FitnessMemberTests/DTOTests.swift`, `VerlaufStoreTests.swift`; Create: `StammdatenTests.swift`

**Interfaces:**
- Produces: `BootstrapResponse.Member` mit `sex, ageBand, heightCm, trainingGoal, onboardingCompletedAt: String?`, `goals: Ziele`, `latestWeight: Messwert?`; `Serienstand.weeklyTarget: Int?`; `Messwert { measuredOn, weightKg }`, `MeasurementsResponse { points, summary }`, `MesswertAntwort { measuredOn, weightKg, goalReached }`; `Ziel { id, kind, targetValue, createdAt }`; `ProfilWrite` mit `enum Feld<T: Encodable>: Encodable { case setzen(T), loeschen }` und Feldern `displayName, sex, ageBand, heightCm, trainingGoal: Feld<…>?`, `onboardingDone: Bool?`; `Geschlecht`, `Altersspanne`, `Trainingsrichtung` als `String`-Enums mit `wort` (deutsch) und `alle`; `APIClient.updateProfile(_:) -> BootstrapResponse.Member`, `measurements() -> MeasurementsResponse`, `putMeasurement(_:) -> MesswertAntwort`, `deleteMeasurement(measuredOn:)`, `setGoal(_:) -> Ziel`, `dropGoal(kind:)`; `VerlaufStore.messwerte: [Messwert]`, `messwertKopf: MeasurementsResponse.Summary?`; `VerlaufLoading.measurements()`
- Consumes: nichts Neues

- [ ] **Step 1: Die DTO-Tests schreiben**

In `DTOTests.swift`: der Bootstrap-Test bekommt das neue `member`-JSON (alle Felder gesetzt) und prüft `ageBand == "25_34"`, `goals.weeklyDays?.targetValue == 3`, `latestWeight?.weightKg == 82.5`; ein zweiter Fall dekodiert `member` mit lauter `null` und `goals: {"weeklyDays": null, "targetWeight": null}`. Ein Fall dekodiert `Serienstand` **ohne** `weeklyTarget` (alter Cache) — das Feld ist optional. Ein Fall kodiert `ProfilWrite(heightCm: .loeschen, ageBand: .setzen("25_34"))` und prüft, dass das JSON `"heightCm":null` und `"ageBand":"25_34"` enthält und **kein** `displayName`.

`StammdatenTests.swift`: `Altersspanne(rawValue: "25_34")?.wort == "25–34"`, `Altersspanne.alle.count == 7`, `Geschlecht.alle.count == 3`, `Trainingsrichtung(rawValue: "lose_weight")?.wort == "Abnehmen"`; ein unbekannter Serverwert ergibt `nil` und wird im Profil als „—" gezeigt, nicht als Absturz.

- [ ] **Step 2: Testlauf, der fehlschlagen muss**

```bash
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" -derivedDataPath /tmp/dd-ziele-5 test -only-testing:FitnessMemberTests/DTOTests 2>&1 | grep -E "error:|TEST"
```

- [ ] **Step 3: DTOs und Stammdaten schreiben**

`ProfilWrite.encode(to:)` schreibt je Feld: `nil` → Schlüssel weglassen, `.loeschen` → `encodeNil`, `.setzen(x)` → `encode(x)`. Das ist der Grund für den eigenen Typ: `Encodable` allein lässt `nil` und „nicht gesendet" nicht unterscheiden, und genau dieser Unterschied ist der Vertrag von `PUT /me/profile`.

`Stammdaten.swift`:

```swift
/// Die Enum-Werte des Servers und ihre deutschen Woerter -- an EINER
/// Stelle, damit Onboarding und Profil nicht zwei Listen pflegen.
enum Altersspanne: String, CaseIterable {
    case bis17 = "under_18", bis24 = "18_24", bis34 = "25_34", bis44 = "35_44",
         bis54 = "45_54", bis64 = "55_64", ab65 = "65_plus"
    var wort: String { … "bis 17", "18–24", … "65+" }
}
```

Analog `Geschlecht` (Weiblich · Männlich · Divers) und `Trainingsrichtung` (Abnehmen · Muskeln aufbauen · Fit bleiben · Stärker werden, je mit `zeile` für die Kachel: „Gewicht runter, Kraft halten" usw.).

- [ ] **Step 4: `APIClient`**

Sechs Methoden nach dem Muster der bestehenden; `deleteMeasurement` und `dropGoal` über `executeNoContent`. `setDisplayName` bleibt als Bequemlichkeit für die Registrierung: `updateProfile(ProfilWrite(displayName: .setzen(name)))`.

- [ ] **Step 5: `VerlaufStore` trägt die Messwerte**

`VerlaufLoading` bekommt `func measurements() async throws(APIError) -> MeasurementsResponse`. `laden(studioId:)` ruft ihn als dritten Abruf; `GespeicherterVerlauf` bekommt `messwerte: [Messwert]?` und `messwertKopf: MeasurementsResponse.Summary?` — **optional**, damit ein Cache von vor dieser Fassung weiter dekodiert. `reset()` leert beide. Dazu `func messwertEintragen(_ antwort: MesswertAntwort)` und `func messwertEntfernen(measuredOn:)`, die den lokalen Stand sofort nachziehen und den Cache schreiben — die Karte auf Home soll nach „Eintragen" nicht auf den nächsten Abruf warten.

`VerlaufStoreTests`: `FakeLoader.measurements()`; ein Fall lädt drei Messwerte und liest `messwertKopf.changeKg`; ein Fall dekodiert einen alten Cache ohne Messwerte; ein Fall `messwertEintragen` ersetzt den Punkt desselben Tages statt einen zweiten anzuhängen und sortiert aufsteigend.

- [ ] **Step 6: Testlauf und Kaltbau**

```bash
xcodebuild … -derivedDataPath /tmp/dd-ziele-5 test 2>&1 | grep -E "warning:|error:|TEST SUCCEEDED|TEST FAILED"
rm -rf /tmp/dd-ziele-5
```

- [ ] **Step 7: Commit**

```bash
git commit -am "feat(ios): DTOs und Client fuer Stammdaten, Messwerte und Ziele; Messwerte im Verlauf-Cache"
```

---

### Aufgabe 6: iOS — das Gate und die reinen Onboarding-Ableitungen

Alles, was am Onboarding ohne UI prüfbar ist: wann es erscheint, welche Schritte es gibt, in welcher Reihenfolge geschrieben wird und was bei einem Fehler wiederholt wird.

**Files:**
- Modify: `FitnessMember/Navigation/RootDestination.swift`, `RootView.swift`
- Create: `FitnessMember/Onboarding/OnboardingAntworten.swift`, `OnboardingSchreiber.swift`
- Modify: `FitnessMemberTests/RootDestinationTests.swift`; Create: `OnboardingAntwortenTests.swift`, `OnboardingSchreiberTests.swift`

**Interfaces:**
- Produces: `RootDestination.onboarding`; `RootDestinationLogic.destination(session:catalogState:onboardingOffen:)`; `struct OnboardingAntworten { geschlecht, altersspanne, groesseCm, gewichtKg, richtung, tageProWoche (Vorgabe 3), zielgewichtKg }`, `OnboardingAntworten.schritte -> [OnboardingSchritt]` (fünf, oder vier ohne Gewicht), `istLeer`; `protocol ProfilSchreibend { updateProfile, putMeasurement, setGoal }` (Ausschnitt aus `APIClient`), `OnboardingSchreiber.schreiben(_:mit:) async -> OnboardingErgebnis` mit `enum OnboardingErgebnis { case fertig; case teilweise(offen: [OnboardingSchritt], fehler: APIError) }`
- Consumes: `ProfilWrite`, `MesswertWrite`, `ZielWrite`

- [ ] **Step 1: Die Tests schreiben**

`RootDestinationTests`: `onboarding` bei Session + `.loaded(hasStudio: false)` + `onboardingOffen: true` — **vor** `noStudio`; ebenso bei `hasStudio: true` vor `main`; nie bei `.loading`, `.failed` oder ohne Session; `false` ergibt das bisherige Verhalten (alle fünf bestehenden Fälle bekommen `onboardingOffen: false`).

`OnboardingAntwortenTests`: ohne Gewicht fehlt Schritt 5; „Später" auf Schritt 2 lässt Schritt 1 stehen (Antworten sind ein Wertetyp, „Später" ist kein Reset); `istLeer` nur, wenn nichts gesetzt und `tageProWoche` auf der Vorgabe steht — **eine unveränderte Vorgabe ist keine Antwort** (sonst schriebe „fünfmal Später" ein Wochenziel).

`OnboardingSchreiberTests` mit einer Attrappe, die je Aufruf einen Fehler setzen kann:
- volle Antworten → Reihenfolge `updateProfile` (mit `onboardingDone: true`), `putMeasurement`, `setGoal(weekly_days)`, `setGoal(target_weight)` — genau diese, genau so
- leere Antworten → nur `updateProfile(onboardingDone: true)`, nichts sonst
- `putMeasurement` scheitert → Ergebnis `teilweise(offen: [.koerper, .zielgewicht, .wieOft])`, das Profil wurde geschrieben; ein zweiter Aufruf mit demselben Ergebnis wiederholt **nur** das Offene und schickt kein zweites `onboardingDone`
- `updateProfile` scheitert → nichts weiter wird versucht, `offen` enthält alles

- [ ] **Step 2: Testlauf, der fehlschlagen muss**

- [ ] **Step 3: Das Gate**

```swift
enum RootDestination: Equatable {
    case authFlow, loadingCatalog, onboarding, noStudio, main
}

/// `onboarding` VOR `noStudio`: die Angaben gehoeren zur Person, nicht
/// zum Studio, und wer noch keinem beigetreten ist, soll nicht zwei
/// Einstiege hintereinander sehen. Nur bei .loaded -- ein gescheiterter
/// Bootstrap weiss nicht, ob das Onboarding offen ist, und darf es nicht
/// raten.
static func destination(session: Session?, catalogState: CatalogLoadState, onboardingOffen: Bool) -> RootDestination {
    guard session != nil else { return .authFlow }
    switch catalogState {
    case .idle, .loading: return .loadingCatalog
    case .loaded(let hasStudio):
        if onboardingOffen { return .onboarding }
        return hasStudio ? .main : .noStudio
    case .failed: return .noStudio
    }
}
```

`RootView` liest `catalogStore.bootstrap?.member.onboardingCompletedAt == nil` und zeigt für `.onboarding` den `OnboardingFlow` (Aufgabe 7) — bis dahin ein `PlaceholderView`, damit der Bau grün bleibt. Nach dem Abschluss ruft der Flow `catalogStore.load()`; der neue Bootstrap trägt den Zeitpunkt, das Gate schließt sich von selbst.

- [ ] **Step 4: Antworten und Schreiber**

`OnboardingSchreiber` ist eine `enum` mit einer statischen Funktion, kein Store: er hält keinen Zustand, er ordnet. Die Reihenfolge und ihr Grund stehen im Kommentar: *Profil zuerst, weil `onboardingDone` das Gate schließt — scheitern die Ziele danach, öffnet sich das Gate nicht mehr, aber Home zeigt die Nachholkarte, und die trägt dieselben Antworten.*

- [ ] **Step 5: Testlauf, Kaltbau, Commit**

```bash
git commit -am "feat(ios): Onboarding-Gate vor dem Studiobeitritt, Antworten und Schreibreihenfolge als reine Ableitungen"
```

---

### Aufgabe 7: iOS — `OnboardingFlow`, fünf Screens, ein Schreibweg

Die Artboards `Onboarding1`–`5`. Ein `NavigationStack` mit Schrittzeile, „Später" auf jedem Screen, Hauptaktion 64 pt unten, Seitenrand 28. Derselbe Flow läuft als Wurzel (Gate) und als Sheet (Nachholkarte auf Home).

**Files:**
- Create: `FitnessMember/Onboarding/OnboardingFlow.swift`, `OnboardingSchritte.swift`, `Zielkachel.swift`
- Modify: `FitnessMember/Navigation/RootView.swift`

- [ ] **Step 1: Der Flow**

`OnboardingFlow(apiClient:, alsSheet: Bool, beiFertig: () -> Void)`. `@State antworten = OnboardingAntworten()`, `@State schritt = 0`, `@State ergebnis: OnboardingErgebnis?`. Die Schrittzeile: `Text("SCHRITT \(n) VON \(antworten.schritte.count)")` als `label`, fünf 4-pt-Segmente, „Später" als `Button` 44 pt hoch rechts. „Später" auf jedem Schritt ruft `abschliessen()` mit den bis dahin gesetzten Antworten — **nicht** mit leeren: wer Schritt 1 und 2 ausgefüllt hat und auf 3 „Später" tippt, behält beides (Test aus Aufgabe 6).

`abschliessen()`: `ergebnis = await OnboardingSchreiber.schreiben(antworten, mit: apiClient)`; bei `.fertig` → `await catalogStore.load()`, `beiFertig()`; bei `.teilweise` → `InlineBanner(tone: .danger, …)` mit dem Satz, was fehlt und was gilt („Dein Profil ist gespeichert. Gewicht und Ziele nicht — keine Verbindung."), und `PrimaryButton("Erneut versuchen")` wiederholt nur das Offene. Offline zuerst abfangen wie in `ProfilRootView`.

- [ ] **Step 2: Die fünf Schritte**

| Schritt | Bausteine | Vorgabe |
| --- | --- | --- |
| Über dich | zwei Chip-Gitter (3 und 4 Spalten) aus `Geschlecht.alle`, `Altersspanne.alle`; Chip 44 pt, Pille, gewählt = 1,5-pt-Akzentstrich, Fläche `surface`, Text `text`; ein zweiter Tipp wählt ab | nichts |
| Dein Körper | Größe als Stepper-Zeile (Minus 58×58, Wert, Plus; 100–250, Schritt 1) — **nicht** `Stepper44`, das an `SettingDefinition` hängt; Gewicht per `RastRad` mit `werte: stride(from: 20, through: 400, by: 0.5)`, `basisGroesse: 64`, `text: Zahlformat.gewicht`, `voWert: Zahlformat.gewichtGesprochen`; erst leer, Rad startet bei 75,0, sobald angetippt | leer |
| Dein Ziel | 2×2 `Zielkachel` aus `Trainingsrichtung.alle`: Symbol (SF: `arrow.down.right`, `dumbbell`, `waveform.path.ecg`, `arrow.up.right`), Titel, Zeile; gewählt = Akzentstrich, Symbol `text` statt `textMuted` | nichts |
| Wie oft? | Zahl 96 pt `.black` tabellarisch, `label` „TAGE PRO WOCHE", zwei Knöpfe 58 pt (Minus/Plus), 1–7, Knopf am Anschlag deaktiviert **mit** `disabledHint` | 3 |
| Zielgewicht | nur mit Gewicht; `RastRad` startet beim eingegebenen Gewicht; Kontextzeile „noch 4,5 kg · Schritt 0,5 kg" aus `abs(gewicht - ziel)`; Hauptaktion „Los geht's" | leer |

Jeder Screen trägt seine Fußnote aus dem Artboard („Nichts gewählt heißt: keine Angabe." / „Beides freiwillig. Änderbar und löschbar im Profil." / … / „Braucht Verbindung. „Später" beendet ohne Zielgewicht."). Schritt 1 trägt zusätzlich die Zeile, wofür Geschlecht und Alter gedacht sind — wörtlich aus dem Artboard.

**Reduce Motion:** der Wechsel zwischen Schritten ist ein Push im Stack; das Rad hat sein Verhalten schon.

**VoiceOver:** Chips als `Button` mit `.isSelected`; die Schrittzeile als ein Element „Schritt 2 von 5"; die Kachel kombiniert Titel und Zeile.

- [ ] **Step 3: In `RootView` einhängen**

```swift
case .onboarding:
    OnboardingFlow(apiClient: apiClient, alsSheet: false) { }
```

Der Abschluss lädt den Bootstrap neu; `destination` wechselt von selbst. Kein zweiter Pfad.

- [ ] **Step 4: Kaltbau, Sichtprüfung im Simulator, Commit**

Alle fünf Screens einmal durchgehen, einmal mit „Später" auf Schritt 1, einmal im Flugmodus auf „Los geht's" (Banner, Erneut versuchen). Dynamic Type XXL auf Schritt 1 und 3.

```bash
git commit -am "feat(ios): Onboarding in fuenf Schritten -- ueberspringbar, ein Schreibweg, Teilwiederholung nach Fehler"
```

---

### Aufgabe 8: iOS — Home: Zielzeile im Kalender, `HomeZieleView`

Die Artboards `Main`, `HomeNachholen`, `HomeZielErreicht`. Der Kalender bekommt zwei Zeilen, die Flamme bleibt. Darunter der Block „Deine Ziele" in drei Zuständen.

**Files:**
- Create: `FitnessMember/Verlauf/HomeZiele.swift`, `FitnessMember/Screens/Home/HomeZieleView.swift`
- Modify: `FitnessMember/Verlauf/HomeSerie.swift`, `FitnessMember/Screens/Home/HomeSerieView.swift`, `HomeRootView.swift`
- Modify: `FitnessMemberTests/HomeSerieTests.swift`; Create: `HomeZieleTests.swift`

**Interfaces:**
- Produces: `HomeSerie.zielzeile(trainiert: Int, ziel: Int) -> String` („2 von 3 Tagen diese Woche", „3 von 3 Tagen · Ziel erreicht", „1 von 1 Tag …"); `HomeZiele.Zustand` (`.nachholen`, `.karte(Gewichtskarte)`), `Gewichtskarte { wert, datumText, differenzText, abstandText, erreichtText, kurve: [Double] }` aus `member`, `messwerte`, `jetzt`; `HomeZiele.kurve(_ punkte:) -> [Double]` (letzte 12)
- Consumes: `BootstrapResponse.Member`, `VerlaufStore.messwerte`, `HomeZeilen.tageHer`, `Zahlformat`

- [ ] **Step 1: Die Tests schreiben**

`HomeSerieTests` ergänzen: `zielzeile(2, 3)`, `zielzeile(3, 3)` (Ziel erreicht), `zielzeile(0, 1)` („0 von 1 Tag"), `zielzeile(4, 3)` („4 von 3 Tagen · Ziel erreicht" — über dem Ziel ist erreicht, nicht falsch). Und: `vorlesetext` erwähnt das Ziel, wenn eins steht („Ziel 3 Tage, 2 erreicht.").

`HomeZieleTests` — drei Zustände, zwei Entscheidungen:

**Entscheidung 1: Die Gewichtskarte erscheint nur mit mindestens einem Messwert.** Ohne Ziele und ohne Gewicht → `.nachholen`. Mit Wochenziel, aber ohne Gewicht → `.nurEintragen`: eine schmale Zeile „Gewicht eintragen" mit dem Plus, keine Karte mit Nullen (§5). Mit Messwert → `.karte`, ob mit oder ohne Zielgewicht. Ein Test je Zustand.

**Entscheidung 2: „Ziel erreicht" lebt im Speicher.** Der Client kennt aus dem Bootstrap nur *aktive* Ziele; ein erreichtes ist dort `null`. `erreichtText` entsteht deshalb aus der Antwort von `putMeasurement` (`goalReached`) und bleibt im `VerlaufStore`, bis ein neues Zielgewicht gesetzt wird — nach einem Neustart fehlt die Zeile. Das ist der Preis dafür, keinen Endpoint für „zuletzt erreichte Ziele" zu bauen; im Kommentar festhalten.

Fälle:
- `abstandText`: Ziel 78, aktuell 82,5 → „noch 4,5 kg"; ohne Zielgewicht `nil`
- `differenzText`: „−2,0 kg" mit Minuszeichen U+2212, „+1,5 kg", „±0" — über `Zahlformat.gewicht`, nie eigene Formatierung
- `kurve` nimmt die letzten 12 Punkte, weniger, wenn weniger da sind
- `datumText`: „heute", „gestern", „vor 3 Tagen" über `HomeZeilen.tageHer`

- [ ] **Step 2: Testlauf, der fehlschlagen muss**

- [ ] **Step 3: Kalender: „Ziel 3 Tage" und die Zielzeile**

`HomeSerieView` bekommt `let wochenziel: Int?`. Rechts neben „DEINE SERIE" ein zweites `label` „ZIEL 3 TAGE" in `textFaint`; unter dem Wochenstreifen (vor der Tagesliste) eine `HStack`: `Text(HomeSerie.zielzeile(…))` 12 pt semibold `textMuted` links, rechts ein Strich je Zieltag (18×4 pt, Radius 2, `line` / gefüllt `text`). Beides nur mit Ziel. `trainiert` ist `wochentage.filter(\.trainiert).count` — dieselbe Menge, die der Streifen zeichnet, keine zweite Quelle.

**Flamme, Fußnote, `serienstand`: unverändert.** Der Kommentar am neuen Block sagt warum (Spec Abschnitt 9, Punkt 5).

- [ ] **Step 4: `HomeZieleView`**

Zwischen `HomeSerieView` und `fortschritt` in `HomeRootView`, unter dem `label` „DEINE ZIELE":

- `.nachholen`: Karte mit „Ziele festlegen", der Zeile aus dem Artboard und `SecondaryButton("Loslegen")`, der `OnboardingFlow(alsSheet: true)` öffnet; `beiFertig` schließt das Sheet und lädt Bootstrap + Verlauf.
- `.karte`: Kopfzeile (`label` „GEWICHT · ABNEHMEN" — die Richtung aus `Trainingsrichtung.wort`, oder nur „GEWICHT" ohne Richtung), Wert 26 pt `.black` + „kg" + Datum; rechts die Mini-Kurve (Swift Charts `LineMark` über 12 Punkte, 120×44, `accent`, keine Achsen, `RuleMark` gestrichelt für das Ziel in `textFaint`) und Chevron; darunter zwei Zellen (Differenz seit erstem Eintrag / Abstand zum Ziel — die zweite fehlt ohne Zielgewicht); darunter die Zeile „Eintragen" mit Plus. Tippen auf die Karte → `pfad.append(.gewichtsverlauf)`; „Eintragen" → `GewichtEintragenSheet` (Aufgabe 9).
- `erreichtText` gesetzt: statt der zwei Zellen eine Zeile mit Haken in `accent` und „Zielgewicht erreicht · 78,0 kg am 3. November", darunter „Neues Ziel setzen" (öffnet `ZielSheet(.zielgewicht)` aus Aufgabe 10) und „Eintragen".
- `.nurEintragen`: eine Zeile „Gewicht eintragen" mit Plus.

`HomeRoute` bekommt `.gewichtsverlauf`; die `navigationDestination` zeigt `GewichtsverlaufView` (Aufgabe 9 — bis dahin `PlaceholderView`).

**Akzent:** die Flamme trägt ihn auf diesem Screen. Der Haken in `accent` ist eine Linie, keine Fläche. Die Kurve in `accent` ist die eine Diagrammfarbe nach §13 — kein Verstoß, dieselbe Regel wie beim Übungsfortschritt.

- [ ] **Step 5: Testlauf, Kaltbau, Commit**

```bash
git commit -am "feat(ios): Wochenziel neben der Serie, Block Deine Ziele auf Home"
```

---

### Aufgabe 9: iOS — Gewicht eintragen, Gewichtsverlauf

Die Artboards `GewichtEintragen` und `Gewichtsverlauf`. Das Sheet ist der einzige Schreibweg des Gewichts nach dem Onboarding; der Verlauf ist das Diagramm nach dem Vorbild von `UebungsfortschrittView`.

**Files:**
- Create: `FitnessMember/Screens/Home/GewichtEintragenSheet.swift`, `GewichtsverlaufView.swift`
- Modify: `FitnessMember/Verlauf/Fortschrittsfenster.swift`
- Modify: `FitnessMemberTests/FortschrittsfensterTests.swift`

- [ ] **Step 1: `Fortschrittsfenster` über ein Protokoll**

`protocol Datiert { var tag: String { get } }` — `ExerciseProgress.Point` liefert `performedOn`, `Messwert` liefert `measuredOn`. `punkte(_:jetzt:)` und `achsenbereich(_:)` werden generisch (`achsenbereich` nimmt `[Double]`). Der bestehende Test läuft unverändert; ein Fall für `Messwert` kommt dazu.

- [ ] **Step 2: Das Sheet**

`GewichtEintragenSheet(vorgabe: Double?, tag: String = heute, speichern: (MesswertWrite) async -> String?)` nach dem Muster von `NameSheet`: Titel „GEWICHT EINTRAGEN", eine Datumszeile (Vorgabe heute, `DatePicker` im Sheet mit `in: ...Date()`, Anzeige „Heute, 13. September" / `Zahlformat.wochentagDatum`), das `RastRad` (Vorgabe: jüngster Messwert, sonst 75,0), Kontextzeile „Schritt 0,5 kg · zuletzt 83,0 am 10. Sep", `PrimaryButton("Eintragen")`, Fußnote „Ein Wert je Tag. Ein zweiter am selben Tag ersetzt den ersten." Der Ortstag kommt aus `Calendar.current` mit der **Studio-Zeitzone** wie in `HomeRootView.zeitzone` — eine Einheit gehört dem Studio, ein Gewicht der Person, aber der Tag soll derselbe sein, an dem das Mitglied es einträgt: `TimeZone.current`. (Das ist die eine Stelle, an der `TimeZone.current` richtig ist; Kommentar.)

`speichern` in `HomeZieleView`: `apiClient.putMeasurement`, dann `verlauf.messwertEintragen(antwort)`, bei `goalReached` den `erreichtText` setzen und `catalogStore.load()` (das Ziel ist nicht mehr aktiv). Offline: „Keine Verbindung. Das Gewicht wurde nicht gespeichert." — kein `PendingWriteStore` (Spec 5.2).

- [ ] **Step 3: Der Verlauf**

`GewichtsverlaufView` nach `UebungsfortschrittView`: Kopf „GEWICHT" + „Ziel 78,0 kg · noch 4,5", Wert 64 pt, Differenz in `accent`, „SEIT 1. AUGUST"; Umschalter über `Fortschrittsfenster`; Diagramm mit `LineMark` + `PointMark` (≥ 8 pt), `RuleMark(y: ziel)` gestrichelt mit Beschriftung „ZIEL 78,0" in `textFaint`, Achse aus `achsenbereich` **einschließlich des Ziels** (sonst läge die Linie außerhalb); Beschriftung nur am ersten und letzten Punkt; Unterzeile „Dein Eintrag je Tag · kg · keine Glättung"; Rohwerte als Liste (Datum, Gewicht, Differenz zum Vortag) mit `.swipeActions` „Löschen" (`apiClient.deleteMeasurement`, dann `verlauf.messwertEntfernen`) und Tippen → Sheet mit dem Tag vorbelegt. Über der Liste rechts „Antippen ändert, Wischen löscht" in `textFaint` — die Geste steht sichtbar da (§5, deaktiviert ist nie stumm, verborgen auch nicht).

**VoiceOver:** Diagramm mit `.accessibilityLabel("Gewichtsverlauf")` und `.accessibilityChartDescriptor`; die Rohwerte sind die Wertetabelle.

- [ ] **Step 4: Kaltbau, Sichtprüfung, Commit**

Ein Verlauf mit einem Punkt, mit zwölf, mit Ziel unter und über der Kurve. Reduce Motion. Dynamic Type XXL.

```bash
git commit -am "feat(ios): Gewicht eintragen und Gewichtsverlauf mit Ziellinie"
```

---

### Aufgabe 10: iOS — Profil: „Über dich", „Ziele", die Sheets

Die Artboards `Profil` und `ProfilAlter`. Jede Angabe änderbar und einzeln löschbar; jedes Ziel änderbar und aufgebbar.

**Files:**
- Create: `FitnessMember/Screens/Profil/AuswahlSheet.swift`, `GroesseSheet.swift`, `ZielSheet.swift`
- Modify: `FitnessMember/Screens/Profil/ProfilRootView.swift`

- [ ] **Step 1: `AuswahlSheet`**

`AuswahlSheet<Wahl: Hashable>(titel:, hinweis:, optionen: [(Wahl, String)], gewaehlt: Wahl?, spalten: Int, speichern: (Wahl?) async -> String?)` — Chips wie im Onboarding, `PrimaryButton("Übernehmen")`, darunter „Angabe entfernen" als Umriss in `danger` (52 pt), nur wenn etwas gesetzt ist. Drei Aufrufer: Geschlecht (3 Spalten), Alter (4), Richtung (2 — hier als Kacheln? Nein: Chips, das Sheet ist kein Onboarding).

`GroesseSheet`: die Stepper-Zeile aus Schritt 2 + „Übernehmen" + „Angabe entfernen".

`ZielSheet(.tageProWoche | .zielgewicht)`: Schritt 4 bzw. 5 als Sheet, `PrimaryButton("Übernehmen")` ruft `setGoal`, „Ziel aufgeben" ruft `dropGoal`; danach `catalogStore.load()`.

- [ ] **Step 2: `ProfilRootView`**

Nach der Kopfkarte zwei neue `Section`s:

- **ÜBER DICH:** Geschlecht · Alter · Größe — je Zeile Label links, Wert rechts in `textMuted` („—" ohne Angabe), Chevron; Tippen öffnet das Sheet. Schreibt `ProfilWrite` mit `.setzen`/`.loeschen`, dann `catalogStore.load()`.
- **ZIELE:** Richtung · Tage pro Woche · Zielgewicht · „Gewicht eintragen" (Plus, öffnet das Sheet aus Aufgabe 9) · „Gewichtsverlauf" (`NavigationLink` → `GewichtsverlaufView`, rechts „82,5 kg · gestern").

Unter „DEINE DATEN" wird der Produktgrenze-Satz um den zweiten ergänzt — wörtlich aus dem Artboard: „Deine Körperdaten und Ziele sieht niemand außer dir — auch dein Studio nicht. Jede Angabe lässt sich einzeln entfernen."

Die Fehlerbehandlung folgt `NameSheet`/`ProfilRootView`: `.offline` zuerst mit eigenem Satz, sonst `error.servertext`.

- [ ] **Step 3: Kaltbau, Sichtprüfung, Commit**

Jede Zeile einmal setzen, ändern, entfernen. Ein Ziel aufgeben und auf Home prüfen, dass die Zielzeile verschwindet.

```bash
git commit -am "feat(ios): Profil mit Ueber dich und Ziele -- alles aenderbar, alles einzeln entfernbar"
```

---

### Aufgabe 11: Gesamtlauf, Migrationen in die Cloud, Abnahmeliste

**Files:**
- Create: `docs/superpowers/plans/2026-09-XX-ziele-abnahme.md`
- Modify: `docs/superpowers/specs/2026-09-13-ziele-und-fortschritt-design.md` (Status-Zeile)

- [ ] **Step 1: Alle drei Ebenen, kalt**

```bash
cd packages/domain && pnpm vitest run && cd ../..
pnpm vitest run
pnpm typecheck
cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -derivedDataPath /tmp/dd-ziele-final test 2>&1 | grep -E "warning:|error:|TEST SUCCEEDED|TEST FAILED|Test run with"
rm -rf /tmp/dd-ziele-final
```

Erwartet: alles grün, **genau die vier vorbestehenden Warnungen.**

- [ ] **Step 2: Migrationen in die Cloud — vor dem Deploy**

Nach `2026-09-01-gesamtfahrplan.md` §4i: erst `supabase migration list` (ist die Datenbank hinten oder vorn?), dann `--dry-run` (genau `0041`–`0043`, rein additiv: drei Enums, zwei Tabellen, zwei Funktionen, Policies, Indizes — **keine** zerstörende Anweisung, nichts an `workout_*`), dann Push, dann `pnpm smoke:migrations`. Die CLI kommt von der Entwicklermaschine nicht an die Postgres-Strecke (§4d) — dann über den MCP-Server und die Versionen anschließend auf `0041`–`0043` normalisieren.

- [ ] **Step 3: Die Abnahmeliste schreiben**

Nach dem Vorbild von `2026-09-11-satzpfad-feinschliff.md`. Diese Punkte gehören hinein:

1. **Neues Konto registrieren.** Nach dem Code erscheint das Onboarding, vor jedem Studio. „Später" auf Schritt 1: Home ohne Ziele, Nachholkarte da; die App startet danach **ohne** Onboarding.
2. **Bestandskonto anmelden.** Das Onboarding erscheint genau einmal.
3. **Alle fünf Schritte ausfüllen.** Home zeigt „Ziel 3 Tage", die Zielzeile, die Gewichtskarte mit dem Eintrag von heute; Profil zeigt alle Werte.
4. **Schritt 2 ohne Gewicht.** Schritt 5 fehlt; Home zeigt die Zeile „Gewicht eintragen" statt der Karte.
5. **Flugmodus auf „Los geht's".** Banner nennt, was gespeichert ist und was nicht; Flugmodus aus, „Erneut versuchen" holt nur das Fehlende nach; kein zweites `onboardingDone` (Serverlog).
6. **Wochenziel 3, zwei Trainingstage.** Zielzeile „2 von 3", zwei Striche gefüllt — **die Flamme zählt unverändert**, die Fußnote auch. Dritter Tag: „3 von 3 · Ziel erreicht", Flamme unverändert.
7. **Gewicht eintragen, dann denselben Tag noch einmal.** Ein Punkt, ersetzt. Verlauf zeigt ihn, Wischen löscht ihn.
8. **Zielgewicht erreichen.** Eintrag unter der Marke: Karte zeigt den Haken; Profil zeigt kein Zielgewicht mehr; „Neues Ziel setzen" öffnet das Sheet.
9. **Als Trainer im Portal:** Überblick unverändert, keine Spur von Gewicht oder Zielen.
10. **Studio verlassen, Home öffnen.** Gewichtskarte und Verlauf bleiben; Zielzeile fehlt (keine Woche ohne Zeitzone), Wochenziel steht weiter im Profil.
11. **Jede Angabe im Profil entfernen.** Danach steht „—", Home zeigt die Nachholkarte, wenn kein Ziel mehr aktiv ist.
12. **Dynamic Type XXL** auf Onboarding 1 und 3, Home, Gewichtsverlauf, Profil.
13. **VoiceOver** auf dem Gewichtsverlauf: Kurve und Rohwerte erreichbar; die Zielzeile im Kalender wird als ein Satz gelesen.
14. **Reduce Motion:** Schrittwechsel und Sheet ohne Bewegung, nichts fehlt.

- [ ] **Step 4: Spec-Status und Commit**

In der Spec: `**Status:** … Umsetzungsplan 2026-09-14-ziele-und-fortschritt.md, gebaut am …`.

```bash
git add docs/superpowers
git commit -m "docs: offene manuelle Abnahme fuer Ziele und Fortschritt"
```

---

## Was dieser Plan bewusst nicht tut

- **Kein zweiter Schwellwert in `serienstand`.** Die Serie zählt Wochen mit mindestens einer Einheit; das Wochenziel ist eine Zeile daneben. Entschieden am 13. September, Spec Abschnitt 9, Punkt 5.
- **Kein BMI, kein Trend, keine Prognose, keine Kalorien** — auch nicht als Vorbereitung im Datenmodell.
- **Keine Öffnung für Personal**, auch nicht als Summe: `studio_overview` bleibt, wie es ist, und der Test in Aufgabe 4 sichert das zu.
- **Kein HealthKit-Import**, keine Erinnerung, kein Push.
- **Keine Übungsziele** (`exercise_weight`) — die Spalte ist da, die Sorte im Enum fehlt absichtlich noch: ein Enum-Wert, den keine Funktion prüft, wäre eine offene Tür.
- **Kein Endpoint für erreichte Ziele.** Die „erreicht"-Zeile lebt aus der Antwort des Eintrags im Speicher; nach einem Neustart fehlt sie. Der Preis ist genannt (Aufgabe 8, Step 1).
- **Kein `PendingWriteStore` für Gewicht oder Ziele** — derselbe Grund wie beim Namen (Home-Profil-Spec 3.4): was sich nachholen lässt, braucht keine zweite Warteschlange.
- **Keine Transaktion um Messwert und Zielmarkierung** — zwei Statements, Fall und Folge in Aufgabe 3, Step 5 benannt.
