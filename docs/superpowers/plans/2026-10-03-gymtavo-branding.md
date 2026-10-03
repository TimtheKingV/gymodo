# GYMTAVO-Branding: Wortmarke und sichtbare Texte

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Die GYMTAVO-Wortmarke ersetzt den Textschriftzug „gymodo“ in Web (Landeseite, Einstiegshülle) und iOS (Login), und alle für Nutzer sichtbaren Produktnamen in App und Web heißen danach „Gymtavo“.

**Architecture:** Grundlage ist der Patch `~/Downloads/gymtavo-branding-pr/gymtavo-branding.patch` (Basis 3d8bed5, lässt sich sauber auf master 37080ce anwenden). Er wird nicht als Ganzes übernommen, sondern aufgeteilt: Vorlage und SVGs unverändert, Web- und iOS-Einbau je mit rotem Test zuerst, das Xcode-Projekt per `xcodegen generate` statt handgeschriebener pbxproj-IDs. Danach die Textumstellung, getrennt nach Web und iOS.

**Tech Stack:** Next.js (apps/web), Playwright (e2e), SwiftUI + Swift Testing (apps/ios-member), XcodeGen.

**Spec:** `~/Downloads/gymtavo-branding-pr/PR-DRAFT.md` und `assets/branding/README.md` aus dem Patch. Umfang erweitert am 03.10.: zusätzlich alle sichtbaren „gymodo“-Texte, ohne Bundle-ID, Domain und Associated Domains.

## Global Constraints

- Wortmarke: Archivo 900, Buchstaben `#F2F4F7` (dunkler Grund) bzw. `#0A0B0D` (heller Grund), Punkt `#D4FF3F`, Hintergrund transparent. Die SVGs aus dem Patch werden byte-gleich übernommen.
- Beide Oberflächen sind dunkel (`--bg` / `DesignSystem.Color.bg` = `#0A0B0D`) → überall `gymtavo-wordmark.svg` (helle Buchstaben). `-on-light` liegt nur als Vorlage bereit.
- Barrierefreiheit: Wortmarke als Bild mit Namen „GYMTAVO“ (Web `alt`, iOS `accessibilityLabel`).
- Schreibweise im Fließtext: **„Gymtavo“** (Satzschreibung). Die Großschreibung GYMTAVO gehört nur der Wortmarke.
- Bleibt unverändert: `de.gymtaro.*` (Bundle-ID, Logger-Subsysteme, DispatchQueue-Label), `gymodo-web.vercel.app` (Domain, Associated Domains, `TagLink.host`, `.env.production.example`, Config.xcconfig.example, `tag-scan.test.ts`), Testnotiz-Formatkennungen `gymodo.testnotiz/1` und `/2`, `bundleId: "gymodo.web.portal"`, Testnotiz-Markdown-Kopfzeilen (Entwicklerwerkzeug, vom finetuning-Skill gelesen), Kommentare und alte Pläne unter `docs/`.
- QR/NFC: kein Eingriff in Scanner, NFC-Leser, Tag-Routing oder Druckausgaben; nur `docs/branding/qr-nfc-design-status.md` aus dem Patch.
- Commits: deutsch mit ae/oe/ue, ein Commit pro Aufgabe, Trailer laut Sitzung, danach `git log -1 --format=%B` prüfen. Swift-Kommentare ASCII und mit Begründung.
- Arbeit in eigenem Worktree `.claude/worktrees/gymtavo-branding`, Branch `feat/gymtavo-branding` von `master`. Kein Push ohne Freigabe.

## Review Focus

