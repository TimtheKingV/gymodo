# Onboarding reparieren — Umsetzungsplan

> **Für agentische Ausführung:** ERFORDERLICHE UNTER-SKILL: `superpowers:subagent-driven-development` (empfohlen) oder `superpowers:executing-plans`, Aufgabe für Aufgabe. Die Schritte tragen Checkboxen (`- [ ]`).

**Ziel:** Ein Mensch, der sich anmeldet, registriert oder sein Passwort zurücksetzt, kommt in der Produktion an — statt auf einer schwarzen Seite oder mit einer Mail, die das Falsche enthält.

**Architektur:** Zwei voneinander unabhängige Wurzelursachen, die sich gegenseitig verdecken. Die eine liegt in der Cloud-Konfiguration (Mailvorlagen), die andere im Code (die Wurzelseite ist eine Sackgasse). Dazu eine dritte, die beide unsichtbar gehalten hat: kein Test geht den Weg, den ein Mensch geht.

**Tech-Stack:** Supabase Auth (GoTrue), Supabase CLI `config push`, Next.js 15 App Router, Playwright.

**Befund:** Diese Datei. Es gibt keine eigene Spec — der Fehler wurde am 3. September beim ersten menschlichen Anmeldeversuch in der Produktion gefunden.

---

## Globale Rahmenbedingungen

- **`supabase config push` überträgt die ganze `[auth]`-Sektion.** Ohne gesourcete `.env.production` setzt er `site_url` der Produktion auf `http://127.0.0.1:3000`. Das Verfahren steht wörtlich in `.env.production`:
  ```bash
  set -a; . ./.env.production; set +a
  pnpm exec supabase config push
  ```
  **`SUPABASE_ENV=production` funktioniert nicht** — die CLI 2.116.0 wertet es nicht aus, geprüft am 1. September. Nur eine echte Shell-Variable hat Vorrang vor `.env`.
- **Keine Schlüssel in `.env.production`.** Nur URLs. Anon- und Service-Role-Schlüssel leben in Vercel und im Supabase-Dashboard.
- **Die Testsuite lädt `.env.production` nicht.** Vitest und Playwright laden `.env`, und dort gehören Cloud-Werte niemals hinein.
- **Gleiche Antwort für existierende und nicht existierende Adressen.** `passwortVergessenAnfordern` gibt in beiden Fällen `sentTo` zurück — gegen User-Enumeration. Das bleibt so.
- **Deutsche Oberflächentexte mit Umlauten, deutsche Bezeichner im Web-Layer.**

---

## Die Wurzelursachen

### A — Die Cloud kennt die Mailvorlagen nicht

Auf Platte liegen drei Vorlagen, und **alle drei setzen auf einen sechsstelligen Code**:

```
supabase/templates/confirmation.html   {{ .Token }}
supabase/templates/magic_link.html     {{ .Token }}
supabase/templates/recovery.html       {{ .Token }}
```

Der Code erwartet genau das. `passwort-vergessen/actions.ts:10` verlangt `/^\d{6}$/` und ruft `verifyOtp({ type: "recovery" })`; `registrieren/actions.ts` dasselbe mit `type: "signup"`.

**Beobachtet am 3. September:** die Mail enthielt einen **Link**, keinen Code. Ein Link ist Supabases Standardvorlage (`{{ .ConfirmationURL }}`). Die Cloud trägt die eigenen Vorlagen also nicht.

