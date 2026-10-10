# Wiederholungszähler (Sensor Teilprojekt B), Etappen E1–E3 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Die Produktgrenze „Gymtavo misst nichts“ ist überall herausgenommen (E1), der Wiederholungszähler existiert als reines Swift-Package mit Offline-Tests und Gütebericht über alle Aufnahmen (E2), und der Satz kann Herkunft, Zählerstand und Wiederholungs-Ereignisse speichern (E3).

**Architecture:** E1 ändert nur Texte, Kommentare und Tests. E2 legt `apps/ios-member/Packages/Sensorik` an, zieht die reinen Sensor-Typen aus Teilprojekt A hinein und baut daneben einen regelbasierten Zähler (reine Zustandsmaschine `verarbeite(messwert) -> [ZaehlerEreignis]`), getestet mit `swift test` auf dem Mac und in CI. E3 erweitert `workout_sets` um `volume_source`, `volume_counted`, `rep_events`, die Domäne (`recordSet`) um Schema und Konsistenzregeln und das iOS-DTO um die Felder; die App sendet vorerst immer `eingegeben`.

**Tech Stack:** Swift 6 / Swift Testing / SwiftPM / xcodegen, TypeScript / Zod / Vitest, Supabase Postgres, Playwright, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-10-10-sensor-wiederholungszaehler-design.md` (im Folgenden „Spec B“), dazu `docs/superpowers/specs/2026-09-19-sensor-anbindung-aufzeichnung-design.md` („Spec A“).

**Nicht in diesem Plan:** E4 (Zähler live im Satzpfad) und E5 (Release hinter dem Gütetor) bekommen einen eigenen Plan, sobald Gymtavo-Katalog Etappe 4 (iOS) gemergt ist — beide ändern `GeraetModel`, `SetWrite` und `SatzMitschnittKontext`, und ein heute geschriebener E4-Plan würde gegen veralteten Code planen.

## Global Constraints

- Eigener Worktree unter `.claude/worktrees/` von `origin/master`; `.env` und `apps/ios-member/Config.xcconfig` hineinkopieren. Andere Sessions laufen parallel.
- Nur eine Session baut iOS zur selben Zeit: vor jedem `xcodebuild` `pgrep -lx xcodebuild` prüfen. Simulator per ID: `-destination 'id=A2FB7461-E303-4CFE-AA08-9AC1B8C41707'` (iPhone 17 Pro; zwei Simulatoren tragen den Namen).
- Nach jeder Änderung an `project.yml` oder an Dateien im App-/Test-Target: `cd apps/ios-member && xcodegen generate` und das erzeugte `project.pbxproj` mit committen.
- Commits deutsch mit ae/oe/ue, Form `feat(sensorik): …` / `fix(…)` / `docs(…)` / `test(…)`, ein Commit je Schritt. Trailer exakt: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Nach jedem Commit `git log -1 --format=%B` prüfen.
- Swift-Kommentare ASCII (ae/oe/ue/ss), sie nennen einen Grund statt den Code zu beschreiben. Tests mit Swift Testing (`@Test`, `#expect`, `#require`).
- Docs (Markdown) mit echten Umlauten, wie die bestehenden Specs. Nutzertexte in App und Web mit echten Umlauten.
- Kanonischer Satz (Spec B 3.2), wörtlich: `Gymtavo speichert nur, was du bestätigst. Mit Sensor zählt Gymtavo deine Wiederholungen mit — du siehst die Zahl und entscheidest. Einweisungsvideos und Einstellhinweise sind Inhalte deines Studios, keine Trainings- oder Gesundheitsempfehlung von Gymtavo.`
- Befestigungsarten, Rohwerte wörtlich: `stapel, langhantel, kurzhantel, hebelarm, kabelgriff, koerper`. Unsicher-Gründe: `luecke, signalSchwach, taktUnregelmaessig`. Herkunft: `eingegeben, gemessen, korrigiert`.
- Gütetor (Spec B 5.5): je Art im Torset ≥ 20 Sätze aus ≥ 3 Trainingstagen, exakt ≥ 90 %, ±1 ≥ 98 %, Rücknahmen ≤ 10 %.
- Volles Testset vor dem Melden: `pnpm typecheck`, `pnpm test`, `pnpm test:integration`, `swift test --package-path apps/ios-member/Packages/Sensorik`, `xcodebuild test -scheme FitnessMember -destination 'id=A2FB7461-E303-4CFE-AA08-9AC1B8C41707'` (aus `apps/ios-member`). Bei Web-Text-Änderungen zusätzlich die betroffenen e2e-Specs. Rote lokale Tests erst gegen die bekannten Umgebungsfallen prüfen (geteilte Supabase-DB, Docker-Uhr, wiederverwendeter Dev-Server).
- Die lokale Supabase-DB ist mit anderen Worktrees geteilt: nie zurücksetzen. Die Migration aus E3 ist rein additiv (Default) und darf mit `pnpm exec supabase migration up` eingespielt werden.
- Nicht pushen, bis Tim es sagt.

## Review Focus

1. **Warteschlangen-Einträge älterer Builds** (`PendingWriteStore` auf Platte, ohne `volumeSource`): müssen nach dem Update dekodieren und als `eingegeben` gesendet werden — sonst gehen genau die Offline-Sätze verloren. Test in Task 11.
2. **Alte App-Versionen ohne die neuen Felder** am Server: PUT muss wie heute durchgehen und `eingegeben` speichern. Test in Task 10.
3. **Gebündelte Zeitstempel** (zwei bis vier Messwerte mit identischem `t`, Raster 30–60 ms) dürfen die Zählung nicht verändern und keine Division durch null auslösen. Test in Task 6.
4. **Zeilenende-Varianten und leere Zeilen in `messwerte.csv`** (vom iPhone kopiert, eventuell mit abschließender Leerzeile): der Leser im Package darf daran nicht scheitern. Test in Task 4.
5. **Gütebericht-Test bei fehlenden Daten** (Ordner ohne Eintrag in `korrekturen.json`, Ordner ohne `messwerte.csv`, Ratentest-JSON-Dateien im selben Verzeichnis): Bericht muss solche Einträge überspringen statt zu werfen. Test in Task 8.

---

## Teil E1 — Die Produktgrenze fällt

E1 ist ein eigener PR (Branch z. B. `claude/sensor-b-e1-produktgrenze`).

### Task 1: Normative Docs und Specs nachtragen

**Files:**
- Modify: `fitness-retrofit-technical-blueprint.md:99-101`, `:1254`
- Modify: `docs/superpowers/specs/2026-08-28-fitness-retrofit-m1-design.md:112`, `:114-118`, `:609`
- Modify: `docs/superpowers/specs/2026-08-30-designsystem.md:180-182`, `:228`
- Modify: `docs/superpowers/specs/2026-09-19-sensor-anbindung-aufzeichnung-design.md:6`, `:42`, `:338`
- Modify: `docs/superpowers/specs/2026-10-03-landeseite-neu-gpath-referenz.md:100`, `:319`, `:333`, `:336`
- Modify: `docs/superpowers/specs/2026-09-13-ziele-und-fortschritt-design.md:21`, `:252`
- Modify: `docs/superpowers/specs/2026-09-09-ios-home-profil-design.md:157`, `:197`
- Modify: `docs/superpowers/specs/2026-09-10-ios-geraet-ohne-scan-design.md:236`
- Modify: `docs/superpowers/specs/2026-09-21-cardio-geraete-design.md:433`

**Interfaces:**
- Consumes: Spec B 3.1 (Regel), 3.2 (Texte), 3.3 (Fundstellen).
- Produces: Designsystem §10 trägt den kanonischen Satz, den Task 2 und 3 wörtlich übernehmen.

Zeilennummern stammen von `master` `64595c0`; vor dem Bearbeiten mit `grep -n "misst nichts\|Produktgrenze" <datei>` gegenprüfen.

- [ ] **Step 1: Blueprint §2.3 ersetzen.** Den Absatz unter `### 2.3 Wichtigste Produktgrenze` so ändern:

```markdown
### 2.3 Wichtigste Produktgrenze

> **Nachtrag 10. Oktober 2026** (Teilprojekt B, `docs/superpowers/specs/2026-10-10-sensor-wiederholungszaehler-design.md` §3): Die Grenze „die Plattform misst nichts“ ist aufgehoben. Es gilt:
>
> Die Plattform speichert nur, was das Mitglied bestätigt. Messen darf sie nur über den Bewegungssensor und nur, was ein Zähler mit nachgewiesener Güte erfasst — heute die Wiederholungen. Gewicht, Ausführungsqualität und Körperdaten misst sie nicht und behauptet es nicht. Jede gezählte Zahl trägt ihre Herkunft am Satz.

~~Ohne Sensorik kennt die Plattform nur Daten, die der Trainer vorgibt oder das Mitglied bestätigt. Sie darf nicht behaupten, die tatsächliche Ausführung, das eingestellte Gewicht oder die absolvierten Wiederholungen automatisch gemessen zu haben.~~
```

In der Risikotabelle (`:1254`) hinter „klare Produktgrenze“ ergänzen: `(seit 10.10.2026 in der Fassung aus §2.3)`.

- [ ] **Step 2: M1-Spec.** In §4.2 `jede Form von Sensorik.` ersetzen durch `jede Form von Sensorik in M1 (der Bewegungssensor folgt mit Teilprojekt B, `2026-10-10-sensor-wiederholungszaehler-design.md`).` In §4.3 die Zeile `Unverändert aus Blueprint §2.3, und sie gilt uneingeschränkt:` und das Zitat ersetzen durch:

```markdown
> **Nachtrag 10. Oktober 2026:** ersetzt durch die neue Fassung in Blueprint §2.3 (Teilprojekt B, `2026-10-10-sensor-wiederholungszaehler-design.md` §3):
>
> Die Plattform speichert nur, was das Mitglied bestätigt. Messen darf sie nur über den Bewegungssensor und nur, was ein Zähler mit nachgewiesener Güte erfasst — heute die Wiederholungen. Gewicht, Ausführungsqualität und Körperdaten misst sie nicht und behauptet es nicht. Jede gezählte Zahl trägt ihre Herkunft am Satz.

~~Unverändert aus Blueprint §2.3, und sie gilt uneingeschränkt: „Ohne Sensorik kennt die Plattform nur Daten, die das Mitglied bestätigt. Sie darf nicht behaupten, die tatsächliche Ausführung, das eingestellte Gewicht oder die absolvierten Wiederholungen gemessen zu haben.“~~
```

Der Absatz „Ergänzend: Die Einweisungsinhalte …“ bleibt unverändert. In der Risikotabelle (`:609`) hinter „Produktgrenze in der UI“ ergänzen: `(Wortlaut seit 10.10.2026: Designsystem §10)`.

- [ ] **Step 3: Designsystem §10 und §13.** Das Zitat unter „Produktgrenze im Klartext“ ersetzen:

```markdown
- **Produktgrenze im Klartext**, sichtbar auf Geräte-Screen und Profil (Wortlaut seit 10. Oktober 2026, Teilprojekt B §3.2; vorher „gymodo misst nichts. Angezeigt wird ausschließlich, was du selbst bestätigt hast. …“):

  > Gymtavo speichert nur, was du bestätigst. Mit Sensor zählt Gymtavo deine Wiederholungen mit — du siehst die Zahl und entscheidest. Einweisungsvideos und Einstellhinweise sind Inhalte deines Studios, keine Trainings- oder Gesundheitsempfehlung von Gymtavo.
```

In §13 `sie muss nachprüfbar bleiben, weil die Plattform nichts misst.` ersetzen durch `sie muss nachprüfbar bleiben, weil nur Bestätigtes gespeichert wird.`

- [ ] **Step 4: Specs mit Verweisen.** Je Fundstelle eine Nachtrag-Zeile direkt unter der Stelle, Form: `> **Nachtrag 10. Oktober 2026:** <Satz>. Siehe `2026-10-10-sensor-wiederholungszaehler-design.md` §3.` Die Sätze:
  - Spec A `:6` und `:42`: „Die Grenze ist mit Teilprojekt B gefallen; es gilt die neue Fassung in Blueprint §2.3.“ — `:338` (§11.2): „Erledigt mit Teilprojekt B.“
  - Landeseite `:100`: „Der Wortlaut ist entschieden: der kanonische Satz aus Designsystem §10 statt des Vorschlags hier.“ — `:319` (Widerspruchstabelle): „Aufgelöst: die Grenze ist gefallen, App, Landeseite und `/t/[token]` tragen den neuen Satz.“ — `:333` und `:336`: „Mit E1 von Teilprojekt B zusammen umgezogen.“
  - Ziele `:21` und `:252`: „‚misst nichts‘ ist aufgehoben; für Körperdaten bleibt es strenger: keine Messung, kein HealthKit, nur Eingabe.“
  - Home/Profil `:157` und `:197`: „Neue Texte: Home ‚Gymtavo zeigt, was du bestätigst.‘, Profil siehe Teilprojekt B §3.2.“
  - Gerät ohne Scan `:236`: „Die Regel gilt sinngemäß weiter: kein Wort behauptet eine Messung, wo keine stattfand.“
  - Cardio `:433`: „Der Grund ist jetzt: der Sensor zählt nur Wiederholungen; Nebenwerte liest das Mitglied weiter von der Anzeige ab.“

- [ ] **Step 5: Gegenprobe.** Run: `grep -rn "misst nichts" fitness-retrofit-technical-blueprint.md docs/superpowers/specs/ | grep -v "Nachtrag\|~~\|vorher „gymodo"` — Expected: nur noch Treffer in historischen Befund-Specs (`2026-09-03-portal-frontend-design.md`, `2026-09-07-member-app-design-challenge.md`, `2026-09-08-ios-training-kurse-design.md`) und in Spec B selbst.

- [ ] **Step 6: Commit**

```bash
git add fitness-retrofit-technical-blueprint.md docs/superpowers/specs/
git commit -m "docs: Produktgrenze \"misst nichts\" faellt (Sensor Teilprojekt B)

Nachtraege in Blueprint 2.3, M1 4.2/4.3, Designsystem 10/13 und den
Specs mit Verweisen. Abgeschlossene Plaene und Artboards bleiben.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log -1 --format=%B
```

### Task 2: iOS-Texte, Kommentare und Tests

**Files:**
- Create: `apps/ios-member/FitnessMember/DesignSystem/Produktgrenze.swift`
- Create: `apps/ios-member/FitnessMemberTests/ProduktgrenzeTests.swift`
- Modify: `apps/ios-member/FitnessMember/Screens/Geraet/GeraetModel.swift:529-533`
- Modify: `apps/ios-member/FitnessMember/Screens/Home/HomeRootView.swift:354`
- Modify: `apps/ios-member/FitnessMember/Screens/Profil/ProfilRootView.swift:276-286`
- Modify: `apps/ios-member/project.yml:36-39`
- Modify (Kommentare): `Screens/Training/TrainingRootView.swift:356`, `Screens/Training/TrainingStartView.swift:11`, `Verlauf/HomeZeilen.swift:240`, `Screens/Home/UebungsfortschrittView.swift:145`, `Screens/Geraet/WertZeile.swift:125`
- Modify: `apps/ios-member/FitnessMemberTests/GeraetEinstiegsartTests.swift:5-10`

**Interfaces:**
- Produces: `enum Produktgrenze { static let kanonisch: String }` im App-Target.

- [ ] **Step 1: Failing test schreiben** — `apps/ios-member/FitnessMemberTests/ProduktgrenzeTests.swift`:

```swift
import Testing
@testable import FitnessMember

/// Der Satz steht wortgleich in designsystem.md SS10, auf der Landeseite
/// und auf /t/[token]. Laeuft er hier auseinander, sagt die App etwas
/// anderes als das Web -- genau das, was Befund 19 verhindern sollte.
struct ProduktgrenzeTests {
    @Test func derKanonischeSatzStimmtMitDemDesignsystemUeberein() {
        #expect(Produktgrenze.kanonisch == "Gymtavo speichert nur, was du bestätigst. Mit Sensor zählt Gymtavo deine Wiederholungen mit — du siehst die Zahl und entscheidest. Einweisungsvideos und Einstellhinweise sind Inhalte deines Studios, keine Trainings- oder Gesundheitsempfehlung von Gymtavo.")
    }

    @Test func derSatzBehauptetNichtMehrDassNichtsGemessenWird() {
        #expect(!Produktgrenze.kanonisch.contains("misst nichts"))
    }
}
```