1. **320 px breites Telefon, Landeseite:** Kopf hat links/rechts je 48 px Innenabstand; Wortmarke (160 px) plus „Anmelden“-Knopf passen in 224 px nicht → horizontales Scrollen. Erwartet: kein Überlauf. → Test in Aufgabe 2.
2. **Veraltete Negativ-Assertion:** `e2e/schreibtisch.spec.ts:82` prüft `/gymodo misst nichts/` auf Anzahl 0 — nach der Umbenennung wäre der Test grün, egal was die Seite zeigt. Erwartet: prüft den neuen Namen. → Aufgabe 4.
3. **Asset fehlt im App-Bundle** (Katalog nicht in der Resources-Phase): SwiftUI zeigt still nichts statt eines Fehlers. Erwartet: Testabbruch. → Test in Aufgabe 3.
4. **Home-Bildschirm-Name:** Ohne `CFBundleDisplayName` steht unter dem Icon „FitnessMember“. Erwartet: „Gymtavo“. → Aufgabe 5.
5. **Vergessene sichtbare Stelle:** ein „gymodo“ in Nutzertext, das die Liste verfehlt. Erwartet: keins. → Grep-Wächter am Ende von Aufgabe 4 und 5.

---

### Aufgabe 1: Worktree, Vorlage und SVGs übernehmen

**Files:**
- Create (aus dem Patch): `assets/branding/{README.md,Archivo-OFL.txt,gymtavo-logo.html,gymtavo-wordmark.svg,gymtavo-wordmark-on-light.svg}`, `docs/branding/qr-nfc-design-status.md`, `apps/web/public/branding/{gymtavo-wordmark.svg,gymtavo-wordmark-on-light.svg}`

- [ ] **Schritt 1: Worktree anlegen**

```bash
cd /Users/timbuttner/Documents/fitness-app
git worktree add .claude/worktrees/gymtavo-branding -b feat/gymtavo-branding master
cp .env .claude/worktrees/gymtavo-branding/.env
cp apps/ios-member/Config.xcconfig .claude/worktrees/gymtavo-branding/apps/ios-member/Config.xcconfig
```
Dann per EnterWorktree mit diesem Pfad betreten, `pnpm install`.

- [ ] **Schritt 2: Nur Vorlage, Doku und Web-SVGs aus dem Patch anwenden**

```bash
P=~/Downloads/gymtavo-branding-pr/gymtavo-branding.patch
git apply --whitespace=fix --include='assets/branding/*' --include='docs/branding/*' --include='apps/web/public/branding/*' "$P"
git status --short
```
Expected: genau 8 neue Dateien. `--whitespace=fix` entfernt die Leerzeilen, die der Patch an Dateienden anhängt.

- [ ] **Schritt 3: Prüfen**

```bash
for f in assets/branding/*.svg apps/web/public/branding/*.svg; do xmllint --noout "$f" && echo "ok $f"; done
cmp assets/branding/gymtavo-wordmark.svg apps/web/public/branding/gymtavo-wordmark.svg
cmp assets/branding/gymtavo-wordmark-on-light.svg apps/web/public/branding/gymtavo-wordmark-on-light.svg
```
Expected: viermal `ok`, `cmp` ohne Ausgabe.

- [ ] **Schritt 4: README an den erweiterten Umfang anpassen**

In `assets/branding/README.md` den Satz
`Bei Aenderungen alle SVG-Kopien zusammen aktualisieren. Keine App-Icon-,\nBundle-ID-, URL- oder umfassende Produktnamen-Migration in diesem PR.`
ersetzen durch:

```markdown
Bei Aenderungen alle SVG-Kopien zusammen aktualisieren. Sichtbare Texte
heissen "Gymtavo"; App-Icon, Bundle-ID (de.gymtaro.*), Domain
(gymodo-web.vercel.app) und Testnotiz-Formatkennungen sind bewusst nicht
umgestellt.
```
Außerdem den Satz über das „eingecheckte Xcode-Projekt“ ersetzen durch: `Das Xcode-Projekt wird mit xcodegen generate aus project.yml erzeugt; der Katalog liegt unter sources: FitnessMember.`

- [ ] **Schritt 5: Commit**

```bash
git add assets/branding docs/branding apps/web/public/branding
git commit -m "feat(branding): GYMTAVO-Wortmarke als Vorlage und SVG uebernehmen"
```

---

### Aufgabe 2: Wortmarke im Web