**Warum:** `config.toml` bekam die Vorlagen für `recovery` und `confirmation` erst mit `6a1fffb` am 2. September (*„Passwort vergessen und zuruecksetzen per Code"*). Der letzte `config push` liegt davor, am 1. September — damals ging es um `magic_link` für den OTP-Login. Seitdem hat niemand gepusht.

**Das ist dieselbe Drift wie in `2026-09-01-gesamtfahrplan.md` §4c–4f, zum vierten Mal — nur diesmal in der Auth-Konfiguration statt im Schema.**

Der Link ist zusätzlich in sich unbrauchbar: er führt auf `site_url` und trägt das Wiederherstellungstoken im **URL-Fragment**. Ein Fragment erreicht den Server nie, und `/` ist eine Server-Komponente — sie sieht keine Sitzung und schreibt *„Nicht angemeldet."*

### B — Die Wurzelseite ist eine Sackgasse

`apps/web/app/page.tsx` ist die M0-Rauchprobe. Ihr gesamter Inhalt:

```tsx
<p data-testid="user-email">{user.email}</p>
<ul data-testid="studio-list"><li>{studio.name}</li></ul>
```

Kein Stylesheet, **kein einziger Link weiter**. Und dort landet jeder Onboarding-Weg:

| Datei | Zeile |
| --- | --- |
| `login/actions.ts` | `redirect("/")` |
| `passwort-vergessen/actions.ts` | `redirect("/")` |
| `registrieren/actions.ts` | `redirect("/")` (zweimal) |

Ein Trainer, der sich anmeldet, sieht seine Adresse, den Studionamen und schwarz.

### C — Warum es niemand gesehen hat

Die E2E-Tests melden sich an und springen dann per `page.goto` direkt auf `/portal/…`. **Kein Test geht den Weg, den ein Mensch geht.** Dieselbe Lückensorte wie das 22-Byte-JPEG in `2026-09-02-einrichtung-am-geraet.md`: geprüft wurde der Codepfad, nicht der Weg.

---

## Dateistruktur

| Datei | Verantwortung |
| --- | --- |
| `apps/web/app/page.tsx` **(ändern)** | Personal wird ins Portal weitergeleitet; Mitglieder behalten die bestehende Seite |
| `e2e/onboarding.spec.ts` **(neu)** | Der menschliche Weg: anmelden und ankommen, ohne `page.goto` auf ein Ziel |
| `docs/superpowers/plans/2026-09-01-gesamtfahrplan.md` **(ändern)** | Vierte Drift als §4g, offene Punkte nachziehen |

**Aufgabe 1 fasst keine Datei an** — sie ist ein Konfigurations-Push gegen die Cloud.

---

## Aufgabe 1: Die Mailvorlagen in die Cloud bringen

Der Kern des gemeldeten Fehlers. Ohne diesen Schritt bleibt jede Mail falsch, egal was im Code steht.

**Dateien:** keine. Ein Push gegen das Projekt `Gymodo` (`hverawzrwjgztolxuose`).

**Interfaces:**
- Nutzt: `.env.production` (vorhanden, gitignoriert), `supabase/templates/*.html`, `supabase/config.toml`
- Liefert: eine Cloud, deren `recovery`-, `confirmation`- und `magic_link`-Mail einen sechsstelligen Code enthält

- [ ] **Schritt 1: Belegen, dass `.env.production` die Cloud-Werte trägt**

```bash
cd C:/Users/bttm/Documents/Fitness-App
grep -E "^SUPABASE_AUTH" .env.production
```

Erwartet, **wörtlich**:

```
SUPABASE_AUTH_SITE_URL=https://gymodo-web.vercel.app
SUPABASE_AUTH_ADDITIONAL_REDIRECT_URLS=https://gymodo-web.vercel.app/**
SUPABASE_AUTH_EMAIL_MAX_FREQUENCY=60s
SUPABASE_AUTH_EMAIL_ENABLE_CONFIRMATIONS=true
```

Steht dort `127.0.0.1`, **hier anhalten.** Ein Push mit den lokalen Werten setzt die Site-URL der Produktion auf localhost, und jeder Anmeldelink in jeder Mail läuft ins Leere.

- [ ] **Schritt 2: Den Diff ansehen, ohne zu pushen**

```bash
set -a; . ./.env.production; set +a
echo "SITE_URL, das gepusht wuerde: $SUPABASE_AUTH_SITE_URL"
```

Erwartet: `https://gymodo-web.vercel.app`. Das ist die Zeile, die im Fehlerfall alles kaputtmacht — sie wird deshalb einzeln bestätigt, bevor der Push läuft.

- [ ] **Schritt 3: Pushen**

**In derselben Shell** wie Schritt 2 — die Variablen leben nur dort:

```bash
pnpm exec supabase config push
```

Die CLI zeigt den Diff und fragt. Erwartet im Diff: die drei `template.*.content_path`-Einträge beziehungsweise deren Inhalt. **`site_url` darf im Diff nicht auf `127.0.0.1` stehen** — steht es dort, ablehnen und zu Schritt 1 zurück.

Bestätigen. Erwartete Ausgabe am Ende: `Finished supabase config push.`

- [ ] **Schritt 4: Belegen, dass der Folge-Diff leer ist**

```bash
pnpm exec supabase config push
```

Erwartet: kein Unterschied mehr. Dasselbe Verfahren, mit dem am 1. September der erste Template-Push belegt wurde (Gesamtfahrplan §4, Phase 0).

- [ ] **Schritt 5: Die Mail von Hand prüfen — der eigentliche Beleg**

Auf `https://gymodo-web.vercel.app/passwort-vergessen` die eigene Adresse eintragen.

Erwartet: eine Mail mit einem **sechsstelligen Code**, nicht mit einem Link. Code und neues Passwort auf derselben Seite eingeben.

Kommt weiterhin ein Link, ist die Hypothese falsch — dann anhalten und den Befund neu aufnehmen, nicht einen zweiten Fix darauflegen.

> **Warum kein automatischer Test:** die Mail entsteht in der Cloud und geht an ein echtes Postfach. Lokal deckt `e2e/auth.spec.ts` den Codeweg gegen Mailpit bereits ab — dieser Schritt prüft, was nur die Produktion beantworten kann: welche Vorlage dort liegt.

- [ ] **Schritt 6: Kein Commit**

Diese Aufgabe verändert keine Datei. Ihr Ergebnis wird in Aufgabe 4 dokumentiert.

---

## Aufgabe 2: Die Wurzelseite führt Personal ins Portal

**Dateien:**
- Ändern: `apps/web/app/page.tsx`
- Anlegen: `e2e/onboarding.spec.ts`

**Interfaces:**
- Nutzt: `createServerSupabaseClient` aus `@/lib/supabase/server`, `redirect` aus `next/navigation`
- Liefert: `/` leitet Trainer und Inhaber auf `/portal` weiter; für alle anderen bleibt die Seite, wie sie ist

**Warum eine Weiterleitung und kein Link:** `/portal` macht es schon genauso — *„Wer in genau einem Studio Trainer ist, landet direkt dort und sieht diese Seite nie."* Ein Zwischenklick auf einer ungestalteten Seite wäre eine Station ohne Zweck.

**Warum nicht den Login umbiegen:** `/` ist auch die Landung für Mitglieder ohne Studio — dort steht das Beitrittsformular. Ein `redirect("/portal")` in `login/actions.ts` schickte die auf eine Seite, die ihnen sagt, dass sie dort nichts zu suchen haben. Die Entscheidung gehört an die Stelle, die den Nutzer kennt.

- [ ] **Schritt 1: Den fehlschlagenden Test schreiben**

`e2e/onboarding.spec.ts`:

```ts
import { expect, test } from "@playwright/test";
import { studioMitTrainer } from "./helpers/studio";

/**
 * Der Weg, den ein Mensch geht -- und den bis zum 3. September kein Test
 * ging: die uebrigen Dateien melden sich an und springen dann per goto auf
 * ihr Ziel. Genau deshalb blieb unbemerkt, dass "/" eine Sackgasse ist:
 * die M0-Rauchprobe ohne Stylesheet und ohne einen Link weiter.
 */
test("Ein Trainer landet nach der Anmeldung im Portal, ohne die Adresse zu kennen", async ({
  page,
}) => {
  const { studioId } = await studioMitTrainer(page, "onboarding-trainer");

  // studioMitTrainer meldet an und wartet, bis die Login-Seite verlassen ist.
  // Ab hier wird NICHT navigiert -- gemessen wird, wo der Login hinfuehrt.
  await expect(page).toHaveURL(new RegExp(`/portal/${studioId}$`));
  await expect(page.getByRole("navigation", { name: "Katalog" })).toBeVisible();

  // Die nackte M0-Seite darf ein angemeldeter Trainer nie zu sehen bekommen.
  await expect(page.getByTestId("user-email")).toHaveCount(0);
});
```

- [ ] **Schritt 2: Test laufen lassen und den Fehlschlag sehen**

Ausführen: `npx playwright test onboarding`

Erwartet: FAIL. Die URL ist `http://127.0.0.1:3000/`, erwartet wurde `/portal/<id>`.

- [ ] **Schritt 3: Die minimale Umsetzung schreiben**

`apps/web/app/page.tsx` — die Abfrage der Mitgliedschaften ergänzen und vor dem bisherigen Inhalt weiterleiten:

```tsx
import { redirect } from "next/navigation";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { BeitrittsFormular } from "./BeitrittsFormular";

export default async function HomePage() {
  const supabase = await createServerSupabaseClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return <p data-testid="anonymous">Nicht angemeldet.</p>;
  }

  // Wer den Katalog pflegt, gehoert ins Portal -- diese Seite ist die
  // M0-Rauchprobe und traegt keinen Weg weiter. Bis zum 3. September landete
  // hier jeder Onboarding-Weg und endete: Adresse, Studioname, schwarz.
  //
  // Der Filter auf user_id ist noetig, seit memberships_select_staff (0031)
  // Mitarbeitern alle Zeilen ihres Studios zeigt -- ohne ihn zaehlte jeder
  // Kollege als eigene Mitgliedschaft. Dieselbe Falle wie in portal/page.tsx.
  const { data: personal } = await supabase
    .from("studio_memberships")
    .select("role")
    .eq("user_id", user.id)
    .in("role", ["trainer", "owner"])
    .limit(1);
  if (personal && personal.length > 0) redirect("/portal");

  const { data: studios } = await supabase.from("studios").select("id, name");

  return (
    <main>
      <p data-testid="user-email">{user.email}</p>
      {studios && studios.length > 0 ? (
        <ul data-testid="studio-list">
          {studios.map((studio) => (
            <li key={studio.id}>{studio.name}</li>
          ))}
        </ul>
      ) : (
        <BeitrittsFormular />
      )}
    </main>
  );
}
```

> **`redirect()` wirft eine Ausnahme**, die Next abfängt. Sie darf deshalb nicht in einem `try`-Block stehen, und nach ihr läuft kein Code mehr — beides ist hier erfüllt.

- [ ] **Schritt 4: Test laufen lassen**

Ausführen: `npx playwright test onboarding`

Erwartet: PASS.

- [ ] **Schritt 5: Prüfen, dass der Mitgliedsweg unberührt ist**

Ausführen: `npx playwright test auth`

Erwartet: PASS, alle vier Tests. `auth.spec.ts:70` (*„ein Konto ohne Studio tritt per Code bei"*) läuft über genau die Seite, die dieser Schritt anfasst — ein Konto ohne Mitgliedschaft muss weiterhin das Beitrittsformular sehen und darf **nicht** ins Portal geschickt werden.

- [ ] **Schritt 6: Die volle Suite**

Ausführen: `pnpm typecheck && pnpm test:e2e`

Erwartet: 29 Tests grün (28 Bestand plus der neue).

- [ ] **Schritt 7: Committen**

```bash
git add apps/web/app/page.tsx e2e/onboarding.spec.ts
git commit -m "fix(web): die Wurzelseite fuehrt Personal ins Portal statt ins Schwarze"
```

---

## Aufgabe 3: Den Weg nach dem Passwortwechsel prüfen

Aufgabe 2 repariert den Login. Die drei übrigen Onboarding-Wege landen auf derselben Seite und werden dadurch mitgeheilt — aber *dass* sie es werden, ist bisher nur eine Behauptung.

**Dateien:**
- Ändern: `e2e/onboarding.spec.ts`

**Interfaces:**
- Nutzt: `latestOtpFor` und `E2E_PASSWORD` aus `e2e/helpers/login`, `studioMitTrainer` aus `e2e/helpers/studio`
- Liefert: nichts, was eine spätere Aufgabe braucht

- [ ] **Schritt 1: Den Test schreiben**

An `e2e/onboarding.spec.ts` anhängen:

```ts
import { latestOtpFor } from "./helpers/login";

/**
 * Der zweite Weg auf dieselbe Seite. Aufgabe 2 heilt ihn mit, und genau
 * deshalb steht er hier: eine mitgeheilte Strecke, die niemand nachmisst,
 * ist eine Behauptung.
 */
test("Nach dem Passwortwechsel steht ein Trainer im Portal, nicht im Schwarzen", async ({
  page,
}) => {
  const { email, studioId } = await studioMitTrainer(page, "onboarding-reset");

  const angefordert = new Date();
  await page.goto("/passwort-vergessen");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByRole("button", { name: "Code anfordern" }).click();

  const code = await latestOtpFor(email, angefordert);
  await page.getByLabel("Code aus der E-Mail").fill(code);
  await page.getByLabel("Neues Passwort").fill("neues-passwort-1234");
  await page.getByRole("button", { name: "Passwort setzen" }).click();

  await expect(page).toHaveURL(new RegExp(`/portal/${studioId}$`));
});
```

Die Beschriftungen stammen aus `passwort-vergessen/page.tsx` (Zeilen 14, 16, 18, 28) und sind dort nachgesehen, nicht geraten: `E-Mail`, `Code anfordern`, `Code aus der E-Mail`, `Neues Passwort`, `Passwort setzen`.

- [ ] **Schritt 2: Test laufen lassen**

Ausführen: `npx playwright test onboarding`

Erwartet: beide Tests PASS.

Schlägt er fehl, weil die Sitzung nach `updateUser` fehlt: das ist ein echter Befund und **kein** Grund, den Test anzupassen. `passwortZuruecksetzen` ruft `verifyOtp` und danach `updateUser` — ist danach keine Sitzung gesetzt, landet der Nutzer angemeldet-aussehend auf `/` und wird von dort nicht weitergeleitet. Dann Aufgabe 2 erneut ansehen, nicht den Test abschwächen.

- [ ] **Schritt 3: Committen**

```bash
git add e2e/onboarding.spec.ts
git commit -m "test(e2e): auch der Passwortwechsel endet im Portal, nicht auf der Rauchprobe"
```

---

## Aufgabe 4: Den Fahrplan nachziehen

**Dateien:**
- Ändern: `docs/superpowers/plans/2026-09-01-gesamtfahrplan.md`

- [ ] **Schritt 1: Die vierte Drift als §4g eintragen**

Vor `### Das Ungleichgewicht, das die Reihenfolge bestimmt` einfügen:

```markdown
### 4g. Die vierte Drift — diesmal die Auth-Konfiguration

Am 3. September, beim **ersten menschlichen Anmeldeversuch in der Produktion**: die Mail zum Zurücksetzen des Passworts enthielt einen Link, die Oberfläche verlangt einen sechsstelligen Code.

Auf Platte setzen alle drei Vorlagen (`confirmation`, `magic_link`, `recovery`) auf `{{ .Token }}`. Ein Link ist Supabases Standardvorlage — die Cloud trug die eigenen also nicht. `config.toml` bekam `recovery` und `confirmation` erst mit `6a1fffb` am 2. September; der letzte `config push` liegt davor, am 1. September.

**Es ist dieselbe Drift wie 4c bis 4f, zum vierten Mal — und zum ersten Mal nicht im Schema, sondern in der Auth-Konfiguration.** Die Lehre aus 4e gilt unverändert: erst fragen, welche Seite hinten ist. Hier war es die Cloud.

**Was den Fehler verdeckt hat:** der Link führt auf `site_url` und trägt sein Token im URL-Fragment. Ein Fragment erreicht den Server nie, `/` ist eine Server-Komponente — sie sah keine Sitzung und schrieb *„Nicht angemeldet."* Der Nutzer sieht damit einen Anmeldefehler, wo eine falsche Vorlage liegt.

**Und warum es niemand vorher sah:** kein Test ging den Weg, den ein Mensch geht. Die E2E-Dateien melden sich an und springen dann per `page.goto` auf ihr Ziel. `e2e/onboarding.spec.ts` schließt diese Lücke — er navigiert nach dem Login nicht mehr, sondern misst, wo man landet.
```

- [ ] **Schritt 2: Phase 0 nachziehen**

Die Zeile zum Template-Push ergänzen:

```markdown
- [x] **Mailvorlagen in der Cloud** — am 1. September für `magic_link` gepusht, am 3. September für `recovery` und `confirmation` nachgezogen (Abschnitt 4g)
```

- [ ] **Schritt 3: Offene Punkte in Abschnitt 6 ergänzen**

```markdown
| **Die Wurzelseite `/` ist ungestaltet** — seit dem 3. September sieht Personal sie nicht mehr, Mitglieder ohne Studio schon. Sie trägt das Beitrittsformular und stammt aus M0 | Phase 5 | nichts, aber es ist die erste Seite, die ein Mitglied im Web sieht |
```

- [ ] **Schritt 4: Committen**

```bash
git add docs/superpowers/plans/2026-09-01-gesamtfahrplan.md
git commit -m "docs: vierte Drift -- die Mailvorlagen der Cloud, und die Sackgasse auf /"
```

---

## Abnahme

- [ ] `pnpm typecheck` — keine Fehler
- [ ] `pnpm test:e2e` — 29 Tests grün
- [ ] **Von Hand in der Produktion:** Passwort zurücksetzen liefert eine Mail mit **sechsstelligem Code**
- [ ] **Von Hand in der Produktion:** nach dem Login landet man auf `/portal/<id>` und sieht die Rail
- [ ] `supabase config push` meldet beim zweiten Lauf keinen Unterschied

---

## Was dieser Plan nicht repariert

| Punkt | Warum |
| --- | --- |
| **Die Gestaltung von `/`** | Sie bleibt die M0-Rauchprobe. Personal sieht sie nach Aufgabe 2 nicht mehr; ein Mitglied ohne Studio schon, und für das ist sie der Beitrittsweg. Gestaltung ist Phase 5. |
| **Ein Weg für den Fall, dass doch ein Link ankommt** | Nach Aufgabe 1 kommen keine Links mehr. Eine Seite, die zusätzlich Fragment-Tokens auswertet, wäre ein zweiter Codepfad für einen Zustand, den es nicht mehr gibt — und zwei Wege ins Konto sind eine Angriffsfläche mehr. |
| **Die Registrierungs-Bestätigungsmail von Hand** | Sie hängt an derselben Vorlagenkonfiguration und wird von Aufgabe 1 mitgeheilt. Ein zweiter Handtest kostet ein weiteres Postfach; der Codeweg ist lokal durch `auth.spec.ts` gedeckt. Wer ihn trotzdem prüfen will: mit einer zweiten Adresse registrieren. |