- [ ] **Step 2: Test laufen lassen, er schlägt fehl.** `cd apps/ios-member && xcodegen generate && pgrep -lx xcodebuild; xcodebuild test -scheme FitnessMember -destination 'id=A2FB7461-E303-4CFE-AA08-9AC1B8C41707' -only-testing:FitnessMemberTests/ProduktgrenzeTests 2>&1 | tail -20` — Expected: Kompilierfehler `cannot find 'Produktgrenze' in scope`.

- [ ] **Step 3: Implementieren.** `apps/ios-member/FitnessMember/DesignSystem/Produktgrenze.swift`:

```swift
import Foundation

/// Eine Quelle fuer den Satz aus designsystem.md SS10 (Wortlaut seit
/// Sensor Teilprojekt B, Spec 3.2). Eigene Datei statt einer Eigenschaft
/// von GeraetModel, damit der Test ihn ohne Geraetekontext pruefen kann.
enum Produktgrenze {
    static let kanonisch = """
        Gymtavo speichert nur, was du bestätigst. Mit Sensor zählt Gymtavo \
        deine Wiederholungen mit — du siehst die Zahl und entscheidest. \
        Einweisungsvideos und Einstellhinweise sind Inhalte deines Studios, \
        keine Trainings- oder Gesundheitsempfehlung von Gymtavo.
        """
}
```

In `GeraetModel.swift` die Eigenschaft ersetzen:

```swift
    /// Pflichtort laut designsystem.md SS10.
    let produktgrenze = Produktgrenze.kanonisch
```

`HomeRootView.swift:354`: `Text("Gymtavo zeigt, was du bestätigst.")`.

`ProfilRootView.swift`, erster Text in `deineDaten`:

```swift
            Text(
                "Gespeichert wird nur, was du selbst bestätigst — Einstellwerte, Sätze, ob ein Trainer dabei war. Vom Sensor gezählte Wiederholungen zählen erst, wenn du den Satz sicherst."
            )
```

Den Kommentar darunter (`:280-284`) ändern in: `// Zweiter Satz seit Aufgabe 10 (Brief Step 2), woertlich aus dem Artboard: Koerperdaten und Ziele bleiben reine Eingabe -- strenger als die Grenze fuer Saetze (Sensor-Spec B 3.2). Eine eigene Zeile, kein angehaengter Halbsatz an der Zeile ueber Einstellwerten und Saetzen, die etwas anderes meint.` Den zweiten Text selbst nur ändern, wenn er „misst“ enthält (dann „misst nichts“ streichen, Rest wörtlich lassen).

`project.yml:39`: `INFOPLIST_KEY_NSBluetoothAlwaysUsageDescription: "Gymtavo verbindet sich mit deinem Bewegungssensor, um deine Wiederholungen zu zählen."` Der Kommentar darüber bleibt.

Kommentare, jeweils nur die Begründung austauschen:
- `TrainingRootView.swift:356`: `// Ohne Satz gibt es keine bestaetigte Zahl -- also auch keine`
- `TrainingStartView.swift:11`: `/// Satzpfad, und Zahlen gibt es erst mit einem bestaetigten Satz.`
- `HomeZeilen.swift:240`: `/// dazwischen ist keine (keine Zahl, die nicht aus bestaetigten Saetzen kommt).`
- `UebungsfortschrittView.swift:145`: `/// Die Kurve fasst bestaetigte Saetze zusammen und muss nachpruefbar`
- `WertZeile.swift:125`: `/// Minuten und Meter liest das Mitglied von der Anzeige des Geraets ab -- der Sensor zaehlt nur Wiederholungen --`
- `GeraetEinstiegsartTests.swift:8-10`: `/// Auswahl hat jemand etwas angetippt. Ein Wort, das eine Messung behauptet, wo keine stattfand, bleibt auch nach Sensor-Spec B verboten: erkannt wird das Geraet, gemessen wird es nicht.`

- [ ] **Step 4: Tests laufen lassen.** `cd apps/ios-member && xcodegen generate && pgrep -lx xcodebuild; xcodebuild test -scheme FitnessMember -destination 'id=A2FB7461-E303-4CFE-AA08-9AC1B8C41707' 2>&1 | tail -20` — Expected: `** TEST SUCCEEDED **`. Danach `grep -rn "misst nichts" apps/ios-member/FitnessMember apps/ios-member/FitnessMemberTests` — Expected: nur der zweite Test in `ProduktgrenzeTests.swift`.

- [ ] **Step 5: Commit**

```bash
git add apps/ios-member/
git commit -m "feat(ios): neue Produktgrenze statt \"Gymtavo misst nichts\"

Kanonischer Satz als Konstante mit Test, neue Texte in Home und Profil,
Bluetooth-Text \"zaehlen\", Kommentare nennen den eigentlichen Grund.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log -1 --format=%B
```

### Task 3: Web-Texte, Kommentar in der Domäne und e2e-Tests

**Files:**
- Modify: `apps/web/app/landung/texte.ts:100-101`
- Modify: `apps/web/app/t/[token]/page.tsx:248-251`
- Modify: `packages/domain/src/progression.ts:9`
- Modify: `e2e/wurzel.spec.ts:64`, `e2e/tag-fallback.spec.ts:253`, `e2e/schreibtisch.spec.ts:81`

- [ ] **Step 1: e2e-Tests auf den neuen Satz umstellen (schlagen danach fehl).**
  - `e2e/wurzel.spec.ts:64`: `const satz = page.getByRole("contentinfo").getByText(/Gymtavo speichert nur, was du bestätigst/);`
  - `e2e/tag-fallback.spec.ts:253`: `const grenze = page.getByText(/Gymtavo speichert nur, was du bestätigst/);`
  - `e2e/schreibtisch.spec.ts:81`: `await expect(page.getByText(/Gymtavo speichert nur|misst nichts/)).toHaveCount(0);`

- [ ] **Step 2: Rot prüfen.** Produktions-Build wie CI (Dev-Server flakt bei langen Specs): `APPLE_TEAM_ID=ABCDE12345 APPLE_BUNDLE_ID=de.fitretro.member pnpm build`, dann alten Server auf dem Port beenden und `(set -a; . ./.env; set +a; pnpm --filter @fitretro/web start -p 3007 &)`; `E2E_PORT=3007 pnpm test:e2e e2e/wurzel.spec.ts e2e/tag-fallback.spec.ts` — Expected: die beiden Produktgrenze-Tests FAIL (Text nicht gefunden). Nach dem Build untracked `apps/web/AGENTS.md` / `apps/web/CLAUDE.md` löschen, falls entstanden.

- [ ] **Step 3: Texte ändern.**

`apps/web/app/landung/texte.ts`:

```ts
export const PRODUKTGRENZE =
  "Gymtavo speichert nur, was du bestätigst. Mit Sensor zählt Gymtavo deine Wiederholungen mit — du siehst die Zahl und entscheidest. Einweisungsvideos und Einstellhinweise sind Inhalte deines Studios, keine Trainings- oder Gesundheitsempfehlung von Gymtavo.";
```

Die FAQ-Einträge „Was misst Gymtavo?“ und „Wann kommt der Sensor?“ bleiben (Spec B 3.2).

`apps/web/app/t/[token]/page.tsx`:

```tsx
      <p className={styles.grenze}>
        Gymtavo speichert nur, was du bestätigst. Mit Sensor zählt Gymtavo deine
        Wiederholungen mit — du siehst die Zahl und entscheidest. Einweisungsvideos
        und Einstellhinweise sind Inhalte deines Studios, keine Trainings- oder
        Gesundheitsempfehlung von Gymtavo.
      </p>
```

`packages/domain/src/progression.ts:9`: ` * das Mitglied -- die Regel rechnet nur auf bestaetigten Saetzen (Spec Abschnitt 4.3).`

- [ ] **Step 4: Grün prüfen.** Neu bauen und starten wie in Step 2, dann `E2E_PORT=3007 pnpm test:e2e e2e/wurzel.spec.ts e2e/tag-fallback.spec.ts e2e/schreibtisch.spec.ts` — Expected: alle PASS. Zusätzlich `pnpm typecheck && pnpm test`. Gegenprobe: `grep -rn "misst nichts" apps/web packages e2e` — Expected: nur das Negativmuster in `schreibtisch.spec.ts` und der Fixture-Text in `apps/web/app/landung/Fragen.test.tsx` (prüft Escaping, nicht den Inhalt; bleibt).

- [ ] **Step 5: Commit**

```bash
git add apps/web packages/domain/src/progression.ts e2e
git commit -m "feat(web): neue Produktgrenze auf Landeseite und Tag-Fallback

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log -1 --format=%B
```

---

## Teil E2 — Package `Sensorik` und Zähler

E2 ist ein eigener PR (Branch z. B. `claude/sensor-b-e2-zaehler`), unabhängig von E1 und E3.

### Task 4: Package anlegen und reine Typen aus A hineinziehen

**Files:**
- Create: `apps/ios-member/Packages/Sensorik/Package.swift`
- Create: `apps/ios-member/Packages/Sensorik/Sources/Sensorik/SensorikJSON.swift`
- Move (`git mv`) von `apps/ios-member/FitnessMember/Workout/Sensor/` nach `apps/ios-member/Packages/Sensorik/Sources/Sensorik/`: `SensorMesswert.swift`, `WitMotionPaket.swift`, `WitMotionBefehl.swift`, `SensorStatistik.swift`, `SensorAufnahmeDatei.swift`, `SensorAufnahmeLeser.swift`, `SensorAufnahme.swift`
- Move von `apps/ios-member/FitnessMemberTests/` nach `apps/ios-member/Packages/Sensorik/Tests/SensorikTests/`: `WitMotionPaketTests.swift`, `WitMotionBefehlTests.swift`, `SensorStatistikTests.swift`, `SensorAufnahmeTests.swift`
- Create: `apps/ios-member/Packages/Sensorik/Tests/SensorikTests/SensorAufnahmeLeserTests.swift`
- Create: `apps/ios-member/Packages/Sensorik/Tests/SensorikTests/Pfade.swift`
- Modify: `apps/ios-member/project.yml` (packages, dependencies)
- Modify (nur `import Sensorik` ergänzen): `FitnessMember/Workout/Sensor/{AbspielSensorQuelle,BluetoothSensorQuelle,SensorAufnahmeKoordinator,SensorQuelle}.swift`, `FitnessMember/Screens/Geraet/SensorDiagnoseBlatt.swift`, `FitnessMemberTests/{AbspielSensorQuelleTests,SensorAufnahmeKoordinatorTests}.swift` und jede weitere Datei, die der Compiler meldet
- Modify: `.github/workflows/ci.yml` (neuer Job `sensorik`)

**Interfaces:**
- Produces (alle `public`, Verhalten unverändert): `Vektor3`, `SensorMesswert`, `WitMotionPaket`, `WitMotionParser`, `WitMotionBefehl`, `SensorRate`, `SensorStatistik` (+ `Ergebnis`, `Abstand`), `SensorAufnahmeDatei` (+ Untertypen), `SensorRatentestDatei`, `SensorAufnahmeLeser` (+ `Eintrag`, `Fehler`), `SensorAufnahme`; neu `SensorikJSON.encoder(zeitzone:)`, `SensorikJSON.decoder()`.
- Produces (Testziel): `enum Pfade { static let repo: URL; static let aufnahmen: URL; static let beispiel: URL }`.

- [ ] **Step 1: Package-Gerüst.** `apps/ios-member/Packages/Sensorik/Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

// Eigenes Package statt Ordner im App-Target (Sensor-Spec B 5.1): die
// Zaehler-Iterationen laufen mit `swift test` auf dem Mac in Sekunden,
// ohne Simulator und ohne einen xcodebuild, der parallele Sessions blockiert.
let package = Package(
    name: "Sensorik",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "Sensorik", targets: ["Sensorik"])],
    targets: [
        .target(name: "Sensorik"),
        .testTarget(name: "SensorikTests", dependencies: ["Sensorik"]),
    ]
)
```

- [ ] **Step 2: Dateien verschieben.** `git mv` für die sieben Quell- und vier Testdateien wie oben. In jeder verschobenen Quelldatei die Zeilen `#if DEBUG` und das zugehörige `#endif` entfernen (Grund: das Package liegt im Release ungenutzt bei, Spec B 5.1).

- [ ] **Step 3: Coder des Packages.** `Sources/Sensorik/SensorikJSON.swift`:

```swift
import Foundation

/// Kodierung von aufnahme.json und ratentest-*.json. Gleiches Verhalten wie
/// JSONEncoder.testnotiz / JSONDecoder.testnotiz im App-Target (Spec A 6.3:
/// ISO 8601 mit Offset, ohne Sekundenbruchteile) -- als eigene Kopie, weil
/// das Package das Testnotiz-Modul nicht kennen darf.
public enum SensorikJSON {
    public static func encoder(zeitzone: TimeZone = .current) -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let stil = Date.ISO8601FormatStyle(timeZoneSeparator: .colon, timeZone: zeitzone)
        encoder.dateEncodingStrategy = .custom { datum, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(datum.formatted(stil))
        }
        return encoder
    }

    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
```

In `SensorAufnahme.swift` und `SensorAufnahmeLeser.swift` `JSONEncoder.testnotiz(zeitzone:)` → `SensorikJSON.encoder(zeitzone:)` und `JSONDecoder.testnotiz()` → `SensorikJSON.decoder()`. `Zeitformat.ordnername(start, zeitzone:)` in `SensorAufnahme.init` ersetzen durch eine private statische Funktion in `SensorAufnahme`:

```swift
    /// yyyy-MM-dd-HHmm wie Zeitformat.ordnername im App-Target (Spec A 6.1).
    private static func ordnername(_ datum: Date, zeitzone: TimeZone) -> String {
        var kalender = Calendar(identifier: .gregorian)
        kalender.timeZone = zeitzone
        let t = kalender.dateComponents([.year, .month, .day, .hour, .minute], from: datum)
        return String(format: "%04d-%02d-%02d-%02d%02d", t.year!, t.month!, t.day!, t.hour!, t.minute!)
    }
```

- [ ] **Step 4: `public` setzen.** Jeden Typ aus „Produces“ samt der Eigenschaften, Initialisierer, Methoden und Fälle, die App-Target oder Tests benutzen, `public` machen. Für Structs mit synthetisiertem memberwise-Init, die das App-Target konstruiert (`SensorMesswert`, `Vektor3`, `SensorAufnahmeDatei.Sensor`, `.Geraet`, `.Kontext`, `.Label`, `SensorStatistik.Ergebnis`, `.Abstand`, `SensorAufnahmeDatei`, `SensorRatentestDatei`), einen expliziten `public init(...)` mit denselben Parametern in derselben Reihenfolge schreiben (Grund: der synthetisierte Init ist `internal` und vom App-Target aus unsichtbar). Faustregel: kompilieren lassen und jede Meldung `'x' is inaccessible due to 'internal' protection level` durch `public` an der genannten Stelle beheben, nichts darüber hinaus.

- [ ] **Step 5: Pfade für Tests.** `Tests/SensorikTests/Pfade.swift`:

```swift
import Foundation

/// Die Aufnahmen liegen im Repo, nicht im Testbundle: sie wachsen mit jedem
/// Training, und `swift test` soll immer den aktuellen Stand lesen, ohne
/// dass jemand Ressourcen nachpflegt.
enum Pfade {
    /// .../apps/ios-member/Packages/Sensorik/Tests/SensorikTests/Pfade.swift -> Repo-Wurzel
    static let repo: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // SensorikTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // Sensorik
        .deletingLastPathComponent() // Packages
        .deletingLastPathComponent() // ios-member
        .deletingLastPathComponent() // apps
        .deletingLastPathComponent() // Repo

    static let aufnahmen = repo.appendingPathComponent("data/sensoraufnahmen")

    /// Das verbindliche Beispiel aus Spec A 6 bleibt bei den App-Tests liegen
    /// (AbspielSensorQuelleTests liest es als Bundle-Ressource).
    static let beispiel = repo.appendingPathComponent(
        "apps/ios-member/FitnessMemberTests/Fixtures/sensoraufnahme-beispiel")
}
```

- [ ] **Step 6: Verschobene Tests umstellen.** In den vier verschobenen Testdateien `@testable import FitnessMember` → `@testable import Sensorik`. Nutzt ein Test App-Typen (z. B. `JSONDecoder.testnotiz()`), durch `SensorikJSON.decoder()` ersetzen.

- [ ] **Step 7: Failing test für den Leser** — `Tests/SensorikTests/SensorAufnahmeLeserTests.swift`:

```swift
import Foundation
import Testing
@testable import Sensorik

struct SensorAufnahmeLeserTests {
    @Test func dasVerbindlicheBeispielIstLesbar() throws {
        let gelesen = try SensorAufnahmeLeser.lesen(ordner: Pfade.beispiel)
        #expect(gelesen.datei.format == SensorAufnahmeDatei.formatkennung)
        #expect(!gelesen.eintraege.isEmpty)
    }

    /// Vom iPhone kopierte Dateien enden mit Leerzeile; ein Windows-Editor
    /// macht CRLF daraus. Beides darf den Leser nicht stoppen.
    @Test func leereZeilenUndCRLFWerdenUebersprungen() throws {
        let ordner = FileManager.default.temporaryDirectory
            .appendingPathComponent("leser-\(UUID().uuidString)")
        try FileManager.default.copyItem(at: Pfade.beispiel, to: ordner)
        defer { try? FileManager.default.removeItem(at: ordner) }
        let csvURL = ordner.appendingPathComponent("messwerte.csv")
        let original = try String(contentsOf: csvURL, encoding: .utf8)
        let anzahlVorher = try SensorAufnahmeLeser.lesen(ordner: ordner).eintraege.count
        let verbogen = original.replacingOccurrences(of: "\n", with: "\r\n") + "\r\n\r\n"
        try verbogen.write(to: csvURL, atomically: true, encoding: .utf8)
        #expect(try SensorAufnahmeLeser.lesen(ordner: ordner).eintraege.count == anzahlVorher)
    }

    @Test func alleEchtenAufnahmenSindLesbar() throws {
        let ordner = try FileManager.default.contentsOfDirectory(
            at: Pfade.aufnahmen, includingPropertiesForKeys: [.isDirectoryKey])
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
        #expect(!ordner.isEmpty)
        for aufnahme in ordner {
            _ = try SensorAufnahmeLeser.lesen(ordner: aufnahme)
        }
    }
}
```

- [ ] **Step 8: Laufen lassen.** `swift test --package-path apps/ios-member/Packages/Sensorik 2>&1 | tail -30` — Expected: alle bisherigen Tests PASS; `leereZeilenUndCRLFWerdenUebersprungen` FAIL, falls der Leser bei `\r` oder Leerzeilen wirft (sonst PASS — dann ist Step 9 nur die Absicherung).

- [ ] **Step 9: Leser robust machen** (nur falls Step 8 rot). In `SensorAufnahmeLeser.lesen` die Zeilenschleife so beginnen:

```swift
        for rohzeile in csv.split(whereSeparator: \.isNewline).dropFirst() {
            // Leerzeilen am Ende kommen vom iPhone, \r von Editoren -- beides
            // ist kein Messwert und kein Fehler.
            let zeile = rohzeile.trimmingCharacters(in: .whitespaces)
            if zeile.isEmpty { continue }
```

(`split(whereSeparator: \.isNewline)` trennt auch an `\r\n`.) Danach Step 8 wiederholen — Expected: PASS.

- [ ] **Step 10: App-Target einbinden.** `apps/ios-member/project.yml`:

```yaml
packages:
  Supabase:
    url: https://github.com/supabase/supabase-swift
    from: 2.0.0
  Sensorik:
    path: Packages/Sensorik
```

Unter `targets.FitnessMember.dependencies` ergänzen `- package: Sensorik`, ebenso unter `targets.FitnessMemberTests.dependencies` (die App-Tests importieren `Sensorik` direkt). In jeder App- und App-Test-Datei, die einen verschobenen Typ benutzt, `import Sensorik` ergänzen (innerhalb des `#if DEBUG`-Blocks, nach `import Foundation`). `cd apps/ios-member && xcodegen generate`.

- [ ] **Step 11: App bauen und testen.** `pgrep -lx xcodebuild; cd apps/ios-member && xcodebuild test -scheme FitnessMember -destination 'id=A2FB7461-E303-4CFE-AA08-9AC1B8C41707' 2>&1 | tail -20` — Expected: `** TEST SUCCEEDED **`. Zusätzlich Release kompilieren: `xcodebuild build -scheme FitnessMember -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5` — Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 12: CI-Job.** In `.github/workflows/ci.yml` unter `jobs:` ergänzen:

```yaml
  # Der Zaehler und das Aufnahmeformat sind reines Foundation (Sensor-Spec
  # B 5.1) -- Linux reicht und kostet einen Bruchteil eines macOS-Runners.
  sensorik:
    runs-on: ubuntu-latest
    container: swift:6.2-noble
    steps:
      - uses: actions/checkout@v4
      - run: swift test --package-path apps/ios-member/Packages/Sensorik
```

Lokal gegenprüfen, falls Docker läuft: `docker run --rm -v "$PWD":/w -w /w swift:6.2-noble swift test --package-path apps/ios-member/Packages/Sensorik 2>&1 | tail -5` — Expected: alle PASS. Schlägt es nur unter Linux fehl (eine Foundation-API fehlt dort), die Stelle mit einer Linux-tauglichen Alternative ersetzen; geht das nicht, den Job auf `runs-on: macos-15` ohne `container` umstellen und den Grund im Kommentar nennen.

- [ ] **Step 13: Commit**

```bash
git add apps/ios-member .github/workflows/ci.yml
git commit -m "feat(sensorik): Package Sensorik mit den reinen Typen aus Teilprojekt A

Parser, Befehle, Statistik und Aufnahmeformat wandern unveraendert in ein
lokales Package; Tests laufen mit swift test auf dem Mac und in CI.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log -1 --format=%B
```

### Task 5: Zähler-Typen und `RepEvents`

**Files:**
- Create: `apps/ios-member/Packages/Sensorik/Sources/Sensorik/Befestigungsart.swift`
- Create: `apps/ios-member/Packages/Sensorik/Sources/Sensorik/ZaehlerEreignis.swift`
- Create: `apps/ios-member/Packages/Sensorik/Sources/Sensorik/RepEvents.swift`
- Test: `apps/ios-member/Packages/Sensorik/Tests/SensorikTests/RepEventsTests.swift`

**Interfaces:**
- Produces:
  - `public enum Befestigungsart: String, Codable, Sendable, CaseIterable { case stapel, langhantel, kurzhantel, hebelarm, kabelgriff, koerper; public static let freigegeben: Set<Befestigungsart> }`
  - `public enum UnsicherGrund: String, Codable, Sendable { case luecke, signalSchwach, taktUnregelmaessig }`
  - `public struct Wiederholung: Equatable, Sendable { nummer: Int; beginn, umkehr, ende: TimeInterval; ausschlag: Double; sicherheit: Double; pauseDavor: TimeInterval?; dauerKonzentrisch, dauerExzentrisch: TimeInterval (berechnet) }`
  - `public enum ZaehlerEreignis: Equatable, Sendable { case wiederholung(Wiederholung), unsicher(UnsicherGrund), zuende }`
  - `public struct RepEvents: Codable, Equatable, Sendable { algo: String; befestigungsart: Befestigungsart; unsicher: UnsicherGrund?; wiederholungen: [Eintrag]; init(algo:befestigungsart:ereignisse:satzbeginn:) }` mit `public struct Eintrag: Codable, Equatable, Sendable { beginn, umkehr, ende, ausschlag, sicherheit: Double }`

- [ ] **Step 1: Failing test** — `Tests/SensorikTests/RepEventsTests.swift`:

```swift
import Foundation
import Testing
@testable import Sensorik

struct RepEventsTests {
    private func wdh(_ n: Int, _ b: Double, _ u: Double, _ e: Double) -> ZaehlerEreignis {
        .wiederholung(Wiederholung(nummer: n, beginn: b, umkehr: u, ende: e,
                                   ausschlag: 112.437, sicherheit: 0.9349, pauseDavor: nil))
    }

    @Test func zeitenSindRelativZumSatzbeginnUndGerundet() {
        let events = RepEvents(algo: "langhantel/1", befestigungsart: .langhantel,
                               ereignisse: [wdh(1, 103.421, 104.6149, 105.98)], satzbeginn: 100)
        #expect(events.wiederholungen == [.init(beginn: 3.42, umkehr: 4.61, ende: 5.98,
                                                 ausschlag: 112.44, sicherheit: 0.93)])
        #expect(events.unsicher == nil)
    }

    @Test func derUnsicherGrundWirdUebernommen() {
        let events = RepEvents(algo: "stapel/1", befestigungsart: .stapel,
                               ereignisse: [wdh(1, 1, 2, 3), .unsicher(.luecke), .zuende], satzbeginn: 0)
        #expect(events.unsicher == .luecke)
        #expect(events.wiederholungen.count == 1)
    }

    /// Der Server (Zod, Spec B 6.2) erwartet `unsicher` immer als Schluessel,
    /// auch wenn er null ist -- ein fehlender Schluessel waere eine zweite
    /// Bedeutung von "nichts".
    @Test func jsonHatDieSchluesselDesServers() throws {
        let events = RepEvents(algo: "langhantel/1", befestigungsart: .langhantel,
                               ereignisse: [wdh(1, 3.42, 4.61, 5.98)], satzbeginn: 0)
        let json = try #require(String(data: SensorikJSON.encoder().encode(events), encoding: .utf8))
        #expect(json.contains("\"unsicher\" : null"))
        #expect(json.contains("\"befestigungsart\" : \"langhantel\""))
        #expect(json.contains("\"algo\" : \"langhantel/1\""))
        let zurueck = try SensorikJSON.decoder().decode(RepEvents.self, from: Data(json.utf8))
        #expect(zurueck == events)
    }

    @Test func dieRohwerteDerBefestigungsartenSindFest() {
        #expect(Befestigungsart.allCases.map(\.rawValue)
                == ["stapel", "langhantel", "kurzhantel", "hebelarm", "kabelgriff", "koerper"])
        #expect(Befestigungsart.freigegeben.isEmpty)
    }

    @Test func phasendauernSindAbgeleitet() {
        let w = Wiederholung(nummer: 1, beginn: 1, umkehr: 2.5, ende: 4, ausschlag: 1, sicherheit: 1, pauseDavor: nil)
        #expect(w.dauerKonzentrisch == 1.5)
        #expect(w.dauerExzentrisch == 1.5)
    }
}
```

- [ ] **Step 2: Rot prüfen.** `swift test --package-path apps/ios-member/Packages/Sensorik --filter RepEventsTests 2>&1 | tail -10` — Expected: Kompilierfehler `cannot find 'RepEvents' in scope`.

- [ ] **Step 3: Implementieren.** `Befestigungsart.swift`:

```swift
/// Wie der Sensor haengt (Sensor-Spec B 6.7). Feste Liste statt Freitext,
/// weil der Zaehler je Art ein eigenes Profil braucht: am Stapel ist das
/// Signal linear, an der Hantel kommt Drehung dazu, am Hebel ein Kreisbogen.
public enum Befestigungsart: String, Codable, Sendable, CaseIterable {
    case stapel, langhantel, kurzhantel, hebelarm, kabelgriff, koerper

    /// Arten, fuer die der Zaehler im Release zaehlt (Spec B 7). Jede kommt
    /// in einem eigenen Commit zusammen mit dem Guetebericht hinein, der das
    /// Tor zeigt; GueteberichtTests haelt sie dort fest.
    public static let freigegeben: Set<Befestigungsart> = []
}
```

`ZaehlerEreignis.swift`:

```swift
import Foundation

public enum UnsicherGrund: String, Codable, Sendable {
    case luecke, signalSchwach, taktUnregelmaessig
}

/// Eine gezaehlte Wiederholung. Zeiten sind Messwertzeiten (Spec A 5.3) mit
/// rund 30 ms Aufloesung wegen der Buendelung am iPhone (Spec A 4.7).
public struct Wiederholung: Equatable, Sendable {
    public let nummer: Int
    public let beginn: TimeInterval
    /// Geschwindigkeit null zwischen Hin- und Rueckweg.
    public let umkehr: TimeInterval
    public let ende: TimeInterval
    /// Betrag des Spitzenwerts im Profil-Signal (Grad/s oder m/s).
    public let ausschlag: Double
    public let sicherheit: Double
    /// nil fuer die erste Wiederholung des Satzes.
    public let pauseDavor: TimeInterval?

    public init(nummer: Int, beginn: TimeInterval, umkehr: TimeInterval, ende: TimeInterval,
                ausschlag: Double, sicherheit: Double, pauseDavor: TimeInterval?) {
        self.nummer = nummer; self.beginn = beginn; self.umkehr = umkehr; self.ende = ende
        self.ausschlag = ausschlag; self.sicherheit = sicherheit; self.pauseDavor = pauseDavor
    }

    public var dauerKonzentrisch: TimeInterval { umkehr - beginn }
    public var dauerExzentrisch: TimeInterval { ende - umkehr }
}

public enum ZaehlerEreignis: Equatable, Sendable {
    case wiederholung(Wiederholung)
    case unsicher(UnsicherGrund)
    case zuende
}
```

`RepEvents.swift`:

```swift
import Foundation

/// Was vom Zaehler am Satz gespeichert wird (Spec B 6.2) -- als rep_events
/// auf dem Server und als zaehler.ereignisse in aufnahme.json. Nur Werte,
/// die sich nicht ableiten lassen: Phasendauern und Pausen rechnet, wer sie
/// braucht (Teilprojekt C, D).
public struct RepEvents: Codable, Equatable, Sendable {
    public struct Eintrag: Codable, Equatable, Sendable {
        public let beginn: Double
        public let umkehr: Double
        public let ende: Double
        public let ausschlag: Double
        public let sicherheit: Double

        public init(beginn: Double, umkehr: Double, ende: Double, ausschlag: Double, sicherheit: Double) {
            self.beginn = beginn; self.umkehr = umkehr; self.ende = ende
            self.ausschlag = ausschlag; self.sicherheit = sicherheit
        }
    }

    public let algo: String
    public let befestigungsart: Befestigungsart
    public let unsicher: UnsicherGrund?
    public let wiederholungen: [Eintrag]

    public init(algo: String, befestigungsart: Befestigungsart,
                ereignisse: [ZaehlerEreignis], satzbeginn: TimeInterval) {
        self.algo = algo
        self.befestigungsart = befestigungsart
        var unsicher: UnsicherGrund?
        var liste: [Eintrag] = []
        for ereignis in ereignisse {
            switch ereignis {
            case .wiederholung(let w):
                liste.append(Eintrag(beginn: Self.r(w.beginn - satzbeginn), umkehr: Self.r(w.umkehr - satzbeginn),
                                     ende: Self.r(w.ende - satzbeginn), ausschlag: Self.r(w.ausschlag),
                                     sicherheit: Self.r(w.sicherheit)))
            case .unsicher(let grund):
                unsicher = grund
            case .zuende:
                break
            }
        }
        self.unsicher = unsicher
        self.wiederholungen = liste
    }

    /// Zwei Nachkommastellen: feiner als das 30-ms-Raster ist keine Zeit.
    private static func r(_ wert: Double) -> Double { (wert * 100).rounded() / 100 }

    private enum CodingKeys: String, CodingKey { case algo, befestigungsart, unsicher, wiederholungen }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(algo, forKey: .algo)
        try c.encode(befestigungsart, forKey: .befestigungsart)
        // Immer als Schluessel, auch als null (Spec B 6.2).
        try c.encode(unsicher, forKey: .unsicher)
        try c.encode(wiederholungen, forKey: .wiederholungen)
    }
}
```

- [ ] **Step 4: Grün prüfen.** `swift test --package-path apps/ios-member/Packages/Sensorik --filter RepEventsTests 2>&1 | tail -10` — Expected: 5 Tests PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/ios-member/Packages/Sensorik
git commit -m "feat(sensorik): Befestigungsart, Zaehler-Ereignisse und RepEvents

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log -1 --format=%B
```

### Task 6: Profile und Zähler

**Files:**
- Create: `apps/ios-member/Packages/Sensorik/Sources/Sensorik/ZaehlerProfil.swift`
- Create: `apps/ios-member/Packages/Sensorik/Sources/Sensorik/Zaehler.swift`
- Test: `apps/ios-member/Packages/Sensorik/Tests/SensorikTests/Synthetik.swift`
- Test: `apps/ios-member/Packages/Sensorik/Tests/SensorikTests/ZaehlerTests.swift`

**Interfaces:**
- Consumes: `SensorMesswert`, `Vektor3`, `Befestigungsart`, `Wiederholung`, `ZaehlerEreignis`, `UnsicherGrund` (Task 4, 5).
- Produces:
  - `public struct ZaehlerProfil: Equatable, Sendable` mit `art`, `version: Int`, `eingefrorenAm: Date?`, `signal: Signal` (`.drehrate`, `.geschwindigkeitVertikal`), Parametern wie unten, `var algo: String`, `static func fuer(_ art: Befestigungsart) -> ZaehlerProfil`.
  - `public struct Zaehler: Sendable` mit `init(profil: ZaehlerProfil, rateHz: Double = 50)`, `mutating func verarbeite(_ m: SensorMesswert) -> [ZaehlerEreignis]`, `mutating func luecke(von: TimeInterval, bis: TimeInterval) -> [ZaehlerEreignis]`, `mutating func abschliessen() -> [ZaehlerEreignis]`, `var anzahl: Int`.

- [ ] **Step 1: Synthetische Sätze** — `Tests/SensorikTests/Synthetik.swift`:

```swift
import Foundation
@testable import Sensorik