**Files:**
- Create: `apps/web/app/branding/GymtavoWordmark.tsx`
- Modify: `apps/web/app/page.tsx:24`, `apps/web/app/einstieg/Einstieg.tsx:36`, `apps/web/app/einstieg/landeseite.module.css:23-29`, `apps/web/app/einstieg/einstieg.module.css:14-25`
- Test: `e2e/wurzel.spec.ts`

**Interfaces:**
- Produces: `export function GymtavoWordmark(): JSX.Element` — `<img>` mit `alt="GYMTAVO"`, Quelle `/branding/gymtavo-wordmark.svg`.

- [ ] **Schritt 1: Rote Tests schreiben** — am Ende von `e2e/wurzel.spec.ts` anhängen:

```ts
/**
 * GYMTAVO-Wortmarke statt Textschriftzug. Als Bild mit Namen, damit
 * Screenreader die Marke lesen, und auf 320 px ohne Querscrollen --
 * der Kopf traegt links Marke, rechts "Anmelden" bei 48 px Rand.
 */
test("Die Landeseite zeigt die GYMTAVO-Wortmarke", async ({ page }) => {
  await page.goto("/");
  const marke = page.getByRole("banner").getByRole("img", { name: "GYMTAVO" });
  await expect(marke).toBeVisible();
  expect(await marke.evaluate((el: HTMLImageElement) => el.naturalWidth)).toBeGreaterThan(0);
});

test("Die Einstiegsseiten zeigen dieselbe Wortmarke", async ({ page }) => {
  await page.goto("/login");
  await expect(page.getByRole("banner").getByRole("img", { name: "GYMTAVO" })).toBeVisible();
});

test("Auf 320 px laeuft der Kopf der Landeseite nicht ueber", async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 640 });
  await page.goto("/");
  const ueberlauf = await page.evaluate(
    () => document.documentElement.scrollWidth - document.documentElement.clientWidth,
  );
  expect(ueberlauf).toBe(0);
  await expect(page.getByRole("link", { name: "Anmelden", exact: true })).toBeInViewport();
});
```
Hinweis: `getByRole("banner")` trifft das `<header>`, solange es nicht in `<main>` steckt — das ist in `page.tsx` und `Einstieg.tsx` so. Prüfen, dass `/login` die Hülle `Einstieg` nutzt (`apps/web/app/login/page.tsx`); sonst eine andere Einstiegsroute wählen, die sie nutzt.

- [ ] **Schritt 2: Rot bestätigen**

Run: `pnpm test:e2e e2e/wurzel.spec.ts` (lokales Supabase muss laufen, siehe `playwright.config.ts`)
Expected: die beiden Wortmarken-Tests FAIL (kein img „GYMTAVO“). Der 320-px-Test kann schon grün sein; dann ist er Wächter für Schritt 3.

- [ ] **Schritt 3: Baustein und Einbau**

`apps/web/app/branding/GymtavoWordmark.tsx`:

```tsx
/**
 * Die Wortmarke aus assets/branding/gymtavo-logo.html als SVG mit
 * Glyphenumrissen -- keine Webschrift, kein externer Request. Helle
 * Buchstaben, weil beide Seiten, die sie tragen, auf --bg stehen.
 */
export function GymtavoWordmark() {
  return (
    <img
      src="/branding/gymtavo-wordmark.svg"
      alt="GYMTAVO"
      width={128}
      height={24}
      style={{ display: "block", width: 128, height: "auto", flexShrink: 1, minWidth: 0 }}
    />
  );
}
```
128 statt der 160 px aus dem Patch: das bisherige `.marke` war 20 px Versal (rund 90 px breit); 160 px wirkten im Kopf doppelt so laut und sprengen 320 px. Bei der Sichtprüfung gegen `gymtavo-logo.html` darf der Wert nachjustiert werden.

`apps/web/app/page.tsx`: Import `import { GymtavoWordmark } from "./branding/GymtavoWordmark";` nach den bestehenden Imports, Zeile 24 `<span className={styles.marke}>gymodo</span>` → `<GymtavoWordmark />`.

