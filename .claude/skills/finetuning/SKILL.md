---
name: finetuning
description: Arbeitet eine Testsitzung (sitzung.md aus dem Testnotiz-Modul) für das Trainerportal testgetrieben ab – Notizen den Dateien zuordnen, Ursache finden, Plan in docs/superpowers/plans schreiben, je Etappe roter Test → Umsetzung, prüfen, committen, auf Freigabe PR und Merge nach grüner CI. Nutzen, wenn Testnotizen, eine sitzung.md oder „Feinschliff“ am Portal abgearbeitet werden sollen.
---

# Finetuning – Testnotizen für das Trainerportal abarbeiten

Eine Testsitzung (`sitzung.md`, Format:
`docs/superpowers/specs/2026-09-14-testnotiz-format.md`) wird Notiz für Notiz
in kleine, geprüfte Änderungen übersetzt. Der Referenzlauf ist PR #27 mit dem
Plan `docs/superpowers/plans/2026-09-23-testnotizen-trainerportal.md`. Lies ihn
vor dem Start, er zeigt Ton, Gliederung und Tiefe.

Nutzt `/superpowers`, wenn verfügbar. Sonst gilt dieser Ablauf.

## 1 · Verstehen, bevor geändert wird

- Jede Notiz nennt **Screen** (`page.tsx`-Pfad), **Ebenen** (Layouts) und oft
  ein **Element** (Beschriftung oder `id`). Die Datei öffnen, das Element im
  Code finden, auch in den Layouts und Bausteinen darüber.
- **Ursache vor Symptom.** Beispiel 23.09.: Die Schrift war schwarz, weil
  `<dialog>` vom Browser `color: CanvasText` erbt. Die Lösung war eine Zeile am
  Dialog, nicht eine Farbe am Namen.
- Ist eine Notiz mehrdeutig, entscheide mit Begründung und nenne die
  Entscheidung am Ende. Frag nur, wenn die Antwort den Umbau grundlegend ändert.
- Verwandte Notizen zu Etappen bündeln (z. B. „Stift-Marke“ #3 + #5).

## 2 · Plan schreiben

`docs/superpowers/plans/<JJJJ-MM-TT>-testnotizen-trainerportal.md`:

- Kopf: Quelle (Sitzung, Gerät, Stand-Commit), Vorgehen.
- Je Etappe: welche Notizen, Ursache, Änderung, **welcher Test zuerst rot
  wird**. Reine CSS-Änderungen ohne Test, dafür begründen.
- Schluss: Abschnitt **Geprüft**, nach der Umsetzung ausfüllen.

## 3 · Testgetrieben umsetzen, Etappe für Etappe

1. **Rot:** Vitest-Test neben der Komponente (`*.test.tsx`, Kopfzeile
   `// @vitest-environment jsdom`) oder Reinfunktion (`*.test.ts`). Laufen
   lassen und das Scheitern sehen:
   `cd apps/web && npx vitest run <Name>`
2. **Grün:** minimal umsetzen, bis der Test besteht.
3. Kann ein Baustein das schon, einen Charakterisierungstest schreiben und das
   im Plan so nennen.

Test-Handgriffe aus dem Repo:
- `vi.mock("next/link", …)` → schlichtes `<a>`;
  `vi.mock("next/navigation", …)` für `usePathname`,
  `useSelectedLayoutSegment`, `useSearchParams` (Werte über `vi.hoisted`).
- Server-Aktionen mocken (`vi.mock("../actions", …)`).
- jsdom kennt `showModal`/`close` nicht vollständig: im `beforeAll`
  nachbilden (open-Attribut setzen, `close`-Ereignis feuern).
  `HTMLMediaElement.prototype.play` durch ein Promise ersetzen.
- Logik mit Verzweigungen (z. B. Schrittfolgen) in eine Reinfunktion ziehen und
  die direkt testen (Vorbild: `geraete/assistent.ts`).

## 4 · Stil des Repos

- Deutsche Bezeichner. Kommentare auf Deutsch **ohne Umlaute im Code**
  (ae/oe/ue/ss), mit Verweis `(Testnotiz TT.MM., #n)`. Sie begründen das
  *Warum*. Sichtbare Texte mit echten Umlauten.
- Farben nur über Tokens aus `app/globals.css` (`--accent`, `--on-accent`,
  `--text`, `--text-muted`, `--warn`, `--surface`, …). `--warn` nie
  flächig.
- **Eine Hauptaktion (Akzent) pro Bildschirm.** Nebenaktionen `.secondary`,
  zerstörende `.destructive`.
- Bausteine in `app/portal/bausteine/` wiederverwenden (`Seite`, `Abschnitt`,
  `Zeile`, `Hinzufuegen`, `Schrittleiste`, `Stift`, `NochZuTun`,
  `VideoAbspieler`, …), statt Neues daneben zu bauen.
- Native Elemente vor Eigenbau: `<dialog>`, `<details>`.
- Trefferflächen ≥ 40 px (44 px am Telefon). `e2e/bausteine.spec.ts` prüft das.
- iOS/Safari mitdenken: Die Tests entstehen am iPhone.

## 5 · E2E nachziehen

Geänderte Beschriftungen, eingeklappte Bereiche und neue Abläufe in `e2e/*.spec.ts`
anpassen. Bestehende Kommentare dort erklären, warum Tests so gebaut sind.
Stehen lassen, ergänzen.

## 6 · Prüfen

```bash
cd apps/web && npx vitest run          # alle Unit-Tests
pnpm typecheck                         # Web (next typegen + tsc)
cd ../.. && npx tsc --noEmit           # Wurzel inkl. e2e/
NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321 NEXT_PUBLIC_SUPABASE_ANON_KEY=dummy \
APPLE_TEAM_ID=ABCDE12345 APPLE_BUNDLE_ID=x.y.z pnpm build   # Produktionsbau
```

Fehlen Abhängigkeiten: `pnpm install --frozen-lockfile`.

Playwright braucht ein lokales Supabase (`cp .env.example .env && pnpm exec
supabase start`). In Cloud-Sessions sperrt das Netz die Docker-Images. Dann
laufen die E2E-Tests erst in CI. Das im Plan und in der Antwort offen sagen,
nicht verschweigen.

## 7 · Abschließen

1. Abschnitt **Geprüft** im Plan ausfüllen: was lief, was nicht, was am
   Gerät noch anzusehen ist.
2. Committen (`feat(portal): Testnotizen TT.MM. – …`, Körper: eine Zeile je
   Notiz) und auf den vorgegebenen Branch pushen.
3. Antwort an den Nutzer: eine Tabelle **Notiz → Umsetzung**, dann offene
   Entscheidungen mit Empfehlung.
4. **PR und Merge nur auf Wunsch.** PR gegen `master`, CI-Job `web` abwarten,
   erst bei grün und konfliktfrei mergen (merge commit). Ist CI rot, Ursache
   beheben und neu pushen, nie Tests abschalten.