/// Kuenstliche Saetze mit bekannter Wahrheit. Die Zeitstempel sind wie am
/// iPhone gebuendelt (Spec A 4.7): `buendel` Messwerte teilen sich einen t.
enum Synthetik {
    struct Abschnitt {
        var perioden: Int
        var periode: Double = 2.0
        var amplitude: Double = 1.0 // Anteil der Grundamplitude
    }

    static func satz(signal: ZaehlerProfil.Signal, abschnitte: [Abschnitt],
                     ruheVorher: Double = 3, ruheNachher: Double = 2,
                     rate: Double = 50, buendel: Int = 2,
                     rauschenGradProS: Double = 0,
                     luecke: (ab: Double, dauer: Double)? = nil) -> [SensorMesswert] {
        let dt = 1 / rate
        var werte: [SensorMesswert] = []
        var i = 0
        func ablegen(_ wert: Double) {
            // Zeitstempel des Buendels: der erste Messwert des Buendels gibt ihn vor.
            let bundleT = Double(i / buendel * buendel) * dt
            if let luecke, bundleT >= luecke.ab, bundleT < luecke.ab + luecke.dauer { i += 1; return }
            let stoerung = rauschenGradProS * sin(2 * .pi * 7 * Double(i) * dt)
            switch signal {
            case .drehrate:
                werte.append(SensorMesswert(
                    t: bundleT, beschleunigung: Vektor3(x: 0, y: 0, z: 1),
                    drehrate: Vektor3(x: 0, y: 200 * wert + stoerung, z: 0), winkel: Vektor3(x: 0, y: 0, z: 0)))
            case .geschwindigkeitVertikal:
                // wert ist hier die Beschleunigung in m/s^2 entlang z.
                werte.append(SensorMesswert(
                    t: bundleT, beschleunigung: Vektor3(x: 0, y: 0, z: 1 + wert / 9.81),
                    drehrate: Vektor3(x: stoerung, y: 0, z: 0), winkel: Vektor3(x: 0, y: 0, z: 0)))
            }
            i += 1
        }
        let ruheSamples = { (dauer: Double) in Int((dauer * rate).rounded()) }
        for _ in 0..<ruheSamples(ruheVorher) { ablegen(0) }
        for abschnitt in abschnitte {
            let n = Int((Double(abschnitt.perioden) * abschnitt.periode * rate).rounded())
            for k in 0..<n {
                let phase = 2 * .pi * Double(k) * dt / abschnitt.periode
                switch signal {
                case .drehrate:
                    ablegen(abschnitt.amplitude * sin(phase))
                case .geschwindigkeitVertikal:
                    // v = 0,4 m/s * sin -> a = dv/dt
                    let v0 = 0.4 * abschnitt.amplitude
                    ablegen(v0 * 2 * .pi / abschnitt.periode * cos(phase))
                }
            }
        }
        for _ in 0..<ruheSamples(ruheNachher) { ablegen(0) }
        return werte
    }

    static func zaehlen(_ werte: [SensorMesswert], art: Befestigungsart, rate: Double = 50) -> [ZaehlerEreignis] {
        var zaehler = Zaehler(profil: .fuer(art), rateHz: rate)
        var ereignisse: [ZaehlerEreignis] = []
        for m in werte { ereignisse += zaehler.verarbeite(m) }
        ereignisse += zaehler.abschliessen()
        return ereignisse
    }

    static func anzahl(_ ereignisse: [ZaehlerEreignis]) -> Int {
        ereignisse.filter { if case .wiederholung = $0 { true } else { false } }.count
    }
}
```

- [ ] **Step 2: Failing tests** — `Tests/SensorikTests/ZaehlerTests.swift`:

```swift
import Foundation
import Testing
@testable import Sensorik

struct ZaehlerTests {
    typealias A = Synthetik.Abschnitt

    @Test(arguments: [Befestigungsart.langhantel, .kurzhantel, .hebelarm, .kabelgriff])
    func drehrateZaehltJedePeriode(art: Befestigungsart) {
        let werte = Synthetik.satz(signal: .drehrate, abschnitte: [A(perioden: 10)])
        #expect(Synthetik.anzahl(Synthetik.zaehlen(werte, art: art)) == 10)
    }

    @Test(arguments: [Befestigungsart.stapel, .koerper])
    func geschwindigkeitZaehltJedePeriode(art: Befestigungsart) {
        let werte = Synthetik.satz(signal: .geschwindigkeitVertikal, abschnitte: [A(perioden: 10)])
        #expect(Synthetik.anzahl(Synthetik.zaehlen(werte, art: art)) == 10)
    }

    @Test func nurRuheZaehltNichts() {
        let werte = Synthetik.satz(signal: .drehrate, abschnitte: [], ruheVorher: 20)
        let ereignisse = Synthetik.zaehlen(werte, art: .langhantel)
        #expect(ereignisse == [.zuende])
    }

    /// Spec A 4.7: bei 50 Hz zwei, bei 100 Hz vier Messwerte je Zeitstempel.
    @Test(arguments: [1, 2, 4])
    func buendelungAendertDieZahlNicht(buendel: Int) {
        let werte = Synthetik.satz(signal: .drehrate, abschnitte: [A(perioden: 8)], buendel: buendel)
        #expect(Synthetik.anzahl(Synthetik.zaehlen(werte, art: .langhantel)) == 8)
    }

    @Test func zwanzigUndHundertHzZaehlenGleich() {
        for rate in [20.0, 100.0] {
            let werte = Synthetik.satz(signal: .drehrate, abschnitte: [A(perioden: 8)], rate: rate, buendel: 1)
            #expect(Synthetik.anzahl(Synthetik.zaehlen(werte, art: .langhantel, rate: rate)) == 8)
        }
    }

    @Test func leichtesRauschenZaehltNichtMit() {
        let werte = Synthetik.satz(signal: .drehrate, abschnitte: [A(perioden: 10)], rauschenGradProS: 8)
        #expect(Synthetik.anzahl(Synthetik.zaehlen(werte, art: .langhantel)) == 10)
    }

    @Test func eineLueckeImSatzMachtUnsicherUndDanachKommtNichtsMehr() {
        // Ruhe 3 s, dann Perioden zu 2 s: die Luecke bei 10 s liegt in der vierten.
        let werte = Synthetik.satz(signal: .drehrate, abschnitte: [A(perioden: 10)], luecke: (ab: 10, dauer: 1))
        let ereignisse = Synthetik.zaehlen(werte, art: .langhantel)
        let index = ereignisse.firstIndex(of: .unsicher(.luecke))
        #expect(index != nil)
        if let index {
            #expect(Synthetik.anzahl(Array(ereignisse[index...])) == 0)
        }
        #expect(Synthetik.anzahl(ereignisse) < 10)
        #expect(ereignisse.last == .zuende)
    }

    @Test func eineExpliziteLueckeWirktWieEineImplizite() {
        let werte = Synthetik.satz(signal: .drehrate, abschnitte: [A(perioden: 6)])
        var zaehler = Zaehler(profil: .fuer(.langhantel))
        var ereignisse: [ZaehlerEreignis] = []
        for m in werte.prefix(werte.count / 2) { ereignisse += zaehler.verarbeite(m) }
        ereignisse += zaehler.luecke(von: 7, bis: 7.2)
        for m in werte.suffix(werte.count / 2) { ereignisse += zaehler.verarbeite(m) }
        #expect(ereignisse.contains(.unsicher(.luecke)))
        #expect(Synthetik.anzahl(Array(ereignisse.drop(while: { $0 != .unsicher(.luecke) }))) == 0)
    }

    /// 0,38 der Grundamplitude liegt ueber der Schwelle nach der ersten
    /// Wiederholung (0,35) und unter dem Schwach-Anteil (0,4): sie wird
    /// erkannt, aber als zu schwach bewertet.
    @Test func eineSchwacheWiederholungAmEndeMachtUnsicher() {
        let werte = Synthetik.satz(signal: .drehrate,
                                   abschnitte: [A(perioden: 8), A(perioden: 1, amplitude: 0.38)])
        let ereignisse = Synthetik.zaehlen(werte, art: .langhantel)
        #expect(Synthetik.anzahl(ereignisse) == 8)
        #expect(ereignisse.contains(.unsicher(.signalSchwach)))
    }

    @Test func eineViertZuLangsameWiederholungMachtUnsicher() {
        let werte = Synthetik.satz(signal: .drehrate,
                                   abschnitte: [A(perioden: 6), A(perioden: 1, periode: 7)])
        let ereignisse = Synthetik.zaehlen(werte, art: .langhantel)
        #expect(Synthetik.anzahl(ereignisse) == 6)
        #expect(ereignisse.contains(.unsicher(.taktUnregelmaessig)))
    }

    @Test func gleicherEingangGibtGleicheEreignisse() {
        let werte = Synthetik.satz(signal: .geschwindigkeitVertikal, abschnitte: [A(perioden: 7)])
        #expect(Synthetik.zaehlen(werte, art: .stapel) == Synthetik.zaehlen(werte, art: .stapel))
    }

    @Test func ereignisseSindInSichStimmig() {
        let werte = Synthetik.satz(signal: .drehrate, abschnitte: [A(perioden: 10)])
        let wiederholungen = Synthetik.zaehlen(werte, art: .langhantel).compactMap {
            if case .wiederholung(let w) = $0 { w } else { nil }
        }
        #expect(wiederholungen.map(\.nummer) == Array(1...10))
        for w in wiederholungen {
            #expect(w.beginn < w.umkehr && w.umkehr < w.ende)
            #expect((0...1).contains(w.sicherheit))
        }
        #expect(wiederholungen.first?.pauseDavor == nil)
        #expect(wiederholungen.dropFirst().allSatisfy { $0.pauseDavor != nil })
        // Ruhevorlauf 3 s: die erste Wiederholung beginnt nicht davor.
        #expect((wiederholungen.first?.beginn ?? 0) >= 2.8)
    }

    @Test func dasProfilKenntSeineAlgoKennung() {
        #expect(ZaehlerProfil.fuer(.langhantel).algo == "langhantel/1")
        #expect(ZaehlerProfil.fuer(.stapel).signal == .geschwindigkeitVertikal)
        #expect(ZaehlerProfil.fuer(.kurzhantel).signal == .drehrate)
    }
}
```

- [ ] **Step 3: Rot prüfen.** `swift test --package-path apps/ios-member/Packages/Sensorik --filter ZaehlerTests 2>&1 | tail -10` — Expected: Kompilierfehler `cannot find 'Zaehler' in scope`.

- [ ] **Step 4: Profile.** `Sources/Sensorik/ZaehlerProfil.swift`:

```swift
import Foundation

/// Parameter je Befestigungsart (Spec B 5.2, 5.3). Alle Zahlen sind
/// Startwerte und werden an den Aufnahmen abgestimmt; jede Aenderung
/// erhoeht `version` und setzt `eingefrorenAm` neu, damit das Torset nur
/// Saetze zaehlt, die der Zaehler vorher nicht gesehen hat (Spec B 5.5).
public struct ZaehlerProfil: Equatable, Sendable {
    public enum Signal: Equatable, Sendable {
        /// Drehrate um die Achse mit der groessten Streuung: Hantel, Hebel, Kabelgriff.
        case drehrate
        /// Geschwindigkeit entlang der Schwerkraft: Stapel, Koerper.
        case geschwindigkeitVertikal
    }

    public let art: Befestigungsart
    public let version: Int
    public let eingefrorenAm: Date?
    public let signal: Signal
    /// Grenzfrequenz des Tiefpasses in Hz. Eine Wiederholung dauert ueber
    /// eine Sekunde; alles ueber 3 Hz ist Zittern oder Klappern.
    public let tiefpassHz: Double
    /// Halbwellen-Schwelle vor der ersten Wiederholung (Grad/s bzw. m/s).
    public let startSchwelle: Double
    /// Danach: Schwelle = max(startSchwelle, schwellenAnteil * Ausschlag der ersten).
    public let schwellenAnteil: Double
    public let mindestDauer: TimeInterval
    public let hoechstDauer: TimeInterval
    /// Ab der dritten Wiederholung: unter diesem Anteil am Median-Ausschlag ist sie schwach.
    public let schwachAnteil: Double
    /// Ab der dritten Wiederholung: erlaubter Faktor der Dauer um den Median.
    public let taktBand: Double
    /// Messwertabstand, ab dem eine Luecke vorliegt (auch App im Hintergrund, Spec A 11.1).
    public let lueckeAb: TimeInterval
    /// Ruhe: Drehrate unter diesem Betrag (Grad/s) ...
    public let ruheDrehrate: Double
    /// ... und Betrag der Beschleunigung so nah an 1 g.
    public let ruheBeschleunigung: Double
    /// Bewegungszeit, aus der die Drehachse bestimmt wird.
    public let achsenFenster: TimeInterval
    /// Zeitkonstante der leckenden Integration; haelt die Drift der
    /// Geschwindigkeit klein, ohne eine Wiederholung zu verschlucken.
    public let leckZeit: TimeInterval

    public var algo: String { "\(art.rawValue)/\(version)" }

    public static func fuer(_ art: Befestigungsart) -> ZaehlerProfil {
        switch art {
        case .langhantel, .kurzhantel, .hebelarm, .kabelgriff:
            ZaehlerProfil(art: art, version: 1, eingefrorenAm: nil, signal: .drehrate,
                          tiefpassHz: 3, startSchwelle: 30, schwellenAnteil: 0.35,
                          mindestDauer: 0.6, hoechstDauer: 10, schwachAnteil: 0.4, taktBand: 2.5,
                          lueckeAb: 0.5, ruheDrehrate: 10, ruheBeschleunigung: 0.05,
                          achsenFenster: 1.0, leckZeit: 1.0)
        case .stapel, .koerper:
            ZaehlerProfil(art: art, version: 1, eingefrorenAm: nil, signal: .geschwindigkeitVertikal,
                          tiefpassHz: 3, startSchwelle: 0.12, schwellenAnteil: 0.35,
                          mindestDauer: 0.6, hoechstDauer: 10, schwachAnteil: 0.4, taktBand: 2.5,
                          lueckeAb: 0.5, ruheDrehrate: 10, ruheBeschleunigung: 0.05,
                          achsenFenster: 1.0, leckZeit: 1.0)
        }
    }
}
```

- [ ] **Step 5: Zähler.** `Sources/Sensorik/Zaehler.swift`:

```swift
import Foundation

/// Regelbasierter Wiederholungszaehler (Sensor-Spec B 5.3). Rein: keine
/// Uhr, keine Nebenlaeufigkeit, kein Zufall -- offline gegen Aufnahmen und
/// live im Satzpfad laeuft derselbe Code.
///
/// Gefiltert wird mit der Sollrate statt mit Zeitstempel-Differenzen, weil
/// gebuendelte Messwerte denselben Zeitstempel tragen (Spec A 4.7); die
/// Zeitstempel bestimmen nur die Zeiten der Ereignisse und die Luecken.
public struct Zaehler: Sendable {
    private enum Halbwelle: Sendable {
        case wartet
        case erste(beginn: TimeInterval, spitze: Double)
        case zweite(beginn: TimeInterval, umkehr: TimeInterval, spitze: Double)
    }

    public let profil: ZaehlerProfil
    private let dt: Double
    private let alpha: Double

    private var gestoppt = false
    private var letzteT: TimeInterval?
    private var wiederholungen: [Wiederholung] = []

    // Signalaufbereitung
    private var schwerkraft: Vektor3?
    private var achse: Int?
    private var puffer: [SensorMesswert] = []
    private var bewegtSeit: TimeInterval?
    private var geschwindigkeit = 0.0
    private var gefiltert = 0.0

    // Halbwellen
    private var zustand: Halbwelle = .wartet
    private var vorzeichen: Double?
    private var schwelle: Double
    private var letztesS = 0.0
    private var nulldurchgang: TimeInterval?

    public init(profil: ZaehlerProfil, rateHz: Double = 50) {
        self.profil = profil
        dt = 1 / rateHz
        let rc = 1 / (2 * .pi * profil.tiefpassHz)
        alpha = dt / (rc + dt)
        schwelle = profil.startSchwelle
        if profil.signal == .geschwindigkeitVertikal { achse = -1 } // braucht keine Achsensuche
    }