`apps/web/app/einstieg/Einstieg.tsx`: Import `import { GymtavoWordmark } from "../branding/GymtavoWordmark";` vor dem Stylesheet-Import, Zeile 36 ebenso ersetzen.

In beiden CSS-Modulen die nun unbenutzte Regel `.marke { … }` löschen.

- [ ] **Schritt 4: Grün bestätigen**

Run: `pnpm test:e2e e2e/wurzel.spec.ts`
Expected: alle PASS. Wenn der 320-px-Test rot ist, in `landeseite.module.css` und `einstieg.module.css` nach `.kopf` ergänzen und erneut laufen lassen:

```css
/* Unter 480 px fressen 2 x 48 px Rand den Platz fuer Marke und
   Anmelden-Knopf; 20 px entspricht dem Seitenrand von .seite. */
@media (max-width: 480px) {
  .kopf {
    padding: var(--s24) 20px;
  }
}
```

- [ ] **Schritt 5: Typecheck, Unit-Tests, Sichtprüfung**

Run: `pnpm typecheck && pnpm test`
Expected: grün. Dann `pnpm --filter web dev`, `/` und `/login` bei 1280 px und 320 px im Browser gegen `assets/branding/gymtavo-logo.html` vergleichen (Punkt auf Grundlinie, nichts abgeschnitten).

- [ ] **Schritt 6: Commit**

```bash
git add apps/web/app/branding apps/web/app/page.tsx apps/web/app/einstieg e2e/wurzel.spec.ts
git commit -m "feat(web): GYMTAVO-Wortmarke auf Landeseite und Einstieg"
```

---

### Aufgabe 3: Wortmarke im iOS-Login

**Files:**
- Create: `apps/ios-member/FitnessMember/Assets.xcassets/Contents.json`, `…/Assets.xcassets/GymtavoWordmark.imageset/{Contents.json,gymtavo-wordmark.svg}` (aus dem Patch)
- Create: `apps/ios-member/FitnessMemberTests/MarkenAssetTests.swift`
- Modify: `apps/ios-member/FitnessMember/Screens/Zugang/LoginMailView.swift:13`, `apps/ios-member/FitnessMember.xcodeproj/project.pbxproj` (generiert)

- [ ] **Schritt 1: Roter Test**

`apps/ios-member/FitnessMemberTests/MarkenAssetTests.swift`:

```swift
import Testing
import UIKit

// Fehlt der Katalog in der Resources-Phase, zeigt SwiftUI an der Stelle
// still nichts. Der Test haengt am App-Bundle (TEST_HOST), damit genau
// das auffaellt.
struct MarkenAssetTests {
    @Test func wortmarkeLiegtImAppBundle() {
        #expect(UIImage(named: "GymtavoWordmark", in: .main, with: nil) != nil)
    }
}
```
Dann `cd apps/ios-member && xcodegen generate`, damit die neue Testdatei im Projekt steht.

- [ ] **Schritt 2: Rot bestätigen** (Plattenplatz vorher: `df -h /System/Volumes/Data`, > 3 GB; keine andere Sitzung baut gerade iOS)

Run: `cd apps/ios-member && xcodebuild test -scheme FitnessMember -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FitnessMemberTests/MarkenAssetTests`
Expected: FAIL in `wortmarkeLiegtImAppBundle`.

- [ ] **Schritt 3: Katalog übernehmen und Projekt erzeugen**

```bash
cd ../..   # Worktree-Wurzel
git apply --whitespace=fix --include='apps/ios-member/FitnessMember/Assets.xcassets/*' ~/Downloads/gymtavo-branding-pr/gymtavo-branding.patch
cmp assets/branding/gymtavo-wordmark.svg apps/ios-member/FitnessMember/Assets.xcassets/GymtavoWordmark.imageset/gymtavo-wordmark.svg
cd apps/ios-member && xcodegen generate && git diff --stat FitnessMember.xcodeproj
```
Expected: `cmp` ohne Ausgabe; pbxproj-Diff enthält `Assets.xcassets` in Group und Resources-Phase sowie die Testdatei. Wenn xcodegen darüber hinaus Fremdes umschreibt (Reihenfolge, Einstellungen), das zurücknehmen und stattdessen die vier pbxproj-Hunks aus dem Patch übernehmen: `git checkout FitnessMember.xcodeproj && git apply --include='apps/ios-member/FitnessMember.xcodeproj/*' <patch>`, die Testdatei dann ebenfalls per xcodegen — und im Commit erwähnen.

- [ ] **Schritt 4: LoginMailView** — als erstes Kind des äußeren `VStack` (vor `if pendingTagStore.token != nil`):

```swift
                // Die Marke steht nur hier: Login ist der erste Screen, den
                // ein neues Mitglied sieht, danach traegt der Inhalt.
                Image("GymtavoWordmark")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 26)
                    .accessibilityLabel("GYMTAVO")
```
Höhe 26 statt Rahmen 180×34 aus dem Patch: eine feste Höhe skaliert die Breite aus dem Seitenverhältnis (≈138 pt) und lässt keinen Leerraum im Rahmen; 34 pt stünde größer als der Screentitel „ANMELDEN“. `.renderingMode(.original)` entfällt, weil ein Image aus dem Asset-Katalog ohne Template-Einstellung ohnehin original rendert.

- [ ] **Schritt 5: Grün und volle iOS-Suite**

Run: `xcodebuild test -scheme FitnessMember -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: alle Tests PASS.

- [ ] **Schritt 6: Sichtprüfung** auf iPhone SE (3rd generation)-Simulator und iPhone 17 Pro: Login öffnen, Wortmarke scharf, Punkt grün, Felder und Anmelden-Knopf nicht abgeschnitten (auch mit Tastatur), VoiceOver liest „GYMTAVO“. Vorgehen siehe Memory „Simulator-Sichtcheck per UI-Test“, Screenshots in die PR-Beschreibung.

- [ ] **Schritt 7: Commit**

```bash
git add apps/ios-member/FitnessMember/Assets.xcassets apps/ios-member/FitnessMember/Screens/Zugang/LoginMailView.swift apps/ios-member/FitnessMemberTests/MarkenAssetTests.swift apps/ios-member/FitnessMember.xcodeproj
git commit -m "feat(zugang): GYMTAVO-Wortmarke im Login"
```

---

### Aufgabe 4: Sichtbare Texte im Web

**Files:**
- Modify: `apps/web/app/layout.tsx:4`, `apps/web/app/page.tsx:51,58,60`, `apps/web/app/t/[token]/page.tsx:105,249,250`, `apps/web/app/portal/[studioId]/(schreibtisch)/einstellungen/EinstellungenActions.tsx:117`, `apps/web/app/portal/[studioId]/(schreibtisch)/leute/EinladungErstellen.tsx:75`, `apps/web/app/portal/[studioId]/einrichten/geraet/[machineId]/uebungen/UebungSheet.tsx:116`
- Test: `e2e/wurzel.spec.ts:31,157`, `e2e/tag-fallback.spec.ts:255`, `e2e/schreibtisch.spec.ts:82`

- [ ] **Schritt 1: Tests auf den neuen Namen umstellen (rot)**

In allen vier e2e-Stellen `/gymodo misst nichts/` → `/Gymtavo misst nichts/`. Zusätzlich in `e2e/wurzel.spec.ts` anhängen:

```ts
test("Der Browsertab heisst Gymtavo", async ({ page }) => {
  await page.goto("/");
  await expect(page).toHaveTitle(/Gymtavo/);
});
```

- [ ] **Schritt 2: Rot bestätigen**

Run: `pnpm test:e2e e2e/wurzel.spec.ts e2e/tag-fallback.spec.ts`
Expected: FAIL bei „misst nichts“ und beim Titel. (`schreibtisch.spec.ts:82` bleibt grün — Negativ-Assertion; sie wird erst durch die Umstellung wieder aussagekräftig.)

- [ ] **Schritt 3: Texte ersetzen**

```bash
cd apps/web/app
sed -i '' 's/gymodo/Gymtavo/g' \
  layout.tsx page.tsx 't/[token]/page.tsx' \
  'portal/[studioId]/(schreibtisch)/einstellungen/EinstellungenActions.tsx' \
  'portal/[studioId]/(schreibtisch)/leute/EinladungErstellen.tsx' \
  'portal/[studioId]/einrichten/geraet/[machineId]/uebungen/UebungSheet.tsx'