    public var anzahl: Int { wiederholungen.count }

    public mutating func verarbeite(_ m: SensorMesswert) -> [ZaehlerEreignis] {
        guard !gestoppt else { return [] }
        defer { letzteT = m.t }
        if let letzteT, m.t - letzteT > profil.lueckeAb {
            return stoppen(.luecke)
        }
        schwerkraftNachfuehren(m)

        guard achse != nil else {
            return achseSuchen(m)
        }
        return schritt(m)
    }

    public mutating func luecke(von: TimeInterval, bis: TimeInterval) -> [ZaehlerEreignis] {
        guard !gestoppt else { return [] }
        return stoppen(.luecke)
    }

    public mutating func abschliessen() -> [ZaehlerEreignis] {
        gestoppt = true
        return [.zuende]
    }

    // MARK: - Aufbereitung

    private static func betrag(_ v: Vektor3) -> Double { (v.x * v.x + v.y * v.y + v.z * v.z).squareRoot() }

    private func ruhig(_ m: SensorMesswert) -> Bool {
        Self.betrag(m.drehrate) < profil.ruheDrehrate
            && abs(Self.betrag(m.beschleunigung) - 1) < profil.ruheBeschleunigung
    }

    private mutating func schwerkraftNachfuehren(_ m: SensorMesswert) {
        guard let g = schwerkraft else { schwerkraft = m.beschleunigung; return }
        // Nur in Ruhe nachfuehren: in Bewegung waere die Beschleunigung der
        // Hantel ein Teil der Schaetzung. Zeitkonstante rund 2 s.
        guard ruhig(m) else { return }
        let k = dt / (2 + dt)
        schwerkraft = Vektor3(x: g.x + k * (m.beschleunigung.x - g.x),
                              y: g.y + k * (m.beschleunigung.y - g.y),
                              z: g.z + k * (m.beschleunigung.z - g.z))
    }

    /// Nur fuer Drehraten-Profile: sammeln, bis die erste Bewegung lang
    /// genug ist, dann die Achse mit der groessten Streuung waehlen und den
    /// Puffer nachspielen, damit die erste Wiederholung nicht verloren geht.
    private mutating func achseSuchen(_ m: SensorMesswert) -> [ZaehlerEreignis] {
        puffer.append(m)
        let bewegt = Self.betrag(m.drehrate) > 3 * profil.ruheDrehrate
        if bewegtSeit == nil, bewegt { bewegtSeit = m.t }
        guard let seit = bewegtSeit else {
            // Ruhevorlauf: nur die letzte Sekunde behalten.
            puffer.removeAll { m.t - $0.t > 1 }
            return []
        }
        guard m.t - seit >= profil.achsenFenster else { return [] }
        let bewegung = puffer.filter { $0.t >= seit }
        func streuung(_ wert: (SensorMesswert) -> Double) -> Double {
            let werte = bewegung.map(wert)
            let mittel = werte.reduce(0, +) / Double(werte.count)
            return werte.reduce(0) { $0 + ($1 - mittel) * ($1 - mittel) }
        }
        let streuungen = [streuung { $0.drehrate.x }, streuung { $0.drehrate.y }, streuung { $0.drehrate.z }]
        achse = streuungen.indices.max { streuungen[$0] < streuungen[$1] }
        let nachspielen = puffer
        puffer = []
        var ereignisse: [ZaehlerEreignis] = []
        for alt in nachspielen { ereignisse += schritt(alt) }
        return ereignisse
    }

    private mutating func rohsignal(_ m: SensorMesswert) -> Double {
        switch profil.signal {
        case .drehrate:
            switch achse {
            case 0: return m.drehrate.x
            case 1: return m.drehrate.y
            default: return m.drehrate.z
            }
        case .geschwindigkeitVertikal:
            let g = schwerkraft ?? Vektor3(x: 0, y: 0, z: 1)
            let gBetrag = max(Self.betrag(g), 0.0001)
            let entlang = (m.beschleunigung.x * g.x + m.beschleunigung.y * g.y + m.beschleunigung.z * g.z) / gBetrag
            let linear = (entlang - gBetrag) * 9.81
            geschwindigkeit = geschwindigkeit * (1 - dt / profil.leckZeit) + linear * dt
            return geschwindigkeit
        }
    }

    // MARK: - Halbwellen

    private mutating func schritt(_ m: SensorMesswert) -> [ZaehlerEreignis] {
        gefiltert += alpha * (rohsignal(m) - gefiltert)
        let s = gefiltert
        // "Nulldurchgang" ist der letzte Moment nahe null: ein echter
        // Vorzeichenwechsel oder ein Wert im Band um null. Ohne das Band
        // bliebe er in reiner Ruhe (s exakt 0) beim ersten Messwert stehen,
        // und die erste Wiederholung begaenne mit dem Ruhevorlauf.
        let wechsel = s != 0 && letztesS != 0 && (s > 0) != (letztesS > 0)
        if nulldurchgang == nil || wechsel || abs(s) < 0.1 * schwelle { nulldurchgang = m.t }
        defer { if s != 0 { letztesS = s } }

        switch zustand {
        case .wartet:
            guard abs(s) > schwelle else { return [] }
            let richtung: Double = s > 0 ? 1 : -1
            if vorzeichen == nil { vorzeichen = richtung }
            // Eine Gegenbewegung vor dem ersten Hinweg (z. B. Ausholen) zaehlt nicht.
            guard richtung == vorzeichen else { return [] }
            zustand = .erste(beginn: nulldurchgang ?? m.t, spitze: abs(s))
            return []

        case .erste(let beginn, let spitze):
            if m.t - beginn > profil.hoechstDauer { zustand = .wartet; return [] }
            let vz = vorzeichen ?? 1
            if s * vz < -schwelle {
                zustand = .zweite(beginn: beginn, umkehr: nulldurchgang ?? m.t, spitze: max(spitze, abs(s)))
            } else {
                zustand = .erste(beginn: beginn, spitze: max(spitze, abs(s)))
            }
            return []

        case .zweite(let beginn, let umkehr, let spitze):
            if m.t - beginn > profil.hoechstDauer { zustand = .wartet; return [] }
            let vz = vorzeichen ?? 1
            let neueSpitze = max(spitze, abs(s))
            // Abgeschlossen, sobald der Rueckweg fast zur Ruhe gekommen ist.
            guard s * vz > -schwelle / 2 else {
                zustand = .zweite(beginn: beginn, umkehr: umkehr, spitze: neueSpitze)
                return []
            }
            zustand = .wartet
            return abschliessenWiederholung(beginn: beginn, umkehr: umkehr, ende: m.t, spitze: neueSpitze)
        }
    }

    private mutating func abschliessenWiederholung(beginn: TimeInterval, umkehr: TimeInterval,
                                                    ende: TimeInterval, spitze: Double) -> [ZaehlerEreignis] {
        let dauer = ende - beginn
        // Zu kurz ist ein Wackler, keine Wiederholung -- verwerfen, nicht zweifeln.
        guard dauer >= profil.mindestDauer, umkehr > beginn, ende > umkehr else { return [] }
        if wiederholungen.count >= 2 {
            let spitzen = wiederholungen.map(\.ausschlag).sorted()
            let dauern = wiederholungen.map { $0.ende - $0.beginn }.sorted()
            let medianSpitze = spitzen[spitzen.count / 2]
            let medianDauer = dauern[dauern.count / 2]
            if spitze < profil.schwachAnteil * medianSpitze { return stoppen(.signalSchwach) }
            if dauer > profil.taktBand * medianDauer || dauer < medianDauer / profil.taktBand {
                return stoppen(.taktUnregelmaessig)
            }
        }
        let sicherheit = min(1, max(0, (spitze - schwelle) / schwelle))
        let wiederholung = Wiederholung(
            nummer: wiederholungen.count + 1, beginn: beginn, umkehr: umkehr, ende: ende,
            ausschlag: spitze, sicherheit: sicherheit,
            pauseDavor: wiederholungen.last.map { max(0, beginn - $0.ende) })
        wiederholungen.append(wiederholung)
        if wiederholungen.count == 1 {
            schwelle = max(profil.startSchwelle, profil.schwellenAnteil * spitze)
        }
        return [.wiederholung(wiederholung)]
    }

    private mutating func stoppen(_ grund: UnsicherGrund) -> [ZaehlerEreignis] {
        gestoppt = true
        return [.unsicher(grund)]
    }
}
```

Hinweis: `abschliessen()` liefert nach einem `stoppen` ebenfalls `.zuende`, weil `gestoppt` dort nur das Zählen beendet. Dafür `abschliessen` ohne `guard` lassen (wie oben) — der Test `eineLueckeImSatz…` prüft `ereignisse.last == .zuende`.

- [ ] **Step 6: Grün prüfen.** `swift test --package-path apps/ios-member/Packages/Sensorik --filter ZaehlerTests 2>&1 | tail -30` — Expected: alle PASS. Schlägt ein synthetischer Test wegen eines Startwerts fehl (z. B. Ruheschwelle, Schwelle der Geschwindigkeit), **den Parameter im Profil anpassen, nicht die Erwartung im Test**, und im Kommentar am Parameter den Grund nennen. Der Test „nurRuheZaehltNichts“ und die Stimmigkeitsprüfung dürfen nie gelockert werden.

- [ ] **Step 7: Commit**

```bash
git add apps/ios-member/Packages/Sensorik
git commit -m "feat(sensorik): regelbasierter Wiederholungszaehler mit Profilen je Befestigungsart

Halbwellen mit Hysterese auf Drehrate bzw. vertikaler Geschwindigkeit,
Luecke, schwaches Signal und unregelmaessiger Takt stoppen den Satz.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log -1 --format=%B
```

### Task 7: Korrekturen mit Befestigungsart und Lauf über Aufnahmen

**Files:**
- Modify: `data/sensoraufnahmen/korrekturen.json` (Feld `befestigungsart` je Aufnahme)
- Modify: `data/sensoraufnahmen/README.md`
- Create: `apps/ios-member/Packages/Sensorik/Tests/SensorikTests/Korrekturen.swift`
- Create: `apps/ios-member/Packages/Sensorik/Tests/SensorikTests/AufnahmeLauf.swift`
- Test: `apps/ios-member/Packages/Sensorik/Tests/SensorikTests/AufnahmenTests.swift`

**Interfaces:**
- Consumes: `SensorAufnahmeLeser.lesen(ordner:)`, `.Eintrag` (`.messwert`, `.luecke`, `.rate`), `Zaehler`, `ZaehlerProfil.fuer`, `Pfade`.
- Produces (Testziel):
  - `struct Korrekturen { struct Eintrag: Decodable { was: String; befestigung: String?; befestigungsart: Befestigungsart?; repsWahr: Int?; fuerZaehler: Bool; grund: String? }; let aufnahmen: [String: Eintrag]; static func laden() throws -> Korrekturen }`
  - `struct AufnahmeErgebnis { ordner: String; startedAt: Date; art: Befestigungsart; repsWahr: Int; fuerZaehler: Bool; gezaehlt: Int; unsicher: UnsicherGrund?; ereignisse: [ZaehlerEreignis] }`
  - `enum AufnahmeLauf { static func ueberAlle() throws -> [AufnahmeErgebnis]; static func zaehlen(ordner: URL, art: Befestigungsart) throws -> [ZaehlerEreignis] }`

- [ ] **Step 1: `korrekturen.json` ergänzen.** Bei jeder Aufnahme direkt unter `"befestigung"` den Schlüssel `"befestigungsart"` einfügen. Zuordnung aus dem Freitext:

| Aufnahme | `befestigungsart` |
|---|---|
| `2026-10-08-0836-01` (Curls, Wasserflasche als Langhantel) | `"langhantel"` |
| `2026-10-08-0837-01` (Squats, Wasserflasche als Langhantel) | `"langhantel"` |
| `2026-10-08-0841-01`, `-0844-01`, `-0846-01` (Wasserflasche frei geführt als Stapel) | `"stapel"` |
| `2026-10-08-0846-02` (Kurzhantel Curls) | `"kurzhantel"` |
| `2026-10-08-0852-01` (Liegestütze, Sensor um den Hals) | `"koerper"` |
| alle übrigen (Handtests, Checkliste, kein Satz) | `null` |

`fuerZaehler` bleibt überall `false`. README-Abschnitt ergänzen:

```markdown
## Felder in `korrekturen.json`

- `befestigungsart`: einer von `stapel`, `langhantel`, `kurzhantel`, `hebelarm`, `kabelgriff`, `koerper` oder `null` (Sensor-Spec B 5.4). Der Zähler wählt danach sein Profil; ohne Art läuft die Aufnahme nicht in den Gütebericht.
- `befestigung`: Freitext-Detail wie bisher („oben auf dem Stapel“).
- `repsWahr`: was wirklich gemacht wurde — die Wahrheit für den Zähler.
- `fuerZaehler`: `true` nur für echte Sätze mit eingetragener Art und korrekt bestätigten Wiederholungen. Nur sie zählen für das Gütetor, und nur, wenn sie nach dem `eingefrorenAm` des Profils aufgenommen wurden.

Neue Aufnahmen: Ordner unverändert vom iPhone kopieren, Eintrag hier anlegen, `swift test --package-path apps/ios-member/Packages/Sensorik` laufen lassen und den neuen `guetebericht.md` mit committen.
```

- [ ] **Step 2: Failing tests** — `Tests/SensorikTests/AufnahmenTests.swift`:

```swift
import Foundation
import Testing
@testable import Sensorik

/// Jede Aufnahme mit bekannter Wahrheit laeuft durch den Zaehler. Hier wird
/// nicht die Guete geprueft (das macht GueteberichtTests), sondern dass der
/// Zaehler echte Daten ohne Absturz, deterministisch und stimmig verarbeitet.
struct AufnahmenTests {
    static let mitWahrheit: [String] = {
        guard let k = try? Korrekturen.laden() else { return [] }
        return k.aufnahmen.filter { $0.value.repsWahr != nil && $0.value.befestigungsart != nil }
            .keys.sorted()
    }()

    @Test func korrekturenSindLesbarUndKennenDieNeuenFelder() throws {
        let k = try Korrekturen.laden()
        #expect(k.aufnahmen["2026-10-08-0836-01"]?.befestigungsart == .langhantel)
        #expect(k.aufnahmen["2026-10-04-0912-01"]?.befestigungsart == nil)
    }

    @Test(arguments: mitWahrheit)
    func aufnahmeLaeuftDeterministischUndStimmig(name: String) throws {
        let k = try Korrekturen.laden()
        let art = try #require(k.aufnahmen[name]?.befestigungsart)
        let ordner = Pfade.aufnahmen.appendingPathComponent(name)
        let erster = try AufnahmeLauf.zaehlen(ordner: ordner, art: art)
        let zweiter = try AufnahmeLauf.zaehlen(ordner: ordner, art: art)
        #expect(erster == zweiter)
        #expect(erster.last == .zuende)
        let wiederholungen = erster.compactMap { if case .wiederholung(let w) = $0 { w } else { nil } }
        #expect(wiederholungen.map(\.nummer) == Array(stride(from: 1, through: wiederholungen.count, by: 1)))
        for w in wiederholungen { #expect(w.beginn < w.umkehr && w.umkehr < w.ende) }
        #expect(zip(wiederholungen, wiederholungen.dropFirst()).allSatisfy { $0.beginn < $1.beginn })
    }

    @Test func mitWahrheitIstNichtLeer() {
        #expect(!Self.mitWahrheit.isEmpty)
    }
}
```

- [ ] **Step 3: Rot prüfen.** `swift test --package-path apps/ios-member/Packages/Sensorik --filter AufnahmenTests 2>&1 | tail -10` — Expected: Kompilierfehler `cannot find 'Korrekturen' in scope`.

- [ ] **Step 4: Korrekturen-Leser.** `Tests/SensorikTests/Korrekturen.swift`:

```swift
import Foundation
@testable import Sensorik

/// data/sensoraufnahmen/korrekturen.json (gymodo.sensorkorrektur/1). Liegt im
/// Testziel, weil nur die Offline-Pruefung die Wahrheit braucht -- die App
/// kennt keine Korrekturen.
struct Korrekturen: Decodable {
    struct Eintrag: Decodable {
        let was: String
        let befestigung: String?
        let befestigungsart: Befestigungsart?
        let repsWahr: Int?
        let fuerZaehler: Bool
        let grund: String?
    }

    let format: String
    let aufnahmen: [String: Eintrag]