git diff --stat
```
Danach `git diff` lesen: Kommentare in diesen Dateien, die „gymodo“ als Produkt meinen, sind mitgeändert — das ist in Ordnung. Ein Treffer in einer URL (`gymodo-web`) darf in diesen Dateien nicht vorkommen; falls doch, zurücknehmen.

- [ ] **Schritt 4: Wächter gegen vergessene Stellen**

```bash
git grep -nE '"[^"]*gymodo[^"]*"|>[^<]*gymodo|`[^`]*gymodo' -- apps/web ':!apps/web/lib/testnotiz' ':!apps/web/app/testnotiz' ':!*.test.ts' | grep -v 'gymodo-web\|gymodo\.testnotiz\|gymodo\.web\.portal'
```
Expected: keine Ausgabe. Mehrzeilige JSX-Texte (wie bisher `page.tsx:58`) zusätzlich mit `git grep -n gymodo -- apps/web/app` sichten.

- [ ] **Schritt 5: Grün bestätigen**

Run: `pnpm typecheck && pnpm test && pnpm test:e2e e2e/wurzel.spec.ts e2e/tag-fallback.spec.ts e2e/schreibtisch.spec.ts`
Expected: alle PASS.

- [ ] **Schritt 6: Commit**

```bash
git add apps/web e2e
git commit -m "feat(web): sichtbarer Produktname Gymtavo statt gymodo"
```

---

### Aufgabe 5: Sichtbare Texte in der iOS-App

**Files:**
- Modify: `apps/ios-member/project.yml:32-33` (+ neuer Schlüssel), `apps/ios-member/FitnessMember/Onboarding/OnboardingFlow.swift:187`, `…/Screens/Geraet/ErsteWerteSchritt.swift:34`, `…/Screens/Geraet/GeraetErkanntView.swift:176`, `…/Screens/Geraet/GeraetModel.swift:413,415`, `…/Screens/Geraet/ProblemSheet.swift:24`, `…/Screens/Home/HomeRootView.swift:283`, `…/Screens/Profil/ProfilRootView.swift:278,320`, `…/Screens/Zugang/MemberKeinStudioView.swift:221`, `…/Screens/Zugang/NFCTagLeser.swift:90,119`, `FitnessMember.xcodeproj/project.pbxproj` (generiert)

SwiftUI-Texte werden laut Konvention nicht unit-getestet; abgesichert wird über den Grep-Wächter und die Sichtprüfung.

- [ ] **Schritt 1: Swift-Texte ersetzen** (nur Zeilen, keine ganzen Dateien — `TagLink.swift`, Logger und Testnotiz bleiben)

```bash
cd apps/ios-member/FitnessMember
sed -i '' '187s/gymodo/Gymtavo/' Onboarding/OnboardingFlow.swift
sed -i '' '34s/gymodo/Gymtavo/' Screens/Geraet/ErsteWerteSchritt.swift
sed -i '' '176s/gymodo/Gymtavo/' Screens/Geraet/GeraetErkanntView.swift
sed -i '' '413s/gymodo/Gymtavo/;415s/gymodo/Gymtavo/' Screens/Geraet/GeraetModel.swift
sed -i '' '24s/gymodo/Gymtavo/' Screens/Geraet/ProblemSheet.swift
sed -i '' '283s/gymodo/Gymtavo/' Screens/Home/HomeRootView.swift
sed -i '' '278s/gymodo/Gymtavo/;320s/gymodo/Gymtavo/' Screens/Profil/ProfilRootView.swift
sed -i '' '221s/gymodo/Gymtavo/' Screens/Zugang/MemberKeinStudioView.swift
sed -i '' '90s/gymodo/Gymtavo/;119s/gymodo/Gymtavo/' Screens/Zugang/NFCTagLeser.swift
git diff --stat
```
Vorher mit `git grep -n gymodo -- .` gegen die Zeilennummern abgleichen — haben Aufgaben davor Zeilen verschoben (LoginMailView liegt nicht in der Liste, also nein), Nummern anpassen.

- [ ] **Schritt 2: Info.plist-Texte und Anzeigename** in `apps/ios-member/project.yml`, Target `FitnessMember`, `settings.base`:

```yaml
        INFOPLIST_KEY_CFBundleDisplayName: Gymtavo
        INFOPLIST_KEY_NSCameraUsageDescription: "Gymtavo braucht die Kamera, um den QR-Code am Gerät oder am Studioeingang zu scannen."
        INFOPLIST_KEY_NFCReaderUsageDescription: "Gymtavo liest den NFC-Aufkleber am Gerät, um dich direkt zu diesem Gerät zu bringen."