    static func laden() throws -> Korrekturen {
        let daten = try Data(contentsOf: Pfade.aufnahmen.appendingPathComponent("korrekturen.json"))
        let k = try JSONDecoder().decode(Korrekturen.self, from: daten)
        guard k.format == "gymodo.sensorkorrektur/1" else {
            throw SensorAufnahmeLeser.Fehler.unbekanntesFormat(k.format)
        }
        return k
    }
}
```

- [ ] **Step 5: Lauf über Aufnahmen.** `Tests/SensorikTests/AufnahmeLauf.swift`:

```swift
import Foundation
@testable import Sensorik

struct AufnahmeErgebnis {
    let ordner: String
    let startedAt: Date
    let art: Befestigungsart
    let repsWahr: Int
    let fuerZaehler: Bool
    let gezaehlt: Int
    let unsicher: UnsicherGrund?
    let ereignisse: [ZaehlerEreignis]
}

enum AufnahmeLauf {
    /// Spielt eine Aufnahme so durch den Zaehler, wie die App es live tut:
    /// Messwerte der Reihe nach, Luecken-Zeilen als expliziter Abriss, ein
    /// Ratenwechsel baut den Zaehler nicht neu (die Rate gilt fuer den Filter,
    /// ein Wechsel mitten im Satz kommt nur in der Diagnose vor).
    static func zaehlen(ordner: URL, art: Befestigungsart) throws -> [ZaehlerEreignis] {
        let (datei, eintraege) = try SensorAufnahmeLeser.lesen(ordner: ordner)
        var zaehler = Zaehler(profil: .fuer(art), rateHz: Double(datei.sensor.rateSollHz))
        var ereignisse: [ZaehlerEreignis] = []
        for eintrag in eintraege {
            switch eintrag {
            case .messwert(let m): ereignisse += zaehler.verarbeite(m)
            case .luecke(let von, let bis): ereignisse += zaehler.luecke(von: von, bis: bis)
            case .rate: break
            }
        }
        ereignisse += zaehler.abschliessen()
        return ereignisse
    }

    /// Alle Ordner mit Korrektur-Eintrag, Art und Wahrheit. Ordner ohne
    /// Eintrag, ohne messwerte.csv und lose Dateien (ratentest-*.json) werden
    /// uebersprungen statt zu werfen: neue Aufnahmen liegen oft schon da,
    /// bevor ihre Korrektur geschrieben ist.
    static func ueberAlle() throws -> [AufnahmeErgebnis] {
        let k = try Korrekturen.laden()
        let fm = FileManager.default
        var ergebnisse: [AufnahmeErgebnis] = []
        for (name, eintrag) in k.aufnahmen.sorted(by: { $0.key < $1.key }) {
            guard let art = eintrag.befestigungsart, let wahr = eintrag.repsWahr else { continue }
            let ordner = Pfade.aufnahmen.appendingPathComponent(name)
            guard fm.fileExists(atPath: ordner.appendingPathComponent("messwerte.csv").path) else { continue }
            let (datei, _) = try SensorAufnahmeLeser.lesen(ordner: ordner)
            let ereignisse = try zaehlen(ordner: ordner, art: art)
            let gezaehlt = ereignisse.filter { if case .wiederholung = $0 { true } else { false } }.count
            let unsicher = ereignisse.lazy.compactMap { if case .unsicher(let g) = $0 { g } else { nil } }.first
            ergebnisse.append(AufnahmeErgebnis(
                ordner: name, startedAt: datei.startedAt, art: art, repsWahr: wahr,
                fuerZaehler: eintrag.fuerZaehler, gezaehlt: gezaehlt, unsicher: unsicher, ereignisse: ereignisse))
        }
        return ergebnisse
    }
}
```

- [ ] **Step 6: Grün prüfen.** `swift test --package-path apps/ios-member/Packages/Sensorik --filter AufnahmenTests 2>&1 | tail -20` — Expected: alle PASS (je Aufnahme mit Wahrheit ein Testfall).

- [ ] **Step 7: Commit**

```bash
git add data/sensoraufnahmen/korrekturen.json data/sensoraufnahmen/README.md apps/ios-member/Packages/Sensorik
git commit -m "test(sensorik): Zaehler laeuft ueber alle Aufnahmen mit bekannter Wahrheit

korrekturen.json kennt die Befestigungsart je Aufnahme.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log -1 --format=%B
```

### Task 8: Gütebericht und Gütetor

**Files:**
- Create: `apps/ios-member/Packages/Sensorik/Tests/SensorikTests/Guetebericht.swift`
- Test: `apps/ios-member/Packages/Sensorik/Tests/SensorikTests/GueteberichtTests.swift`
- Create (vom Test geschrieben, eingecheckt): `data/sensoraufnahmen/guetebericht.md`

**Interfaces:**
- Consumes: `AufnahmeLauf.ueberAlle()`, `AufnahmeErgebnis`, `ZaehlerProfil.fuer(_:).eingefrorenAm`, `Befestigungsart.freigegeben`.
- Produces (Testziel):
  - `struct Quoten: Equatable { saetze: Int; tage: Int; exakt: Double; plusMinusEins: Double; ruecknahmen: Double }`
  - `enum Guetebericht { static func quoten(_ ergebnisse: [AufnahmeErgebnis]) -> Quoten; static func torset(_ ergebnisse: [AufnahmeErgebnis], art: Befestigungsart) -> [AufnahmeErgebnis]; static func torErreicht(_ q: Quoten) -> Bool; static func markdown(_ ergebnisse: [AufnahmeErgebnis]) -> String }`

- [ ] **Step 1: Failing tests** — `Tests/SensorikTests/GueteberichtTests.swift`:

```swift
import Foundation
import Testing
@testable import Sensorik

struct GueteberichtTests {
    private func ergebnis(_ wahr: Int, _ gezaehlt: Int, unsicher: UnsicherGrund? = nil,
                          tag: Int = 1, fuer: Bool = true, art: Befestigungsart = .langhantel) -> AufnahmeErgebnis {
        let start = Date(timeIntervalSince1970: 1_800_000_000 + Double(tag) * 86_400)
        return AufnahmeErgebnis(ordner: "x", startedAt: start, art: art, repsWahr: wahr, fuerZaehler: fuer,
                                gezaehlt: gezaehlt, unsicher: unsicher, ereignisse: [])
    }

    /// Ruecknahmen zaehlen nicht als Fehlzaehlung, aber als eigene Quote
    /// (Spec B 5.5) -- sonst wuerde ein Zaehler belohnt, der nie zweifelt.
    @Test func quotenTrennenRuecknahmenVonFehlzaehlungen() {
        let q = Guetebericht.quoten([
            ergebnis(10, 10, tag: 1), ergebnis(10, 9, tag: 2), ergebnis(10, 7, tag: 3),
            ergebnis(10, 4, unsicher: .luecke, tag: 3),
        ])
        #expect(q.saetze == 4)
        #expect(q.tage == 3)
        #expect(q.ruecknahmen == 0.25)
        #expect(abs(q.exakt - 1.0 / 3) < 1e-9)
        #expect(abs(q.plusMinusEins - 2.0 / 3) < 1e-9)
    }

    @Test func dasTorBrauchtMengeTageUndQuoten() {
        let gut = Quoten(saetze: 20, tage: 3, exakt: 0.9, plusMinusEins: 0.98, ruecknahmen: 0.1)
        #expect(Guetebericht.torErreicht(gut))
        #expect(!Guetebericht.torErreicht(Quoten(saetze: 19, tage: 3, exakt: 1, plusMinusEins: 1, ruecknahmen: 0)))
        #expect(!Guetebericht.torErreicht(Quoten(saetze: 20, tage: 2, exakt: 1, plusMinusEins: 1, ruecknahmen: 0)))
        #expect(!Guetebericht.torErreicht(Quoten(saetze: 20, tage: 3, exakt: 0.89, plusMinusEins: 1, ruecknahmen: 0)))
        #expect(!Guetebericht.torErreicht(Quoten(saetze: 20, tage: 3, exakt: 1, plusMinusEins: 0.97, ruecknahmen: 0)))
        #expect(!Guetebericht.torErreicht(Quoten(saetze: 20, tage: 3, exakt: 1, plusMinusEins: 1, ruecknahmen: 0.11)))
    }

    /// Ohne eingefrorenes Profil gibt es kein Torset: wer noch abstimmt,
    /// kann sich nicht selbst pruefen.
    @Test func ohneEingefrorenesProfilIstDasTorsetLeer() {
        #expect(ZaehlerProfil.fuer(.langhantel).eingefrorenAm == nil)
        #expect(Guetebericht.torset([ergebnis(10, 10)], art: .langhantel).isEmpty)
    }

    @Test func ohneSaetzeSindDieQuotenNull() {
        #expect(Guetebericht.quoten([]) == Quoten(saetze: 0, tage: 0, exakt: 0, plusMinusEins: 0, ruecknahmen: 0))
    }

    /// Schreibt den Bericht und haelt jede freigegebene Art am Tor fest.
    @Test func berichtSchreibenUndFreigegebeneArtenPruefen() throws {
        let ergebnisse = try AufnahmeLauf.ueberAlle()
        let text = Guetebericht.markdown(ergebnisse)
        try text.write(to: Pfade.aufnahmen.appendingPathComponent("guetebericht.md"),
                       atomically: true, encoding: .utf8)
        for art in Befestigungsart.freigegeben {
            let q = Guetebericht.quoten(Guetebericht.torset(ergebnisse, art: art))
            #expect(Guetebericht.torErreicht(q), "\(art.rawValue) ist freigegeben, haelt das Tor aber nicht: \(q)")
        }
    }
}
```

- [ ] **Step 2: Rot prüfen.** `swift test --package-path apps/ios-member/Packages/Sensorik --filter GueteberichtTests 2>&1 | tail -10` — Expected: Kompilierfehler `cannot find 'Guetebericht' in scope`.

- [ ] **Step 3: Implementieren.** `Tests/SensorikTests/Guetebericht.swift`:

```swift
import Foundation
@testable import Sensorik

struct Quoten: Equatable {
    let saetze: Int
    let tage: Int
    let exakt: Double
    let plusMinusEins: Double
    let ruecknahmen: Double
}

/// Guetemass und Tor aus Sensor-Spec B 5.5.
enum Guetebericht {
    static let mindestSaetze = 20
    static let mindestTage = 3
    static let exaktMin = 0.90
    static let plusMinusEinsMin = 0.98
    static let ruecknahmenMax = 0.10

    static func quoten(_ ergebnisse: [AufnahmeErgebnis]) -> Quoten {
        guard !ergebnisse.isEmpty else { return Quoten(saetze: 0, tage: 0, exakt: 0, plusMinusEins: 0, ruecknahmen: 0) }
        var kalender = Calendar(identifier: .gregorian)
        kalender.timeZone = TimeZone(identifier: "Europe/Berlin")!
        let tage = Set(ergebnisse.map { kalender.startOfDay(for: $0.startedAt) }).count
        let zurueckgenommen = ergebnisse.filter { $0.unsicher != nil }
        let gezaehlt = ergebnisse.filter { $0.unsicher == nil }
        let n = Double(gezaehlt.count)
        return Quoten(
            saetze: ergebnisse.count,
            tage: tage,
            exakt: n == 0 ? 0 : Double(gezaehlt.filter { $0.gezaehlt == $0.repsWahr }.count) / n,
            plusMinusEins: n == 0 ? 0 : Double(gezaehlt.filter { abs($0.gezaehlt - $0.repsWahr) <= 1 }.count) / n,
            ruecknahmen: Double(zurueckgenommen.count) / Double(ergebnisse.count))
    }

    /// Nur echte Saetze, die der Zaehler in dieser Profilversion nie gesehen
    /// hat: fuerZaehler und nach eingefrorenAm aufgenommen.
    static func torset(_ ergebnisse: [AufnahmeErgebnis], art: Befestigungsart) -> [AufnahmeErgebnis] {
        guard let eingefroren = ZaehlerProfil.fuer(art).eingefrorenAm else { return [] }
        return ergebnisse.filter { $0.art == art && $0.fuerZaehler && $0.startedAt > eingefroren }
    }

    static func torErreicht(_ q: Quoten) -> Bool {
        q.saetze >= mindestSaetze && q.tage >= mindestTage
            && q.exakt >= exaktMin && q.plusMinusEins >= plusMinusEinsMin && q.ruecknahmen <= ruecknahmenMax
    }