```
`PRODUCT_NAME` und `PRODUCT_BUNDLE_IDENTIFIER` bleiben. Dann `cd apps/ios-member && xcodegen generate`.

- [ ] **Schritt 3: Wächter**

```bash
git grep -n gymodo -- apps/ios-member/FitnessMember apps/ios-member/project.yml | grep -vE 'gymodo-web|gymodo\.testnotiz|TestnotizMarkdown|^\S+:[0-9]+:\s*///?'
```
Expected: keine Ausgabe.

- [ ] **Schritt 4: Volle iOS-Suite und Sichtprüfung**

Run: `xcodebuild test -scheme FitnessMember -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Expected: PASS. Dann im Simulator: Home-Bildschirm zeigt „Gymtavo“ unter dem Icon; Profil zeigt „Gymtavo <Version>“; Kamera-Berechtigungsdialog nennt Gymtavo.

- [ ] **Schritt 5: Commit**

```bash
git add apps/ios-member
git commit -m "feat(app): sichtbarer Produktname Gymtavo, Anzeigename auf dem Home-Bildschirm"
```

---

### Aufgabe 6: Gesamtprüfung und PR-Entwurf

- [ ] **Schritt 1: Volle Testmenge**

```bash
pnpm typecheck && pnpm test && pnpm test:integration
pnpm test:e2e
cd apps/ios-member && xcodebuild test -scheme FitnessMember -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```
Expected: alles grün; Ergebnisse wörtlich in den Bericht.

- [ ] **Schritt 2: Abnahmeliste in `assets/branding/README.md` abhaken**, soweit geprüft (Browser 320 px, kleines iPhone, VoiceOver). CI-Punkt bleibt offen bis zum Lauf.

- [ ] **Schritt 3: Bericht an Tim**, Push und Draft-PR erst nach Freigabe. Titel: `feat(branding): GYMTAVO-Wortmarke und Produktname in App und Web`. Beschreibung übernimmt den PR-DRAFT (Quelle, Validierung, QR/NFC offen) plus: Textumstellung, was bewusst bleibt (Bundle-ID, Domain, Formatkennungen), Screenshots Web/iOS.

## Offen (nicht in diesem Plan)

- App-Icon, Bundle-ID `de.gymtaro.*`, Domain `gymodo-web.vercel.app` inkl. Associated Domains und gedruckter NFC/QR-Tag-URLs.
- QR/NFC-Aufkleber: finale Datei fehlt, siehe `docs/branding/qr-nfc-design-status.md`.
- Auth-Mails (Supabase-Templates): enthalten heute keinen Produktnamen im Text; bei einer späteren Gestaltung GYMTAVO verwenden.