    static func markdown(_ ergebnisse: [AufnahmeErgebnis]) -> String {
        func pct(_ x: Double) -> String { String(format: "%.0f %%", locale: Locale(identifier: "en_US_POSIX"), x * 100) }
        func zeile(_ titel: String, _ q: Quoten) -> String {
            "| \(titel) | \(q.saetze) | \(q.tage) | \(pct(q.exakt)) | \(pct(q.plusMinusEins)) | \(pct(q.ruecknahmen)) |"
        }
        var text = """
            # Gütebericht Wiederholungszähler

            Erzeugt von `GueteberichtTests` (`swift test --package-path apps/ios-member/Packages/Sensorik`). Nicht von Hand bearbeiten.
            Tor je Art (Sensor-Spec B 5.5): ≥ \(mindestSaetze) Sätze aus ≥ \(mindestTage) Tagen, exakt ≥ 90 %, ±1 ≥ 98 %, Rücknahmen ≤ 10 %.

            | Art · Set | Sätze | Tage | exakt | ±1 | Rücknahmen |
            |---|---|---|---|---|---|

            """
        for art in Befestigungsart.allCases {
            let entwicklung = ergebnisse.filter { $0.art == art }
            guard !entwicklung.isEmpty else { continue }
            let profil = ZaehlerProfil.fuer(art)
            text += zeile("\(art.rawValue) (\(profil.algo)) · Entwicklung", quoten(entwicklung)) + "\n"
            let tor = torset(ergebnisse, art: art)
            let q = quoten(tor)
            let status = profil.eingefrorenAm == nil ? "nicht eingefroren"
                : (torErreicht(q) ? "Tor erreicht" : "Tor offen")
            text += zeile("\(art.rawValue) · Torset (\(status))", q) + "\n"
        }
        text += "\n## Je Satz\n\n| Aufnahme | Art | wahr | gezählt | Rücknahme |\n|---|---|---|---|---|\n"
        for e in ergebnisse {
            text += "| \(e.ordner) | \(e.art.rawValue) | \(e.repsWahr) | \(e.gezaehlt) | \(e.unsicher?.rawValue ?? "–") |\n"
        }
        return text
    }
}
```

- [ ] **Step 4: Grün prüfen.** `swift test --package-path apps/ios-member/Packages/Sensorik 2>&1 | tail -20` — Expected: alle Tests des Packages PASS, `data/sensoraufnahmen/guetebericht.md` existiert. `cat data/sensoraufnahmen/guetebericht.md` ansehen: eine Entwicklungszeile je vorhandener Art, alle Torsets „nicht eingefroren“, eine Zeile je Aufnahme mit Wahrheit.

- [ ] **Step 5: Commit**

```bash
git add apps/ios-member/Packages/Sensorik data/sensoraufnahmen/guetebericht.md
git commit -m "test(sensorik): Guetebericht je Befestigungsart und Guetetor fuer freigegebene Arten

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log -1 --format=%B
```

- [ ] **Step 6: Erster Abstimmungsdurchgang (ohne Torwirkung).** Den Bericht lesen. Wo der Zähler bei den Wasserflaschen-Aufnahmen offensichtlich danebenliegt (z. B. Curls 12 wahr, 0 gezählt), die Ursache mit einem kurzen Wegwerf-Skript im Scratchpad ansehen (gefiltertes Signal gegen Zeit, Schwellen eingezeichnet) und **nur Profil-Parameter** anpassen, jeweils mit `version` + 1. Die synthetischen Tests aus Task 6 müssen grün bleiben. Ergebnis als eigener Commit mit dem neuen `guetebericht.md`:

```bash
git add apps/ios-member/Packages/Sensorik/Sources/Sensorik/ZaehlerProfil.swift data/sensoraufnahmen/guetebericht.md
git commit -m "feat(sensorik): Startwerte an den Wasserflaschen-Aufnahmen abgestimmt

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log -1 --format=%B
```

Kein Profil wird in E2 eingefroren: das geschieht erst, wenn echte Sätze vorliegen (Spec B 4).

---

## Teil E3 — Herkunft am Satz

E3 ist ein eigener PR (Branch z. B. `claude/sensor-b-e3-herkunft`). Task 9 und 10 hängen von nichts ab. Task 11 braucht `RepEvents` aus dem Package (Task 4 und 5 gemergt); ist Gymtavo-Katalog Etappe 4 vorher gemergt, auf deren Stand von `SetWrite` aufsetzen (`machineId` dort eventuell optional) — die Ergänzung hier ist rein additiv.

### Task 9: Migration

**Files:**
- Create: `supabase/migrations/0048_satz_herkunft.sql` (Nummer prüfen: `ls supabase/migrations | tail -3`; ist 0048 belegt, die nächste freie nehmen und überall hier ersetzen)
- Test: `tests/integration/satz-herkunft-db.test.ts`

**Interfaces:**
- Produces: Spalten `workout_sets.volume_source text not null default 'eingegeben'`, `volume_counted int`, `rep_events jsonb`; Constraint `workout_sets_herkunft_consistent`.

- [ ] **Step 1: Failing test** — `tests/integration/satz-herkunft-db.test.ts`:

```ts
import { beforeAll, describe, expect, it } from "vitest";
import { createTestUser, serviceClient, uniqueEmail } from "./helpers/clients.js";

// Die Datenbank prueft die einfache Konsistenz selbst (Sensor-Spec B 6.1),
// damit kein zweiter Schreibweg je einen "gemessenen" Satz ohne Zaehlerstand
// ablegen kann. Die Regeln, die die Uebung kennen muessen, prueft recordSet.

const ereignisse = {
  algo: "langhantel/1",
  befestigungsart: "langhantel",
  unsicher: null,
  wiederholungen: Array.from({ length: 10 }, (_, i) => ({
    beginn: i * 2, umkehr: i * 2 + 1, ende: i * 2 + 1.9, ausschlag: 110, sicherheit: 0.9,
  })),
};

let basis: Record<string, unknown>;

beforeAll(async () => {
  const admin = serviceClient();
  const { data: studio, error: e1 } = await admin.from("studios").insert({ name: "Herkunft DB" }).select("id").single();
  if (e1) throw e1;
  const userId = await createTestUser(uniqueEmail("herkunft-db"));
  await admin.from("studio_memberships").insert({ studio_id: studio.id, user_id: userId, role: "member" });
  const { data: modell, error: e2 } = await admin.from("equipment_models")
    .insert({ studio_id: studio.id, name: "Curlbank", load_step: 2.5 }).select("id").single();
  if (e2) throw e2;
  const { data: maschine, error: e3 } = await admin.from("machines")
    .insert({ studio_id: studio.id, equipment_model_id: modell.id, label: "C1" }).select("id").single();
  if (e3) throw e3;
  const { data: uebung, error: e4 } = await admin.from("exercises")
    .insert({ studio_id: studio.id, name: "Curl", target_min: 8, target_max: 12 }).select("id").single();
  if (e4) throw e4;
  const sessionId = crypto.randomUUID();
  const { error: e5 } = await admin.from("workout_sessions").insert({ id: sessionId, studio_id: studio.id, user_id: userId });
  if (e5) throw e5;
  basis = {
    studio_id: studio.id, user_id: userId, session_id: sessionId, machine_id: maschine.id,
    exercise_id: uebung.id, load: 20, volume: 10,
  };
});

let setIndex = 0;
async function einfuegen(felder: Record<string, unknown>) {
  setIndex += 1;
  return serviceClient().from("workout_sets")
    .insert({ ...basis, id: crypto.randomUUID(), set_index: setIndex, ...felder })
    .select("volume_source, volume_counted, rep_events").single();
}

describe("workout_sets: Herkunft", () => {
  it("setzt ohne Angabe eingegeben", async () => {
    const { data, error } = await einfuegen({});
    expect(error).toBeNull();
    expect(data).toEqual({ volume_source: "eingegeben", volume_counted: null, rep_events: null });
  });

  it("nimmt gemessen mit Zaehlerstand gleich Umfang an", async () => {
    const { error } = await einfuegen({ volume_source: "gemessen", volume_counted: 10, rep_events: ereignisse });
    expect(error).toBeNull();
  });

  it("nimmt korrigiert mit abweichendem Zaehlerstand an", async () => {
    const { error } = await einfuegen({ volume_source: "korrigiert", volume_counted: 9, rep_events: ereignisse });
    expect(error).toBeNull();
  });

  it.each([
    ["eingegeben mit Zaehlerstand", { volume_source: "eingegeben", volume_counted: 10 }],
    ["gemessen ohne Ereignisse", { volume_source: "gemessen", volume_counted: 10 }],
    ["gemessen mit abweichendem Stand", { volume_source: "gemessen", volume_counted: 9, rep_events: ereignisse }],
    ["korrigiert mit gleichem Stand", { volume_source: "korrigiert", volume_counted: 10, rep_events: ereignisse }],
    ["unbekannte Herkunft", { volume_source: "geschaetzt" }],
    ["Zaehlerstand null Wiederholungen", { volume_source: "korrigiert", volume_counted: 0, rep_events: ereignisse }],
  ])("weist ab: %s", async (_name, felder) => {
    const { error } = await einfuegen(felder);
    expect(error?.code).toBe("23514");
  });
});
```

- [ ] **Step 2: Rot prüfen.** `pnpm test:integration tests/integration/satz-herkunft-db.test.ts` — Expected: FAIL (`column "volume_source" … does not exist` bzw. PGRST204).

- [ ] **Step 3: Migration** — `supabase/migrations/0048_satz_herkunft.sql`:

```sql
-- Herkunft der Wiederholungszahl am Satz (Sensor-Spec B 6.1).
--
-- Seit Teilprojekt B darf der Bewegungssensor Wiederholungen zaehlen. Das
-- Mitglied bestaetigt die Zahl beim Sichern oder korrigiert sie am Rad;
-- gespeichert wird, woher sie kommt, was der Zaehler stand und je
-- Wiederholung ein paar Kennzahlen fuer Tempo (C) und Spiel (D).
--
-- Rein additiv: Bestand und alte Clients landen ueber den Default bei
-- 'eingegeben'. Keine neue Policy -- die Spalten gehoeren zur Zeile und
-- fallen unter dieselbe Sichtbarkeit und Loeschung.

alter table public.workout_sets
  add column volume_source text not null default 'eingegeben'
    constraint workout_sets_volume_source_check
    check (volume_source in ('eingegeben', 'gemessen', 'korrigiert')),
  -- Mindestens 1: der Zaehler schreibt erst nach der ersten gezaehlten
  -- Wiederholung ins Rad. Wer nichts gezaehlt bekam, hat 'eingegeben'.
  add column volume_counted int
    constraint workout_sets_volume_counted_check
    check (volume_counted is null or volume_counted between 1 and 1000),
  add column rep_events jsonb,
  -- Die einfache Konsistenz prueft die Datenbank selbst; was die Uebung
  -- wissen muss (nur bei volume_kind 'reps'), prueft recordSet.
  add constraint workout_sets_herkunft_consistent check (
    (volume_source = 'eingegeben' and volume_counted is null and rep_events is null)
    or (volume_source = 'gemessen' and volume_counted = volume and rep_events is not null)
    or (volume_source = 'korrigiert' and volume_counted <> volume and rep_events is not null));
```

- [ ] **Step 4: Einspielen und grün prüfen.** `pnpm exec supabase migration up` (geteilte DB; additiv, schadet anderen Branches nicht), dann `pnpm test:integration tests/integration/satz-herkunft-db.test.ts` — Expected: alle PASS.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/0048_satz_herkunft.sql tests/integration/satz-herkunft-db.test.ts
git commit -m "feat(db): Herkunft, Zaehlerstand und Wiederholungs-Ereignisse am Satz

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log -1 --format=%B
```

### Task 10: Domäne und API

**Files:**
- Create: `packages/domain/src/herkunft.ts`
- Test: `packages/domain/src/herkunft.test.ts`
- Modify: `packages/domain/src/workout.ts` (Schema, `RecordedSet`, `SetRow`, `toRecordedSet`, `recordSet`)
- Modify: `packages/domain/src/index.ts` (Export)
- Test: `tests/integration/domain-record-set.test.ts` (neuer `describe`-Block)
- Test: `tests/integration/api-workout-sets.test.ts` (ein neuer Fall)

**Interfaces:**
- Consumes: Spalten aus Task 9.
- Produces:
  - `export const volumeSourceSchema = z.enum(["eingegeben", "gemessen", "korrigiert"])`, `export type VolumeSource`
  - `export const befestigungsartSchema`, `export const unsicherGrundSchema`, `export const repEventsSchema`, `export type RepEvents`
  - `export function herkunftPruefen(v: { volume: number; volumeSource: VolumeSource; volumeCounted?: number | null; repEvents?: RepEvents | null }): string | null` (Fehlertext oder `null`)
  - `recordSetInputSchema` mit `volumeSource` (Default `"eingegeben"`), `volumeCounted`, `repEvents`
  - `RecordedSet` mit `volumeSource: VolumeSource`, `volumeCounted: number | null`

- [ ] **Step 1: Failing unit tests** — `packages/domain/src/herkunft.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { herkunftPruefen, repEventsSchema } from "./herkunft.js";
import { recordSetInputSchema } from "./workout.js";

function events(n: number) {
  return {
    algo: "langhantel/1",
    befestigungsart: "langhantel" as const,
    unsicher: null,
    wiederholungen: Array.from({ length: n }, (_, i) => ({
      beginn: i * 2, umkehr: i * 2 + 1, ende: i * 2 + 1.9, ausschlag: 110, sicherheit: 0.9,
    })),
  };
}

const basis = {
  sessionId: "11111111-1111-4111-8111-111111111111",
  setId: "22222222-2222-4222-8222-222222222222",
  machineId: "33333333-3333-4333-8333-333333333333",
  exerciseId: "44444444-4444-4444-8444-444444444444",
  setIndex: 1,
  load: 20,
  volume: 10,
};

describe("repEventsSchema", () => {
  it("nimmt das Format aus der App an", () => {
    expect(repEventsSchema.safeParse(events(3)).success).toBe(true);
  });

  it("weist eine Wiederholung ab, deren Umkehr vor dem Beginn liegt", () => {
    const kaputt = events(1);
    kaputt.wiederholungen[0]!.umkehr = -1;
    expect(repEventsSchema.safeParse(kaputt).success).toBe(false);
  });

  it("weist Wiederholungen in falscher Reihenfolge ab", () => {
    const kaputt = events(2);
    kaputt.wiederholungen.reverse();
    expect(repEventsSchema.safeParse(kaputt).success).toBe(false);
  });

  it("weist eine unbekannte Befestigungsart und eine Sicherheit ueber 1 ab", () => {
    expect(repEventsSchema.safeParse({ ...events(1), befestigungsart: "nacken" }).success).toBe(false);
    const zuSicher = events(1);
    zuSicher.wiederholungen[0]!.sicherheit = 1.2;
    expect(repEventsSchema.safeParse(zuSicher).success).toBe(false);
  });

  it("verlangt den Schluessel unsicher, auch als null", () => {
    const { unsicher: _weg, ...ohne } = events(1);
    expect(repEventsSchema.safeParse(ohne).success).toBe(false);
  });
});

describe("herkunftPruefen", () => {
  it.each([
    ["eingegeben ohne alles", { volume: 10, volumeSource: "eingegeben" as const }, null],
    ["gemessen passend", { volume: 10, volumeSource: "gemessen" as const, volumeCounted: 10, repEvents: events(10) }, null],
    ["korrigiert passend", { volume: 12, volumeSource: "korrigiert" as const, volumeCounted: 10, repEvents: events(10) }, null],
  ])("laesst durch: %s", (_n, eingabe, erwartet) => {
    expect(herkunftPruefen(eingabe)).toBe(erwartet);
  });

  it.each([
    ["eingegeben mit Zaehlerstand", { volume: 10, volumeSource: "eingegeben" as const, volumeCounted: 10 }],
    ["eingegeben mit Ereignissen", { volume: 10, volumeSource: "eingegeben" as const, repEvents: events(10) }],
    ["gemessen ohne Ereignisse", { volume: 10, volumeSource: "gemessen" as const, volumeCounted: 10 }],
    ["gemessen mit anderem Stand", { volume: 10, volumeSource: "gemessen" as const, volumeCounted: 9, repEvents: events(9) }],
    ["korrigiert ohne Abweichung", { volume: 10, volumeSource: "korrigiert" as const, volumeCounted: 10, repEvents: events(10) }],
    ["Anzahl Ereignisse passt nicht", { volume: 10, volumeSource: "gemessen" as const, volumeCounted: 10, repEvents: events(9) }],
  ])("weist ab: %s", (_n, eingabe) => {
    expect(herkunftPruefen(eingabe)).toEqual(expect.any(String));
  });
});

describe("recordSetInputSchema -- Herkunft", () => {
  it("setzt ohne Angabe eingegeben (alte App-Versionen)", () => {
    const ergebnis = recordSetInputSchema.safeParse(basis);
    expect(ergebnis.success && ergebnis.data.volumeSource).toBe("eingegeben");
  });

  it("nimmt einen gemessenen Satz an", () => {
    const ergebnis = recordSetInputSchema.safeParse({
      ...basis, volumeSource: "gemessen", volumeCounted: 10, repEvents: events(10),
    });
    expect(ergebnis.success).toBe(true);
  });

  it("weist einen inkonsistenten Satz schon im Schema ab", () => {
    const ergebnis = recordSetInputSchema.safeParse({ ...basis, volumeSource: "gemessen" });
    expect(ergebnis.success).toBe(false);
  });
});
```

- [ ] **Step 2: Rot prüfen.** `pnpm --filter @fitretro/domain test -- herkunft` — Expected: FAIL (`Cannot find module './herkunft.js'`).

- [ ] **Step 3: `herkunft.ts`:**

```ts
import { z } from "zod";

/**
 * Herkunft der Wiederholungszahl (Sensor-Spec B 2, 6.1-6.3).
 *
 * eingegeben: kein Zaehler lief oder er hat nichts gezaehlt.
 * gemessen:   der Zaehler stand beim Sichern auf genau diesem Wert.
 * korrigiert: der Zaehler stand anders, das Mitglied hat am Rad gedreht.
 */
export const volumeSourceSchema = z.enum(["eingegeben", "gemessen", "korrigiert"]);
export type VolumeSource = z.infer<typeof volumeSourceSchema>;

// Rohwerte wie Befestigungsart / UnsicherGrund im Swift-Package Sensorik.
export const befestigungsartSchema = z.enum([
  "stapel", "langhantel", "kurzhantel", "hebelarm", "kabelgriff", "koerper",
]);
export const unsicherGrundSchema = z.enum(["luecke", "signalSchwach", "taktUnregelmaessig"]);

const wiederholungSchema = z
  .object({
    beginn: z.number().min(0),
    umkehr: z.number().min(0),
    ende: z.number().min(0),
    ausschlag: z.number().min(0),
    sicherheit: z.number().min(0).max(1),
  })
  .refine((w) => w.beginn <= w.umkehr && w.umkehr <= w.ende, {
    message: "Eine Wiederholung braucht Beginn <= Umkehr <= Ende.",
  });

/**
 * rep_events (Spec B 6.2): nur, was sich nicht ableiten laesst. Zeiten in
 * Sekunden seit Satzbeginn.
 */
export const repEventsSchema = z.object({
  algo: z.string().min(1).max(64),
  befestigungsart: befestigungsartSchema,
  // Pflichtschluessel, auch als null: ein fehlender Schluessel waere eine
  // zweite Bedeutung von "nichts".
  unsicher: unsicherGrundSchema.nullable(),
  wiederholungen: z
    .array(wiederholungSchema)
    .min(1)
    .max(1000)
    .refine((liste) => liste.every((w, i) => i === 0 || liste[i - 1]!.beginn <= w.beginn), {
      message: "Die Wiederholungen muessen nach Beginn sortiert sein.",
    }),
});
export type RepEvents = z.infer<typeof repEventsSchema>;

/** Konsistenz aus Spec B 6.1; Fehlertext oder null. */
export function herkunftPruefen(v: {
  volume: number;
  volumeSource: VolumeSource;
  volumeCounted?: number | null | undefined;
  repEvents?: RepEvents | null | undefined;
}): string | null {
  const gezaehlt = v.volumeCounted ?? null;
  const events = v.repEvents ?? null;
  if (v.volumeSource === "eingegeben") {
    return gezaehlt === null && events === null
      ? null
      : "Ein eingegebener Satz traegt weder Zaehlerstand noch Ereignisse.";
  }
  if (gezaehlt === null || events === null) {
    return "Ein gezaehlter Satz braucht Zaehlerstand und Ereignisse.";
  }
  if (events.wiederholungen.length !== gezaehlt) {
    return "Die Zahl der Ereignisse passt nicht zum Zaehlerstand.";
  }
  if (v.volumeSource === "gemessen" && gezaehlt !== v.volume) {
    return "Ein gemessener Satz hat den Zaehlerstand als Umfang.";
  }
  if (v.volumeSource === "korrigiert" && gezaehlt === v.volume) {
    return "Ein korrigierter Satz weicht vom Zaehlerstand ab.";
  }
  return null;
}
```

In `packages/domain/src/index.ts` im Stil der vorhandenen benannten Exporte:

```ts
export {
  befestigungsartSchema,
  herkunftPruefen,
  repEventsSchema,
  unsicherGrundSchema,
  volumeSourceSchema,
  type RepEvents,
  type VolumeSource,
} from "./herkunft.js";
```

- [ ] **Step 4: Schema in `workout.ts`.** Import ergänzen: `import { herkunftPruefen, repEventsSchema, volumeSourceSchema, type VolumeSource } from "./herkunft.js";`. Im `z.object({...})` von `recordSetInputSchema` nach `problemReason`:

```ts
    // Herkunft der Wiederholungszahl (Sensor-Spec B 6.3). Alte App-Versionen
    // senden nichts davon und landen bei 'eingegeben'.
    volumeSource: volumeSourceSchema.default("eingegeben"),
    volumeCounted: z.number().int().min(1).max(1000).nullish(),
    repEvents: repEventsSchema.nullish(),
```

und nach dem letzten `.refine(...)` innerhalb von `z.preprocess` einen weiteren:

```ts
  .superRefine((value, ctx) => {
    const fehler = herkunftPruefen(value);
    if (fehler) ctx.addIssue({ code: z.ZodIssueCode.custom, path: ["volumeSource"], message: fehler });
  }),
```

(Ist die Kette mit `.refine` verschachtelt, `superRefine` als letztes Glied derselben Kette anhängen; das schließende `)` von `z.preprocess` bleibt dahinter.)

- [ ] **Step 5: Unit-Tests grün.** `pnpm --filter @fitretro/domain test` — Expected: alle PASS, inklusive der bestehenden `workout.test.ts`.

- [ ] **Step 6: Failing Integrationstests.** In `tests/integration/domain-record-set.test.ts` am Ende ergänzen (nutzt `payload`, `memberAEmail`, `dauerlauf`, `laufband` aus dem Dateikopf):

```ts
function ereignisse(n: number) {
  return {
    algo: "langhantel/1",
    befestigungsart: "langhantel",
    unsicher: null,
    wiederholungen: Array.from({ length: n }, (_, i) => ({
      beginn: i * 2, umkehr: i * 2 + 1, ende: i * 2 + 1.9, ausschlag: 110, sicherheit: 0.9,
    })),
  };
}

describe("recordSet -- Herkunft (Sensor-Spec B 6.3)", () => {
  it("speichert eingegeben, wenn die App nichts dazu sagt", async () => {
    const client = await userClient(memberAEmail);
    const saved = await recordSet(client, payload());
    expect(saved.volumeSource).toBe("eingegeben");
    expect(saved.volumeCounted).toBeNull();
  });

  it("speichert einen gemessenen Satz samt Ereignissen", async () => {
    const client = await userClient(memberAEmail);
    const input = payload({ volumeSource: "gemessen", volumeCounted: 10, repEvents: ereignisse(10) });
    const saved = await recordSet(client, input);
    expect(saved.volumeSource).toBe("gemessen");
    expect(saved.volumeCounted).toBe(10);
    const { data } = await serviceClient().from("workout_sets").select("rep_events").eq("id", input.setId).single();
    expect(data?.rep_events).toEqual(ereignisse(10));
  });

  it("speichert einen korrigierten Satz", async () => {
    const client = await userClient(memberAEmail);
    const saved = await recordSet(client, payload({ volume: 12, volumeSource: "korrigiert", volumeCounted: 10, repEvents: ereignisse(10) }));
    expect(saved.volumeSource).toBe("korrigiert");
    expect(saved.volumeCounted).toBe(10);
  });

  it("bleibt idempotent mit Herkunft", async () => {
    const client = await userClient(memberAEmail);
    const input = payload({ volumeSource: "gemessen", volumeCounted: 10, repEvents: ereignisse(10) });
    expect(await recordSet(client, input)).toEqual(await recordSet(client, input));
  });

  it("weist eine gezaehlte Herkunft an einer Sekundenuebung ab", async () => {
    const client = await userClient(memberAEmail);
    await expect(
      recordSet(client, payload({
        machineId: laufband, exerciseId: dauerlauf, load: 8, secondaryLoad: 1, volume: 10,
        volumeSource: "gemessen", volumeCounted: 10, repEvents: ereignisse(10),
      })),
    ).rejects.toMatchObject({ code: "validation_failed" });
  });

  it("weist einen inkonsistenten Satz ab", async () => {
    const client = await userClient(memberAEmail);
    await expect(recordSet(client, payload({ volumeSource: "gemessen", volumeCounted: 9, repEvents: ereignisse(9) })))
      .rejects.toMatchObject({ code: "validation_failed" });
  });

  it("zeigt rep_events keinem anderen Mitglied", async () => {
    const client = await userClient(memberAEmail);
    const input = payload({ volumeSource: "gemessen", volumeCounted: 10, repEvents: ereignisse(10) });
    await recordSet(client, input);
    const fremdEmail = uniqueEmail("record-fremd");
    await createTestUser(fremdEmail);
    const fremd = await userClient(fremdEmail);
    const { data } = await fremd.from("workout_sets").select("rep_events").eq("id", input.setId);
    expect(data).toEqual([]);
  });
});
```

In `tests/integration/api-workout-sets.test.ts` einen Fall neben „speichert den Satz und liefert ihn kanonisch zurueck“ ergänzen, nach dem Muster der vorhandenen PUT-Aufrufe der Datei (gleicher Helfer, gleiche Kopfzeilen), mit Rumpf ohne die neuen Felder: `expect(body.volumeSource).toBe("eingegeben")` und `expect(body.volumeCounted).toBeNull()`.

- [ ] **Step 7: Rot prüfen.** `pnpm test:integration tests/integration/domain-record-set.test.ts tests/integration/api-workout-sets.test.ts` — Expected: die neuen Fälle FAIL (`volumeSource` ist `undefined`; die Sekundenübung wird angenommen).

- [ ] **Step 8: `recordSet` erweitern.** In `workout.ts`:

`RecordedSet` ergänzen:

```ts
  volumeSource: VolumeSource;
  /** Zaehlerstand beim Sichern; null bei 'eingegeben'. */
  volumeCounted: number | null;
```

`SetRow` ergänzen: `volume_source: VolumeSource; volume_counted: number | null;` und in `toRecordedSet`: `volumeSource: row.volume_source, volumeCounted: row.volume_counted,`.

In `recordSet` direkt nach der `MAX_VOLUME`-Prüfung:

```ts
  // Gezaehlt werden nur Wiederholungen (Sensor-Spec B 6.4). Eine
  // "gemessene" Sekundenzahl waere eine Messung, die nie stattfand.
  if (input.volumeSource !== "eingegeben" && exercise.volume_kind !== "reps") {
    throw new DomainError(
      "validation_failed",
      "Nur Wiederholungen koennen gezaehlt sein.",
    );
  }
```

Im `upsert` nach `problem_reason`:

```ts
      volume_source: input.volumeSource,
      volume_counted: input.volumeCounted ?? null,
      rep_events: input.repEvents ?? null,
```

Im `.select(...)`-String `, volume_source, volume_counted` vor `, performed_at` ergänzen.

- [ ] **Step 9: Grün prüfen.** `pnpm typecheck && pnpm test && pnpm test:integration` — Expected: alles PASS (bekannte Umgebungsfehler in `completeSession` aus der Memory-Notiz gesondert nennen, falls sie auftreten).

- [ ] **Step 10: Commit**

```bash
git add packages/domain tests/integration
git commit -m "feat(domain): recordSet nimmt Herkunft, Zaehlerstand und Ereignisse an

Ohne Angabe bleibt es eingegeben; gezaehlt nur bei Wiederholungen,
Konsistenz im Schema und in der Datenbank.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log -1 --format=%B
```

### Task 11: iOS-DTO und Warteschlange

**Files:**
- Modify: `apps/ios-member/FitnessMember/Networking/DTOs/WorkoutSet.swift`
- Test: `apps/ios-member/FitnessMemberTests/SetWriteHerkunftTests.swift`

**Interfaces:**
- Consumes: `RepEvents` aus `Sensorik` (Task 5), Server-Felder aus Task 10.
- Produces: `enum VolumeSource: String, Codable { case eingegeben, gemessen, korrigiert }`; `SetWrite.volumeSource: VolumeSource = .eingegeben`, `SetWrite.volumeCounted: Int? = nil`, `SetWrite.repEvents: RepEvents? = nil`; `RecordedSet.volumeSource: VolumeSource`, `RecordedSet.volumeCounted: Int?`.

- [ ] **Step 1: Failing tests** — `apps/ios-member/FitnessMemberTests/SetWriteHerkunftTests.swift`:

```swift
import Foundation
import Testing
import Sensorik
@testable import FitnessMember

struct SetWriteHerkunftTests {
    private func satz() -> SetWrite {
        SetWrite(machineId: "m", exerciseId: "e", setIndex: 1, load: 20, volume: 10)
    }

    @Test func ohneZaehlerIstEsEingegeben() {
        #expect(satz().volumeSource == .eingegeben)
        #expect(satz().volumeCounted == nil)
        #expect(satz().repEvents == nil)
    }

    @Test func gemessenUeberlebtDieWarteschlange() throws {
        var s = satz()
        s.volumeSource = .gemessen
        s.volumeCounted = 10
        s.repEvents = RepEvents(algo: "langhantel/1", befestigungsart: .langhantel, ereignisse: [], satzbeginn: 0)
        let zurueck = try JSONDecoder().decode(SetWrite.self, from: JSONEncoder().encode(s))
        #expect(zurueck == s)
    }

    /// Ein Eintrag, den ein aelterer Build offline in den PendingWriteStore
    /// geschrieben hat, kennt die neuen Schluessel nicht. Er muss nach dem
    /// Update dekodieren, sonst ist genau dieser Satz verloren.
    @Test func einAlterWarteschlangenEintragDekodiertAlsEingegeben() throws {
        let alt = #"{"machineId":"m","exerciseId":"e","setIndex":1,"load":20,"volume":10,"problemFlag":false}"#
        let s = try JSONDecoder().decode(SetWrite.self, from: Data(alt.utf8))
        #expect(s.volumeSource == .eingegeben)
        #expect(s.volumeCounted == nil)
        #expect(s.repEvents == nil)
    }

    @Test func eingegebenSchicktKeineZaehlerfelder() throws {
        let json = try #require(String(data: JSONEncoder().encode(satz()), encoding: .utf8))
        #expect(json.contains(#""volumeSource":"eingegeben""#))
        #expect(!json.contains("volumeCounted"))
        #expect(!json.contains("repEvents"))
    }

    @Test func dieAntwortDesServersDekodiertMitHerkunft() throws {
        let antwort = #"{"id":"s","studioId":"st","userId":"u","sessionId":"se","machineId":"m","exerciseId":"e","setIndex":1,"load":20,"secondaryLoad":null,"volume":10,"rir":null,"problemFlag":false,"problemReason":null,"performedAt":"2026-10-10T10:00:00Z","volumeSource":"gemessen","volumeCounted":10}"#
        let r = try JSONDecoder().decode(RecordedSet.self, from: Data(antwort.utf8))
        #expect(r.volumeSource == .gemessen)
        #expect(r.volumeCounted == 10)
    }
}
```

(Wenn `SetWrite`s memberwise-Init nach Gymtavo-Katalog Etappe 4 andere Pflichtparameter hat, `satz()` daran anpassen.)

- [ ] **Step 2: Rot prüfen.** `cd apps/ios-member && xcodegen generate && pgrep -lx xcodebuild; xcodebuild test -scheme FitnessMember -destination 'id=A2FB7461-E303-4CFE-AA08-9AC1B8C41707' -only-testing:FitnessMemberTests/SetWriteHerkunftTests 2>&1 | tail -20` — Expected: Kompilierfehler `value of type 'SetWrite' has no member 'volumeSource'`.

- [ ] **Step 3: Implementieren.** In `WorkoutSet.swift` `import Sensorik` ergänzen und:

```swift
/// Herkunft der Wiederholungszahl -- exakt die drei Werte aus
/// packages/domain/src/herkunft.ts volumeSourceSchema (Sensor-Spec B 6.3).
enum VolumeSource: String, Codable, Equatable {
    case eingegeben, gemessen, korrigiert
}
```

In `struct SetWrite` nach `sessionStartedAt`:

```swift
    /// Bis der Zaehler im Satzpfad laeuft (Sensor-Spec B E4) immer
    /// eingegeben. Zaehlerstand und Ereignisse nur bei gemessen/korrigiert;
    /// nil wird nicht mitgeschickt.
    var volumeSource: VolumeSource = .eingegeben
    var volumeCounted: Int? = nil
    var repEvents: RepEvents? = nil
```

`CodingKeys` um `volumeSource, volumeCounted, repEvents` erweitern. Im eigenen `init(from:)` am Ende:

```swift
        // Fehlt in Warteschlangen-Eintraegen aelterer Builds -- dann war es
        // eine Eingabe von Hand.
        volumeSource = try c.decodeIfPresent(VolumeSource.self, forKey: .volumeSource) ?? .eingegeben
        volumeCounted = try c.decodeIfPresent(Int.self, forKey: .volumeCounted)
        repEvents = try c.decodeIfPresent(RepEvents.self, forKey: .repEvents)
```

Hat `SetWrite` keinen eigenen `encode(to:)`, lässt der synthetisierte Encoder `nil`-Optionals bereits weg (`encodeIfPresent`) — der Test `eingegebenSchicktKeineZaehlerfelder` bestätigt das. In `struct RecordedSet` ergänzen:

```swift
    let volumeSource: VolumeSource
    let volumeCounted: Int?
```

und — damit Antworten älterer Server-Stände während eines gestaffelten Deploys weiter dekodieren — einen `init(from:)` in einer Extension, der `volumeSource` mit `decodeIfPresent(...) ?? .eingegeben` liest und alle anderen Felder wie bisher mit `decode`/`decodeIfPresent` (bei Optionals). Danach Step 2 wiederholen.

- [ ] **Step 4: Grün prüfen (volles App-Testset).** `pgrep -lx xcodebuild; cd apps/ios-member && xcodebuild test -scheme FitnessMember -destination 'id=A2FB7461-E303-4CFE-AA08-9AC1B8C41707' 2>&1 | tail -20` — Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add apps/ios-member
git commit -m "feat(ios): Satz-DTO kennt Herkunft, Zaehlerstand und Ereignisse

Die App sendet bis E4 immer eingegeben; alte Warteschlangen-Eintraege
dekodieren weiter.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log -1 --format=%B
```

### Task 12: Abschluss der Etappen

**Files:**
- Modify: `docs/superpowers/specs/2026-10-10-sensor-wiederholungszaehler-design.md` (Status-Zeile)
- Modify: `docs/superpowers/plans/2026-10-10-sensor-wiederholungszaehler.md` (Häkchen)

- [ ] **Step 1: Volles Testset** (Global Constraints) und Ergebnis notieren; umgebungsbedingte Fehler gesondert benennen.
- [ ] **Step 2: Spec-Status** je abgeschlossener Etappe ergänzen, z. B. `**Umgesetzt:** E1 (PR #…), E2 (PR #…), E3 (PR #…). E4/E5: eigener Plan nach Gymtavo-Katalog Etappe 4.`
- [ ] **Step 3: Commit**

```bash
git add docs/superpowers
git commit -m "docs(plan): Sensor B Etappen E1 bis E3 umgesetzt und abgehakt

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log -1 --format=%B
```

---

## Spec-Abdeckung (Selbstprüfung)

| Spec B | Task |
|---|---|
| 3.1 Regel, 3.3 (a) Docs | 1 |
| 3.2/3.3 (b)(c)(d) iOS | 2 |
| 3.2/3.3 (b)(c)(d) Web, Domain-Kommentar | 3 |
| 5.1 Package, CI | 4 |
| 5.2 Typen, `RepEvents` | 5 |
| 5.2 `ZaehlerProfil`, `Zaehler`; 5.3 Kette | 6 |
| 5.4 Korrekturen; 5.5 Lauf über Aufnahmen | 7 |
| 5.5 Gütebericht, Tor | 8 |
| 6.1 Migration | 9 |
| 6.2/6.3 Domäne, API | 10 |
| 6.3 iOS-DTO | 11 |
| 6.4–6.8, 7 | eigener Plan (E4/E5) |
