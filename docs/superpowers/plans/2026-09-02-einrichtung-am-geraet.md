# Einrichtung am Gerät — Umsetzungsplan

> **Für agentische Ausführung:** ERFORDERLICHE UNTER-SKILL: `superpowers:subagent-driven-development` (empfohlen) oder `superpowers:executing-plans`, Aufgabe für Aufgabe. Die Schritte tragen Checkboxen (`- [ ]`) zum Mitführen.

**Ziel:** Der sechsschrittige Gang durch die Halle im Trainerportal — Modell, Einstellungen, Gerät, Tag, Übungen, Video — auf 390 px, mit dem Sucher als einzigem echten Neubau.

**Architektur:** Der Gang trägt seinen Zustand in der URL, nicht in einem Client-State. Nach jedem Schritt existiert die Zeile in der Datenbank, und der nächste Schritt ist ein Server-Component-Aufruf mit der frischen ID im Pfad — ein Neuladen mitten in der Halle verliert nichts. Die Bildschirme liegen unter einer eigenen Route-Gruppe ohne die Desktop-Rail; die Fachschicht bekommt drei neue Funktionen und **keine Migration**. Der Sucher ist `getUserMedia` plus `jsQR` im Browser, weil Safari `BarcodeDetector` nicht kennt; sein Backend (`inspect_tag`, `bind_tag_to_machine`) steht seit `0028` vollständig.

**Tech-Stack:** Next.js 15 (App Router, Server Actions), React 19, TypeScript, `@fitretro/domain`, Supabase (RLS + `security definer`-Funktionen), `jsqr`, `tus-js-client`, Vitest (Unit + Integration), Playwright (E2E).

**Spec:** `docs/superpowers/specs/2026-09-01-einrichtung-am-geraet-design.md`

**Artboards:** `docs/superpowers/design/portal/Telefon*.dc.html` und `Ablauf.dc.html`, erzeugt von `gen_telefon.py` — dort steht die verbindliche Textfassung jedes Bildschirms.

**Vorgänger-Specs:** `2026-09-01-tag-lieferung-design.md` (§3, Antworttabelle von `inspect_tag`), `2026-08-30-designsystem.md` (Tokens), `2026-08-31-trainerportal-struktur-design.md` (§5, Offline-Ausnahme).

---

## Globale Rahmenbedingungen

Aus der Spec, wörtlich übernommen. Jede Aufgabe steht implizit unter diesen Sätzen.

- **Keine Migration.** Spec §5: *„Die zweite Runde kostet keine Migration."* Alles hängt an Tabellen und Funktionen, die seit `0028` stehen. Wer in diesem Plan eine `.sql`-Datei anlegt, hat sich verlaufen.
- **Das Portal erzeugt keinen Token.** Spec §6. `createTag` ist weg und bleibt weg; `token_hash` ist seit `0026` eine generierte Spalte und für `authenticated` nicht schreibbar.
- **Das Foto ist Pflicht, die Spalte bleibt nullable.** Spec §5: *„Dass das Foto Pflicht ist, bleibt eine Regel der Oberfläche — die Spalte ist nullable, und das soll sie bleiben: Altmodelle tragen keines."*
- **Schritt 2 (Einstellungen) und Schritt 6 (Video) sind überspringbar, Schritt 1, 3 und 4 nicht.** Spec §2.
- **Genau eine Akzentfläche je Bildschirm.** Designsystem. Der Akzent (`--accent`, `#d4ff3f`) gehört der einen Hauptaktion. Konvention aus Spec §3, maschinell prüfbar: `background: var(--accent)` für die Aktionsfläche, `background-color: var(--accent)` für Balken und Marken. Sucher und Aufnahme tragen **keine** Akzentfläche im Fluss — dort ist der Auslöser die Handlung.
- **Trefferflächen in der Halle sind größer als am Schreibtisch.** Designsystem §1, umgesetzt in `build.py`: Hauptaktion 56 px hoch und volle Breite, Nebenaktion 48 px, Eingabefeld mindestens 52 px.
- **„Offline" gilt hier, und nur hier.** Spec §4 und Entscheidung 7, ausdrückliche Ausnahme zu `trainerportal-struktur-design.md` §5. Die Formulierung ist immer *„gespeichert, wird gesendet"*, nie *„fehlgeschlagen"*.
- **Deutsche Oberflächentexte mit Umlauten, deutsche Bezeichner im Web-Layer, englische Funktionsnamen in `packages/domain`.** So steht der Bestand; Quellcode-Kommentare in `packages/domain` schreiben Umlaute aus (`Geraet`), Oberflächentexte nicht.
- **Immer der nutzergebundene Client, nie Service-Role.** `packages/domain/src/catalog.ts`, Kopfkommentar: *„Die Studio-Konsistenz lebt in den Policies."*
- **Der Token ist ein Locator, kein Ausweis.** 22 Zeichen base64url, `/^[A-Za-z0-9_-]{22}$/`.

---

## Dateistruktur

### Fachschicht — `packages/domain/`

| Datei | Verantwortung |
| --- | --- |
| `src/tag-scan.ts` **(neu)** | Der Tokenraum als reine Zeichenkettenarbeit: Muster, Formatprüfung, und was aus einem gescannten QR-Inhalt herauszulesen ist. **Kein `node:`-Import** — der Sucher ist ein Browserbundle. |
| `src/nummern.ts` **(neu)** | `naechsteGeraeteNummer`. Rein, ohne Supabase-Import. |
| `src/tags.ts` **(ändern)** | Bezieht Muster und `isValidTagToken` aus `tag-scan.ts`, statt sie ein zweites Mal zu schreiben. |
| `src/catalog.ts` **(ändern)** | `listStudioExercises` — die studioweite Übungsliste, die `getStudioCatalog` nicht liefert. |
| `src/index.ts`, `package.json` **(ändern)** | Re-Exporte und ein Unterpfad (`./tag-scan`) für die Client-Komponente. |

### Web — `apps/web/app/portal/[studioId]/`

Die Desktop-Seiten wandern in die Route-Gruppe `(schreibtisch)`, damit der Gang eine eigene Hülle bekommt. **Route-Gruppen ändern keine URL** — `/portal/<id>/geraete` bleibt `/portal/<id>/geraete`.

| Datei | Verantwortung |
| --- | --- |
| `(schreibtisch)/layout.tsx` | Die bisherige Rail-Hülle, unverändert bis auf die Importtiefe |
| `(schreibtisch)/{page,geraete,leute,modelle,tags}` | Unverändert bis auf die Importtiefe |
| `Rail.tsx`, `catalog.ts` | Bleiben liegen — keine Route-Dateien |
| `einrichten/layout.tsx` **(neu)** | Hallen-Hülle: 390-px-Spalte, Studiokopf, `UploadsProvider` |
| `einrichten/halle.module.css` **(neu)** | Die Telefonebene der Tokens. Getrennt von `portal.module.css`, weil sie andere Trefferflächen trägt |
| `einrichten/actions.ts` **(neu)** | Die Server Actions des Gangs. Getrennt von `portal/actions.ts`, weil sie **IDs zurückgeben** statt nur `ok` — der nächste Schritt braucht die frische ID im Pfad |
| `einrichten/befund.ts` **(neu)** | Verdikt → Antwortsatz und nächster Schritt. Rein, damit die Antworttabelle aus Spec §4 als Test dasteht |
| `einrichten/Schrittleiste.tsx` **(neu)** | Sechs Segmente plus Wegmarke |
| `einrichten/page.tsx` **(neu)** | Einstieg — `TelefonStart` |
| `einrichten/modell/page.tsx` **(neu)** | Schritt 1, wählen — `TelefonModell` |
| `einrichten/modell/neu/page.tsx` + `ModellNeuFormular.tsx` **(neu)** | Schritt 1, anlegen — `TelefonModellNeu`, Foto Pflicht |
| `einrichten/modell/[modelId]/einstellungen/page.tsx` + `ParameterSheet.tsx` **(neu)** | Schritt 2 — `TelefonEinstellungen`, `TelefonParameterNeu` |
| `einrichten/modell/[modelId]/geraet/page.tsx` **(neu)** | Schritt 3 — `TelefonGeraet` |
| `einrichten/geraet/[machineId]/tag/page.tsx` + `Sucher.tsx` + `TagSchritt.tsx` **(neu)** | Schritt 4 — `TelefonKleben`, `TelefonScan`, `TelefonScanTreffer` |
| `einrichten/geraet/[machineId]/uebungen/page.tsx` + `UebungSheet.tsx` **(neu)** | Schritt 5 — `TelefonUebungen`, `TelefonUebungWaehlen`, `TelefonUebungNeu` |
| `einrichten/geraet/[machineId]/fertig/page.tsx` **(neu)** | `TelefonFertig` |
| `einrichten/Uploads.tsx` + `einrichten/uploads/page.tsx` **(neu)** | Die Warteschlange — `TelefonUploads` |

**Warum `einrichten/actions.ts` und nicht `portal/actions.ts`:** die Desktop-Actions geben `ActionResult` zurück und revalidieren feste Schreibtischpfade. Der Gang braucht nach jedem Schritt die erzeugte ID, um weiterzunavigieren. Beides in eine Datei zu zwingen hieße, jede bestehende Action um einen Rückgabewert und einen Pfadparameter zu erweitern — acht Aufrufstellen anfassen für nichts. Was zusammen wächst, liegt zusammen.

### Tests

| Datei | Deckt |
| --- | --- |
| `packages/domain/src/tag-scan.test.ts` **(neu)** | Aufgabe 1 |
| `packages/domain/src/nummern.test.ts` **(neu)** | Aufgabe 2 |
| `tests/integration/domain-exercises.test.ts` **(neu)** | Aufgabe 3, samt Mandantengrenze |
| `apps/web/app/portal/[studioId]/einrichten/befund.test.ts` **(neu)** | Aufgabe 4 — die Antworttabelle aus Spec §4 |
| `e2e/einrichten.spec.ts` **(neu)** | Der ganze Gang, Aufgaben 5–13 |

---

## Was dieser Plan bewusst nicht baut

Damit ein Prüfer die Lücken nicht für Versehen hält:

- **Die Chipnavigation aus `build.py`** (`Überblick · Kurse · Geräte · Tags · Leute · Einstellungen`) steht auf jedem `telefon()`-Artboard, ist aber die Telefonfassung des *ganzen* Portals. Drei dieser sechs Seiten gibt es nicht (Überblick, Kurse, Einstellungen), die übrigen nur als Desktop-Ansicht. Sie gehört zu Phase 5. Der Gang trägt stattdessen einen Studiokopf mit einem Rückweg zum Schreibtisch.
- **Die Kamera-Oberflächen für Foto und Aufnahme** (`TelefonFoto.dc.html`, `TelefonVideo.dc.html`) werden durch `<input type="file" capture="environment">` erfüllt — dieselbe Bedienung, vom Betriebssystem gestellt, samt Auslöser und Wiederholung. Spec §5 nennt „Foto am Telefon" ausdrücklich **vollständig vorhanden** und vermisst allein die mobile Form; `VideoUpload.tsx` geht seit dem Medienplan denselben Weg. `getUserMedia` bleibt dem Sucher vorbehalten, wo es keine Alternative gibt. Der Preis ist der laufende 45-Sekunden-Zähler des Artboards: die Länge steht als Satz am Feld und wird nach dem Upload **an der Datei** geprüft (`readVideoDurationSeconds`), nicht während der Aufnahme. Eine zu lange Aufnahme fällt damit später auf als gezeichnet.
- **Die Ablaufkarte (`Ablauf.dc.html`, 1440 px).** Sie erklärt den Gang, sie führt ihn nicht — eine Wandtafel, kein Bildschirm im Fluss. Ihr Platz ist der Schreibtisch, und der wird in Phase 5 gestaltet.
- **Der Überblick** (`~ Überblick — „Am Gerät scannen" statt „Tags anlegen"`). Die Seite gibt es noch nicht; sie hängt an der Datenschutzgrenze aus Phase 2.4.
- **Kein Offline-Zwischenspeicher** (kein Service Worker, kein IndexedDB). Spec §4 verlangt für „kein Netz" *eine Formulierung*, keine Synchronisationsschicht: *„gespeichert, wird gesendet"*. Der Videoupload setzt über TUS ohnehin fort. Ein echter Offline-Puffer für Gerät und Tag wäre ein eigener Bauabschnitt mit eigener Konfliktfrage und steht in keiner Spec.
- **Kein `BarcodeDetector`-Zweig.** Chrome auf Android hätte ihn, Safari nicht. Zwei Decoder-Pfade heißen zwei Fehlerbilder und ein Pfad, der auf dem Testgerät nie läuft. Der Sucher nimmt immer `jsQR`.

### Die elf Zustandskarten, Karte für Karte

`TelefonZustaende.dc.html` ist das dichteste Artboard der Seite. Damit sich nachrechnen lässt, was davon gebaut wird:

| Karte | Wo |
| --- | --- |
| Der Tag hängt schon woanders | Aufgabe 4 + 9 |
| Der Tag ist gesperrt | Aufgabe 4 + 9 |
| Das ist ein Aushangschild | Aufgabe 4 + 9 |
| Der Tag gehört nicht zu diesem Studio | Aufgabe 4 + 9 |
| Tag ersetzen | Aufgabe 13 |
| Die Kamera ist nicht freigegeben | Aufgabe 9, `Sucher.tsx` |
| Die Packung ist leer | Aufgabe 5 (Einstieg) und 12 (Abschluss) |
| Noch keine Übung | Aufgabe 10 |
| Das Modell hat kein Foto | Aufgabe 5 (Einstieg) und 7 (Schritt 2) |
| Noch keine Einstellparameter | Aufgabe 7 |
| **Kein Netz im Keller** | **nicht gebaut** — siehe den Punkt zum Offline-Zwischenspeicher oben |

---

## Aufgabe 1: Den Tokenraum aus dem Scan lesen

Der Sucher bekommt vom Decoder eine Zeichenkette. Auf dem Tag steht eine vollständige Adresse (`https://…/t/<token>`, `2026-09-01-scan-beitritt-design.md` §1), im Rückfallweg tippt der Trainer nur den Token. Beides muss zum selben Token führen, und beides an einer Stelle.

Die Datei darf **kein `node:crypto`** anfassen: `VideoUpload.tsx` trägt den Befund im Kommentar — das Barrel `index.ts` zieht über `tags.ts` das Modul mit, und der Browserbundle scheitert daran. Deshalb wandern Muster und Formatprüfung nach unten in eine node-freie Datei, und `tags.ts` bezieht sie von dort.

**Dateien:**
- Anlegen: `packages/domain/src/tag-scan.ts`
- Anlegen: `packages/domain/src/tag-scan.test.ts`
- Ändern: `packages/domain/src/tags.ts`
- Ändern: `packages/domain/src/index.ts`, `packages/domain/package.json`

**Schnittstellen:**
- Nutzt: nichts
- Liefert:
  - `TAG_TOKEN_LENGTH: 22`, `TAG_TOKEN_PATTERN: RegExp`
  - `isValidTagToken(value: string): boolean` — zieht aus `tags.ts` hierher um, Signatur unverändert
  - `parseTagScan(roh: string): string | null` — Token aus Adresse oder Klartext, sonst `null`

- [ ] **Schritt 1: Den fehlschlagenden Test schreiben**

`packages/domain/src/tag-scan.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { isValidTagToken, parseTagScan } from "./tag-scan.js";

const TOKEN = "AbCdEfGhIjKlMnOpQrStUv";

describe("parseTagScan", () => {
  it("nimmt den blanken Token, wie ihn der Rueckfallweg eintippt", () => {
    expect(parseTagScan(TOKEN)).toBe(TOKEN);
  });

  it("schneidet Leerraum weg -- ein Tastaturvorschlag haengt gern eines an", () => {
    expect(parseTagScan(`  ${TOKEN} `)).toBe(TOKEN);
  });

  it("liest den Token aus der Adresse, die auf dem Tag steht", () => {
    expect(parseTagScan(`https://gymodo-web.vercel.app/t/${TOKEN}`)).toBe(TOKEN);
  });

  it("liest ihn auch mit Schraegstrich, Abfrage und Anker dahinter", () => {
    expect(parseTagScan(`https://example.test/t/${TOKEN}/`)).toBe(TOKEN);
    expect(parseTagScan(`https://example.test/t/${TOKEN}?von=nfc`)).toBe(TOKEN);
    expect(parseTagScan(`https://example.test/t/${TOKEN}#oben`)).toBe(TOKEN);
  });

  it("weist einen fremden QR ab, statt etwas zu erfinden", () => {
    expect(parseTagScan("https://example.test/irgendwas")).toBeNull();
    expect(parseTagScan("WLAN:S=Kraftwerk;T=WPA;P=geheim;;")).toBeNull();
    expect(parseTagScan("")).toBeNull();
  });

  it("weist einen zu kurzen und einen zu langen Token ab", () => {
    expect(parseTagScan("AbCdEfGhIjKlMnOpQrStU")).toBeNull();
    expect(parseTagScan("AbCdEfGhIjKlMnOpQrStUvW")).toBeNull();
  });

  // Ein 23-Zeichen-Token in einer Adresse darf nicht stillschweigend auf 22
  // zurueckschneiden -- das zeigte auf einen fremden Tag.
  it("schneidet einen zu langen Token in der Adresse nicht zurecht", () => {
    expect(parseTagScan(`https://example.test/t/${TOKEN}W`)).toBeNull();
  });

  it("weist Zeichen ab, die base64url nicht kennt", () => {
    expect(parseTagScan("AbCdEfGhIjKlMnOpQrSt+/")).toBeNull();
  });

  // Der Locator steht im Klartext auf einem Aufkleber -- die Klein- und
  // Grossschreibung traegt Information und darf nicht eingeebnet werden.
  it("bleibt schreibungsempfindlich", () => {
    expect(parseTagScan(TOKEN.toLowerCase())).toBe(TOKEN.toLowerCase());
    expect(parseTagScan(TOKEN.toLowerCase())).not.toBe(TOKEN);
  });
});

describe("isValidTagToken", () => {
  it("gilt fuer genau 22 base64url-Zeichen", () => {
    expect(isValidTagToken(TOKEN)).toBe(true);
    expect(isValidTagToken("zu-kurz")).toBe(false);
  });
});
```

- [ ] **Schritt 2: Test laufen lassen und den Fehlschlag sehen**

Ausführen: `pnpm --filter @fitretro/domain exec vitest run src/tag-scan.test.ts`

Erwartet: FAIL — `Failed to resolve import "./tag-scan.js"`

- [ ] **Schritt 3: Die minimale Umsetzung schreiben**

`packages/domain/src/tag-scan.ts`:

```ts
/**
 * Der Tokenraum als reine Zeichenkettenarbeit -- ohne node:crypto, damit der
 * Sucher diese Datei in einen Browserbundle packen kann. tags.ts bezieht das
 * Muster von hier; dort steht nur noch, was Zufall und Hash braucht.
 */

/** Laenge eines base64url-kodierten 128-Bit-Tokens. */
export const TAG_TOKEN_LENGTH = 22;
export const TAG_TOKEN_PATTERN = /^[A-Za-z0-9_-]{22}$/;

/** Formatpruefung vor jeder Verwendung. Ersetzt keine Autorisierung. */
export function isValidTagToken(value: string): boolean {
  return value.length === TAG_TOKEN_LENGTH && TAG_TOKEN_PATTERN.test(value);
}

// Auf dem Tag steht die vollstaendige Adresse, im Rueckfallweg tippt der
// Trainer nur den Token. Der Anker am Ende laesst Schraegstrich, Abfrage und
// Fragment zu, aber kein 23. Tokenzeichen -- sonst schnitte ein zu langer
// Token stillschweigend auf 22 zurueck und zeigte auf einen fremden Tag.
const AUS_ADRESSE = /\/t\/([A-Za-z0-9_-]{22})(?:[/?#]|$)/;

/**
 * Was der Sucher gelesen hat, als Token -- oder null.
 *
 * Null heisst "das ist kein Tag von uns" und fuehrt zur Antwort *unbekannt*.
 * Erfunden wird hier nichts: ein fremder QR bekommt keine Notloesung.
 */
export function parseTagScan(roh: string): string | null {
  const text = roh.trim();
  if (isValidTagToken(text)) return text;
  const treffer = AUS_ADRESSE.exec(text);
  return treffer ? treffer[1]! : null;
}
```

- [ ] **Schritt 4: `tags.ts` auf die neue Datei umstellen**

`packages/domain/src/tags.ts` vollständig ersetzen durch:

```ts
import { createHash, randomBytes } from "node:crypto";
import { TAG_TOKEN_LENGTH } from "./tag-scan.js";

export { isValidTagToken } from "./tag-scan.js";

/**
 * Erzeugt einen Tag-Token mit 128 Bit Zufall.
 * Der Token ist ein oeffentlicher Locator, keine Authentisierung.
 */
export function createTagToken(): string {
  const token = randomBytes(16).toString("base64url");
  // Sicherung gegen ein Auseinanderlaufen von Erzeuger und Muster: beides
  // steht jetzt in zwei Dateien, und der Erzeuger haelt sich an die andere.
  if (token.length !== TAG_TOKEN_LENGTH) {
    throw new Error(`Tokenlaenge ${token.length}, erwartet ${TAG_TOKEN_LENGTH}`);
  }
  return token;
}

/**
 * SHA-256 des Tokens als Hex. Seit 0026 erzeugt die Datenbank ihn selbst als
 * generierte Spalte; diese Funktion bleibt fuer das Betreiberwerkzeug.
 */
export function hashTagToken(token: string): string {
  return createHash("sha256").update(token, "utf8").digest("hex");
}
```

- [ ] **Schritt 5: Exporte nachziehen**

In `packages/domain/src/index.ts` die bisherige Tag-Zeile

```ts
export { createTagToken, hashTagToken, isValidTagToken } from "./tags.js";
```

ersetzen durch:

```ts
export { createTagToken, hashTagToken } from "./tags.js";
export {
  TAG_TOKEN_LENGTH,
  TAG_TOKEN_PATTERN,
  isValidTagToken,
  parseTagScan,
} from "./tag-scan.js";
```

In `packages/domain/package.json` die `exports` ergänzen:

```json
  "exports": {
    ".": "./src/index.ts",
    "./media": "./src/media.ts",
    "./chargen": "./src/chargen.ts",
    "./tag-scan": "./src/tag-scan.ts"
  }
```

- [ ] **Schritt 6: Tests laufen lassen**

Ausführen: `pnpm --filter @fitretro/domain test`

Erwartet: PASS — auch `src/tags.test.ts` und `src/index.test.ts` unverändert grün.

Ausführen: `pnpm typecheck`

Erwartet: keine Fehler.

- [ ] **Schritt 7: Committen**

```bash
git add packages/domain/src/tag-scan.ts packages/domain/src/tag-scan.test.ts \
        packages/domain/src/tags.ts packages/domain/src/index.ts \
        packages/domain/package.json
git commit -m "feat(domain): Tokenraum node-frei als tag-scan.ts, mit parseTagScan"
```

---

## Aufgabe 2: Die nächste Gerätenummer vorschlagen

`TelefonGeraet.dc.html`: *„Vorgeschlagen ist die nächste nach der höchsten. Sie steht am Gerät und in der App des Mitglieds — nimm die, die schon draufsteht."* Ein Vorschlag, keine Vorschrift: Spec §7 hält ausdrücklich fest, dass das Portal `machines.label` **nicht** erzwingen soll, und `0007_machines.sql` kennt keine Eindeutigkeit.

Nur rein numerische Bezeichnungen zählen mit. `„Beinpresse 7"` wird nicht angerechnet — wer seine Geräte so benennt, bekommt keinen erratenen Vorschlag.

**Dateien:**
- Anlegen: `packages/domain/src/nummern.ts`
- Anlegen: `packages/domain/src/nummern.test.ts`
- Ändern: `packages/domain/src/index.ts`

**Schnittstellen:**
- Nutzt: nichts
- Liefert: `naechsteGeraeteNummer(labels: string[]): string`

- [ ] **Schritt 1: Den fehlschlagenden Test schreiben**

`packages/domain/src/nummern.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { naechsteGeraeteNummer } from "./nummern.js";

describe("naechsteGeraeteNummer", () => {
  it("faengt bei eins an, wenn noch kein Geraet steht", () => {
    expect(naechsteGeraeteNummer([])).toBe("1");
  });

  it("nimmt die naechste nach der hoechsten, nicht die naechste Luecke", () => {
    expect(naechsteGeraeteNummer(["12", "13"])).toBe("14");
    expect(naechsteGeraeteNummer(["1", "3"])).toBe("4");
  });

  it("achtet nicht auf die Reihenfolge der Liste", () => {
    expect(naechsteGeraeteNummer(["13", "7", "12"])).toBe("14");
  });

  // Der Entwurf raet nicht: wer "Beinpresse 7" schreibt, fuehrt keine
  // Nummern, und ein aus Prosa gezogener Vorschlag waere geraten.
  it("ueberliest Bezeichnungen, die keine blanke Zahl sind", () => {
    expect(naechsteGeraeteNummer(["Beinpresse 7", "Latzug"])).toBe("1");
    expect(naechsteGeraeteNummer(["7", "Beinpresse 9"])).toBe("8");
  });

  it("nimmt Leerraum um die Zahl herum hin", () => {
    expect(naechsteGeraeteNummer([" 12 "])).toBe("13");
  });

  it("liest eine fuehrende Null als Zahl", () => {
    expect(naechsteGeraeteNummer(["07"])).toBe("8");
  });
});
```

- [ ] **Schritt 2: Test laufen lassen und den Fehlschlag sehen**

Ausführen: `pnpm --filter @fitretro/domain exec vitest run src/nummern.test.ts`

Erwartet: FAIL — `Failed to resolve import "./nummern.js"`

- [ ] **Schritt 3: Die minimale Umsetzung schreiben**

`packages/domain/src/nummern.ts`:

```ts
/**
 * Der Nummernvorschlag fuer ein neues Geraet.
 *
 * Ein Vorschlag, keine Vorschrift: machines.label ist frei (0007), und der
 * Entwurf sagt ausdruecklich, dass das Portal die Nummer nicht erzwingt --
 * am Geraet klebt womoeglich schon eine andere, und die gilt.
 */
export function naechsteGeraeteNummer(labels: string[]): string {
  const zahlen = labels
    .map((label) => label.trim())
    .filter((label) => /^\d+$/.test(label))
    .map(Number);
  const hoechste = zahlen.length === 0 ? 0 : Math.max(...zahlen);
  return String(hoechste + 1);
}
```

- [ ] **Schritt 4: Export nachziehen**

In `packages/domain/src/index.ts` ergänzen:

```ts
export { naechsteGeraeteNummer } from "./nummern.js";
```

- [ ] **Schritt 5: Tests laufen lassen**

Ausführen: `pnpm --filter @fitretro/domain test`

Erwartet: PASS

- [ ] **Schritt 6: Committen**

```bash
git add packages/domain/src/nummern.ts packages/domain/src/nummern.test.ts \
        packages/domain/src/index.ts
git commit -m "feat(domain): naechsteGeraeteNummer schlaegt vor, ohne zu erzwingen"
```

---

## Aufgabe 3: Die studioweite Übungsliste

Spec §2: *„Schritt 4 zeigt eine Auswahl über die vorhandenen Übungen des Studios, kein leeres Namensfeld. Sonst steht ‚Rudern sitzend' fünfmal im Katalog, jedes Mal anders geschrieben."* (Der Gang ist seit der zweiten Runde sechsschrittig; die Übungen sind darin Schritt 5.)

`getStudioCatalog` liefert Übungen nur **je Modell** (`CatalogModel.exercises`). Eine Übung, die an keinem Modell hängt, kommt dort gar nicht vor — und `TelefonUebungWaehlen.dc.html` zeigt genau so eine Zeile: *„Trizepsdrücken am Seil · Noch an keinem Modell"*. Die Liste fehlt also wirklich.

**Dateien:**
- Ändern: `packages/domain/src/catalog.ts` (hinter `detachExercise`, vor `createMachine`)
- Ändern: `packages/domain/src/index.ts`
- Anlegen: `tests/integration/domain-exercises.test.ts`

**Schnittstellen:**
- Nutzt: `requireUserId` aus `./auth.js`, `DomainError` aus `./errors.js` — beide in `catalog.ts` bereits importiert
- Liefert:
  ```ts
  export type StudioExercise = {
    id: string;
    name: string;
    description: string | null;
    targetRepsMin: number;
    targetRepsMax: number;
    modelCount: number;
  };
  export async function listStudioExercises(
    client: SupabaseClient,
    studioId: string,
  ): Promise<StudioExercise[]>;
  ```

- [ ] **Schritt 1: Den fehlschlagenden Test schreiben**

`tests/integration/domain-exercises.test.ts`:

```ts
import { beforeAll, describe, expect, it } from "vitest";
import { listStudioExercises } from "@fitretro/domain";
import {
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";

let studioA: string;
let studioB: string;
let trainerA: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioFehler } = await admin
    .from("studios")
    .insert([{ name: "Uebungen Studio A" }, { name: "Uebungen Studio B" }])
    .select("id");
  if (studioFehler) throw studioFehler;
  studioA = studios[0]!.id;
  studioB = studios[1]!.id;

  trainerA = uniqueEmail("uebungen-trainer-a");
  const nutzer = await createTestUser(trainerA);
  const { error: mitgliedFehler } = await admin
    .from("studio_memberships")
    .insert({ studio_id: studioA, user_id: nutzer, role: "trainer" });
  if (mitgliedFehler) throw mitgliedFehler;

  const { data: modelle, error: modellFehler } = await admin
    .from("equipment_models")
    .insert([
      { studio_id: studioA, name: "Uebungen-Modell 1", weight_step_kg: 5 },
      { studio_id: studioA, name: "Uebungen-Modell 2", weight_step_kg: 5 },
    ])
    .select("id");
  if (modellFehler) throw modellFehler;

  const { data: uebungen, error: uebungFehler } = await admin
    .from("exercises")
    .insert([
      {
        studio_id: studioA,
        name: "Rudern sitzend",
        target_reps_min: 10,
        target_reps_max: 15,
      },
      {
        studio_id: studioA,
        name: "Trizepsdruecken am Seil",
        target_reps_min: 10,
        target_reps_max: 15,
      },
      {
        studio_id: studioB,
        name: "Fremde Uebung",
        target_reps_min: 8,
        target_reps_max: 12,
      },
    ])
    .select("id");
  if (uebungFehler) throw uebungFehler;

  // "Rudern sitzend" haengt an beiden Modellen, "Trizepsdruecken" an keinem.
  const { error: linkFehler } = await admin
    .from("equipment_model_exercises")
    .insert([
      {
        equipment_model_id: modelle[0]!.id,
        exercise_id: uebungen[0]!.id,
        sort_order: 1,
      },
      {
        equipment_model_id: modelle[1]!.id,
        exercise_id: uebungen[0]!.id,
        sort_order: 1,
      },
    ]);
  if (linkFehler) throw linkFehler;
});

describe("listStudioExercises", () => {
  it("nennt auch die Uebung, die an keinem Modell haengt", async () => {
    const client = await userClient(trainerA);
    const liste = await listStudioExercises(client, studioA);

    const namen = liste.map((uebung) => uebung.name);
    expect(namen).toContain("Rudern sitzend");
    // Genau der Fall, den getStudioCatalog nicht kennt -- und den das
    // Auswahl-Sheet zeigt.
    expect(namen).toContain("Trizepsdruecken am Seil");
  });

  it("zaehlt, an wie vielen Modellen eine Uebung haengt", async () => {
    const client = await userClient(trainerA);
    const liste = await listStudioExercises(client, studioA);

    const rudern = liste.find((uebung) => uebung.name === "Rudern sitzend")!;
    expect(rudern.modelCount).toBe(2);
    expect(rudern.targetRepsMin).toBe(10);
    expect(rudern.targetRepsMax).toBe(15);

    const trizeps = liste.find(
      (uebung) => uebung.name === "Trizepsdruecken am Seil",
    )!;
    expect(trizeps.modelCount).toBe(0);
  });

  it("sortiert nach Namen -- das Sheet wird gelesen, nicht durchsucht", async () => {
    const client = await userClient(trainerA);
    const liste = await listStudioExercises(client, studioA);
    const namen = liste.map((uebung) => uebung.name);
    expect(namen).toEqual([...namen].sort((a, b) => a.localeCompare(b, "de")));
  });

  it("gibt die Uebungen eines fremden Studios nicht heraus", async () => {
    const client = await userClient(trainerA);
    const liste = await listStudioExercises(client, studioB);
    expect(liste).toEqual([]);
  });
});
```

- [ ] **Schritt 2: Test laufen lassen und den Fehlschlag sehen**

Ausführen: `npx vitest run --config vitest.config.ts tests/integration/domain-exercises.test.ts`

Erwartet: FAIL — `listStudioExercises is not a function`

- [ ] **Schritt 3: Die minimale Umsetzung schreiben**

In `packages/domain/src/catalog.ts`, hinter `detachExercise` und vor `createMachine`:

```ts
export type StudioExercise = {
  id: string;
  name: string;
  description: string | null;
  targetRepsMin: number;
  targetRepsMax: number;
  /** An wie vielen Modellen sie haengt. Null ist ein gueltiger Zustand. */
  modelCount: number;
};

/**
 * Alle Uebungen eines Studios -- auch die, die an keinem Modell haengen.
 *
 * getStudioCatalog liefert Uebungen nur je Modell; eine freie Uebung kaeme
 * dort nicht vor. Das Auswahl-Sheet im Gang braucht aber gerade sie: sonst
 * legt jedes Studio "Rudern sitzend" fuenfmal an, jedes Mal anders
 * geschrieben (Spec 2).
 *
 * Kein requireStudioStaff: die Policy auf exercises entscheidet. Ein fremdes
 * Studio liefert die leere Menge, keinen Fehler -- der Aufrufer soll nicht
 * erfahren, ob es das Studio gibt.
 */
export async function listStudioExercises(
  client: SupabaseClient,
  studioId: string,
): Promise<StudioExercise[]> {
  await requireUserId(client);

  const { data, error } = await client
    .from("exercises")
    .select(
      "id, name, description, target_reps_min, target_reps_max, equipment_model_exercises (id)",
    )
    .eq("studio_id", studioId)
    .order("name", { ascending: true });

  if (error) throw new DomainError("internal", error.message);

  return (data ?? []).map((zeile) => ({
    id: zeile.id as string,
    name: zeile.name as string,
    description: (zeile.description as string | null) ?? null,
    targetRepsMin: zeile.target_reps_min as number,
    targetRepsMax: zeile.target_reps_max as number,
    modelCount:
      (zeile.equipment_model_exercises as unknown[] | null)?.length ?? 0,
  }));
}
```

- [ ] **Schritt 4: Exporte nachziehen**

In `packages/domain/src/index.ts` bei den `./catalog.js`-Exporten `listStudioExercises` alphabetisch einfügen (zwischen `getStudioCatalog` und `reactivateMachine`) und bei den Typen `StudioExercise` (hinter `StudioCatalog`).

- [ ] **Schritt 5: Tests laufen lassen**

Ausführen: `npx vitest run --config vitest.config.ts tests/integration/domain-exercises.test.ts`

Erwartet: PASS, 4 Tests.

Ausführen: `pnpm typecheck`

Erwartet: keine Fehler.

- [ ] **Schritt 6: Committen**

```bash
git add packages/domain/src/catalog.ts packages/domain/src/index.ts \
        tests/integration/domain-exercises.test.ts
git commit -m "feat(domain): listStudioExercises kennt auch die freie Uebung"
```

---

## Aufgabe 4: Die Antworttabelle des Suchers als Code

Spec §4 und `TelefonZustaende.dc.html` legen fest, was der Sucher sagt und welcher Ausgang danach offensteht. `inspect_tag` (0028) liefert fünf Verdikte: `frei`, `vergeben`, `gesperrt`, `aushangschild`, `unbekannt`. Die Zuordnung von Verdikt zu Satz ist reine Abbildung — und damit das eine Stück dieses Bauabschnitts, das sich ohne Kamera und ohne Datenbank prüfen lässt.

Zwei Fälle tragen **keine** Hauptaktion, und das ist der Kern der Tabelle: *„schon vergeben"* (Spec §4: *„keine Hauptaktion"* — ein vergebener Tag wird nicht mit einem Tap umgehängt, Entscheidung 8) und *„Aushangschild"* (*„eine Sackgasse mit genau einem Ausgang"*).

**Dateien:**
- Anlegen: `apps/web/app/portal/[studioId]/einrichten/befund.ts`
- Anlegen: `apps/web/app/portal/[studioId]/einrichten/befund.test.ts`

**Schnittstellen:**
- Nutzt: nichts
- Liefert:
  ```ts
  export type Verdikt = "frei" | "vergeben" | "gesperrt" | "aushangschild" | "unbekannt";
  export type Befund =
    | { verdikt: "frei"; batchCode: string; batchIndex: number }
    | { verdikt: "vergeben"; machineId: string; machineLabel: string }
    | { verdikt: "gesperrt" }
    | { verdikt: "aushangschild" }
    | { verdikt: "unbekannt" };
  export type Antwort = {
    titel: string;
    text: string;
    hauptaktion: "verbinden" | "ersetzen" | null;
    ton: "gut" | "neutral" | "warnung";
  };
  export function antwortAuf(
    befund: Befund,
    geraetLabel: string,
    optionen?: { geraetHatTag?: boolean },
  ): Antwort;
  ```

- [ ] **Schritt 1: Den fehlschlagenden Test schreiben**

`apps/web/app/portal/[studioId]/einrichten/befund.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { antwortAuf } from "./befund";

describe("antwortAuf", () => {
  it("bietet bei einem freien Tag das Verbinden an und nennt die Charge", () => {
    const antwort = antwortAuf(
      { verdikt: "frei", batchCode: "7", batchIndex: 42 },
      "Kabelzug 14",
    );
    expect(antwort.titel).toBe("Tag erkannt");
    expect(antwort.text).toContain("Charge 7");
    expect(antwort.hauptaktion).toBe("verbinden");
    expect(antwort.ton).toBe("gut");
  });

  // Entscheidung 8: "Ein vergebener Tag wird nicht mit einem Tap umgehaengt."
  // Sonst verliert ein Geraet seinen Tag, ohne dass jemand davorsteht.
  it("bietet bei einem vergebenen Tag KEINE Hauptaktion, sondern nennt das Geraet", () => {
    const antwort = antwortAuf(
      { verdikt: "vergeben", machineId: "abc", machineLabel: "Beinpresse 7" },
      "Kabelzug 14",
    );
    expect(antwort.text).toContain("Beinpresse 7");
    expect(antwort.hauptaktion).toBeNull();
  });

  it("laesst einen gesperrten Tag gesperrt", () => {
    const antwort = antwortAuf({ verdikt: "gesperrt" }, "Kabelzug 14");
    expect(antwort.titel).toContain("Gesperrt");
    expect(antwort.hauptaktion).toBeNull();
    expect(antwort.ton).toBe("warnung");
  });

  // Spec 4: eine Sackgasse mit genau einem Ausgang. Das Schild ist ab der
  // Lieferung gueltig -- hier gibt es nichts zu verbinden.
  it("sagt beim Aushangschild, was in der Hand liegt, und bietet nichts an", () => {
    const antwort = antwortAuf({ verdikt: "aushangschild" }, "Kabelzug 14");
    expect(antwort.titel).toBe("Das ist ein Aushangschild");
    expect(antwort.text).toContain("an die Wand");
    expect(antwort.hauptaktion).toBeNull();
  });

  it("gibt fuer unbekannt und fremdes Studio dieselbe Antwort", () => {
    const antwort = antwortAuf({ verdikt: "unbekannt" }, "Kabelzug 14");
    expect(antwort.text).toContain("Melde dich beim Betreiber");
    expect(antwort.hauptaktion).toBeNull();
  });

  // Der Fall "am Geraet klebt schon einer": derselbe freie Tag, aber die
  // Hauptaktion heisst Ersetzen statt Verbinden (Zustaende, "Am Geraet").
  it("macht aus Verbinden ein Ersetzen, wenn das Geraet schon einen Tag traegt", () => {
    const antwort = antwortAuf(
      { verdikt: "frei", batchCode: "7", batchIndex: 42 },
      "Kabelzug 14",
      { geraetHatTag: true },
    );
    expect(antwort.hauptaktion).toBe("ersetzen");
    expect(antwort.text).toContain("wird dabei ungültig");
  });
});
```

- [ ] **Schritt 2: Test laufen lassen und den Fehlschlag sehen**

Ausführen: `pnpm --filter @fitretro/web test`

Erwartet: FAIL — `Failed to resolve import "./befund"`

- [ ] **Schritt 3: Die minimale Umsetzung schreiben**

`apps/web/app/portal/[studioId]/einrichten/befund.ts`:

```ts
/**
 * Die Antworttabelle des Suchers -- Spec 4 und TelefonZustaende.dc.html.
 *
 * Rein und ohne Netz, damit sie sich als Test lesen laesst: was der Sucher
 * antwortet, ist eine Produktentscheidung und keine Laufzeitfrage. Die
 * Verdikte kommen woertlich aus inspect_tag (0028).
 */

export type Verdikt =
  | "frei"
  | "vergeben"
  | "gesperrt"
  | "aushangschild"
  | "unbekannt";

export type Befund =
  | { verdikt: "frei"; batchCode: string; batchIndex: number }
  | { verdikt: "vergeben"; machineId: string; machineLabel: string }
  | { verdikt: "gesperrt" }
  | { verdikt: "aushangschild" }
  | { verdikt: "unbekannt" };

export type Antwort = {
  titel: string;
  text: string;
  /** null heisst: hier gibt es nichts zu tun, nur einen Weg zurueck. */
  hauptaktion: "verbinden" | "ersetzen" | null;
  ton: "gut" | "neutral" | "warnung";
};

export function antwortAuf(
  befund: Befund,
  geraetLabel: string,
  optionen: { geraetHatTag?: boolean } = {},
): Antwort {
  switch (befund.verdikt) {
    case "frei":
      return optionen.geraetHatTag
        ? {
            titel: "Tag erkannt",
            text: `Charge ${befund.batchCode} · Nummer ${befund.batchIndex}. An ${geraetLabel} klebt schon ein Tag — der alte wird dabei ungültig. Zieh ihn danach ab: er öffnet nichts mehr, aber er verwirrt.`,
            hauptaktion: "ersetzen",
            ton: "warnung",
          }
        : {
            titel: "Tag erkannt",
            text: `Charge ${befund.batchCode} · Nummer ${befund.batchIndex} · vorrätig, noch keinem Gerät zugeordnet. Ab dem Verbinden ist ${geraetLabel} für Mitglieder auffindbar.`,
            hauptaktion: "verbinden",
            ton: "gut",
          };

    // Keine Hauptaktion, und das ist Entscheidung 8: sonst verloere ein Geraet
    // seinen Tag, ohne dass jemand davorsteht.
    case "vergeben":
      return {
        titel: "Der Tag hängt schon woanders",
        text: `Dieser Tag gehört zu ${befund.machineLabel}. Ein vergebener Tag wird nicht mit einem Tap umgehängt. Nimm einen anderen aus der Packung.`,
        hauptaktion: null,
        ton: "neutral",
      };

    case "gesperrt":
      return {
        titel: "Gesperrt bleibt gesperrt",
        text: "Auch nach einem Neustart, auch nach einem Jahr. Der Eintrag steht als Nachweis weiter in der Liste. Nimm einen anderen aus der Packung.",
        hauptaktion: null,
        ton: "warnung",
      };

    // Eine Sackgasse mit genau einem Ausgang: das Schild ist ab der Lieferung
    // gueltig und gehoert an die Wand.
    case "aushangschild":
      return {
        titel: "Das ist ein Aushangschild",
        text: "Kein Gerätetag: dieses Schild gehört an die Wand. Wer es scannt, wird Mitglied — dafür ist es ab der Lieferung gültig, du musst nichts freischalten. Nimm einen Tag aus der Gerätepackung.",
        hauptaktion: null,
        ton: "neutral",
      };

    // Eine Antwort fuer zwei Faelle, und das ist Absicht (Spec 4): dieselbe
    // Regel, die join_studio_by_tag im Rumpf traegt.
    case "unbekannt":
      return {
        titel: "Der Tag gehört nicht zu diesem Studio",
        text: "Unbekannt oder aus einem fremden Studio. Neue Lieferung angekommen? Melde dich beim Betreiber.",
        hauptaktion: null,
        ton: "warnung",
      };
  }
}
```

- [ ] **Schritt 4: Test laufen lassen**

Ausführen: `pnpm --filter @fitretro/web test`

Erwartet: PASS, 6 Tests in `befund.test.ts`, `route.test.ts` unverändert grün.

- [ ] **Schritt 5: Committen**

```bash
git add "apps/web/app/portal/[studioId]/einrichten/befund.ts" \
        "apps/web/app/portal/[studioId]/einrichten/befund.test.ts"
git commit -m "feat(web): Antworttabelle des Suchers als reine Abbildung"
```

---

## Aufgabe 5: Die Hallen-Hülle und der Einstieg

Der Gang braucht eine Seite ohne die 288-px-Rail. `[studioId]/layout.tsx` legt sie heute über **alles** unter `[studioId]`. Die Route-Gruppe `(schreibtisch)` schiebt sie auf die Desktop-Seiten zurück, ohne eine einzige URL zu ändern — Klammersegmente zählen im Pfad nicht mit.

Diese Aufgabe fasst fünf bestehende Seiten an und ist deshalb die riskanteste im Plan. Die Absicherung ist der bestehende E2E-Bestand: `trainerportal.spec.ts`, `leute.spec.ts` und `auth.spec.ts` laufen über genau diese Seiten und müssen danach unverändert grün sein.

**Dateien:**
- Verschieben: `apps/web/app/portal/[studioId]/{layout.tsx,page.tsx,geraete,leute,modelle,tags}` → `.../(schreibtisch)/…`
- Anlegen: `apps/web/app/portal/[studioId]/einrichten/layout.tsx`
- Anlegen: `apps/web/app/portal/[studioId]/einrichten/halle.module.css`
- Anlegen: `apps/web/app/portal/[studioId]/einrichten/Schrittleiste.tsx`
- Anlegen: `apps/web/app/portal/[studioId]/einrichten/page.tsx`
- Anlegen: `e2e/helpers/studio.ts`
- Anlegen: `e2e/einrichten.spec.ts`

**Schnittstellen:**
- Nutzt: `ladeKatalog`, `erreichbarkeit` aus `../catalog` (Aufgabe 3 hat sie nicht angefasst)
- Liefert:
  - `halle.module.css` mit den Klassen, die jede folgende Aufgabe verwendet: `seite`, `kopf`, `studio`, `titel`, `unterzeile`, `zurueck`, `karte`, `karteGestrichelt`, `abschnitt`, `abschnittKopf`, `zeile`, `zeileHaupt`, `zeileMeta`, `notiz`, `label`, `feld`, `eingabe`, `auswahl`, `haupt`, `neben`, `gefaehrlich`, `chips`, `chip`, `chipAktiv`, `marke`, `balkenBahn`, `balken`, `fehler`, `zahl`, `zahlLabel`, `leiste`, `leisteSegment`, `leisteSegmentVoll`
  - `<Schrittleiste nummer={1..6} titel="Modell" />`
  - `e2e/helpers/studio.ts`: `studioMitTrainer(page, praefix): Promise<{ admin, studioId, email, userId }>`

- [ ] **Schritt 1: Die Desktop-Seiten in die Route-Gruppe schieben**

```bash
cd apps/web/app/portal/\[studioId\]
mkdir "(schreibtisch)"
git mv layout.tsx page.tsx geraete leute modelle tags "(schreibtisch)/"
```

`Rail.tsx` und `catalog.ts` bleiben liegen — sie sind keine Route-Dateien und werden von beiden Hüllen gebraucht.

- [ ] **Schritt 2: Die Importtiefe nachziehen**

Jede verschobene Datei liegt jetzt eine Ebene tiefer. Genau diese Zeilen ändern sich:

| Datei unter `(schreibtisch)/` | alt → neu |
| --- | --- |
| `layout.tsx` | `./Rail` → `../Rail`; `./catalog` → `../catalog`; `../portal.module.css` → `../../portal.module.css` |
| `page.tsx` | `../Form` → `../../Form`; `../actions` → `../../actions`; `./catalog` → `../catalog`; `../portal.module.css` → `../../portal.module.css` |
| `geraete/page.tsx` | `../../Form` → `../../../Form`; `../../actions` → `../../../actions`; `../catalog` → `../../catalog`; `../../portal.module.css` → `../../../portal.module.css` |
| `leute/page.tsx` | `../../portal.module.css` → `../../../portal.module.css` (`./LeuteActions` bleibt) |
| `leute/LeuteActions.tsx` | `../../Form` → `../../../Form`; `../../actions` → `../../../actions`; `../../portal.module.css` → `../../../portal.module.css` |
| `modelle/[modelId]/page.tsx` | `../../../Form` → `../../../../Form`; `../../../ParameterFormular` → `../../../../ParameterFormular`; `../../../VideoUpload` → `../../../../VideoUpload`; `../../../actions` → `../../../../actions`; `../../catalog` → `../../../catalog`; `../../../portal.module.css` → `../../../../portal.module.css` |
| `tags/page.tsx` | `../../Form` → `../../../Form`; `../../actions` → `../../../actions`; `../catalog` → `../../catalog`; `../../portal.module.css` → `../../../portal.module.css` (`./TagBinden` bleibt) |
| `tags/TagBinden.tsx` | `../../actions` → `../../../actions`; `../../portal.module.css` → `../../../portal.module.css` |

Die Aliasimporte (`@/lib/supabase/server`) und die Paketimporte (`@fitretro/domain`) bleiben unberührt.

- [ ] **Schritt 3: Prüfen, dass der Schreibtisch unverändert steht**

**Zuerst die alten generierten Typen wegräumen:**

```bash
rm -rf apps/web/.next/types
```

`next typegen` legt die Routentypen neu an, **löscht aber die alten nicht**. Ohne diesen Schritt meldet der Typecheck `TS2307: Cannot find module '../../../app/portal/[studioId]/tags/page.js'` für jede verschobene Seite — ein Fehler in generiertem Code, der auf eine Datei zeigt, die es nicht mehr gibt. Das sieht nach einem kaputten Umbau aus und ist nur Müll von vorher.

Ausführen: `pnpm typecheck`

Erwartet: keine Fehler. Ein übersehener relativer Import fällt hier auf, nicht erst im Browser.

Ausführen: `pnpm test:e2e -- trainerportal leute auth`

Erwartet: PASS. Die URLs sind dieselben geblieben — eine Route-Gruppe zählt im Pfad nicht mit. Wäre das falsch, schlüge hier jeder Test mit 404 fehl.

- [ ] **Schritt 4: Committen, bevor Neues dazukommt**

Der Umbau steht für sich und soll sich getrennt zurückrollen lassen.

```bash
git add -A "apps/web/app/portal/[studioId]"
git commit -m "refactor(web): Schreibtischseiten in die Route-Gruppe (schreibtisch)"
```

- [ ] **Schritt 5: Die Telefonebene der Tokens anlegen**

`apps/web/app/portal/[studioId]/einrichten/halle.module.css`:

```css
/* Die Telefonebene der Tokens aus docs/superpowers/specs/2026-08-30-designsystem.md.
   Getrennt von portal.module.css, weil sie andere Trefferflaechen traegt:
   die App wird einhaendig bedient, oft mit feuchten Haenden (Designsystem 1).
   Hauptaktion 56 px, Nebenaktion 48 px, Feld mindestens 52 px.

   Konvention aus Spec 3: `background` fuer die eine Akzentflaeche je
   Bildschirm, `background-color` fuer Balken und Marken. Dieselbe Farbe,
   zwei Rollen -- und "genau eine Akzentflaeche" wird damit pruefbar. */

.seite {
  max-width: 390px;
  margin: 0 auto;
  min-height: 100vh;
  background: var(--bg);
  display: flex;
  flex-direction: column;
}

.kopf {
  border-bottom: 1px solid var(--line);
  background: var(--surface);
  padding: var(--s16);
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: var(--s12);
}

.studio {
  font-size: 15px;
  font-weight: 800;
  letter-spacing: -0.02em;
  text-transform: uppercase;
}

.inhalt {
  padding: var(--s20) var(--s16) var(--s40);
  display: flex;
  flex-direction: column;
  gap: var(--s16);
  flex-grow: 1;
}

.titel {
  font-size: 26px;
  font-weight: 800;
  letter-spacing: -0.03em;
  text-transform: uppercase;
  margin: var(--s8) 0 0;
}

.unterzeile {
  color: var(--text-muted);
  font-size: 13px;
  margin: var(--s4) 0 0;
}

.zurueck {
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--text-faint);
}

.label {
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--text-muted);
}

.notiz {
  font-size: 12px;
  color: var(--text-faint);
  line-height: 1.4;
  margin: 0;
}

.karte {
  border: 1px solid var(--line);
  border-radius: var(--r-card);
  background: var(--surface);
  padding: var(--s16);
  display: flex;
  flex-direction: column;
  gap: var(--s12);
}

.karteGestrichelt {
  composes: karte;
  border-style: dashed;
}

.karteWarnung {
  composes: karte;
  border-color: var(--warn);
}

.abschnitt {
  border: 1px solid var(--line);
  border-radius: var(--r-card);
  background: var(--surface);
  overflow: hidden;
}

.abschnittKopf {
  padding: 14px var(--s16);
  border-bottom: 1px solid var(--line);
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: var(--s12);
}

.zeile {
  padding: var(--s12) var(--s16);
  border-bottom: 1px solid var(--line);
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--s12);
  min-height: 56px;
}

.zeile:last-child {
  border-bottom: none;
}

.zeileHaupt {
  min-width: 0;
  font-weight: 600;
}

.zeileMeta {
  font-size: 12px;
  color: var(--text-muted);
  margin-top: 2px;
}

.zeileMetaFaint {
  composes: zeileMeta;
  color: var(--text-faint);
}

.feld {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.eingabe,
.auswahl {
  background: var(--well);
  border: 1px solid var(--line);
  border-radius: var(--r-control);
  min-height: 52px;
  padding: 0 var(--s12);
  color: var(--text);
  width: 100%;
}

.eingabe:focus,
.auswahl:focus {
  outline: 2px solid var(--accent);
  outline-offset: 1px;
}

/* Die eine Akzentflaeche je Bildschirm. */
.haupt {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  height: 56px;
  width: 100%;
  border: none;
  border-radius: var(--r-control);
  background: var(--accent);
  color: var(--on-accent);
  font-weight: 700;
}

.haupt:disabled {
  opacity: 0.45;
}

.neben {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  height: 48px;
  width: 100%;
  border-radius: var(--r-control);
  background: var(--surface-raised);
  border: 1px solid var(--line);
  color: var(--text);
  font-weight: 600;
}

.nebenSchmal {
  composes: neben;
  width: auto;
  padding: 0 var(--s16);
  flex-shrink: 0;
}

.gefaehrlich {
  composes: neben;
  background: transparent;
  border-color: var(--danger);
  color: var(--danger);
}

.chips {
  display: flex;
  gap: var(--s8);
  overflow-x: auto;
}

.chip {
  display: inline-flex;
  align-items: center;
  flex: 0 0 auto;
  min-height: 40px;
  padding: var(--s8) var(--s16);
  border: none;
  border-radius: var(--r-pill);
  background: var(--surface-raised);
  color: var(--text-muted);
  font-weight: 600;
  font-size: 13px;
  white-space: nowrap;
}

.chipAktiv {
  composes: chip;
  color: var(--text);
  box-shadow: inset 0 0 0 1px var(--accent);
}

.marke {
  display: inline-flex;
  align-items: center;
  border: 1px solid var(--line);
  border-radius: var(--r-pill);
  padding: 2px 10px;
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--text-muted);
}

.balkenBahn {
  height: 6px;
  border-radius: var(--r-pill);
  background: var(--surface-raised);
  overflow: hidden;
}

/* Akzent als Wert, nicht als Aktionsflaeche -- daher background-color. */
.balken {
  height: 100%;
  background-color: var(--accent);
}

.fehler {
  color: var(--danger);
  font-size: 13px;
  margin: 0;
}

.zahl {
  font-size: 28px;
  font-weight: 800;
  letter-spacing: -0.03em;
  line-height: 1;
}

.zahlOffen {
  composes: zahl;
  color: var(--warn);
}

.zahlLabel {
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--text-muted);
  margin-top: 6px;
}

.zahlLabelOffen {
  composes: zahlLabel;
  color: var(--warn);
}

.zahlen {
  display: flex;
  gap: var(--s20);
}

.leiste {
  display: flex;
  flex-direction: column;
  gap: var(--s8);
}

.leisteSegmente {
  display: flex;
  gap: var(--s4);
}

/* Bewusst ohne Akzent: der gehoert der Hauptaktion, nicht der Wegmarke. */
.leisteSegment {
  flex: 1;
  height: 3px;
  border-radius: var(--r-pill);
  background: var(--line);
}

.leisteSegmentVoll {
  composes: leisteSegment;
  background: var(--text);
}
```

- [ ] **Schritt 6: Die Schrittleiste anlegen**

`apps/web/app/portal/[studioId]/einrichten/Schrittleiste.tsx`:

```tsx
import styles from "./halle.module.css";

const SCHRITTE = 6;

/**
 * Die Wegmarke des Gangs -- sechs Segmente und ein Satz. Bewusst ohne
 * Akzent: der gehoert auf jedem Bildschirm der einen Hauptaktion.
 *
 * Der Sucher und die Aufnahme tragen sie nicht, weil sie randlos ueber der
 * Kamera liegen; dort steht die Marke als blosse Zeile.
 */
export function Schrittleiste({
  nummer,
  titel,
}: {
  nummer: number;
  titel: string;
}) {
  return (
    <div className={styles.leiste}>
      <div className={styles.leisteSegmente} aria-hidden="true">
        {Array.from({ length: SCHRITTE }, (_, index) => (
          <div
            key={index}
            className={
              index < nummer ? styles.leisteSegmentVoll : styles.leisteSegment
            }
          />
        ))}
      </div>
      <span className={styles.label}>
        Schritt {nummer} von {SCHRITTE} · {titel}
      </span>
    </div>
  );
}
```

- [ ] **Schritt 7: Die Hallen-Hülle anlegen**

`apps/web/app/portal/[studioId]/einrichten/layout.tsx`:

```tsx
import Link from "next/link";
import { ladeKatalog } from "../catalog";
import styles from "./halle.module.css";

/**
 * Der Gang durch die Halle hat keine Rail: er laeuft auf 390 px, einhaendig,
 * neben einem Geraet. Die Chipnavigation der Artboards gehoert zur
 * Telefonfassung des ganzen Portals und kommt mit Phase 5 -- hier steht nur
 * der Weg zurueck an den Schreibtisch.
 */
export default async function HalleLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: Promise<{ studioId: string }>;
}) {
  const { studioId } = await params;
  const katalog = await ladeKatalog(studioId);

  return (
    <div className={styles.seite}>
      <header className={styles.kopf}>
        <span className={styles.studio}>{katalog.studioName}</span>
        <Link href={`/portal/${studioId}`} className={styles.zurueck}>
          Schreibtisch
        </Link>
      </header>
      <main className={styles.inhalt}>{children}</main>
    </div>
  );
}
```

- [ ] **Schritt 8: Den Einstieg anlegen**

`apps/web/app/portal/[studioId]/einrichten/page.tsx` — `TelefonStart.dc.html`:

```tsx
import Link from "next/link";
import { ladeKatalog } from "../catalog";
import styles from "./halle.module.css";

/**
 * Der Einstieg steht in der Halle, nicht am Schreibtisch: was fehlt noch,
 * wie viele Tags sind in der Packung, und ein Knopf, der den Gang beginnt.
 *
 * "Was noch fehlt" fuehrt zwei verschiedene Maengel in einer Liste, weil sie
 * denselben Ausgang haben -- den Gang. Ein Geraet ohne aktiven Tag existiert
 * fuer Mitglieder nicht; ein Modell ohne Foto ist nach dem Scan nicht von
 * seinem baugleichen Nachbarn zu unterscheiden (Entscheidung 10).
 */
export default async function EinrichtenPage({
  params,
}: {
  params: Promise<{ studioId: string }>;
}) {
  const { studioId } = await params;
  const katalog = await ladeKatalog(studioId);
  const basis = `/portal/${studioId}/einrichten`;

  const geraete = katalog.models.flatMap((modell) =>
    modell.machines
      .filter((geraet) => geraet.status === "active")
      .map((geraet) => ({ ...geraet, modell })),
  );

  const ohneTag = geraete.filter((geraet) => geraet.activeTagCount === 0);
  const unvollstaendig = katalog.models.filter(
    (modell) =>
      modell.photoPath === null || modell.settingDefinitions.length === 0,
  );

  const geliefert = katalog.shipments
    .filter((lieferung) => lieferung.kind === "machine")
    .reduce((summe, lieferung) => summe + lieferung.quantity, 0);
  const verbraucht = katalog.tags.filter((tag) => tag.kind === "machine").length;
  const vorraetig = geliefert - verbraucht;

  function mangel(modell: (typeof katalog.models)[number]): string {
    if (modell.photoPath === null && modell.settingDefinitions.length === 0) {
      return "Kein Foto, keine Einstellparameter · Mitglieder sähen nur den Namen";
    }
    if (modell.photoPath === null) {
      return "Kein Foto · nach dem Scan nicht von einem baugleichen Gerät zu unterscheiden";
    }
    return "Keine Einstellparameter · das Mitglied hat nichts einzustellen";
  }

  return (
    <>
      <div>
        <h1 className={styles.titel}>Einrichten</h1>
        <p className={styles.unterzeile}>
          Geh von Gerät zu Gerät. Jedes ist fertig, sobald sein Tag klebt.
        </p>
      </div>

      <div className={styles.karte}>
        <div className={styles.zahlen}>
          <div>
            <div className={styles.zahl}>{geraete.length}</div>
            <div className={styles.zahlLabel}>Geräte</div>
          </div>
          <div>
            <div className={styles.zahl}>{katalog.models.length}</div>
            <div className={styles.zahlLabel}>Modelle</div>
          </div>
          <div>
            <div className={ohneTag.length > 0 ? styles.zahlOffen : styles.zahl}>
              {ohneTag.length}
            </div>
            <div
              className={
                ohneTag.length > 0 ? styles.zahlLabelOffen : styles.zahlLabel
              }
            >
              ohne Tag
            </div>
          </div>
        </div>
      </div>

      <div className={styles.karte}>
        <div>
          <div style={{ fontSize: 16, fontWeight: 600 }}>
            {vorraitigText(vorraetig)}
          </div>
          <div className={styles.notiz}>
            {katalog.shipments.length === 0
              ? "Noch keine Lieferung angekommen. Ohne Tag findet ein Mitglied kein Gerät."
              : `${katalog.shipments.length} ${katalog.shipments.length === 1 ? "Lieferung" : "Lieferungen"} · ${geliefert} Stück, ${verbraucht} vergeben`}
          </div>
        </div>
      </div>

      <Link href={`${basis}/modell`} className={styles.haupt}>
        Gerät einrichten
      </Link>

      {ohneTag.length + unvollstaendig.length > 0 ? (
        <section className={styles.abschnitt}>
          <div className={styles.abschnittKopf}>
            <h2 className={styles.label}>Was noch fehlt</h2>
          </div>
          {ohneTag.map((geraet) => (
            <div key={geraet.id} className={styles.zeile}>
              <div style={{ minWidth: 0 }}>
                <div className={styles.zeileHaupt}>{geraet.label}</div>
                <div className={styles.zeileMeta}>
                  {geraet.locationNote ?? "ohne Standortangabe"} · kein Tag, für
                  Mitglieder nicht auffindbar
                </div>
              </div>
              <Link
                href={`${basis}/geraet/${geraet.id}/tag`}
                className={styles.nebenSchmal}
              >
                Weiter
              </Link>
            </div>
          ))}
          {unvollstaendig.map((modell) => (
            <div key={modell.id} className={styles.zeile}>
              <div style={{ minWidth: 0 }}>
                <div className={styles.zeileHaupt}>{modell.name}</div>
                <div className={styles.zeileMetaFaint}>{mangel(modell)}</div>
              </div>
              <Link
                href={`${basis}/modell/${modell.id}/einstellungen`}
                className={styles.nebenSchmal}
              >
                Weiter
              </Link>
            </div>
          ))}
        </section>
      ) : null}

      <p className={styles.notiz}>
        Ein Gerät ist fertig, sobald sein Tag klebt. Übungen und Videos lassen
        sich jederzeit nachtragen.
      </p>
    </>
  );
}

function vorraitigText(vorraetig: number): string {
  if (vorraetig <= 0) return "Kein Tag vorrätig";
  return `${vorraetig} ${vorraetig === 1 ? "Tag" : "Tags"} vorrätig`;
}
```

- [ ] **Schritt 9: Den E2E-Helfer anlegen**

`e2e/helpers/studio.ts`:

```ts
import type { Page } from "@playwright/test";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { E2E_PASSWORD, anmelden } from "./login";

export type Halle = {
  admin: SupabaseClient;
  studioId: string;
  email: string;
  userId: string;
};

/**
 * Ein Studio mit angemeldetem Trainer -- der Ausgangspunkt jedes Tests im
 * Gang. Ohne ihn baut jede Datei dieselben vierzig Zeilen noch einmal.
 */
export async function studioMitTrainer(
  page: Page,
  praefix: string,
): Promise<Halle> {
  const admin = createClient(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    { auth: { persistSession: false } },
  );

  const email = `${praefix}-${crypto.randomUUID()}@example.test`;
  const { data: nutzer, error: nutzerFehler } = await admin.auth.admin.createUser(
    { email, password: E2E_PASSWORD, email_confirm: true },
  );
  if (nutzerFehler) throw nutzerFehler;

  const { data: studio, error: studioFehler } = await admin
    .from("studios")
    .insert({ name: `${praefix} Studio` })
    .select("id")
    .single();
  if (studioFehler) throw studioFehler;

  const { error: mitgliedFehler } = await admin
    .from("studio_memberships")
    .insert({
      studio_id: studio.id,
      user_id: nutzer.user.id,
      role: "trainer",
    });
  if (mitgliedFehler) throw mitgliedFehler;

  await anmelden(page, email);
  return { admin, studioId: studio.id, email, userId: nutzer.user.id };
}
```

- [ ] **Schritt 10: Den E2E-Test für den Einstieg schreiben**

`e2e/einrichten.spec.ts`:

```ts
import { expect, test } from "@playwright/test";
import { studioMitTrainer } from "./helpers/studio";

test("Der Einstieg zaehlt den Bestand und fuehrt in den Gang", async ({
  page,
}) => {
  const { studioId } = await studioMitTrainer(page, "einrichten-einstieg");

  await page.goto(`/portal/${studioId}/einrichten`);
  await expect(page.getByRole("heading", { name: "Einrichten" })).toBeVisible();

  // Ein frisches Studio hat nichts -- und sagt das, statt eine leere Liste
  // zu zeigen.
  await expect(page.getByText("Kein Tag vorrätig")).toBeVisible();
  await expect(
    page.getByText("Noch keine Lieferung angekommen."),
  ).toBeVisible();

  // Die Rail des Schreibtischs darf hier nicht stehen.
  await expect(page.getByRole("navigation", { name: "Katalog" })).toHaveCount(0);

  await page.getByRole("link", { name: "Gerät einrichten" }).click();
  await expect(page).toHaveURL(
    new RegExp(`/portal/${studioId}/einrichten/modell$`),
  );
});
```

- [ ] **Schritt 11: Test laufen lassen**

Ausführen: `pnpm test:e2e -- einrichten`

Erwartet: Der erste Teil PASS bis zum Klick, dann FAIL mit 404 auf `/einrichten/modell` — die Seite kommt in Aufgabe 6. Die letzte Zusicherung auskommentieren, den Rest grün sehen, und sie in Aufgabe 6 wieder einschalten.

- [ ] **Schritt 12: Committen**

```bash
git add "apps/web/app/portal/[studioId]/einrichten" e2e/helpers/studio.ts \
        e2e/einrichten.spec.ts
git commit -m "feat(web): Hallen-Huelle und Einstieg des Einrichtungsgangs"
```

---

## Aufgabe 6: Schritt 1 — Modell wählen oder knapp anlegen

Zwei Bildschirme: `TelefonModell` (wählen) und `TelefonModellNeu` (anlegen). Das Foto ist hier **Pflicht** — Entscheidung 10: *„Es ist der Grund, warum ein Mitglied nach dem Scan merkt, dass es vor dem falschen Gerät steht — das ist keine Nacharbeit."*

Pflicht heißt: die Oberfläche lässt ohne Foto nicht weiter. Die Spalte bleibt nullable, weil Altmodelle keines tragen (globale Rahmenbedingung).

Reihenfolge im Formular: Foto zuerst aufnehmen, dann die Felder. Das Modell muss aber existieren, bevor `uploadEquipmentPhoto` einen `equipmentModelId` bekommt. Auflösung ohne Zwischenzustand in der Datenbank: die Datei wird im Browser gehalten, mit dem Formular abgeschickt, und die Server Action legt **erst das Modell, dann das Foto** an — beides in einem Aufruf. Schlägt das Foto fehl, bleibt ein Modell ohne Foto stehen; es landet dann im Einstieg unter „Was noch fehlt" und in Schritt 2 als Zeile *„Foto fehlt"*. Genau dafür ist dieser Weg da (Entscheidung 12).

**Dateien:**
- Anlegen: `apps/web/app/portal/[studioId]/einrichten/actions.ts`
- Anlegen: `apps/web/app/portal/[studioId]/einrichten/modell/page.tsx`
- Anlegen: `apps/web/app/portal/[studioId]/einrichten/modell/neu/page.tsx`
- Anlegen: `apps/web/app/portal/[studioId]/einrichten/modell/neu/ModellNeuFormular.tsx`
- Ändern: `e2e/einrichten.spec.ts`

**Schnittstellen:**
- Nutzt: `createEquipmentModel`, `uploadEquipmentPhoto`, `MAX_PHOTO_BYTES`, `DomainError` aus `@fitretro/domain`; `createServerSupabaseClient` aus `@/lib/supabase/server`
- Liefert (in `actions.ts`, alle folgenden Aufgaben bauen darauf auf):
  ```ts
  export type Ergebnis<T> = ({ ok: true } & T) | { ok: false; error: string };
  export async function modellAnlegen(
    studioId: string,
    _prev: unknown,
    formData: FormData,
  ): Promise<Ergebnis<{ modelId: string }>>;
  ```

**Static schlägt dynamic:** `modell/neu` und `modell/[modelId]` liegen auf derselben Ebene. Next.js löst statische Segmente vor dynamischen auf, `neu` gewinnt also immer. Das ist dokumentiertes Verhalten, aber es heißt auch: **kein Modell darf je die ID `neu` bekommen** — bei UUIDs kein Thema.

- [ ] **Schritt 1: Den fehlschlagenden E2E-Test schreiben**

In `e2e/einrichten.spec.ts` anhängen (und die auskommentierte Zusicherung aus Aufgabe 5 wieder einschalten):

```ts
test("Schritt 1 legt ein Modell mit Pflichtfoto an und geht zu den Einstellungen", async ({
  page,
}) => {
  const { studioId } = await studioMitTrainer(page, "einrichten-modell");

  await page.goto(`/portal/${studioId}/einrichten/modell`);
  await expect(page.getByText("Noch kein Modell im Studio")).toBeVisible();
  await page.getByRole("link", { name: "Neues Modell anlegen" }).click();

  await page.getByLabel("Name").fill("Kabelzug");
  await page.getByLabel("Hersteller").fill("Technogym");
  // Der Gewichtsschritt ist eine Chipreihe, kein Feld: drei Werte, und die
  // Schrittweite kommt von den Platten am Geraet, nicht aus dem Kopf.
  await page.getByRole("button", { name: "5 kg", exact: true }).click();
  await page.getByLabel("Ab").fill("5");
  await page.getByLabel("Bis").fill("100");

  // Ohne Foto geht es nicht weiter -- Entscheidung 10.
  await expect(
    page.getByRole("button", { name: "Weiter zu den Einstellungen" }),
  ).toBeDisabled();

  await page.getByLabel("Foto des Modells").setInputFiles({
    name: "kabelzug.jpg",
    mimeType: "image/jpeg",
    buffer: jpegOhneExif(),
  });
  await expect(
    page.getByRole("button", { name: "Weiter zu den Einstellungen" }),
  ).toBeEnabled();

  await page
    .getByRole("button", { name: "Weiter zu den Einstellungen" })
    .click();

  await expect(page).toHaveURL(
    new RegExp(`/portal/${studioId}/einrichten/modell/[0-9a-f-]+/einstellungen$`),
  );
  await expect(page.getByText("Schritt 2 von 6 · Einstellungen")).toBeVisible();
  await expect(page.getByText("Foto · Steht")).toBeVisible();
});
```

Dazu am Dateikopf der Testdatei den kleinsten gültigen JPEG-Rumpf — `sniffMediaType` prüft die Signatur, `stripImageMetadata` läuft darüber:

```ts
/** Ein minimales JPEG. sniffMediaType prueft die Signatur, nicht mehr. */
function jpegOhneExif(): Buffer {
  return Buffer.from([
    0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 0x01,
    0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xff, 0xd9,
  ]);
}
```

- [ ] **Schritt 2: Test laufen lassen und den Fehlschlag sehen**

Ausführen: `pnpm test:e2e -- einrichten`

Erwartet: FAIL — 404 auf `/einrichten/modell`.

- [ ] **Schritt 3: Die Server Action anlegen**

`apps/web/app/portal/[studioId]/einrichten/actions.ts`:

```ts
"use server";

import { revalidatePath } from "next/cache";
import {
  DomainError,
  createEquipmentModel,
  uploadEquipmentPhoto,
} from "@fitretro/domain";
import { createServerSupabaseClient } from "@/lib/supabase/server";

/**
 * Die Server Actions des Gangs.
 *
 * Getrennt von portal/actions.ts, weil sie IDs zurueckgeben statt nur ok:
 * der naechste Schritt braucht die frische ID im Pfad. Der Zustand des Gangs
 * steht in der URL, nicht in einem Client-State -- ein Neuladen mitten in
 * der Halle verliert damit nichts.
 */

/** Fuer eine Aktion, die etwas zurueckgibt -- eine ID fuer den naechsten Schritt. */
export type Ergebnis<T> = ({ ok: true } & T) | { ok: false; error: string };

/** Fuer eine Aktion, die nur gelingt oder nicht. */
export type ActionErgebnis = { ok: true } | { ok: false; error: string };

/** Ein Ergebnisformat fuer alle Formulare: entweder es klappt, oder ein Satz. */
function fehlerAus(fehler: unknown, ersatz: string): { ok: false; error: string } {
  if (fehler instanceof DomainError) return { ok: false, error: fehler.message };
  // Ein unerwarteter Fehler wird geloggt, aber nie im Wortlaut angezeigt:
  // seine Meldung kann Spaltennamen oder IDs fremder Zeilen enthalten.
  console.error("Einrichtungsschritt fehlgeschlagen:", fehler);
  return { ok: false, error: ersatz };
}

function text(formData: FormData, name: string): string {
  return String(formData.get(name) ?? "").trim();
}

function optionalerText(formData: FormData, name: string): string | null {
  const wert = text(formData, name);
  return wert.length > 0 ? wert : null;
}

/** Deutsche Eingabe: 2,5 ist dasselbe wie 2.5. */
function zahl(formData: FormData, name: string): number | undefined {
  const roh = text(formData, name).replace(",", ".");
  if (roh.length === 0) return undefined;
  const wert = Number(roh);
  return Number.isFinite(wert) ? wert : Number.NaN;
}

/**
 * Modell und Foto in einem Aufruf. Das Foto ist Pflicht (Entscheidung 10),
 * aber die Spalte bleibt nullable -- Altmodelle tragen keines.
 *
 * Reihenfolge erzwungen: uploadEquipmentPhoto braucht eine Modell-ID, also
 * entsteht erst die Zeile. Schlaegt der Upload danach fehl, bleibt ein
 * Modell ohne Foto stehen. Das ist kein verlorener Zustand, sondern genau
 * der Fall, den Schritt 2 als "Foto fehlt" nachfragt (Entscheidung 12).
 */
export async function modellAnlegen(
  studioId: string,
  _prev: unknown,
  formData: FormData,
): Promise<Ergebnis<{ modelId: string }>> {
  const client = await createServerSupabaseClient();

  const datei = formData.get("photo");
  if (!(datei instanceof File) || datei.size === 0) {
    return {
      ok: false,
      error:
        "Ohne Foto geht es nicht weiter — es ist der einzige Grund, warum jemand vor dem falschen Gerät merkt, dass er falsch steht.",
    };
  }

  let modelId: string;
  try {
    const modell = await createEquipmentModel(client, {
      studioId,
      name: text(formData, "name"),
      manufacturer: optionalerText(formData, "manufacturer"),
      weightStepKg: zahl(formData, "weightStepKg") ?? Number.NaN,
      minWeightKg: zahl(formData, "minWeightKg") ?? 0,
      maxWeightKg: zahl(formData, "maxWeightKg") ?? null,
    });
    modelId = modell.id;
  } catch (fehler) {
    return fehlerAus(fehler, "Das Modell liess sich nicht anlegen.");
  }

  try {
    // Das Foto laeuft bewusst durch den Server: nur hier lassen sich die
    // Aufnahmedaten entfernen, bevor die Datei im Bucket landet.
    await uploadEquipmentPhoto(client, {
      equipmentModelId: modelId,
      bytes: new Uint8Array(await datei.arrayBuffer()),
    });
  } catch (fehler) {
    const antwort = fehlerAus(fehler, "Das Foto liess sich nicht speichern.");
    // Das Modell steht trotzdem -- der Gang geht weiter, Schritt 2 fragt das
    // Foto nach. Ein Rollback waere hier der schlechtere Zustand.
    revalidatePath(`/portal/${studioId}/einrichten`);
    return antwort;
  }

  revalidatePath(`/portal/${studioId}/einrichten`);
  return { ok: true, modelId };
}
```

- [ ] **Schritt 4: „Modell wählen" anlegen**

`apps/web/app/portal/[studioId]/einrichten/modell/page.tsx`:

```tsx
import Link from "next/link";
import { ladeKatalog } from "../../catalog";
import { Schrittleiste } from "../Schrittleiste";
import styles from "../halle.module.css";

/**
 * Schritt 1: welches Modell. Der Akzent gehoert dem Anlegen, nicht dem
 * Waehlen -- bei der Erstbestueckung ist das der Fall, der oefter eintritt.
 */
export default async function ModellWaehlenPage({
  params,
}: {
  params: Promise<{ studioId: string }>;
}) {
  const { studioId } = await params;
  const katalog = await ladeKatalog(studioId);
  const basis = `/portal/${studioId}/einrichten`;

  function meta(modell: (typeof katalog.models)[number]): string {
    const teile = [
      modell.manufacturer ?? "Ohne Hersteller",
      `${modell.machines.length} ${modell.machines.length === 1 ? "Gerät" : "Geräte"}`,
      `${modell.exercises.length} ${modell.exercises.length === 1 ? "Übung" : "Übungen"}`,
      `${modell.settingDefinitions.length} ${modell.settingDefinitions.length === 1 ? "Parameter" : "Parameter"}`,
    ];
    if (modell.photoPath === null) teile.push("kein Foto");
    return teile.join(" · ");
  }

  return (
    <>
      <Schrittleiste nummer={1} titel="Modell" />
      <div>
        <Link href={basis} className={styles.zurueck}>
          ← Einrichten
        </Link>
        <h1 className={styles.titel}>Was steht hier?</h1>
      </div>

      {katalog.models.length > 0 ? (
        <section className={styles.abschnitt}>
          <div className={styles.abschnittKopf}>
            <h2 className={styles.label}>Modelle im Studio</h2>
          </div>
          {katalog.models.map((modell) => (
            <div key={modell.id} className={styles.zeile}>
              <div style={{ minWidth: 0 }}>
                <div className={styles.zeileHaupt}>{modell.name}</div>
                <div
                  className={
                    modell.photoPath === null
                      ? styles.zeileMetaFaint
                      : styles.zeileMeta
                  }
                >
                  {meta(modell)}
                </div>
              </div>
              <Link
                href={`${basis}/modell/${modell.id}/einstellungen`}
                className={styles.nebenSchmal}
              >
                Wählen
              </Link>
            </div>
          ))}
        </section>
      ) : (
        <p className={styles.notiz}>Noch kein Modell im Studio.</p>
      )}

      <div className={styles.karteGestrichelt}>
        <div>
          <div style={{ fontSize: 16, fontWeight: 600 }}>Noch nicht dabei</div>
          <div className={styles.notiz}>
            Ein Modell beschreibt den Gerätetyp. Zwei Kabelzüge nebeneinander
            sind ein Modell und zwei Geräte.
          </div>
        </div>
        <Link href={`${basis}/modell/neu`} className={styles.haupt}>
          Neues Modell anlegen
        </Link>
      </div>
    </>
  );
}
```

- [ ] **Schritt 5: „Modell anlegen" anlegen**

`apps/web/app/portal/[studioId]/einrichten/modell/neu/page.tsx`:

```tsx
import Link from "next/link";
import { Schrittleiste } from "../../Schrittleiste";
import { ModellNeuFormular } from "./ModellNeuFormular";
import styles from "../../halle.module.css";

export default async function ModellNeuPage({
  params,
}: {
  params: Promise<{ studioId: string }>;
}) {
  const { studioId } = await params;

  return (
    <>
      <Schrittleiste nummer={1} titel="Modell" />
      <div>
        <Link
          href={`/portal/${studioId}/einrichten/modell`}
          className={styles.zurueck}
        >
          ← Modell wählen
        </Link>
        <h1 className={styles.titel}>Neues Modell</h1>
      </div>

      <ModellNeuFormular studioId={studioId} />

      <p className={styles.notiz}>
        Ohne Foto geht es nicht weiter — es ist der einzige Grund, warum jemand
        vor dem falschen Gerät merkt, dass er falsch steht. Beschreibungen
        trägst du am Schreibtisch nach, die Einstellparameter kommen im
        nächsten Schritt.
      </p>
    </>
  );
}
```

`apps/web/app/portal/[studioId]/einrichten/modell/neu/ModellNeuFormular.tsx`:

```tsx
"use client";

import { useActionState, useId, useState } from "react";
import { useRouter } from "next/navigation";
import { MAX_PHOTO_BYTES } from "@fitretro/domain/media";
import { modellAnlegen } from "../../actions";
import styles from "../../halle.module.css";

const SCHRITTE = ["1,25", "2,5", "5"];

/**
 * Bewusst knapp: Foto, Name, Hersteller, Schrittweite, Spanne. Alles Weitere
 * bleibt Schreibtisch (Entscheidung 6).
 *
 * Das Foto kommt ueber capture aus der Systemkamera und nicht aus einem
 * eigenen Sucher: dieselbe Bedienung, vom Betriebssystem gestellt, und
 * getUserMedia bleibt dem Tag-Sucher vorbehalten, wo es keine Alternative
 * gibt. Spec 5 nennt "Foto am Telefon" ausdruecklich vollstaendig vorhanden.
 */
export function ModellNeuFormular({ studioId }: { studioId: string }) {
  const router = useRouter();
  const [hatFoto, setHatFoto] = useState(false);
  const [dateiFehler, setDateiFehler] = useState<string | null>(null);
  const [schritt, setSchritt] = useState("2,5");
  const fotoId = useId();

  const [ergebnis, formAction, laeuft] = useActionState(
    async (_prev: unknown, formData: FormData) => {
      const antwort = await modellAnlegen(studioId, null, formData);
      if (antwort.ok) {
        router.push(
          `/portal/${studioId}/einrichten/modell/${antwort.modelId}/einstellungen`,
        );
      }
      return antwort;
    },
    null,
  );

  return (
    <form action={formAction} style={{ display: "grid", gap: 16 }}>
      <div className={styles.feld}>
        <label className={styles.label} htmlFor={fotoId}>
          Foto des Modells
        </label>
        <input
          id={fotoId}
          name="photo"
          type="file"
          accept="image/jpeg,image/png"
          capture="environment"
          className={styles.eingabe}
          onChange={(ereignis) => {
            const datei = ereignis.target.files?.[0];
            if (!datei) {
              setHatFoto(false);
              setDateiFehler(null);
              return;
            }
            if (datei.size > MAX_PHOTO_BYTES) {
              setHatFoto(false);
              setDateiFehler(
                `Das Foto ist ${(datei.size / 1024 / 1024).toFixed(0)} MiB groß. Mehr als ${MAX_PHOTO_BYTES / 1024 / 1024} MiB nimmt der Upload nicht an.`,
              );
              return;
            }
            setDateiFehler(null);
            setHatFoto(true);
          }}
        />
        <span className={styles.notiz}>
          Das ganze Gerät ins Bild. Ein Foto je Modell, nicht je Gerät — zwei
          baugleiche Kabelzüge zeigen dasselbe Bild.
        </span>
        {dateiFehler ? (
          <p className={styles.fehler} role="alert">
            {dateiFehler}
          </p>
        ) : null}
      </div>

      <Feld name="name" label="Name" required placeholder="Kabelzug" />
      <Feld name="manufacturer" label="Hersteller" placeholder="Technogym" />

      <div className={styles.feld}>
        <span className={styles.label}>Gewichtsschritt</span>
        <div className={styles.chips}>
          {SCHRITTE.map((wert) => (
            <button
              key={wert}
              type="button"
              className={wert === schritt ? styles.chipAktiv : styles.chip}
              aria-pressed={wert === schritt}
              onClick={() => setSchritt(wert)}
            >
              {wert} kg
            </button>
          ))}
        </div>
        <input type="hidden" name="weightStepKg" value={schritt} />
        <span className={styles.notiz}>
          Die Schrittweite kommt von den Platten am Gerät. Sie rastet später das
          Rad des Mitglieds — ein Wert, den das Gerät nicht kann, wird damit
          unmöglich.
        </span>
      </div>

      <div style={{ display: "flex", gap: 12 }}>
        <div style={{ flex: 1 }}>
          <Feld name="minWeightKg" label="Ab" inputMode="decimal" placeholder="5" />
        </div>
        <div style={{ flex: 1 }}>
          <Feld name="maxWeightKg" label="Bis" inputMode="decimal" placeholder="100" />
        </div>
      </div>

      {ergebnis && !ergebnis.ok ? (
        <p className={styles.fehler} role="alert">
          {ergebnis.error}
        </p>
      ) : null}

      <button type="submit" className={styles.haupt} disabled={!hatFoto || laeuft}>
        {laeuft ? "Wird angelegt …" : "Weiter zu den Einstellungen"}
      </button>
    </form>
  );
}

function Feld({
  name,
  label,
  ...rest
}: { name: string; label: string } & React.InputHTMLAttributes<HTMLInputElement>) {
  const id = useId();
  return (
    <div className={styles.feld}>
      <label className={styles.label} htmlFor={id}>
        {label}
      </label>
      <input id={id} name={name} className={styles.eingabe} {...rest} />
    </div>
  );
}
```

- [ ] **Schritt 6: Test laufen lassen**

Ausführen: `pnpm test:e2e -- einrichten`

Erwartet: der Modell-Test PASS bis zur Zusicherung auf `Schritt 2 von 6`, dort FAIL mit 404 — die Einstellungsseite kommt in Aufgabe 7. Die letzten beiden Zusicherungen auskommentieren, den Rest grün sehen.

- [ ] **Schritt 7: Committen**

```bash
git add "apps/web/app/portal/[studioId]/einrichten" e2e/einrichten.spec.ts
git commit -m "feat(web): Schritt 1 -- Modell waehlen und knapp anlegen, Foto Pflicht"
```

---

## Aufgabe 7: Schritt 2 — Einstellungen

Der Schritt, der vorher am Schreibtisch stand. Entscheidung 11: *„Die Rasten zählt aber nur ab, wer davorsteht: am Schreibtisch werden sie geraten oder gar nicht erfasst, und dann ist `GeraetKalibrierung` in der Member-App leer."*

Foto und Parameter stehen in **einer** Karte, weil sie dasselbe teilen: beide hängen am Modell, nicht am Gerät (Entscheidung 9). Ein bestehendes Modell ohne Foto zeigt hier die Zeile *„Foto fehlt"* — Entscheidung 12: *„Das ist der einzige Weg, ein Altmodell im Gang zu vervollständigen."*

Der Schritt ist überspringbar. Der Akzent gehört deshalb dem Weiterkommen, nicht dem Hinzufügen — sonst betont der Bildschirm das Sammeln und nicht das Fertigwerden.

**Dateien:**
- Ändern: `apps/web/app/portal/[studioId]/einrichten/actions.ts`
- Anlegen: `apps/web/app/portal/[studioId]/einrichten/modell/[modelId]/einstellungen/page.tsx`
- Anlegen: `apps/web/app/portal/[studioId]/einrichten/modell/[modelId]/einstellungen/ParameterSheet.tsx`
- Ändern: `e2e/einrichten.spec.ts`

**Schnittstellen:**
- Nutzt: `Ergebnis`, `text`, `optionalerText`, `zahl`, `fehlerAus` aus Aufgabe 6; `createSettingDefinition`, `deleteSettingDefinition`, `uploadEquipmentPhoto` aus `@fitretro/domain`
- Liefert:
  ```ts
  export async function parameterAnlegen(
    studioId: string, modelId: string, _prev: unknown, formData: FormData,
  ): Promise<ActionErgebnis>;
  export async function parameterLoeschen(
    studioId: string, modelId: string, settingId: string,
  ): Promise<ActionErgebnis>;
  export async function fotoNachreichen(
    studioId: string, modelId: string, _prev: unknown, formData: FormData,
  ): Promise<ActionErgebnis>;
  ```

- [ ] **Schritt 1: Den fehlschlagenden E2E-Test schreiben**

In `e2e/einrichten.spec.ts` anhängen:

```ts
test("Schritt 2 fragt ein fehlendes Foto nach und nimmt Parameter auf", async ({
  page,
}) => {
  const { admin, studioId } = await studioMitTrainer(page, "einrichten-einst");

  // Ein Altmodell ohne Foto -- genau der Fall aus Entscheidung 12.
  const { data: modell, error } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioId, name: "Brustpresse", weight_step_kg: 5 })
    .select("id")
    .single();
  if (error) throw error;

  await page.goto(
    `/portal/${studioId}/einrichten/modell/${modell.id}/einstellungen`,
  );
  await expect(page.getByText("Schritt 2 von 6 · Einstellungen")).toBeVisible();
  await expect(page.getByText("Foto · Fehlt")).toBeVisible();
  await expect(page.getByText("Noch keine Einstellparameter")).toBeVisible();

  await page.getByRole("button", { name: "Parameter hinzufügen" }).click();
  await page.getByLabel("Beschriftung").fill("Sitzhöhe");
  await page.getByLabel("Schlüssel").fill("sitz");
  await page.getByLabel("Von").fill("1");
  await page.getByLabel("Bis").fill("8");
  await page.getByLabel("Schritt", { exact: true }).fill("1");
  await page.getByRole("button", { name: "Hinzufügen" }).click();

  await expect(page.getByText("Sitzhöhe")).toBeVisible();
  await expect(page.getByText("Zahl · 1 – 8 · Schritt 1")).toBeVisible();

  // Das Foto laesst sich hier nachreichen -- der einzige Weg fuer ein
  // Altmodell.
  await page.getByLabel("Foto nachreichen").setInputFiles({
    name: "brustpresse.jpg",
    mimeType: "image/jpeg",
    buffer: jpegOhneExif(),
  });
  await expect(page.getByText("Foto · Steht")).toBeVisible();

  await page.getByRole("link", { name: "Weiter zum Gerät" }).click();
  await expect(page).toHaveURL(
    new RegExp(`/einrichten/modell/${modell.id}/geraet$`),
  );
});
```

- [ ] **Schritt 2: Test laufen lassen und den Fehlschlag sehen**

Ausführen: `pnpm test:e2e -- einrichten`

Erwartet: FAIL — 404 auf der Einstellungsseite.

- [ ] **Schritt 3: Die drei Actions ergänzen**

In `apps/web/app/portal/[studioId]/einrichten/actions.ts` die Importe erweitern

```ts
import {
  DomainError,
  createEquipmentModel,
  createSettingDefinition,
  deleteSettingDefinition,
  uploadEquipmentPhoto,
} from "@fitretro/domain";
```

und ans Dateiende anhängen:

```ts
/** Der Pfad, den Schritt 2 revalidiert. Zwei Actions teilen ihn. */
function einstellungenPfad(studioId: string, modelId: string): string {
  return `/portal/${studioId}/einrichten/modell/${modelId}/einstellungen`;
}

/**
 * Ein Einstellparameter am Modell. Zwei Arten, mehr kennt das Schema nicht:
 * eine Zahl mit Spanne und Schrittweite (0004) oder eine Auswahl aus
 * mindestens zwei verschiedenen Werten (0017). settingDefinitionInputSchema
 * traegt dieselben Regeln wie die Constraints, nur frueher.
 */
export async function parameterAnlegen(
  studioId: string,
  modelId: string,
  _prev: unknown,
  formData: FormData,
): Promise<ActionErgebnis> {
  const client = await createServerSupabaseClient();
  const kind = text(formData, "kind") === "enum" ? "enum" : "number";
  try {
    await createSettingDefinition(client, {
      equipmentModelId: modelId,
      key: text(formData, "key"),
      label: text(formData, "label"),
      kind,
      minValue: kind === "number" ? (zahl(formData, "minValue") ?? null) : null,
      maxValue: kind === "number" ? (zahl(formData, "maxValue") ?? null) : null,
      stepValue: kind === "number" ? (zahl(formData, "stepValue") ?? null) : null,
      unit: optionalerText(formData, "unit"),
      allowedValues:
        kind === "enum"
          ? text(formData, "allowedValues")
              .split("\n")
              .map((zeile) => zeile.trim())
              .filter((zeile) => zeile.length > 0)
          : null,
    });
  } catch (fehler) {
    return fehlerAus(fehler, "Der Parameter liess sich nicht anlegen.");
  }
  revalidatePath(einstellungenPfad(studioId, modelId));
  return { ok: true };
}

export async function parameterLoeschen(
  studioId: string,
  modelId: string,
  settingId: string,
): Promise<ActionErgebnis> {
  const client = await createServerSupabaseClient();
  try {
    await deleteSettingDefinition(client, settingId);
  } catch (fehler) {
    return fehlerAus(fehler, "Der Parameter liess sich nicht loeschen.");
  }
  revalidatePath(einstellungenPfad(studioId, modelId));
  return { ok: true };
}

/**
 * Das Foto eines Altmodells nachreichen. Der einzige Weg dafuer im Gang
 * (Entscheidung 12) -- am Schreibtisch stuende man ohne das Geraet davor.
 */
export async function fotoNachreichen(
  studioId: string,
  modelId: string,
  _prev: unknown,
  formData: FormData,
): Promise<ActionErgebnis> {
  const client = await createServerSupabaseClient();
  const datei = formData.get("photo");
  if (!(datei instanceof File) || datei.size === 0) {
    return { ok: false, error: "Es ist keine Datei ausgewaehlt." };
  }
  try {
    await uploadEquipmentPhoto(client, {
      equipmentModelId: modelId,
      bytes: new Uint8Array(await datei.arrayBuffer()),
    });
  } catch (fehler) {
    return fehlerAus(fehler, "Das Foto liess sich nicht speichern.");
  }
  revalidatePath(einstellungenPfad(studioId, modelId));
  return { ok: true };
}
```

- [ ] **Schritt 4: Die Einstellungsseite anlegen**

`apps/web/app/portal/[studioId]/einrichten/modell/[modelId]/einstellungen/page.tsx`:

```tsx
import Link from "next/link";
import { notFound } from "next/navigation";
import { ladeKatalog } from "../../../../catalog";
import { Schrittleiste } from "../../../Schrittleiste";
import { FotoNachreichen, ParameterSheet, ParameterLoeschen } from "./ParameterSheet";
import styles from "../../../halle.module.css";

/**
 * Schritt 2. Foto und Parameter stehen in einer Karte, weil sie dasselbe
 * teilen: beide haengen am Modell, nicht am Geraet (Entscheidung 9). Der
 * zweite baugleiche Kabelzug laeuft hier mit einem Tap durch.
 *
 * Der Akzent gehoert dem Weiterkommen, nicht dem Hinzufuegen -- sonst betont
 * der Bildschirm das Sammeln und nicht das Fertigwerden.
 */
export default async function EinstellungenPage({
  params,
}: {
  params: Promise<{ studioId: string; modelId: string }>;
}) {
  const { studioId, modelId } = await params;
  const katalog = await ladeKatalog(studioId);
  const modell = katalog.models.find((eintrag) => eintrag.id === modelId);
  if (!modell) notFound();

  const basis = `/portal/${studioId}/einrichten`;

  function parameterMeta(
    parameter: (typeof modell.settingDefinitions)[number],
  ): string {
    if (parameter.kind === "enum") {
      return `Auswahl · ${(parameter.allowedValues ?? []).join(", ")}`;
    }
    const spanne =
      parameter.minValue !== null && parameter.maxValue !== null
        ? `${parameter.minValue} – ${parameter.maxValue}`
        : "ohne Spanne";
    const schritt =
      parameter.stepValue !== null ? ` · Schritt ${parameter.stepValue}` : "";
    const einheit = parameter.unit ? ` ${parameter.unit}` : "";
    return `Zahl · ${spanne}${schritt}${einheit}`;
  }

  return (
    <>
      <Schrittleiste nummer={2} titel="Einstellungen" />
      <div>
        <Link href={`${basis}/modell`} className={styles.zurueck}>
          ← Modell
        </Link>
        <h1 className={styles.titel}>Was lässt sich einstellen?</h1>
        <p className={styles.unterzeile}>
          {modell.name}
          {modell.manufacturer ? ` · ${modell.manufacturer}` : ""}
        </p>
      </div>

      <p className={styles.notiz}>
        Zähl die Rasten einmal ab. Beides gilt für alle {modell.name} im Studio
        — das Mitglied wählt daraus später seine eigenen Werte.
      </p>

      <section className={styles.abschnitt}>
        <div className={styles.abschnittKopf}>
          <h2 className={styles.label}>Am Modell</h2>
          <span className={styles.zeileMeta}>
            {modell.settingDefinitions.length}{" "}
            {modell.settingDefinitions.length === 1 ? "Parameter" : "Parameter"}
          </span>
        </div>

        <div className={styles.zeile}>
          <div style={{ minWidth: 0 }}>
            <div className={styles.zeileHaupt}>
              Foto · {modell.photoPath === null ? "Fehlt" : "Steht"}
            </div>
            <div
              className={
                modell.photoPath === null
                  ? styles.zeileMetaFaint
                  : styles.zeileMeta
              }
            >
              {modell.photoPath === null
                ? "Nach dem Scan sähe ein Mitglied nur den Namen und wüsste nicht, ob es richtig steht."
                : "Bestätigt dem Mitglied in einer Sekunde, dass es am richtigen Gerät steht."}
            </div>
          </div>
          <FotoNachreichen
            studioId={studioId}
            modelId={modelId}
            hatFoto={modell.photoPath !== null}
          />
        </div>

        {modell.settingDefinitions.map((parameter) => (
          <div key={parameter.id} className={styles.zeile}>
            <div style={{ minWidth: 0 }}>
              <div className={styles.zeileHaupt}>{parameter.label}</div>
              <div className={styles.zeileMeta}>{parameterMeta(parameter)}</div>
            </div>
            <ParameterLoeschen
              studioId={studioId}
              modelId={modelId}
              settingId={parameter.id}
            />
          </div>
        ))}

        {modell.settingDefinitions.length === 0 ? (
          <div className={styles.zeile}>
            <div className={styles.zeileMetaFaint}>
              Noch keine Einstellparameter. Das Gerät ist trotzdem vollständig
              nutzbar — das Mitglied hat nur nichts einzustellen.
            </div>
          </div>
        ) : null}
      </section>

      <ParameterSheet studioId={studioId} modelId={modelId} />

      <Link href={`${basis}/modell/${modelId}/geraet`} className={styles.haupt}>
        Weiter zum Gerät
      </Link>

      <p className={styles.notiz}>
        Überspringen geht: ein Gerät ohne Einstellparameter ist vollständig
        nutzbar. Nachtragen lässt es sich jederzeit — nur nicht mehr mit den
        Rasten vor Augen.
      </p>
    </>
  );
}
```

- [ ] **Schritt 5: Das Parameter-Sheet und die beiden kleinen Clients anlegen**

`apps/web/app/portal/[studioId]/einrichten/modell/[modelId]/einstellungen/ParameterSheet.tsx`:

```tsx
"use client";

import { useActionState, useId, useRef, useState, useTransition } from "react";
import {
  fotoNachreichen,
  parameterAnlegen,
  parameterLoeschen,
} from "../../../actions";
import styles from "../../../halle.module.css";

/**
 * Zahlenparameter und Auswahl brauchen verschiedene Felder -- ein Sitz hat
 * einen Bereich, eine Griffstellung eine Liste. Beides gleichzeitig zu
 * zeigen hiesse, den Trainer raten zu lassen, welche Haelfte gilt.
 *
 * Kein Akzent: der gehoert auf diesem Bildschirm dem "Weiter zum Geraet".
 */
export function ParameterSheet({
  studioId,
  modelId,
}: {
  studioId: string;
  modelId: string;
}) {
  const [offen, setOffen] = useState(false);
  const [kind, setKind] = useState<"number" | "enum">("number");
  const werteId = useId();

  const [ergebnis, formAction, laeuft] = useActionState(
    async (_prev: unknown, formData: FormData) => {
      const antwort = await parameterAnlegen(studioId, modelId, null, formData);
      if (antwort.ok) setOffen(false);
      return antwort;
    },
    null,
  );

  if (!offen) {
    return (
      <button
        type="button"
        className={styles.neben}
        onClick={() => setOffen(true)}
      >
        Parameter hinzufügen
      </button>
    );
  }

  return (
    <form action={formAction} className={styles.karte}>
      <div style={{ fontSize: 16, fontWeight: 600 }}>Neuer Parameter</div>

      <Feld
        name="label"
        label="Beschriftung"
        required
        placeholder="Sitzhöhe"
        hinweis="So steht er später vor dem Mitglied am Gerät."
      />
      <Feld
        name="key"
        label="Schlüssel"
        required
        placeholder="sitz"
        hinweis="Kurz und ohne Leerzeichen. Ändert sich später nicht."
      />

      <div className={styles.feld}>
        <span className={styles.label}>Art</span>
        <div className={styles.chips}>
          {(["number", "enum"] as const).map((wert) => (
            <button
              key={wert}
              type="button"
              className={wert === kind ? styles.chipAktiv : styles.chip}
              aria-pressed={wert === kind}
              onClick={() => setKind(wert)}
            >
              {wert === "number" ? "Zahl" : "Auswahl"}
            </button>
          ))}
        </div>
        <input type="hidden" name="kind" value={kind} />
        <span className={styles.notiz}>
          Eine Auswahl braucht mindestens zwei verschiedene Werte — mit einem
          einzigen ist sie keine Auswahl, sondern ein fester Wert.
        </span>
      </div>

      {kind === "number" ? (
        <>
          <div style={{ display: "flex", gap: 12 }}>
            <div style={{ flex: 1 }}>
              <Feld name="minValue" label="Von" inputMode="decimal" placeholder="1" />
            </div>
            <div style={{ flex: 1 }}>
              <Feld name="maxValue" label="Bis" inputMode="decimal" placeholder="8" />
            </div>
            <div style={{ flex: 1 }}>
              <Feld name="stepValue" label="Schritt" inputMode="decimal" placeholder="1" />
            </div>
          </div>
          <Feld
            name="unit"
            label="Einheit"
            placeholder="°"
            hinweis="Leer lassen, wenn die Rasten nur durchgezählt sind."
          />
        </>
      ) : (
        <div className={styles.feld}>
          <label className={styles.label} htmlFor={werteId}>
            Erlaubte Werte
          </label>
          <textarea
            id={werteId}
            name="allowedValues"
            className={styles.eingabe}
            rows={3}
            placeholder={"A\nB\nC"}
          />
          <span className={styles.notiz}>Ein Wert je Zeile.</span>
        </div>
      )}

      {ergebnis && !ergebnis.ok ? (
        <p className={styles.fehler} role="alert">
          {ergebnis.error}
        </p>
      ) : null}

      <button type="submit" className={styles.neben} disabled={laeuft}>
        {laeuft ? "Wird angelegt …" : "Hinzufügen"}
      </button>
      <p className={styles.notiz}>
        Der Parameter hängt am Modell, nicht an einem einzelnen Gerät. Jedes
        baugleiche Gerät trägt ihn danach mit.
      </p>
    </form>
  );
}

/** Der einzige Weg, ein Altmodell im Gang zu vervollstaendigen. */
export function FotoNachreichen({
  studioId,
  modelId,
  hatFoto,
}: {
  studioId: string;
  modelId: string;
  hatFoto: boolean;
}) {
  const id = useId();
  const [fehler, setFehler] = useState<string | null>(null);
  const [laeuft, starte] = useTransition();
  const eingabe = useRef<HTMLInputElement>(null);

  return (
    <div style={{ flexShrink: 0 }}>
      <label className={styles.nebenSchmal} htmlFor={id}>
        {laeuft ? "…" : hatFoto ? "Ersetzen" : "Aufnehmen"}
      </label>
      <input
        ref={eingabe}
        id={id}
        type="file"
        accept="image/jpeg,image/png"
        capture="environment"
        aria-label={hatFoto ? "Foto ersetzen" : "Foto nachreichen"}
        style={{ display: "none" }}
        onChange={(ereignis) => {
          const datei = ereignis.target.files?.[0];
          if (!datei) return;
          const formData = new FormData();
          formData.set("photo", datei);
          setFehler(null);
          starte(async () => {
            const antwort = await fotoNachreichen(
              studioId,
              modelId,
              null,
              formData,
            );
            if (eingabe.current) eingabe.current.value = "";
            if (!antwort.ok) setFehler(antwort.error);
          });
        }}
      />
      {fehler ? (
        <span className={styles.fehler} role="alert">
          {fehler}
        </span>
      ) : null}
    </div>
  );
}

export function ParameterLoeschen({
  studioId,
  modelId,
  settingId,
}: {
  studioId: string;
  modelId: string;
  settingId: string;
}) {
  const [fehler, setFehler] = useState<string | null>(null);
  const [laeuft, starte] = useTransition();

  return (
    <span style={{ flexShrink: 0 }}>
      {fehler ? (
        <span className={styles.fehler} role="alert">
          {fehler}
        </span>
      ) : null}
      <button
        type="button"
        className={styles.nebenSchmal}
        disabled={laeuft}
        aria-label="Parameter entfernen"
        onClick={() => {
          setFehler(null);
          starte(async () => {
            const antwort = await parameterLoeschen(
              studioId,
              modelId,
              settingId,
            );
            if (!antwort.ok) setFehler(antwort.error);
          });
        }}
      >
        {laeuft ? "…" : "Entfernen"}
      </button>
    </span>
  );
}

function Feld({
  name,
  label,
  hinweis,
  ...rest
}: {
  name: string;
  label: string;
  hinweis?: string;
} & React.InputHTMLAttributes<HTMLInputElement>) {
  const id = useId();
  return (
    <div className={styles.feld}>
      <label className={styles.label} htmlFor={id}>
        {label}
      </label>
      <input id={id} name={name} className={styles.eingabe} {...rest} />
      {hinweis ? <span className={styles.notiz}>{hinweis}</span> : null}
    </div>
  );
}
```

- [ ] **Schritt 6: Test laufen lassen**

Ausführen: `pnpm test:e2e -- einrichten`

Erwartet: der Einstellungs-Test PASS bis zum letzten Klick, dort FAIL mit 404 — die Geräteseite kommt in Aufgabe 8. Die letzten beiden Zeilen auskommentieren, den Rest grün sehen. Die auskommentierten Zusicherungen aus Aufgabe 6 wieder einschalten — sie greifen jetzt.

- [ ] **Schritt 7: Committen**

```bash
git add "apps/web/app/portal/[studioId]/einrichten" e2e/einrichten.spec.ts
git commit -m "feat(web): Schritt 2 -- Einstellparameter und das nachgereichte Foto"
```

---

## Aufgabe 8: Schritt 3 — Das Gerät

Der kürzeste Schritt: Nummer und Standort. Beides steht nur am Gerät. Die Nummer wird **vorgeschlagen**, nicht erzwungen (Aufgabe 2, Spec §7), und die Standort-Chips sind die bereits vergebenen Standorte des Studios — wer sein Studio in vier Zonen einteilt, tippt sie nicht viermal.

**Dateien:**
- Ändern: `apps/web/app/portal/[studioId]/einrichten/actions.ts`
- Anlegen: `apps/web/app/portal/[studioId]/einrichten/modell/[modelId]/geraet/page.tsx`
- Anlegen: `apps/web/app/portal/[studioId]/einrichten/modell/[modelId]/geraet/GeraetFormular.tsx`
- Ändern: `e2e/einrichten.spec.ts`

**Schnittstellen:**
- Nutzt: `createMachine` aus `@fitretro/domain`, `naechsteGeraeteNummer` aus Aufgabe 2
- Liefert:
  ```ts
  export async function geraetAnlegen(
    studioId: string, modelId: string, _prev: unknown, formData: FormData,
  ): Promise<Ergebnis<{ machineId: string }>>;
  ```

- [ ] **Schritt 1: Den fehlschlagenden E2E-Test schreiben**

In `e2e/einrichten.spec.ts` anhängen:

```ts
test("Schritt 3 schlaegt die naechste Nummer vor und legt das Geraet an", async ({
  page,
}) => {
  const { admin, studioId } = await studioMitTrainer(page, "einrichten-geraet");

  const { data: modell, error: modellFehler } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioId, name: "Kabelzug", weight_step_kg: 2.5 })
    .select("id")
    .single();
  if (modellFehler) throw modellFehler;

  // Zwei Geraete stehen schon, das hoechste traegt die 13.
  const { error: geraeteFehler } = await admin.from("machines").insert([
    {
      studio_id: studioId,
      equipment_model_id: modell.id,
      label: "12",
      location_note: "Rückwand links",
    },
    { studio_id: studioId, equipment_model_id: modell.id, label: "13" },
  ]);
  if (geraeteFehler) throw geraeteFehler;

  await page.goto(`/portal/${studioId}/einrichten/modell/${modell.id}/geraet`);
  await expect(page.getByText("Schritt 3 von 6 · Gerät")).toBeVisible();

  // Vorgeschlagen ist die naechste nach der hoechsten -- 14, nicht die
  // naechste Luecke.
  await expect(page.getByLabel("Nummer")).toHaveValue("14");

  // Der bereits vergebene Standort steht als Chip bereit.
  await page.getByRole("button", { name: "Rückwand links" }).click();
  await expect(page.getByLabel("Standort")).toHaveValue("Rückwand links");

  await page.getByLabel("Standort").fill("Rückwand rechts");
  await page.getByRole("button", { name: "Weiter zum Tag" }).click();

  await expect(page).toHaveURL(
    new RegExp(`/einrichten/geraet/[0-9a-f-]+/tag$`),
  );
  await expect(page.getByText("Schritt 4 von 6 · Tag")).toBeVisible();
});
```

- [ ] **Schritt 2: Test laufen lassen und den Fehlschlag sehen**

Ausführen: `pnpm test:e2e -- einrichten`

Erwartet: FAIL — 404 auf der Geräteseite.

- [ ] **Schritt 3: Die Action ergänzen**

In `actions.ts` `createMachine` zum Import hinzufügen und anhängen:

```ts
/**
 * Die Geraeteinstanz. Ab hier hat der Gang ein Ziel fuer den Tag: das Studio
 * kommt in bind_tag_to_machine aus der Maschine, nicht aus einem Parameter.
 */
export async function geraetAnlegen(
  studioId: string,
  modelId: string,
  _prev: unknown,
  formData: FormData,
): Promise<Ergebnis<{ machineId: string }>> {
  const client = await createServerSupabaseClient();
  try {
    const geraet = await createMachine(client, {
      studioId,
      equipmentModelId: modelId,
      label: text(formData, "label"),
      locationNote: optionalerText(formData, "locationNote"),
    });
    revalidatePath(`/portal/${studioId}/einrichten`);
    return { ok: true, machineId: geraet.id };
  } catch (fehler) {
    return fehlerAus(fehler, "Das Geraet liess sich nicht anlegen.");
  }
}
```

- [ ] **Schritt 4: Die Geräteseite anlegen**

`apps/web/app/portal/[studioId]/einrichten/modell/[modelId]/geraet/page.tsx`:

```tsx
import Link from "next/link";
import { notFound } from "next/navigation";
import { naechsteGeraeteNummer } from "@fitretro/domain";
import { ladeKatalog } from "../../../../catalog";
import { Schrittleiste } from "../../../Schrittleiste";
import { GeraetFormular } from "./GeraetFormular";
import styles from "../../../halle.module.css";

export default async function GeraetPage({
  params,
}: {
  params: Promise<{ studioId: string; modelId: string }>;
}) {
  const { studioId, modelId } = await params;
  const katalog = await ladeKatalog(studioId);
  const modell = katalog.models.find((eintrag) => eintrag.id === modelId);
  if (!modell) notFound();

  const alleGeraete = katalog.models.flatMap((eintrag) => eintrag.machines);

  // Der Vorschlag zaehlt ueber das ganze Studio, nicht nur ueber dieses
  // Modell: die Nummer klebt am Geraet und muss in der Halle eindeutig sein.
  const vorschlag = naechsteGeraeteNummer(
    alleGeraete.map((geraet) => geraet.label),
  );

  const standorte = [
    ...new Set(
      alleGeraete
        .map((geraet) => geraet.locationNote)
        .filter((ort): ort is string => Boolean(ort)),
    ),
  ].sort((a, b) => a.localeCompare(b, "de"));

  return (
    <>
      <Schrittleiste nummer={3} titel="Gerät" />
      <div>
        <Link
          href={`/portal/${studioId}/einrichten/modell/${modelId}/einstellungen`}
          className={styles.zurueck}
        >
          ← Einstellungen
        </Link>
        <h1 className={styles.titel}>Dieses Gerät</h1>
        <p className={styles.unterzeile}>
          {modell.name}
          {modell.manufacturer ? ` · ${modell.manufacturer}` : ""}
        </p>
      </div>

      <GeraetFormular
        studioId={studioId}
        modelId={modelId}
        vorschlag={vorschlag}
        standorte={standorte}
      />

      <p className={styles.notiz}>
        Ein Gerät verschwindet später nicht mehr. Es wird stillgelegt, einzeln,
        mit Namen — die Zuordnungshistorie bleibt.
      </p>
    </>
  );
}
```

`apps/web/app/portal/[studioId]/einrichten/modell/[modelId]/geraet/GeraetFormular.tsx`:

```tsx
"use client";

import { useActionState, useId, useState } from "react";
import { useRouter } from "next/navigation";
import { geraetAnlegen } from "../../../actions";
import styles from "../../../halle.module.css";

/**
 * Nummer und Standort -- beides steht nur am Geraet. Die Nummer ist ein
 * Vorschlag: klebt am Geraet schon eine andere, gilt die (Spec 7).
 */
export function GeraetFormular({
  studioId,
  modelId,
  vorschlag,
  standorte,
}: {
  studioId: string;
  modelId: string;
  vorschlag: string;
  standorte: string[];
}) {
  const router = useRouter();
  const [ort, setOrt] = useState("");
  const nummerId = useId();
  const ortId = useId();

  const [ergebnis, formAction, laeuft] = useActionState(
    async (_prev: unknown, formData: FormData) => {
      const antwort = await geraetAnlegen(studioId, modelId, null, formData);
      if (antwort.ok) {
        router.push(
          `/portal/${studioId}/einrichten/geraet/${antwort.machineId}/tag`,
        );
      }
      return antwort;
    },
    null,
  );

  return (
    <form action={formAction} style={{ display: "grid", gap: 16 }}>
      <div className={styles.feld}>
        <label className={styles.label} htmlFor={nummerId}>
          Nummer
        </label>
        <input
          id={nummerId}
          name="label"
          required
          defaultValue={vorschlag}
          className={styles.eingabe}
        />
        <span className={styles.notiz}>
          Vorgeschlagen ist die nächste nach der höchsten. Sie steht am Gerät
          und in der App des Mitglieds — nimm die, die schon draufsteht.
        </span>
      </div>

      <div className={styles.feld}>
        <label className={styles.label} htmlFor={ortId}>
          Standort
        </label>
        <input
          id={ortId}
          name="locationNote"
          value={ort}
          placeholder="Rückwand rechts"
          className={styles.eingabe}
          onChange={(ereignis) => setOrt(ereignis.target.value)}
        />
        {standorte.length > 0 ? (
          <div className={styles.chips}>
            {standorte.map((vorhanden) => (
              <button
                key={vorhanden}
                type="button"
                className={vorhanden === ort ? styles.chipAktiv : styles.chip}
                onClick={() => setOrt(vorhanden)}
              >
                {vorhanden}
              </button>
            ))}
          </div>
        ) : null}
      </div>

      {ergebnis && !ergebnis.ok ? (
        <p className={styles.fehler} role="alert">
          {ergebnis.error}
        </p>
      ) : null}

      <button type="submit" className={styles.haupt} disabled={laeuft}>
        {laeuft ? "Wird angelegt …" : "Weiter zum Tag"}
      </button>
    </form>
  );
}
```

- [ ] **Schritt 5: Test laufen lassen**

Ausführen: `pnpm test:e2e -- einrichten`

Erwartet: der Geräte-Test PASS bis zur letzten Zusicherung, dort FAIL — die Tag-Seite kommt in Aufgabe 9. Die letzte Zeile auskommentieren; die auskommentierten Zeilen aus Aufgabe 7 wieder einschalten.

- [ ] **Schritt 6: Committen**

```bash
git add "apps/web/app/portal/[studioId]/einrichten" e2e/einrichten.spec.ts
git commit -m "feat(web): Schritt 3 -- Geraet mit vorgeschlagener Nummer und Standort"
```

---

## Aufgabe 9: Schritt 4 — Der Tag, mit dem Sucher

Der einzige echte Neubau. Drei Bildschirme in einer Seite: `TelefonKleben` (die Platzierungsskizze), `TelefonScan` (der Sucher), `TelefonScanTreffer` (die Antwort). Sie teilen einen Zustand, der nicht in die URL gehört — was gerade in der Hand liegt —, also ist das eine Client-Komponente mit drei Ansichten.

**Warum `jsQR` und nicht `BarcodeDetector`:** Safari kennt letzteren nicht (Spec §5), und zwei Decoder-Pfade heißen zwei Fehlerbilder, von denen einer auf dem Testgerät nie läuft.

**Der Rückfallweg steht schon.** Spec §7: der umgebaute `TagBinden` auf der Schreibtisch-Tags-Seite ist ein Feld zum Eintippen desselben Tokens auf derselben Funktion. Hier bekommt der Gang dieselbe Möglichkeit direkt unter dem Sucher — nicht als Notlösung, sondern weil eine verweigerte Kamerafreigabe in mobilem Safari sonst eine Sackgasse wäre.

**Dateien:**
- Ändern: `apps/web/package.json` (`jsqr`)
- Ändern: `apps/web/app/portal/[studioId]/einrichten/actions.ts`
- Anlegen: `apps/web/app/portal/[studioId]/einrichten/geraet/[machineId]/tag/page.tsx`
- Anlegen: `apps/web/app/portal/[studioId]/einrichten/geraet/[machineId]/tag/TagSchritt.tsx`
- Anlegen: `apps/web/app/portal/[studioId]/einrichten/geraet/[machineId]/tag/Sucher.tsx`
- Ändern: `e2e/einrichten.spec.ts`

**Schnittstellen:**
- Nutzt: `parseTagScan` aus `@fitretro/domain/tag-scan` (Aufgabe 1), `antwortAuf`/`Befund` aus `../../../befund` (Aufgabe 4), die RPCs `inspect_tag` und `bind_tag_to_machine` aus `0028`
- Liefert:
  ```ts
  export async function tagPruefen(
    studioId: string, token: string,
  ): Promise<Ergebnis<{ befund: Befund }>>;
  export async function tagVerbinden(
    studioId: string, machineId: string, token: string,
  ): Promise<Ergebnis<{ tagId: string }>>;
  ```

- [ ] **Schritt 1: Den fehlschlagenden E2E-Test schreiben**

Der Sucher selbst lässt sich ohne Kamera nicht ansteuern; geprüft wird deshalb der Rückfallweg — **derselbe Code hinter dem Feld wie hinter dem Decoder**, `tagPruefen` und `tagVerbinden`. Die Decoder-Strecke davor deckt `parseTagScan` (Aufgabe 1) ab, das Verhalten dahinter `antwortAuf` (Aufgabe 4) und `tag-binden.test.ts` (Bestand).

In `e2e/einrichten.spec.ts` anhängen, und am Dateikopf `import { tagAnlegen } from "../tests/helpers/tags";` ergänzen:

```ts
test("Schritt 4 beantwortet den Tag und verbindet ihn mit dem Geraet", async ({
  page,
}) => {
  const { admin, studioId } = await studioMitTrainer(page, "einrichten-tag");

  const { data: modell, error: modellFehler } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioId, name: "Kabelzug", weight_step_kg: 2.5 })
    .select("id")
    .single();
  if (modellFehler) throw modellFehler;

  const { data: geraet, error: geraetFehler } = await admin
    .from("machines")
    .insert({
      studio_id: studioId,
      equipment_model_id: modell.id,
      label: "14",
      location_note: "Rückwand rechts",
    })
    .select("id")
    .single();
  if (geraetFehler) throw geraetFehler;

  await page.goto(`/portal/${studioId}/einrichten/geraet/${geraet.id}/tag`);
  await expect(page.getByText("Schritt 4 von 6 · Tag")).toBeVisible();
  await expect(page.getByRole("heading", { name: "Tag ankleben" })).toBeVisible();
  await expect(page.getByText("Metall braucht die Ferritseite")).toBeVisible();

  // Ein Aushangschild ist vor dem Scan nicht von einem Geraeteaufkleber zu
  // unterscheiden -- das ist Absicht, und deshalb muss die Antwort sagen,
  // was in der Hand liegt (Spec 4, vierte Zeile).
  const schild = await tagAnlegen(admin, {
    studioId,
    kind: "studio",
    status: "active",
  });
  await page.getByLabel("Token vom Tag").fill(schild.token);
  await page.getByRole("button", { name: "Tag prüfen" }).click();
  await expect(page.getByText("Das ist ein Aushangschild")).toBeVisible();
  await expect(page.getByRole("button", { name: "Verbinden" })).toHaveCount(0);
  // Die Antwort ist eine Sackgasse mit genau einem Ausgang -- und der fuehrt
  // zurueck, nicht weiter.
  await page.getByRole("button", { name: "Anderen Tag nehmen" }).click();

  // Ein vergebener Tag nennt sein Geraet und bietet nichts an.
  const { data: anderes, error: anderesFehler } = await admin
    .from("machines")
    .insert({
      studio_id: studioId,
      equipment_model_id: modell.id,
      label: "Beinpresse 7",
    })
    .select("id")
    .single();
  if (anderesFehler) throw anderesFehler;
  const vergeben = await tagAnlegen(admin, {
    studioId,
    machineId: anderes.id,
    status: "active",
  });
  await page.getByLabel("Token vom Tag").fill(vergeben.token);
  await page.getByRole("button", { name: "Tag prüfen" }).click();
  await expect(page.getByText("Dieser Tag gehört zu Beinpresse 7.")).toBeVisible();
  await expect(page.getByRole("button", { name: "Verbinden" })).toHaveCount(0);
  await page.getByRole("button", { name: "Anderen Tag nehmen" }).click();

  // Ein frischer Tag aus der Lieferung ist studiolos und lernt sein Studio
  // erst hier (0028).
  const frisch = await tagAnlegen(admin, { studioId: null });
  await page.getByLabel("Token vom Tag").fill(frisch.token);
  await page.getByRole("button", { name: "Tag prüfen" }).click();
  await expect(page.getByText("Tag erkannt")).toBeVisible();
  await page.getByRole("button", { name: "Verbinden" }).click();

  await expect(page).toHaveURL(
    new RegExp(`/einrichten/geraet/${geraet.id}/uebungen$`),
  );
});
```

- [ ] **Schritt 2: Test laufen lassen und den Fehlschlag sehen**

Ausführen: `pnpm test:e2e -- einrichten`

Erwartet: FAIL — 404 auf der Tag-Seite.

- [ ] **Schritt 3: Den Decoder installieren**

```bash
pnpm --filter @fitretro/web add jsqr@^1.4.0
```

`jsqr` ist reines JavaScript ohne Abhängigkeiten und arbeitet auf `ImageData` — kein WASM, das erst geladen werden müsste, und nichts, was der Storage-CSP im Weg stünde.

- [ ] **Schritt 4: Die beiden Actions ergänzen**

In `actions.ts` anhängen (und `import type { Befund } from "./befund";` am Dateikopf ergänzen):

```ts
/**
 * Was der Sucher gelesen hat, gegen inspect_tag (0028) gehalten.
 *
 * Die Antworttabelle steht in befund.ts; hier wird nur uebersetzt. Die
 * Studiozugehoerigkeit prueft die Funktion selbst und zuerst -- ein
 * gesperrter Tag eines fremden Studios heisst unbekannt, nicht gesperrt,
 * sonst verriete die Antwort seine Existenz.
 */
export async function tagPruefen(
  studioId: string,
  token: string,
): Promise<Ergebnis<{ befund: Befund }>> {
  const client = await createServerSupabaseClient();
  const { data, error } = await client.rpc("inspect_tag", {
    p_token: token.trim(),
    p_studio_id: studioId,
  });

  if (error) {
    console.error("Tag nicht geprueft:", error);
    return { ok: false, error: "Der Tag liess sich nicht prüfen." };
  }

  const zeile = (
    data as Array<{
      verdict: string;
      batch_code: string | null;
      batch_index: number | null;
      machine_id: string | null;
      machine_label: string | null;
    }> | null
  )?.[0];

  switch (zeile?.verdict) {
    case "frei":
      return {
        ok: true,
        befund: {
          verdikt: "frei",
          batchCode: zeile.batch_code ?? "?",
          batchIndex: zeile.batch_index ?? 0,
        },
      };
    case "vergeben":
      return {
        ok: true,
        befund: {
          verdikt: "vergeben",
          machineId: zeile.machine_id!,
          machineLabel: zeile.machine_label ?? "einem anderen Gerät",
        },
      };
    case "gesperrt":
      return { ok: true, befund: { verdikt: "gesperrt" } };
    case "aushangschild":
      return { ok: true, befund: { verdikt: "aushangschild" } };
    default:
      return { ok: true, befund: { verdikt: "unbekannt" } };
  }
}

/**
 * Den gelieferten Tag an das Geraet binden. Das Studio kommt aus der
 * Maschine, nicht von hier -- bind_tag_to_machine leitet es selbst ab und
 * prueft den Aufrufer dagegen (0028).
 */
export async function tagVerbinden(
  studioId: string,
  machineId: string,
  token: string,
): Promise<Ergebnis<{ tagId: string }>> {
  const client = await createServerSupabaseClient();
  const { data, error } = await client.rpc("bind_tag_to_machine", {
    p_token: token.trim(),
    p_machine_id: machineId,
  });

  if (error) {
    console.error("Tag nicht gebunden:", error);
    return { ok: false, error: "Der Tag liess sich nicht binden." };
  }

  const zeile = (data as Array<{ verdict: string; tag_id: string | null }> | null)?.[0];
  if (zeile?.verdict === "gebunden" && zeile.tag_id) {
    revalidatePath(`/portal/${studioId}/einrichten`);
    return { ok: true, tagId: zeile.tag_id };
  }

  // Zwischen Pruefen und Verbinden kann ein zweiter Trainer denselben Tag
  // gebunden haben. Die Antwort kommt dann aus derselben Tabelle wie oben --
  // der Aufrufer prueft einfach neu.
  return {
    ok: false,
    error: "Dieser Tag ist inzwischen nicht mehr frei. Prüf ihn noch einmal.",
  };
}
```

- [ ] **Schritt 5: Den Sucher anlegen**

`apps/web/app/portal/[studioId]/einrichten/geraet/[machineId]/tag/Sucher.tsx`:

```tsx
"use client";

import { useEffect, useRef, useState } from "react";
import jsQR from "jsqr";
import { parseTagScan } from "@fitretro/domain/tag-scan";
import styles from "../../../halle.module.css";

type Zustand = "startet" | "laeuft" | "verweigert" | "nicht-moeglich";

/**
 * Der Sucher. Safari kennt BarcodeDetector nicht (Spec 5), also die Kamera
 * ueber getUserMedia und ein Decoder im Browser. Immer jsQR, kein
 * BarcodeDetector-Zweig: zwei Decoder-Pfade heissen zwei Fehlerbilder, von
 * denen einer auf dem Testgeraet nie laeuft.
 *
 * Der Chip zaehlt hier nicht: im Tag steckt zusaetzlich NFC, aber ein
 * Browser liest kein NFC. Im Portal geht es allein ueber den QR
 * (Entscheidung 5).
 */
export function Sucher({ onToken }: { onToken: (token: string) => void }) {
  const [zustand, setZustand] = useState<Zustand>("startet");
  const videoRef = useRef<HTMLVideoElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  // Der Callback wird ueber ein Ref gelesen, damit der Effekt nicht bei jedem
  // Rendern der Elternkomponente die Kamera neu anfordert.
  const onTokenRef = useRef(onToken);
  onTokenRef.current = onToken;

  useEffect(() => {
    if (typeof navigator === "undefined" || !navigator.mediaDevices?.getUserMedia) {
      setZustand("nicht-moeglich");
      return;
    }

    let stream: MediaStream | null = null;
    let bild = 0;
    let beendet = false;

    function halt() {
      beendet = true;
      cancelAnimationFrame(bild);
      stream?.getTracks().forEach((spur) => spur.stop());
    }

    async function starte() {
      try {
        stream = await navigator.mediaDevices.getUserMedia({
          // Die Rueckkamera: der Trainer haelt das Telefon an das Geraet.
          video: { facingMode: { ideal: "environment" } },
          audio: false,
        });
      } catch {
        setZustand("verweigert");
        return;
      }
      if (beendet) {
        stream.getTracks().forEach((spur) => spur.stop());
        return;
      }

      const video = videoRef.current;
      if (!video) return;
      video.srcObject = stream;
      // playsInline steht am Element; ohne es geht mobiles Safari in den
      // Vollbildspieler und der Sucher verschwindet.
      await video.play().catch(() => undefined);
      setZustand("laeuft");
      bild = requestAnimationFrame(lies);
    }

    function lies() {
      const video = videoRef.current;
      const canvas = canvasRef.current;
      if (!video || !canvas || beendet) return;

      if (video.readyState === video.HAVE_ENOUGH_DATA) {
        const ctx = canvas.getContext("2d", { willReadFrequently: true });
        if (ctx) {
          canvas.width = video.videoWidth;
          canvas.height = video.videoHeight;
          ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
          const daten = ctx.getImageData(0, 0, canvas.width, canvas.height);
          const treffer = jsQR(daten.data, daten.width, daten.height, {
            inversionAttempts: "dontInvert",
          });
          if (treffer) {
            const token = parseTagScan(treffer.data);
            if (token) {
              halt();
              onTokenRef.current(token);
              return;
            }
          }
        }
      }
      bild = requestAnimationFrame(lies);
    }

    void starte();
    return halt;
  }, []);

  if (zustand === "verweigert" || zustand === "nicht-moeglich") {
    return (
      <div className={styles.karteWarnung}>
        <div style={{ fontSize: 16, fontWeight: 600 }}>
          Die Kamera ist nicht freigegeben
        </div>
        <p className={styles.notiz}>
          In Safari: „aA" links in der Adresszeile, dann Website-Einstellungen,
          dann Kamera erlauben. Der Chip im Tag hilft im Browser nicht — aber
          der Token unten steht auch im Klartext auf dem Aufkleber.
        </p>
      </div>
    );
  }

  return (
    <div className={styles.karte}>
      <video
        ref={videoRef}
        playsInline
        muted
        aria-label="Sucher"
        style={{ width: "100%", borderRadius: "var(--r-control)" }}
      />
      <canvas ref={canvasRef} style={{ display: "none" }} />
      <p className={styles.notiz}>
        {zustand === "startet"
          ? "Kamera startet …"
          : "Halt den QR auf dem Tag ins Bild. Geh nah ran — der Code ist klein."}
      </p>
    </div>
  );
}
```

- [ ] **Schritt 6: Die Tag-Seite und ihre drei Ansichten anlegen**

`apps/web/app/portal/[studioId]/einrichten/geraet/[machineId]/tag/page.tsx`:

```tsx
import { notFound } from "next/navigation";
import { ladeKatalog } from "../../../../catalog";
import { Schrittleiste } from "../../../Schrittleiste";
import { TagSchritt } from "./TagSchritt";
import styles from "../../../halle.module.css";

export default async function TagPage({
  params,
}: {
  params: Promise<{ studioId: string; machineId: string }>;
}) {
  const { studioId, machineId } = await params;
  const katalog = await ladeKatalog(studioId);

  const treffer = katalog.models
    .flatMap((modell) => modell.machines.map((geraet) => ({ geraet, modell })))
    .find((eintrag) => eintrag.geraet.id === machineId);
  if (!treffer) notFound();

  return (
    <>
      <Schrittleiste nummer={4} titel="Tag" />
      <div>
        <h1 className={styles.titel}>Tag ankleben</h1>
        <p className={styles.unterzeile}>
          {treffer.geraet.label} · {treffer.modell.name}
          {treffer.geraet.locationNote ? ` · ${treffer.geraet.locationNote}` : ""}
        </p>
      </div>

      <TagSchritt
        studioId={studioId}
        machineId={machineId}
        geraetLabel={treffer.geraet.label}
        geraetHatTag={treffer.geraet.activeTagCount > 0}
      />
    </>
  );
}
```

`apps/web/app/portal/[studioId]/einrichten/geraet/[machineId]/tag/TagSchritt.tsx`:

```tsx
"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { tagPruefen, tagVerbinden } from "../../../actions";
import { antwortAuf, type Befund } from "../../../befund";
import { Sucher } from "./Sucher";
import styles from "../../../halle.module.css";

type Ansicht = "kleben" | "scannen" | "befund";

/**
 * Drei Bildschirme, ein Zustand: was gerade in der Hand liegt. Das gehoert
 * nicht in die URL -- ein Neuladen soll hier zurueck ans Kleben fuehren,
 * nicht auf eine Antwort zu einem Tag, den niemand mehr haelt.
 */
export function TagSchritt({
  studioId,
  machineId,
  geraetLabel,
  geraetHatTag,
}: {
  studioId: string;
  machineId: string;
  geraetLabel: string;
  geraetHatTag: boolean;
}) {
  const router = useRouter();
  const [ansicht, setAnsicht] = useState<Ansicht>("kleben");
  const [token, setToken] = useState("");
  const [befund, setBefund] = useState<Befund | null>(null);
  const [fehler, setFehler] = useState<string | null>(null);
  const [laeuft, starte] = useTransition();

  function pruefe(kandidat: string) {
    setFehler(null);
    starte(async () => {
      const antwort = await tagPruefen(studioId, kandidat);
      if (!antwort.ok) {
        setFehler(antwort.error);
        return;
      }
      setToken(kandidat);
      setBefund(antwort.befund);
      setAnsicht("befund");
    });
  }

  if (ansicht === "befund" && befund) {
    const antwort = antwortAuf(befund, geraetLabel, { geraetHatTag });
    return (
      <>
        <div
          className={
            antwort.ton === "warnung" ? styles.karteWarnung : styles.karte
          }
        >
          <div style={{ fontSize: 22, fontWeight: 800, letterSpacing: "-0.02em" }}>
            {antwort.titel}
          </div>
          <p className={styles.notiz}>{antwort.text}</p>
        </div>

        {antwort.hauptaktion !== null ? (
          <button
            type="button"
            className={styles.haupt}
            disabled={laeuft}
            onClick={() => {
              setFehler(null);
              starte(async () => {
                const ergebnis = await tagVerbinden(studioId, machineId, token);
                if (!ergebnis.ok) {
                  setFehler(ergebnis.error);
                  return;
                }
                router.push(
                  `/portal/${studioId}/einrichten/geraet/${machineId}/uebungen`,
                );
              });
            }}
          >
            {antwort.hauptaktion === "ersetzen" ? "Ersetzen" : "Verbinden"}
          </button>
        ) : null}

        {fehler ? (
          <p className={styles.fehler} role="alert">
            {fehler}
          </p>
        ) : null}

        <button
          type="button"
          className={styles.neben}
          onClick={() => {
            setBefund(null);
            setToken("");
            setAnsicht("kleben");
          }}
        >
          Anderen Tag nehmen
        </button>
      </>
    );
  }

  return (
    <>
      {ansicht === "kleben" ? (
        <>
          <div className={styles.karte}>
            <Skizze />
            <p className={styles.notiz}>
              In Augenhöhe, wo man im Stehen hinsieht.
            </p>
          </div>

          <section className={styles.abschnitt}>
            <div className={styles.abschnittKopf}>
              <h2 className={styles.label}>Worauf es ankommt</h2>
            </div>
            <div className={styles.zeile}>
              <div>
                <div className={styles.zeileHaupt}>Nicht auf Bewegtes</div>
                <div className={styles.zeileMeta}>
                  Kein Gewichtsblock, kein Hebel, kein Polster
                </div>
              </div>
            </div>
            <div className={styles.zeile}>
              <div>
                <div className={styles.zeileHaupt}>
                  Metall braucht die Ferritseite
                </div>
                <div className={styles.zeileMeta}>
                  Sonst liest der Chip nicht — der QR schon
                </div>
              </div>
            </div>
            <div className={styles.zeile}>
              <div>
                <div className={styles.zeileHaupt}>Sauber und trocken</div>
                <div className={styles.zeileMeta}>
                  Einmal abwischen hält den Tag jahrelang
                </div>
              </div>
            </div>
          </section>

          <button
            type="button"
            className={styles.haupt}
            onClick={() => setAnsicht("scannen")}
          >
            Tag scannen
          </button>
        </>
      ) : (
        <Sucher onToken={pruefe} />
      )}

      {/* Der Rueckfallweg steht neben dem Sucher, nicht dahinter: eine
          verweigerte Kamerafreigabe waere sonst eine Sackgasse (Spec 7). */}
      <div className={styles.feld}>
        <label className={styles.label} htmlFor="tag-token">
          Token vom Tag
        </label>
        <input
          id="tag-token"
          className={styles.eingabe}
          value={token}
          placeholder="22 Zeichen"
          onChange={(ereignis) => setToken(ereignis.target.value)}
        />
        <span className={styles.notiz}>
          Steht im Klartext neben dem QR. Nimm irgendeinen Tag aus der
          Gerätepackung — welcher es ist, findet die Prüfung heraus.
        </span>
      </div>

      {fehler ? (
        <p className={styles.fehler} role="alert">
          {fehler}
        </p>
      ) : null}

      <button
        type="button"
        className={styles.neben}
        disabled={laeuft || token.trim() === ""}
        onClick={() => pruefe(token)}
      >
        {laeuft ? "Wird geprüft …" : "Tag prüfen"}
      </button>
    </>
  );
}

/** Wo der Tag hingehoert. Die Position entscheidet ueber die Trefferquote. */
function Skizze() {
  return (
    <svg
      width="100%"
      height="150"
      viewBox="0 0 300 150"
      fill="none"
      stroke="var(--text-faint)"
      strokeWidth="1.75"
      strokeLinecap="round"
      strokeLinejoin="round"
      role="img"
      aria-label="Skizze: der Tag klebt in Augenhöhe am feststehenden Rahmen"
    >
      <path d="M60 132h90" />
      <path d="M105 132V44" />
      <path d="M105 44h52" />
      <path d="M157 44v14" />
      <rect x="60" y="60" width="34" height="62" rx="3" />
      <path d="M60 74h34M60 86h34M60 98h34M60 110h34" />
      <path d="M128 132v-22h34v22" />
      <path d="M128 110c0-9 7-14 17-14s17 5 17 14" />
      <circle cx="196" cy="82" r="17" stroke="var(--accent)" strokeWidth="2" />
      <path d="M188 82h16M196 74v16" stroke="var(--accent)" strokeWidth="2" />
      <path
        d="M179 82h-14"
        stroke="var(--accent)"
        strokeWidth="2"
        strokeDasharray="3 4"
      />
      <text
        x="196"
        y="118"
        fill="var(--accent)"
        fontSize="11"
        fontWeight="700"
        textAnchor="middle"
        stroke="none"
        letterSpacing="1.4"
      >
        HIER
      </text>
    </svg>
  );
}
```

- [ ] **Schritt 7: Test laufen lassen**

Ausführen: `pnpm test:e2e -- einrichten`

Erwartet: der Tag-Test PASS bis zur letzten Zusicherung, dort FAIL — die Übungsseite kommt in Aufgabe 10. Die letzte Zeile auskommentieren; die auskommentierte Zeile aus Aufgabe 8 wieder einschalten.

- [ ] **Schritt 8: Den Sucher von Hand prüfen**

Der einzige Schritt in diesem Plan, den kein Test abnimmt. Ohne ihn ist unbekannt, ob der Neubau funktioniert.

1. `pnpm --filter @fitretro/web dev`, dann von einem Telefon im selben Netz auf die Adresse. **`getUserMedia` verlangt einen sicheren Kontext** — `localhost` gilt als sicher, eine IP im LAN nicht. Also entweder über einen Tunnel mit HTTPS (`cloudflared tunnel --url http://localhost:3000`) oder auf der Vercel-Vorschau prüfen.
2. Einen Tag aus `pnpm tags` als QR erzeugen und auf ein Blatt drucken oder auf einen zweiten Bildschirm legen.
3. Prüfen: Kamera startet, das Bild steht (nicht im Vollbildspieler — dann fehlt `playsInline`), der Treffer kommt in unter zwei Sekunden, und der Bildschirm wechselt zur Antwort.
4. Kamerafreigabe in den Website-Einstellungen entziehen, neu laden: die Karte *„Die Kamera ist nicht freigegeben"* muss stehen, und das Token-Feld darunter muss weiter funktionieren.
5. Wegnavigieren: die Kameraleuchte muss ausgehen (`halt()` im Cleanup).

Was hier auffällt, gehört als offener Punkt in die Spec, nicht in einen stillen Fix.

- [ ] **Schritt 9: Committen**

```bash
git add "apps/web/app/portal/[studioId]/einrichten" apps/web/package.json \
        pnpm-lock.yaml e2e/einrichten.spec.ts
git commit -m "feat(web): Schritt 4 -- Sucher, Antworttabelle und Tag verbinden"
```

---

## Aufgabe 10: Schritt 5 — Übungen

Spec §2: *„Die Reihenfolge ist keine Kosmetik: Übung 1 ist am Gerät die Vorauswahl des Mitglieds (Designsystem §8)."* Und: eine **Auswahl** über die Studio-Übungen, kein leeres Namensfeld — sonst steht „Rudern sitzend" fünfmal im Katalog.

Der Schritt ist überspringbar, aber nicht folgenlos: *„ja, aber dann zeigt das Gerät nichts"*. Der Akzent liegt deshalb auf dem Weiterkommen, nicht auf dem Hinzufügen.

`equipment_model_exercises` hängt am **Modell**, nicht am Gerät. Zwei baugleiche Kabelzüge teilen sich ihre Übungen — die Seite sagt das, damit niemand sie zweimal anlegt.

**Dateien:**
- Ändern: `apps/web/app/portal/[studioId]/einrichten/actions.ts`
- Anlegen: `apps/web/app/portal/[studioId]/einrichten/geraet/[machineId]/uebungen/page.tsx`
- Anlegen: `apps/web/app/portal/[studioId]/einrichten/geraet/[machineId]/uebungen/UebungSheet.tsx`
- Ändern: `e2e/einrichten.spec.ts`

**Schnittstellen:**
- Nutzt: `listStudioExercises` (Aufgabe 3), `attachExerciseToModel`, `createExercise`, `detachExercise`, `reorderModelExercises` aus `@fitretro/domain`
- Liefert:
  ```ts
  export async function uebungHinzufuegen(
    studioId: string, machineId: string, modelId: string, exerciseId: string,
  ): Promise<ActionErgebnis>;
  export async function uebungAnlegen(
    studioId: string, machineId: string, modelId: string,
    _prev: unknown, formData: FormData,
  ): Promise<ActionErgebnis>;
  export async function uebungLoesen(
    studioId: string, machineId: string, linkId: string,
  ): Promise<ActionErgebnis>;
  export async function uebungVerschieben(
    studioId: string, machineId: string, modelId: string, linkIds: string[],
  ): Promise<ActionErgebnis>;
  ```

- [ ] **Schritt 1: Den fehlschlagenden E2E-Test schreiben**

In `e2e/einrichten.spec.ts` anhängen:

```ts
test("Schritt 5 waehlt aus dem Studio, legt neu an und ordnet um", async ({
  page,
}) => {
  const { admin, studioId } = await studioMitTrainer(page, "einrichten-ueb");

  const { data: modell, error: modellFehler } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioId, name: "Kabelzug", weight_step_kg: 2.5 })
    .select("id")
    .single();
  if (modellFehler) throw modellFehler;

  const { data: geraet, error: geraetFehler } = await admin
    .from("machines")
    .insert({
      studio_id: studioId,
      equipment_model_id: modell.id,
      label: "14",
    })
    .select("id")
    .single();
  if (geraetFehler) throw geraetFehler;

  // Eine Uebung, die dem Studio schon gehoert und an keinem Modell haengt.
  const { error: uebungFehler } = await admin.from("exercises").insert({
    studio_id: studioId,
    name: "Rudern sitzend",
    target_reps_min: 10,
    target_reps_max: 15,
  });
  if (uebungFehler) throw uebungFehler;

  await page.goto(`/portal/${studioId}/einrichten/geraet/${geraet.id}/uebungen`);
  await expect(page.getByText("Schritt 5 von 6 · Übungen")).toBeVisible();
  await expect(page.getByText("Noch keine Übung")).toBeVisible();

  // Waehlen statt tippen -- sonst steht dieselbe Uebung mehrfach im Katalog.
  await page.getByRole("button", { name: "Aus dem Studio wählen" }).click();
  await expect(page.getByText("Noch an keinem Modell")).toBeVisible();
  await page
    .getByRole("button", { name: "Rudern sitzend hinzufügen" })
    .click();
  await expect(page.getByText("1. Rudern sitzend")).toBeVisible();

  // Eine neue Uebung entsteht und haengt sofort am Modell.
  await page.getByRole("button", { name: "Neue Übung anlegen" }).click();
  await page.getByLabel("Name").fill("Latzug · Neutralgriff");
  await page.getByLabel("Wiederholungen ab").fill("8");
  await page.getByLabel("bis", { exact: true }).fill("12");
  await page.getByRole("button", { name: "Hinzufügen" }).click();
  await expect(page.getByText("2. Latzug · Neutralgriff")).toBeVisible();

  // Die Reihenfolge ist keine Kosmetik: Uebung 1 ist am Geraet die Vorauswahl.
  await page
    .getByRole("button", { name: "Latzug · Neutralgriff nach oben" })
    .click();
  await expect(page.getByText("1. Latzug · Neutralgriff")).toBeVisible();
  await expect(page.getByText("2. Rudern sitzend")).toBeVisible();

  await page.getByRole("link", { name: "Einrichtung abschließen" }).click();
  await expect(page).toHaveURL(
    new RegExp(`/einrichten/geraet/${geraet.id}/fertig$`),
  );
});
```

- [ ] **Schritt 2: Test laufen lassen und den Fehlschlag sehen**

Ausführen: `pnpm test:e2e -- einrichten`

Erwartet: FAIL — 404 auf der Übungsseite.

- [ ] **Schritt 3: Die vier Actions ergänzen**

In `actions.ts` die Importe erweitern um `attachExerciseToModel`, `createExercise`, `detachExercise`, `reorderModelExercises` und anhängen:

```ts
function uebungenPfad(studioId: string, machineId: string): string {
  return `/portal/${studioId}/einrichten/geraet/${machineId}/uebungen`;
}

/**
 * Eine bestehende Studio-Uebung ans Modell haengen. Ans Ende, damit die
 * gepflegte Reihenfolge nicht durcheinandergeraet -- attachExerciseToModel
 * besorgt das selbst.
 */
export async function uebungHinzufuegen(
  studioId: string,
  machineId: string,
  modelId: string,
  exerciseId: string,
): Promise<ActionErgebnis> {
  const client = await createServerSupabaseClient();
  try {
    await attachExerciseToModel(client, {
      equipmentModelId: modelId,
      exerciseId,
    });
  } catch (fehler) {
    return fehlerAus(fehler, "Die Uebung liess sich nicht hinzufuegen.");
  }
  revalidatePath(uebungenPfad(studioId, machineId));
  return { ok: true };
}

/**
 * Anlegen und zuordnen in einem Schritt: eine Uebung, die an keinem Geraet
 * haengt, taucht nirgends auf und waere ein stiller Fehlschlag.
 */
export async function uebungAnlegen(
  studioId: string,
  machineId: string,
  modelId: string,
  _prev: unknown,
  formData: FormData,
): Promise<ActionErgebnis> {
  const client = await createServerSupabaseClient();
  try {
    const uebung = await createExercise(client, {
      studioId,
      name: text(formData, "name"),
      description: null,
      targetRepsMin: zahl(formData, "targetRepsMin") ?? Number.NaN,
      targetRepsMax: zahl(formData, "targetRepsMax") ?? Number.NaN,
    });
    await attachExerciseToModel(client, {
      equipmentModelId: modelId,
      exerciseId: uebung.id,
    });
  } catch (fehler) {
    return fehlerAus(fehler, "Die Uebung liess sich nicht anlegen.");
  }
  revalidatePath(uebungenPfad(studioId, machineId));
  return { ok: true };
}

export async function uebungLoesen(
  studioId: string,
  machineId: string,
  linkId: string,
): Promise<ActionErgebnis> {
  const client = await createServerSupabaseClient();
  try {
    await detachExercise(client, linkId);
  } catch (fehler) {
    return fehlerAus(fehler, "Die Uebung liess sich nicht loesen.");
  }
  revalidatePath(uebungenPfad(studioId, machineId));
  return { ok: true };
}

/**
 * Die Reihenfolge ist keine Kosmetik: Uebung 1 ist am Geraet die Vorauswahl
 * des Mitglieds (Designsystem 8).
 */
export async function uebungVerschieben(
  studioId: string,
  machineId: string,
  modelId: string,
  linkIds: string[],
): Promise<ActionErgebnis> {
  const client = await createServerSupabaseClient();
  try {
    await reorderModelExercises(client, {
      equipmentModelId: modelId,
      orderedLinkIds: linkIds,
    });
  } catch (fehler) {
    return fehlerAus(fehler, "Die Reihenfolge liess sich nicht speichern.");
  }
  revalidatePath(uebungenPfad(studioId, machineId));
  return { ok: true };
}
```

- [ ] **Schritt 4: Die Übungsseite anlegen**

`apps/web/app/portal/[studioId]/einrichten/geraet/[machineId]/uebungen/page.tsx`:

```tsx
import Link from "next/link";
import { notFound } from "next/navigation";
import { listStudioExercises } from "@fitretro/domain";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { ladeKatalog } from "../../../../catalog";
import { Schrittleiste } from "../../../Schrittleiste";
import { UebungSheet, UebungVerschieben } from "./UebungSheet";
import styles from "../../../halle.module.css";

/**
 * Schritt 5. Die Uebungen haengen am MODELL, nicht am Geraet -- zwei
 * baugleiche Kabelzuege teilen sie sich. Der Bildschirm sagt das, damit
 * niemand sie zweimal anlegt.
 *
 * Der Akzent liegt auf dem Abschliessen, nicht auf dem Hinzufuegen: sonst
 * betont der Bildschirm das Sammeln und nicht das Fertigwerden.
 */
export default async function UebungenPage({
  params,
}: {
  params: Promise<{ studioId: string; machineId: string }>;
}) {
  const { studioId, machineId } = await params;
  const katalog = await ladeKatalog(studioId);

  const treffer = katalog.models
    .flatMap((modell) => modell.machines.map((geraet) => ({ geraet, modell })))
    .find((eintrag) => eintrag.geraet.id === machineId);
  if (!treffer) notFound();

  const { modell, geraet } = treffer;
  const client = await createServerSupabaseClient();
  const studioUebungen = await listStudioExercises(client, studioId);

  const schonDran = new Set(modell.exercises.map((uebung) => uebung.exerciseId));
  const waehlbar = studioUebungen.filter((uebung) => !schonDran.has(uebung.id));
  const reihenfolge = modell.exercises.map((uebung) => uebung.linkId);

  return (
    <>
      <Schrittleiste nummer={5} titel="Übungen" />
      <div>
        <h1 className={styles.titel}>Übungen</h1>
        <p className={styles.unterzeile}>
          {geraet.label} · {modell.name}
        </p>
      </div>

      {modell.exercises.length > 0 ? (
        <section className={styles.abschnitt}>
          {modell.exercises.map((uebung, index) => (
            <div key={uebung.linkId} className={styles.zeile}>
              <div style={{ minWidth: 0 }}>
                <div className={styles.zeileHaupt}>
                  {index + 1}. {uebung.name}
                </div>
                <div className={styles.zeileMeta}>
                  {uebung.targetRepsMin}–{uebung.targetRepsMax} Wiederholungen
                  {uebung.hasVideo
                    ? ` · Video ${uebung.videoDurationS ?? "?"} s`
                    : " · ohne Video"}
                </div>
              </div>
              <UebungVerschieben
                studioId={studioId}
                machineId={machineId}
                modelId={modell.id}
                linkId={uebung.linkId}
                name={uebung.name}
                reihenfolge={reihenfolge}
              />
            </div>
          ))}
        </section>
      ) : (
        <div className={styles.karte}>
          <div style={{ fontSize: 16, fontWeight: 600 }}>Noch keine Übung</div>
          <p className={styles.notiz}>
            Ohne Übung zeigt das Gerät dem Mitglied nichts zum Trainieren. Nimm
            eine aus dem Studio oder leg eine neue an.
          </p>
        </div>
      )}

      <UebungSheet
        studioId={studioId}
        machineId={machineId}
        modelId={modell.id}
        waehlbar={waehlbar}
      />

      <p className={styles.notiz}>
        Die Reihenfolge zählt: Übung 1 ist am Gerät die Vorauswahl. Übungen
        gehören dem Studio, nicht dem Gerät — dieselbe Übung an zwei Modellen
        behält ihren Namen. Das Einweisungsvideo hängt dagegen am Paar aus
        Modell und Übung.
      </p>

      <Link
        href={`/portal/${studioId}/einrichten/geraet/${machineId}/fertig`}
        className={styles.haupt}
      >
        Einrichtung abschließen
      </Link>
    </>
  );
}
```

- [ ] **Schritt 5: Sheet und Umordnen anlegen**

`apps/web/app/portal/[studioId]/einrichten/geraet/[machineId]/uebungen/UebungSheet.tsx`:

```tsx
"use client";

import { useActionState, useId, useState, useTransition } from "react";
import type { StudioExercise } from "@fitretro/domain";
import {
  uebungAnlegen,
  uebungHinzufuegen,
  uebungVerschieben,
} from "../../../actions";
import styles from "../../../halle.module.css";

type Ansicht = "zu" | "waehlen" | "neu";

/**
 * Eine Auswahl statt eines leeren Namensfelds (Spec 2). "Neue Uebung anlegen"
 * traegt hier bewusst keinen Akzent: der Bildschirm soll zum Waehlen
 * einladen, nicht zum Doppeln.
 */
export function UebungSheet({
  studioId,
  machineId,
  modelId,
  waehlbar,
}: {
  studioId: string;
  machineId: string;
  modelId: string;
  waehlbar: StudioExercise[];
}) {
  const [ansicht, setAnsicht] = useState<Ansicht>("zu");
  const [fehler, setFehler] = useState<string | null>(null);
  const [laeuft, starte] = useTransition();

  const [ergebnis, formAction, legtAn] = useActionState(
    async (_prev: unknown, formData: FormData) => {
      const antwort = await uebungAnlegen(
        studioId,
        machineId,
        modelId,
        null,
        formData,
      );
      if (antwort.ok) setAnsicht("zu");
      return antwort;
    },
    null,
  );

  if (ansicht === "zu") {
    return (
      <div className={styles.karteGestrichelt}>
        <div style={{ fontSize: 16, fontWeight: 600 }}>Noch eine Übung</div>
        <button
          type="button"
          className={styles.neben}
          onClick={() => setAnsicht("waehlen")}
        >
          Aus dem Studio wählen
        </button>
        <button
          type="button"
          className={styles.neben}
          onClick={() => setAnsicht("neu")}
        >
          Neue Übung anlegen
        </button>
      </div>
    );
  }

  if (ansicht === "neu") {
    return (
      <form action={formAction} className={styles.karte}>
        <div style={{ fontSize: 16, fontWeight: 600 }}>Neue Übung</div>
        <Feld name="name" label="Name" required placeholder="Latzug · Neutralgriff" />
        <div style={{ display: "flex", gap: 12 }}>
          <div style={{ flex: 1 }}>
            <Feld
              name="targetRepsMin"
              label="Wiederholungen ab"
              inputMode="numeric"
              required
              placeholder="8"
            />
          </div>
          <div style={{ flex: 1 }}>
            <Feld
              name="targetRepsMax"
              label="bis"
              inputMode="numeric"
              required
              placeholder="12"
            />
          </div>
        </div>
        <p className={styles.notiz}>
          Die Spanne ist ein Ziel, kein Vorschlag. gymodo rechnet daraus nichts
          aus — sie steht dem Mitglied unter dem Rad.
        </p>
        {ergebnis && !ergebnis.ok ? (
          <p className={styles.fehler} role="alert">
            {ergebnis.error}
          </p>
        ) : null}
        <button type="submit" className={styles.neben} disabled={legtAn}>
          {legtAn ? "Wird angelegt …" : "Hinzufügen"}
        </button>
        <button
          type="button"
          className={styles.neben}
          onClick={() => setAnsicht("zu")}
        >
          Abbrechen
        </button>
      </form>
    );
  }

  return (
    <div className={styles.karte}>
      <div style={{ fontSize: 16, fontWeight: 600 }}>Übung hinzufügen</div>

      {waehlbar.length === 0 ? (
        <p className={styles.notiz}>
          Alle Übungen des Studios hängen schon an diesem Modell.
        </p>
      ) : (
        <section className={styles.abschnitt}>
          {waehlbar.map((uebung) => (
            <div key={uebung.id} className={styles.zeile}>
              <div style={{ minWidth: 0 }}>
                <div className={styles.zeileHaupt}>{uebung.name}</div>
                <div
                  className={
                    uebung.modelCount === 0
                      ? styles.zeileMetaFaint
                      : styles.zeileMeta
                  }
                >
                  {uebung.modelCount === 0
                    ? "Noch an keinem Modell"
                    : `An ${uebung.modelCount} ${uebung.modelCount === 1 ? "Modell" : "Modellen"}`}{" "}
                  · {uebung.targetRepsMin}–{uebung.targetRepsMax} Wiederholungen
                </div>
              </div>
              <button
                type="button"
                className={styles.nebenSchmal}
                aria-label={`${uebung.name} hinzufügen`}
                disabled={laeuft}
                onClick={() => {
                  setFehler(null);
                  starte(async () => {
                    const antwort = await uebungHinzufuegen(
                      studioId,
                      machineId,
                      modelId,
                      uebung.id,
                    );
                    if (antwort.ok) setAnsicht("zu");
                    else setFehler(antwort.error);
                  });
                }}
              >
                Hinzufügen
              </button>
            </div>
          ))}
        </section>
      )}

      {fehler ? (
        <p className={styles.fehler} role="alert">
          {fehler}
        </p>
      ) : null}

      <p className={styles.notiz}>
        Übungen gehören dem Studio, nicht dem Gerät. Dieselbe Übung an zwei
        Modellen behält ihren Namen.
      </p>
      <button
        type="button"
        className={styles.neben}
        onClick={() => setAnsicht("neu")}
      >
        Neue Übung anlegen
      </button>
      <button
        type="button"
        className={styles.neben}
        onClick={() => setAnsicht("zu")}
      >
        Abbrechen
      </button>
    </div>
  );
}

/**
 * Umordnen mit zwei Knoepfen statt Ziehen. Ein Drag-and-Drop auf einem
 * Touchscreen konkurriert mit dem Seitenscrollen -- und die Liste hat selten
 * mehr als vier Zeilen.
 */
export function UebungVerschieben({
  studioId,
  machineId,
  modelId,
  linkId,
  name,
  reihenfolge,
}: {
  studioId: string;
  machineId: string;
  modelId: string;
  linkId: string;
  name: string;
  reihenfolge: string[];
}) {
  const [fehler, setFehler] = useState<string | null>(null);
  const [laeuft, starte] = useTransition();
  const index = reihenfolge.indexOf(linkId);

  function schiebe(richtung: -1 | 1) {
    const ziel = index + richtung;
    if (ziel < 0 || ziel >= reihenfolge.length) return;
    const neu = [...reihenfolge];
    [neu[index], neu[ziel]] = [neu[ziel]!, neu[index]!];
    setFehler(null);
    starte(async () => {
      const antwort = await uebungVerschieben(studioId, machineId, modelId, neu);
      if (!antwort.ok) setFehler(antwort.error);
    });
  }

  return (
    <span style={{ flexShrink: 0, display: "flex", gap: 8 }}>
      {fehler ? (
        <span className={styles.fehler} role="alert">
          {fehler}
        </span>
      ) : null}
      <button
        type="button"
        className={styles.nebenSchmal}
        aria-label={`${name} nach oben`}
        disabled={laeuft || index <= 0}
        onClick={() => schiebe(-1)}
      >
        ↑
      </button>
      <button
        type="button"
        className={styles.nebenSchmal}
        aria-label={`${name} nach unten`}
        disabled={laeuft || index >= reihenfolge.length - 1}
        onClick={() => schiebe(1)}
      >
        ↓
      </button>
    </span>
  );
}

function Feld({
  name,
  label,
  ...rest
}: { name: string; label: string } & React.InputHTMLAttributes<HTMLInputElement>) {
  const id = useId();
  return (
    <div className={styles.feld}>
      <label className={styles.label} htmlFor={id}>
        {label}
      </label>
      <input id={id} name={name} className={styles.eingabe} {...rest} />
    </div>
  );
}
```

- [ ] **Schritt 6: Test laufen lassen**

Ausführen: `pnpm test:e2e -- einrichten`

Erwartet: der Übungs-Test PASS bis zur letzten Zusicherung, dort FAIL — die Fertig-Seite kommt in Aufgabe 12. Die letzte Zeile auskommentieren; die auskommentierte Zeile aus Aufgabe 9 wieder einschalten.

- [ ] **Schritt 7: Committen**

```bash
git add "apps/web/app/portal/[studioId]/einrichten" e2e/einrichten.spec.ts
git commit -m "feat(web): Schritt 5 -- Uebungen waehlen, anlegen und ordnen"
```

---

## Aufgabe 11: Schritt 6 — Video und die Warteschlange

Zwei Dinge, die zusammengehören: die Aufnahme je Übung (höchstens 45 s, am Paar aus Modell und Übung) und die Warteschlange, die sie hochlädt, **während der Trainer weitergeht**.

`VideoUpload.tsx` gibt es schon — aber es lädt genau eine Datei und lebt in der Komponente, die es rendert. Verlässt der Trainer die Übungsseite, ist der Upload weg. `TelefonUploads.dc.html` zeigt genau das Gegenteil: vier Uploads über drei Geräte, einer davon *„Von gestern, noch nicht oben"*.

Die Auflösung: eine Warteschlange im Layout des Gangs, also oberhalb jeder Seite. `VideoUpload` bleibt für den Schreibtisch unangetastet.

**Warum eins nach dem anderen:** vier gleichzeitige TUS-Uploads über Studio-WLAN teilen sich dieselbe Bandbreite und werden alle vier langsam. Nacheinander ist der erste nach einer Minute durch. Fotos gehen vor Videos — sie sind klein, und ohne Foto erkennt niemand das Gerät.

**Dateien:**
- Anlegen: `apps/web/app/portal/[studioId]/einrichten/Uploads.tsx`
- Anlegen: `apps/web/app/portal/[studioId]/einrichten/uploads/page.tsx`
- Ändern: `apps/web/app/portal/[studioId]/einrichten/layout.tsx`
- Ändern: `apps/web/app/portal/[studioId]/einrichten/geraet/[machineId]/uebungen/page.tsx` und `UebungSheet.tsx`
- Ändern: `e2e/einrichten.spec.ts`

**Schnittstellen:**
- Nutzt: `videoUploadVorbereiten`, `videoBestaetigen` aus `../../actions` (Schreibtisch-Actions, unverändert — sie brauchen keine ID zurück), `MAX_VIDEO_BYTES`, `MAX_VIDEO_SECONDS` aus `@fitretro/domain/media`, `tus-js-client`
- Liefert:
  ```ts
  export type Auftrag = {
    id: string;
    titel: string;
    modelId: string;
    linkId: string;
    datei: File;
    stand: "wartet" | "laeuft" | "prueft" | "fertig" | "fehler";
    anteil: number;
    fehler?: string;
  };
  export function UploadsProvider(props: {
    studioId: string; children: React.ReactNode;
  }): JSX.Element;
  export function useUploads(): {
    auftraege: Auftrag[];
    offen: number;
    einreihen(auftrag: { titel: string; modelId: string; linkId: string; datei: File }): void;
  };
  export function VideoAufnehmen(props: {
    modelId: string; linkId: string; uebungName: string; titel: string; hatVideo: boolean;
  }): JSX.Element;
  export function UploadsMarke(props: { studioId: string }): JSX.Element | null;
  ```

- [ ] **Schritt 1: Den fehlschlagenden E2E-Test schreiben**

Ein echter Videoupload gehört nicht in einen E2E-Lauf — die TUS-Strecke deckt `tests/integration/domain-media.test.ts` ab, und `trainerportal.spec.ts` sagt im Kopfkommentar ausdrücklich, warum sie draußen bleibt. Geprüft wird hier die **Warteschlange**: dass eine eingereihte Datei die Seite überlebt.

In `e2e/einrichten.spec.ts` anhängen:

```ts
test("Ein Video wartet in der Warteschlange und ueberlebt den Seitenwechsel", async ({
  page,
}) => {
  const { admin, studioId } = await studioMitTrainer(page, "einrichten-upload");

  const { data: modell, error: modellFehler } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioId, name: "Kabelzug", weight_step_kg: 2.5 })
    .select("id")
    .single();
  if (modellFehler) throw modellFehler;

  const { data: geraet, error: geraetFehler } = await admin
    .from("machines")
    .insert({ studio_id: studioId, equipment_model_id: modell.id, label: "14" })
    .select("id")
    .single();
  if (geraetFehler) throw geraetFehler;

  const { data: uebung, error: uebungFehler } = await admin
    .from("exercises")
    .insert({
      studio_id: studioId,
      name: "Rudern sitzend",
      target_reps_min: 10,
      target_reps_max: 15,
    })
    .select("id")
    .single();
  if (uebungFehler) throw uebungFehler;

  const { error: linkFehler } = await admin
    .from("equipment_model_exercises")
    .insert({
      equipment_model_id: modell.id,
      exercise_id: uebung.id,
      sort_order: 1,
    });
  if (linkFehler) throw linkFehler;

  await page.goto(`/portal/${studioId}/einrichten/geraet/${geraet.id}/uebungen`);

  // Eine Datei, die die Groessenpruefung passiert -- der Upload selbst darf
  // scheitern, die Warteschlange muss ihn trotzdem fuehren.
  await page.getByLabel("Video für Rudern sitzend").setInputFiles({
    name: "rudern.mp4",
    mimeType: "video/mp4",
    buffer: Buffer.alloc(1024, 1),
  });

  const warteschlange = page.getByRole("link", { name: /Uploads/ });
  await expect(warteschlange).toBeVisible();

  // Der Seitenwechsel ist der Punkt: die Warteschlange lebt im Layout des
  // Gangs, nicht in der Uebungsseite.
  await page.goto(`/portal/${studioId}/einrichten/uploads`);
  await expect(
    page.getByText("Kabelzug 14 · Rudern sitzend"),
  ).toBeVisible();
  await expect(page.getByText("Lass diesen Bildschirm offen")).toBeVisible();
});
```

- [ ] **Schritt 2: Test laufen lassen und den Fehlschlag sehen**

Ausführen: `pnpm test:e2e -- einrichten`

Erwartet: FAIL — kein Feld „Video für Rudern sitzend".

- [ ] **Schritt 3: Die Warteschlange anlegen**

`apps/web/app/portal/[studioId]/einrichten/Uploads.tsx`:

```tsx
"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useRef,
  useState,
} from "react";
import * as tus from "tus-js-client";
// Der Unterpfad statt des Barrels: index.ts zieht ueber tags.ts das
// node:crypto-Modul mit, und das laesst sich nicht in einen Browserbundle
// packen (siehe VideoUpload.tsx).
import { MAX_VIDEO_BYTES, MAX_VIDEO_SECONDS } from "@fitretro/domain/media";
import { createBrowserSupabaseClient, storageUrl } from "@/lib/supabase/browser";
import { videoBestaetigen, videoUploadVorbereiten } from "../../actions";
import styles from "./halle.module.css";

export type Auftrag = {
  id: string;
  titel: string;
  modelId: string;
  linkId: string;
  datei: File;
  stand: "wartet" | "laeuft" | "prueft" | "fertig" | "fehler";
  anteil: number;
  fehler?: string;
};

type Schlange = {
  auftraege: Auftrag[];
  offen: number;
  einreihen: (auftrag: {
    titel: string;
    modelId: string;
    linkId: string;
    datei: File;
  }) => void;
};

const Kontext = createContext<Schlange | null>(null);

export function useUploads(): Schlange {
  const wert = useContext(Kontext);
  if (!wert) throw new Error("useUploads ausserhalb des UploadsProvider");
  return wert;
}

/**
 * Die Warteschlange lebt im Layout des Gangs, nicht in der Uebungsseite:
 * der Trainer geht weiter, waehrend hochgeladen wird (TelefonUploads).
 *
 * Eins nach dem anderen. Vier gleichzeitige TUS-Uploads ueber Studio-WLAN
 * teilen sich dieselbe Bandbreite und werden alle vier langsam; nacheinander
 * ist der erste nach einer Minute durch.
 *
 * Sie ueberlebt einen Seitenwechsel INNERHALB des Gangs, nicht ein
 * Neuladen -- die File-Objekte leben im Speicher des Tabs. Das ist die
 * Grenze, die der Bildschirm auch benennt: "Lass diesen Bildschirm offen."
 */
export function UploadsProvider({
  studioId,
  children,
}: {
  studioId: string;
  children: React.ReactNode;
}) {
  const [auftraege, setAuftraege] = useState<Auftrag[]>([]);
  const laeuftGerade = useRef(false);

  const einreihen = useCallback(
    (neu: { titel: string; modelId: string; linkId: string; datei: File }) => {
      setAuftraege((bisher) => [
        ...bisher,
        {
          id: crypto.randomUUID(),
          titel: neu.titel,
          modelId: neu.modelId,
          linkId: neu.linkId,
          datei: neu.datei,
          stand: "wartet",
          anteil: 0,
        },
      ]);
    },
    [],
  );

  function setze(id: string, aenderung: Partial<Auftrag>) {
    setAuftraege((bisher) =>
      bisher.map((auftrag) =>
        auftrag.id === id ? { ...auftrag, ...aenderung } : auftrag,
      ),
    );
  }

  useEffect(() => {
    if (laeuftGerade.current) return;
    const naechster = auftraege.find((auftrag) => auftrag.stand === "wartet");
    if (!naechster) return;

    laeuftGerade.current = true;
    void (async () => {
      try {
        await sende(naechster);
      } finally {
        laeuftGerade.current = false;
      }
    })();

    async function sende(auftrag: Auftrag) {
      setze(auftrag.id, { stand: "laeuft", anteil: 0 });

      if (auftrag.datei.size > MAX_VIDEO_BYTES) {
        setze(auftrag.id, {
          stand: "fehler",
          fehler: `Die Datei ist ${(auftrag.datei.size / 1024 / 1024).toFixed(0)} MiB groß. Mehr als ${MAX_VIDEO_BYTES / 1024 / 1024} MiB nimmt der Upload nicht an.`,
        });
        return;
      }

      const ziel = await videoUploadVorbereiten(
        auftrag.linkId,
        auftrag.datei.size,
      );
      if (!ziel.ok) {
        setze(auftrag.id, { stand: "fehler", fehler: ziel.error });
        return;
      }

      const supabase = createBrowserSupabaseClient();
      const {
        data: { session },
      } = await supabase.auth.getSession();
      if (!session) {
        setze(auftrag.id, {
          stand: "fehler",
          fehler: "Die Anmeldung ist abgelaufen. Bitte neu anmelden.",
        });
        return;
      }

      try {
        await new Promise<void>((fertig, gescheitert) => {
          const upload = new tus.Upload(auftrag.datei, {
            endpoint: storageUrl(),
            headers: { authorization: `Bearer ${session.access_token}` },
            // Der Storage-Dienst verlangt genau diese Blockgroesse.
            chunkSize: 6 * 1024 * 1024,
            uploadDataDuringCreation: true,
            removeFingerprintOnSuccess: true,
            metadata: {
              bucketName: ziel.bucket,
              objectName: ziel.storagePath,
              contentType: auftrag.datei.type || "video/mp4",
            },
            onProgress: (gesendet, gesamt) => {
              setze(auftrag.id, { anteil: gesamt > 0 ? gesendet / gesamt : 0 });
            },
            onError: (ursache) => gescheitert(ursache),
            onSuccess: () => fertig(),
          });
          // Ein abgebrochener Upload derselben Datei wird fortgesetzt statt
          // neu begonnen -- genau dafuer ist TUS da.
          upload.findPreviousUploads().then((frueher) => {
            if (frueher.length > 0) upload.resumeFromPreviousUpload(frueher[0]!);
            upload.start();
          });
        });
      } catch (ursache) {
        setze(auftrag.id, {
          stand: "fehler",
          // Nie "fehlgeschlagen": der Gang ist die Halle, und dort heisst es
          // "gespeichert, wird gesendet" (Spec 4).
          fehler:
            ursache instanceof Error
              ? `Unterbrochen: ${ursache.message}. Wähle dieselbe Datei noch einmal, sie setzt fort.`
              : "Unterbrochen. Wähle dieselbe Datei noch einmal, sie setzt fort.",
        });
        return;
      }

      // Erst jetzt sieht der Server die Bytes: Format und Laufzeit werden am
      // Inhalt geprueft, nicht an dem, was der Browser behauptet.
      setze(auftrag.id, { stand: "prueft", anteil: 1 });
      const bestaetigt = await videoBestaetigen(
        studioId,
        auftrag.modelId,
        auftrag.linkId,
        ziel.storagePath,
      );
      setze(
        auftrag.id,
        bestaetigt.ok
          ? { stand: "fertig" }
          : { stand: "fehler", fehler: bestaetigt.error },
      );
    }
  }, [auftraege, studioId]);

  const offen = auftraege.filter(
    (auftrag) => auftrag.stand !== "fertig" && auftrag.stand !== "fehler",
  ).length;

  return (
    <Kontext.Provider value={{ auftraege, offen, einreihen }}>
      {children}
    </Kontext.Provider>
  );
}

/**
 * Die Aufnahme entsteht auf dem Trainerhandy und geht aus mobilem Safari
 * hoch (Spec 6.8). Sie wird eingereiht, nicht abgewartet -- der Trainer geht
 * zum naechsten Geraet weiter.
 */
export function VideoAufnehmen({
  modelId,
  linkId,
  uebungName,
  titel,
  hatVideo,
}: {
  modelId: string;
  linkId: string;
  /** Fuer die Beschriftung am Feld -- der Trainer sieht das Geraet ja. */
  uebungName: string;
  /** Fuer die Warteschlange, die Uebungen mehrerer Geraete fuehrt. */
  titel: string;
  hatVideo: boolean;
}) {
  const { einreihen } = useUploads();
  const eingabe = useRef<HTMLInputElement>(null);

  return (
    <div className={styles.feld}>
      <label className={styles.label} htmlFor={`video-${linkId}`}>
        {hatVideo ? `Video ersetzen für ${uebungName}` : `Video für ${uebungName}`}
      </label>
      <input
        ref={eingabe}
        id={`video-${linkId}`}
        type="file"
        accept="video/mp4,video/quicktime"
        capture="environment"
        className={styles.eingabe}
        onChange={(ereignis) => {
          const datei = ereignis.target.files?.[0];
          if (!datei) return;
          einreihen({ titel, modelId, linkId, datei });
          if (eingabe.current) eingabe.current.value = "";
        }}
      />
      <span className={styles.notiz}>
        Höchstens {MAX_VIDEO_SECONDS} Sekunden. Die Länge wird an der Datei
        geprüft, nicht geschätzt — eine zu lange Aufnahme wird abgelehnt, nicht
        beschnitten.
      </span>
    </div>
  );
}

/** Die Zeile im Kopf des Gangs, solange etwas offen ist. */
export function UploadsMarke({ studioId }: { studioId: string }) {
  const { offen } = useUploads();
  if (offen === 0) return null;
  return (
    <a
      href={`/portal/${studioId}/einrichten/uploads`}
      className={styles.marke}
      aria-label={`Uploads: ${offen} offen`}
    >
      Uploads · {offen}
    </a>
  );
}
```

- [ ] **Schritt 4: Die Warteschlangenseite anlegen**

`apps/web/app/portal/[studioId]/einrichten/uploads/page.tsx`:

```tsx
"use client";

import Link from "next/link";
import { use } from "react";
import { useUploads, type Auftrag } from "../Uploads";
import styles from "../halle.module.css";

const STAND_TEXT: Record<Auftrag["stand"], string> = {
  wartet: "wartet",
  laeuft: "wird übertragen",
  prueft: "wird geprüft",
  fertig: "oben",
  fehler: "unterbrochen",
};

export default function UploadsPage({
  params,
}: {
  params: Promise<{ studioId: string }>;
}) {
  const { studioId } = use(params);
  const { auftraege, offen } = useUploads();

  return (
    <>
      <div>
        <Link
          href={`/portal/${studioId}/einrichten`}
          className={styles.zurueck}
        >
          ← Einrichten
        </Link>
        <h1 className={styles.titel}>Uploads</h1>
        <p className={styles.unterzeile}>
          Läuft weiter, während du weitergehst.
        </p>
      </div>

      {auftraege.length === 0 ? (
        <p className={styles.notiz}>Nichts in der Warteschlange.</p>
      ) : (
        <section className={styles.abschnitt}>
          <div className={styles.abschnittKopf}>
            <h2 className={styles.label}>Warteschlange</h2>
            <span className={styles.zeileMeta}>{offen} offen</span>
          </div>
          {auftraege.map((auftrag) => (
            <div key={auftrag.id} className={styles.zeile}>
              <div style={{ minWidth: 0, width: "100%" }}>
                <div className={styles.zeileHaupt}>{auftrag.titel}</div>
                <div className={styles.zeileMeta}>
                  {(auftrag.datei.size / 1024 / 1024).toFixed(1)} MB ·{" "}
                  {STAND_TEXT[auftrag.stand]}
                </div>
                {auftrag.stand === "laeuft" || auftrag.stand === "wartet" ? (
                  <div
                    className={styles.balkenBahn}
                    role="progressbar"
                    aria-valuemin={0}
                    aria-valuemax={100}
                    aria-valuenow={Math.round(auftrag.anteil * 100)}
                    aria-label={`Fortschritt ${auftrag.titel}`}
                    style={{ marginTop: 8 }}
                  >
                    <div
                      className={styles.balken}
                      style={{ width: `${Math.round(auftrag.anteil * 100)}%` }}
                    />
                  </div>
                ) : null}
                {auftrag.fehler ? (
                  <p className={styles.fehler} role="alert">
                    {auftrag.fehler}
                  </p>
                ) : null}
                {auftrag.stand === "wartet" ? (
                  <span className={styles.notiz}>
                    Beginnt, sobald das vorige durch ist.
                  </span>
                ) : null}
              </div>
            </div>
          ))}
        </section>
      )}

      <div className={styles.karteWarnung}>
        <div style={{ fontWeight: 600 }}>Lass diesen Bildschirm offen</div>
        <p className={styles.notiz}>
          Safari hält Uploads an, sobald du zu einer anderen App wechselst. Sie
          gehen nicht verloren — sie warten, bis du zurückkommst. Ein Neuladen
          der Seite leert die Warteschlange allerdings: dann wählst du die
          Dateien noch einmal, und der Upload setzt fort, wo er stand.
        </p>
      </div>

      <Link href={`/portal/${studioId}/einrichten`} className={styles.neben}>
        Weiter einrichten
      </Link>
    </>
  );
}
```

- [ ] **Schritt 5: Provider und Marke ins Layout hängen**

In `apps/web/app/portal/[studioId]/einrichten/layout.tsx` den Import ergänzen

```tsx
import { UploadsMarke, UploadsProvider } from "./Uploads";
```

und den Rückgabewert ersetzen durch:

```tsx
  return (
    <UploadsProvider studioId={studioId}>
      <div className={styles.seite}>
        <header className={styles.kopf}>
          <span className={styles.studio}>{katalog.studioName}</span>
          <span style={{ display: "flex", gap: 12, alignItems: "center" }}>
            <UploadsMarke studioId={studioId} />
            <Link href={`/portal/${studioId}`} className={styles.zurueck}>
              Schreibtisch
            </Link>
          </span>
        </header>
        <main className={styles.inhalt}>{children}</main>
      </div>
    </UploadsProvider>
  );
```

- [ ] **Schritt 6: Die Aufnahme an die Übungsliste hängen**

In `uebungen/page.tsx` den Import `import { VideoAufnehmen } from "../../../Uploads";` ergänzen und die Übungszeile so erweitern, dass unter Name und Meta die Aufnahme steht — der Container der Zeile wird dafür senkrecht:

```tsx
            <div key={uebung.linkId} className={styles.zeile}>
              <div style={{ minWidth: 0, width: "100%", display: "grid", gap: 12 }}>
                <div style={{ display: "flex", justifyContent: "space-between", gap: 12 }}>
                  <div style={{ minWidth: 0 }}>
                    <div className={styles.zeileHaupt}>
                      {index + 1}. {uebung.name}
                    </div>
                    <div className={styles.zeileMeta}>
                      {uebung.targetRepsMin}–{uebung.targetRepsMax} Wiederholungen
                      {uebung.hasVideo
                        ? ` · Video ${uebung.videoDurationS ?? "?"} s`
                        : " · ohne Video"}
                    </div>
                  </div>
                  <UebungVerschieben
                    studioId={studioId}
                    machineId={machineId}
                    modelId={modell.id}
                    linkId={uebung.linkId}
                    name={uebung.name}
                    reihenfolge={reihenfolge}
                  />
                </div>
                <VideoAufnehmen
                  modelId={modell.id}
                  linkId={uebung.linkId}
                  uebungName={uebung.name}
                  titel={`${modell.name} ${geraet.label} · ${uebung.name}`}
                  hatVideo={uebung.hasVideo}
                />
              </div>
            </div>
```

Ebenso den Schlusssatz der Seite um die Überspringbarkeit ergänzen:

```tsx
      <p className={styles.notiz}>
        Ein Gerät ohne Video ist vollständig nutzbar, nur ohne Anleitung. Die
        Uploads laufen weiter, während du zum nächsten Gerät gehst.
      </p>
```

- [ ] **Schritt 7: Test laufen lassen**

Ausführen: `pnpm test:e2e -- einrichten`

Erwartet: PASS für den Upload-Test.

Ausführen: `pnpm --filter @fitretro/web build`

Erwartet: keine Fehler. Dieser Schritt fängt ab, was `typecheck` nicht sieht: ein `node:crypto` im Client-Bundle bricht erst hier.

- [ ] **Schritt 8: Committen**

```bash
git add "apps/web/app/portal/[studioId]/einrichten" e2e/einrichten.spec.ts
git commit -m "feat(web): Schritt 6 -- Aufnahme und die Warteschlange ueber Geraete hinweg"
```

---

## Aufgabe 12: Fertig, der Rückweg vom Schreibtisch, und der ganze Gang

Der Abschluss zählt auf, was jetzt gilt, und bietet zwei Ausgänge: das nächste Gerät oder Feierabend. Dazu kommt der Verweis, der auf dem Schreibtisch fehlt (`Modell.dc.html`, markiert `~`: *„Tag scannen" je Geräteinstanz*), und der Test, der den ganzen Gang in einem Zug läuft. Erst er beweist, dass die sechs Schritte zusammenhängen.

> **Der Probe-Scan aus `TelefonFertig.dc.html` wird hier nicht gebaut, und das ist kein Versehen.**
>
> Er bräuchte den Klartext-Token, um auf `/t/<token>` zu verlinken. Den bekommt das Portal nicht: `0026_tag_klartext.sql` entzieht `authenticated` das Recht auf `machine_tags` und gewährt es spaltenweise wieder — `token` ist ausdrücklich **nicht** dabei, `token_hash` schon. Der Kommentar dort sagt, warum: der Klartext soll nicht aus einer Portalsitzung herausfallen.
>
> Die Artboards sind älter als diese Entscheidung. Sie aufzulösen heißt, entweder eine `security definer`-Funktion zu bauen, die den Token für ein einzelnes Gerät herausgibt, oder die Fallback-Seite auch über eine Geräte-ID erreichbar zu machen — beides eine Entwurfsfrage, kein Detail der Umsetzung. Sie steht unten unter *„Was dieser Plan offenlässt"*.

**Dateien:**
- Anlegen: `apps/web/app/portal/[studioId]/einrichten/geraet/[machineId]/fertig/page.tsx`
- Ändern: `apps/web/app/portal/[studioId]/(schreibtisch)/modelle/[modelId]/page.tsx`
- Ändern: `e2e/einrichten.spec.ts`

**Schnittstellen:**
- Nutzt: `ladeKatalog`; keine neue Action, keine Typänderung an `CatalogTag`
- Liefert: nichts, was eine spätere Aufgabe braucht

- [ ] **Schritt 1: Den fehlschlagenden E2E-Test schreiben — der ganze Gang**

In `e2e/einrichten.spec.ts` anhängen (und alle in den Aufgaben 6–10 auskommentierten Zusicherungen wieder einschalten):

```ts
test("Der ganze Gang: sechs Schritte, ein Geraet, und danach ist es auffindbar", async ({
  page,
}) => {
  const { admin, studioId } = await studioMitTrainer(page, "einrichten-gang");
  const tag = await tagAnlegen(admin, { studioId: null });

  await page.goto(`/portal/${studioId}/einrichten`);
  await page.getByRole("link", { name: "Gerät einrichten" }).click();

  // 1 Modell, Foto Pflicht
  await page.getByRole("link", { name: "Neues Modell anlegen" }).click();
  await page.getByLabel("Name").fill("Kabelzug");
  await page.getByLabel("Hersteller").fill("Technogym");
  await page.getByLabel("Ab").fill("5");
  await page.getByLabel("Bis").fill("100");
  await page.getByLabel("Foto des Modells").setInputFiles({
    name: "kabelzug.jpg",
    mimeType: "image/jpeg",
    buffer: jpegOhneExif(),
  });
  await page
    .getByRole("button", { name: "Weiter zu den Einstellungen" })
    .click();

  // 2 Einstellungen
  await expect(page.getByText("Foto · Steht")).toBeVisible();
  await page.getByRole("button", { name: "Parameter hinzufügen" }).click();
  await page.getByLabel("Beschriftung").fill("Sitzhöhe");
  await page.getByLabel("Schlüssel").fill("sitz");
  await page.getByLabel("Von").fill("1");
  await page.getByLabel("Bis").fill("8");
  await page.getByRole("button", { name: "Hinzufügen" }).click();
  await expect(page.getByText("Sitzhöhe")).toBeVisible();
  await page.getByRole("link", { name: "Weiter zum Gerät" }).click();

  // 3 Gerät
  await expect(page.getByLabel("Nummer")).toHaveValue("1");
  await page.getByLabel("Nummer").fill("14");
  await page.getByLabel("Standort").fill("Rückwand rechts");
  await page.getByRole("button", { name: "Weiter zum Tag" }).click();

  // 4 Tag
  await page.getByRole("button", { name: "Tag scannen" }).click();
  await page.getByLabel("Token vom Tag").fill(tag.token);
  await page.getByRole("button", { name: "Tag prüfen" }).click();
  await expect(page.getByText("Tag erkannt")).toBeVisible();
  await page.getByRole("button", { name: "Verbinden" }).click();

  // 5 Übungen
  await page.getByRole("button", { name: "Neue Übung anlegen" }).click();
  await page.getByLabel("Name").fill("Rudern sitzend");
  await page.getByLabel("Wiederholungen ab").fill("10");
  await page.getByLabel("bis", { exact: true }).fill("15");
  await page.getByRole("button", { name: "Hinzufügen" }).click();
  await expect(page.getByText("1. Rudern sitzend")).toBeVisible();
  await page.getByRole("link", { name: "Einrichtung abschließen" }).click();

  // 6 Fertig -- Schritt 6 ist uebersprungen, und das ist erlaubt.
  await expect(page.getByText("Kabelzug 14 steht")).toBeVisible();
  await expect(page.getByText("Für Mitglieder auffindbar")).toBeVisible();
  await expect(page.getByText("Tag verbunden")).toBeVisible();
  await expect(page.getByText("1 Übung ohne Video")).toBeVisible();

  // Der Schreibtisch weiss es auch -- und fuehrt zurueck in den Gang.
  await page.goto(`/portal/${studioId}/geraete`);
  await expect(page.getByText("Das Gerät in Betrieb ist erreichbar.")).toBeVisible();

  await page.getByRole("link", { name: "Kabelzug" }).first().click();
  await expect(
    page.getByRole("link", { name: "Tag scannen" }).first(),
  ).toBeVisible();
});
```

- [ ] **Schritt 2: Test laufen lassen und den Fehlschlag sehen**

Ausführen: `pnpm test:e2e -- einrichten`

Erwartet: FAIL — 404 auf der Fertig-Seite.

- [ ] **Schritt 3: Die Fertig-Seite anlegen**

`apps/web/app/portal/[studioId]/einrichten/geraet/[machineId]/fertig/page.tsx`:

```tsx
import Link from "next/link";
import { notFound } from "next/navigation";
import { ladeKatalog } from "../../../../catalog";
import styles from "../../../halle.module.css";

/**
 * Der Abschluss zaehlt auf, was jetzt gilt -- und was nicht. Ein Geraet ohne
 * Video ist vollstaendig nutzbar (Spec 6.8); die Zeile steht trotzdem da,
 * weil der Ueberblick am Schreibtisch darueber Buch fuehrt.
 *
 * Der Probe-Scan des Artboards fehlt hier bewusst: er braeuchte den
 * Klartext-Token, und 0026 gewaehrt authenticated die Spalte token nicht.
 * Siehe den Plan, Aufgabe 12.
 */
export default async function FertigPage({
  params,
}: {
  params: Promise<{ studioId: string; machineId: string }>;
}) {
  const { studioId, machineId } = await params;
  const katalog = await ladeKatalog(studioId);

  const treffer = katalog.models
    .flatMap((modell) => modell.machines.map((geraet) => ({ geraet, modell })))
    .find((eintrag) => eintrag.geraet.id === machineId);
  if (!treffer) notFound();

  const { modell, geraet } = treffer;
  const basis = `/portal/${studioId}/einrichten`;

  const aktiverTag = katalog.tags.find(
    (tag) => tag.machineId === machineId && tag.status === "active",
  );
  const ohneVideo = modell.exercises.filter((uebung) => !uebung.hasVideo).length;

  const geliefert = katalog.shipments
    .filter((lieferung) => lieferung.kind === "machine")
    .reduce((summe, lieferung) => summe + lieferung.quantity, 0);
  const vorraetig =
    geliefert - katalog.tags.filter((tag) => tag.kind === "machine").length;

  const zeilen: Array<{ haupt: string; meta: string; faint?: boolean }> = [
    modell.photoPath !== null
      ? { haupt: "Foto steht", meta: `Am Modell ${modell.name}` }
      : {
          haupt: "Kein Foto",
          meta: `Am Modell ${modell.name} · Mitglieder sähen nur den Namen`,
          faint: true,
        },
    modell.settingDefinitions.length > 0
      ? {
          haupt: `${modell.settingDefinitions.length} ${modell.settingDefinitions.length === 1 ? "Einstellparameter" : "Einstellparameter"}`,
          meta: `${modell.settingDefinitions.map((p) => p.label).join(", ")} · ebenfalls am Modell`,
        }
      : {
          haupt: "Keine Einstellparameter",
          meta: "Nutzbar, das Mitglied hat nur nichts einzustellen",
          faint: true,
        },
    aktiverTag
      ? {
          haupt: "Tag verbunden",
          meta: `Charge ${aktiverTag.batchCode} · Nummer ${aktiverTag.batchIndex} · aktiv seit gerade eben`,
        }
      : {
          haupt: "Kein aktiver Tag",
          meta: "Ohne ihn findet kein Mitglied dieses Gerät",
          faint: true,
        },
    {
      haupt: `${modell.exercises.length} ${modell.exercises.length === 1 ? "Übung" : "Übungen"}`,
      meta:
        modell.exercises.length > 0
          ? modell.exercises.map((uebung) => uebung.name).join(", ")
          : "Ohne Übung zeigt das Gerät nichts zum Trainieren",
    },
  ];

  if (ohneVideo > 0) {
    zeilen.push({
      haupt: `${ohneVideo} ${ohneVideo === 1 ? "Übung ohne Video" : "Übungen ohne Video"}`,
      meta: "Nutzbar, nur ohne Anleitung",
      faint: true,
    });
  }

  return (
    <>
      <div>
        <h1 className={styles.titel}>
          {modell.name} {geraet.label} {aktiverTag ? "steht" : "wartet noch"}
        </h1>
        <p className={styles.unterzeile}>
          {aktiverTag
            ? "Für Mitglieder auffindbar"
            : "Ohne Tag für Mitglieder nicht auffindbar"}
        </p>
      </div>

      <section className={styles.abschnitt}>
        <div className={styles.abschnittKopf}>
          <h2 className={styles.label}>Was jetzt gilt</h2>
        </div>
        {zeilen.map((zeile) => (
          <div key={zeile.haupt} className={styles.zeile}>
            <div style={{ minWidth: 0 }}>
              <div className={styles.zeileHaupt}>{zeile.haupt}</div>
              <div
                className={zeile.faint ? styles.zeileMetaFaint : styles.zeileMeta}
              >
                {zeile.meta}
              </div>
            </div>
          </div>
        ))}
      </section>

      {aktiverTag ? null : (
        <Link
          href={`${basis}/geraet/${machineId}/tag`}
          className={styles.neben}
        >
          Tag nachholen
        </Link>
      )}

      <Link href={`${basis}/modell`} className={styles.haupt}>
        Nächstes Gerät
      </Link>
      <Link href={basis} className={styles.neben}>
        Für heute fertig
      </Link>

      <p className={styles.notiz}>
        {vorraetig > 0
          ? `${vorraetig} ${vorraetig === 1 ? "Tag" : "Tags"} noch in der Packung.`
          : "Kein Tag mehr vorrätig. Die eingerichteten Geräte funktionieren weiter; die übrigen warten auf die nächste Lieferung."}
      </p>
    </>
  );
}
```

- [ ] **Schritt 4: Den Rückweg vom Schreibtisch in den Gang legen**

`Modell.dc.html` ist im Bildschirmverzeichnis mit `~` markiert: *„‚Tag scannen' je Geräteinstanz"*. Heute steht dort nichts, was in die Halle führt — ein Trainer, der am Schreibtisch merkt, dass Gerät 13 keinen Tag hat, hat keinen Weg dorthin.

In `apps/web/app/portal/[studioId]/(schreibtisch)/modelle/[modelId]/page.tsx` die Geräteliste um einen Link je Instanz erweitern. Die Zeile findet sich mit:

```bash
grep -n "activeTagCount\|machines.map" "apps/web/app/portal/[studioId]/(schreibtisch)/modelle/[modelId]/page.tsx"
```

In den Aktionsbereich der Gerätezeile, neben „Stilllegen":

```tsx
                  {/* Der Weg in die Halle. Welcher Tag an welchem Geraet
                      haengt, entscheidet der Scan vor dem Geraet -- nicht
                      ein Dropdown am Schreibtisch (Entscheidung 3). */}
                  <Link
                    href={`/portal/${studioId}/einrichten/geraet/${geraet.id}/tag`}
                    className={styles.secondary}
                  >
                    {geraet.activeTagCount > 0 ? "Tag ersetzen" : "Tag scannen"}
                  </Link>
```

`Link` ist auf der Seite bereits importiert; falls nicht, `import Link from "next/link";` ergänzen.

- [ ] **Schritt 5: Tests laufen lassen**

Ausführen: `pnpm typecheck && pnpm test && pnpm test:integration`

Erwartet: PASS.

Ausführen: `pnpm test:e2e -- einrichten trainerportal`

Erwartet: PASS, alle Tests beider Dateien — auch die in den Aufgaben 6 bis 10 wieder eingeschalteten Zusicherungen. `trainerportal.spec.ts` läuft über die geänderte Modellseite und beweist, dass der neue Link dort nichts verschoben hat.

- [ ] **Schritt 6: Committen**

```bash
git add "apps/web/app/portal/[studioId]" e2e/einrichten.spec.ts
git commit -m "feat(web): Abschluss des Gangs, Rueckweg vom Schreibtisch, ganzer Weg als E2E"
```

---

## Aufgabe 13: Einen zerkratzten Tag ersetzen

`TelefonZustaende.dc.html`, Abschnitt *„Am Gerät"*: *„Der Tag an Latzug 12 ist zerkratzt. Kleb einen neuen daneben und scanne ihn — der alte wird dabei ungültig."*

`bind_tag_to_machine` sperrt den alten Tag **nicht** — es bindet nur den neuen. Ohne diese Aufgabe trüge ein Gerät danach zwei aktive Tags: beide funktionieren, keiner ist falsch, aber das Versprechen des Bildschirms wäre gebrochen.

**Der Weg ist die Anwendungsschicht, nicht eine Migration.** Die globale Rahmenbedingung schließt eine Migration aus, und der Fall trägt sie nicht: das Ersetzen ist zweischrittig, und der schlechteste Ausgang eines Abbruchs dazwischen ist *„beide Tags aktiv"* — also genau der Zustand, den es ohne diese Aufgabe immer gäbe. Kein Datenverlust, und ein zweiter Anlauf räumt auf. Das ist der Preis, und er wird hier benannt statt versteckt.

**Dateien:**
- Ändern: `apps/web/app/portal/[studioId]/einrichten/actions.ts`
- Ändern: `apps/web/app/portal/[studioId]/einrichten/geraet/[machineId]/tag/TagSchritt.tsx`
- Ändern: `e2e/einrichten.spec.ts`

**Schnittstellen:**
- Nutzt: `tagVerbinden` (Aufgabe 9), `revokeTag` aus `@fitretro/domain`, `getStudioCatalog`
- Liefert:
  ```ts
  export async function tagErsetzen(
    studioId: string, machineId: string, token: string,
  ): Promise<Ergebnis<{ tagId: string; gesperrt: number }>>;
  ```

- [ ] **Schritt 1: Den fehlschlagenden E2E-Test schreiben**

In `e2e/einrichten.spec.ts` anhängen:

```ts
test("Ein zerkratzter Tag wird ersetzt, und der alte wird dabei ungueltig", async ({
  page,
}) => {
  const { admin, studioId } = await studioMitTrainer(page, "einrichten-ersatz");

  const { data: modell, error: modellFehler } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioId, name: "Latzug", weight_step_kg: 2.5 })
    .select("id")
    .single();
  if (modellFehler) throw modellFehler;

  const { data: geraet, error: geraetFehler } = await admin
    .from("machines")
    .insert({ studio_id: studioId, equipment_model_id: modell.id, label: "12" })
    .select("id")
    .single();
  if (geraetFehler) throw geraetFehler;

  const alt = await tagAnlegen(admin, {
    studioId,
    machineId: geraet.id,
    status: "active",
  });
  const neu = await tagAnlegen(admin, { studioId: null });

  await page.goto(`/portal/${studioId}/einrichten/geraet/${geraet.id}/tag`);
  await page.getByLabel("Token vom Tag").fill(neu.token);
  await page.getByRole("button", { name: "Tag prüfen" }).click();

  // Derselbe freie Tag -- aber die Hauptaktion heisst jetzt Ersetzen.
  await expect(page.getByText("wird dabei ungültig")).toBeVisible();
  await page.getByRole("button", { name: "Ersetzen" }).click();
  await expect(page).toHaveURL(
    new RegExp(`/einrichten/geraet/${geraet.id}/uebungen$`),
  );

  const { data: tags, error: tagFehler } = await admin
    .from("machine_tags")
    .select("token, status, machine_id")
    .in("token", [alt.token, neu.token]);
  if (tagFehler) throw tagFehler;

  const alterTag = tags.find((tag) => tag.token === alt.token)!;
  const neuerTag = tags.find((tag) => tag.token === neu.token)!;

  expect(neuerTag.status).toBe("active");
  expect(neuerTag.machine_id).toBe(geraet.id);
  expect(alterTag.status).toBe("revoked");
  // Sperren, nicht loeschen: machine_id bleibt als Nachweis stehen.
  expect(alterTag.machine_id).toBe(geraet.id);
});
```

- [ ] **Schritt 2: Test laufen lassen und den Fehlschlag sehen**

Ausführen: `pnpm test:e2e -- einrichten`

Erwartet: FAIL — der alte Tag steht noch auf `active`.

- [ ] **Schritt 3: Die Action ergänzen**

In `actions.ts` `getStudioCatalog` und `revokeTag` zum Import hinzufügen und anhängen:

```ts
/**
 * Einen zerkratzten Tag ersetzen: den neuen binden, die uebrigen aktiven
 * desselben Geraets sperren.
 *
 * Zwei Schritte, kein einer. bind_tag_to_machine sperrt nichts, und eine
 * Migration schliesst der Bauabschnitt aus. Der schlechteste Ausgang eines
 * Abbruchs dazwischen ist "beide Tags aktiv" -- also genau der Zustand, der
 * ohne diese Funktion immer eintraete. Kein Datenverlust, und ein zweiter
 * Anlauf raeumt auf.
 *
 * Zuerst binden, dann sperren, nie umgekehrt: waere die Reihenfolge
 * getauscht, stuende das Geraet nach einem Abbruch ganz ohne Tag da und
 * waere fuer Mitglieder verschwunden.
 */
export async function tagErsetzen(
  studioId: string,
  machineId: string,
  token: string,
): Promise<Ergebnis<{ tagId: string; gesperrt: number }>> {
  const gebunden = await tagVerbinden(studioId, machineId, token);
  if (!gebunden.ok) return gebunden;

  const client = await createServerSupabaseClient();
  let gesperrt = 0;
  try {
    const katalog = await getStudioCatalog(client, studioId);
    const alte = katalog.tags.filter(
      (tag) =>
        tag.machineId === machineId &&
        tag.status === "active" &&
        tag.id !== gebunden.tagId,
    );
    for (const tag of alte) {
      await revokeTag(client, tag.id);
      gesperrt += 1;
    }
  } catch (fehler) {
    // Der neue Tag klebt und funktioniert. Dass der alte noch offen ist,
    // faellt beim naechsten Scan auf -- und dann steht dieselbe Aktion da.
    console.error("Alter Tag nicht gesperrt:", fehler);
    return {
      ok: false,
      error:
        "Der neue Tag ist verbunden, der alte ließ sich nicht sperren. Scann den neuen noch einmal.",
    };
  }

  revalidatePath(`/portal/${studioId}/einrichten`);
  return { ok: true, tagId: gebunden.tagId, gesperrt };
}
```

- [ ] **Schritt 4: Den Ersetzen-Knopf verdrahten**

In `TagSchritt.tsx` den Import um `tagErsetzen` erweitern und im `onClick` der Hauptaktion die Verzweigung setzen:

```tsx
            onClick={() => {
              setFehler(null);
              starte(async () => {
                const ergebnis =
                  antwort.hauptaktion === "ersetzen"
                    ? await tagErsetzen(studioId, machineId, token)
                    : await tagVerbinden(studioId, machineId, token);
                if (!ergebnis.ok) {
                  setFehler(ergebnis.error);
                  return;
                }
                router.push(
                  `/portal/${studioId}/einrichten/geraet/${machineId}/uebungen`,
                );
              });
            }}
```

- [ ] **Schritt 5: Tests laufen lassen**

Ausführen: `pnpm test:e2e -- einrichten`

Erwartet: PASS, alle Tests der Datei.

- [ ] **Schritt 6: Den ganzen Bestand laufen lassen**

Ausführen: `pnpm typecheck && pnpm test && pnpm test:integration && pnpm build`

Erwartet: PASS. `pnpm build` ist nicht optional — ein `node:crypto` im Client-Bundle bricht nur dort.

Ausführen: `pnpm test:e2e`

Erwartet: PASS über alle sechs Dateien. `trainerportal.spec.ts`, `leute.spec.ts` und `auth.spec.ts` beweisen, dass die Route-Gruppe aus Aufgabe 5 nichts verschoben hat.

- [ ] **Schritt 7: Committen**

```bash
git add "apps/web/app/portal/[studioId]/einrichten" e2e/einrichten.spec.ts
git commit -m "feat(web): einen zerkratzten Tag ersetzen, der alte wird dabei gesperrt"
```

---

## Abnahme

Der Bauabschnitt ist fertig, wenn alles davon zutrifft:

- [ ] `pnpm typecheck` — keine Fehler
- [ ] `pnpm test` — Unit-Tests in `packages/domain` und `apps/web` grün
- [ ] `pnpm test:integration` — 37 Dateien grün (36 Bestand plus `domain-exercises`)

  > **Bekannter Wackler, nicht aus diesem Bauabschnitt:** `rls-workout-sessions.test.ts > positiv: ein Mitglied beendet seine eigene Session` fällt sporadisch mit `workout_sessions_completed_after_start` (23514). Der Test setzt `completed_at` aus der **Node-Uhr**, während `started_at` per `now()` aus der **Datenbank** kommt; driftet die Containeruhr um Millisekunden nach vorn, liegt das Ende vor dem Anfang. Gemessen am 2. September: zwei von drei Läufen grün, auf unverändertem Stand. Er gehört repariert (das Ende serverseitig setzen), aber nicht in diesem Plan — hier zählt nur, dass er **kein** Neuschaden ist.
- [ ] `pnpm test:e2e` — 6 Dateien grün (5 Bestand plus `einrichten`)
- [ ] `pnpm build` — kein `node:crypto` im Client-Bundle
- [ ] **Der Sucher ist von Hand an einem echten Telefon gelaufen** (Aufgabe 9, Schritt 8) — der einzige Punkt, den kein Test abnimmt
- [ ] `supabase/migrations/` ist unverändert — 31 Dateien, keine neue

Danach `docs/superpowers/plans/2026-09-01-gesamtfahrplan.md` nachziehen, wie es dessen Abschnitt 8 verlangt: die Zeile *„Sucher im Portal"* und *„Einrichtung am Gerät"* in Abschnitt 3 auf ✅, den Bezugsstand in der Kopftabelle, und Phase 3 in Abschnitt 5 als abgeschlossen.

---

## Was dieser Plan offenlässt

Die offenen Punkte aus Spec §7, die er **nicht** entscheidet — sie bleiben dort gültig und gehören nach dem ersten echten Einrichtungsgang beantwortet:

| Punkt | Warum er offen bleibt |
| --- | --- |
| **Druckmaße des QR** (Modulgröße, Fehlerkorrekturstufe) | Der QR ist jetzt der einzige Erfassungsweg des Trainers. Welche Modulgröße auf Armlänge liest, zeigt ein Druck, kein Code. **Blockiert die erste Tag-Bestellung.** |
| **Ist das Abtippen von 22 Zeichen zumutbar?** | Der Rückfallweg steht (Aufgabe 9), aber ob ihn jemand benutzt, zeigt der erste Gang. |
| **Wie viele Einstellparameter sind am Telefon zumutbar?** | Der Entwurf zeigt drei. Bei acht wird Schritt 2 zur Fleißarbeit, und der Trainer überspringt ihn — womit die Sache schlechter dastünde als vorher. |
| **Verdient ein übersprungener Schritt 2 eine eigene Zeile im Überblick?** | Der Einstieg führt Foto und Parameter heute zusammen in „Was noch fehlt". Ob sie dort getrennt gehören, ist eine Frage an den Überblick — und den gibt es noch nicht. |
| **Ein Foto je Modell reicht nicht immer** | Zwei baugleiche Geräte an verschiedenen Wänden zeigen dasselbe Bild. Ein Foto je Gerät wurde erwogen und verworfen (Spalte auf `machines`, Umbau von `getTagContext` und `resolve_tag_fallback`, hundert Aufnahmen statt zwanzig). |
| **Leerer Vorrat mitten in der Halle** | Der Zustand ist gezeichnet und wird angezeigt; einen Bestellweg gibt es im Portal nicht, und ob es einen geben soll, ist eine Betreiberfrage. |

Drei Punkte kommen aus **diesem** Plan dazu:

| Punkt | Herkunft |
| --- | --- |
| **Der Probe-Scan hat keinen Weg an den Token.** `TelefonFertig.dc.html` bietet ihn an, `0026_tag_klartext.sql` verhindert ihn: `authenticated` bekommt die Spalte `machine_tags.token` nicht gewährt, absichtlich. Die Artboards sind älter als diese Entscheidung. Aufzulösen wäre sie durch eine `security definer`-Funktion, die den Token je Gerät herausgibt, oder durch eine Fallback-Seite, die auch über eine Geräte-ID erreichbar ist — beides eine Entwurfsfrage. **Bis dahin fehlt dem Trainer der Blick auf das, was ein Mitglied sieht.** | Aufgabe 12 |
| **Die Warteschlange überlebt kein Neuladen.** Die `File`-Objekte liegen im Speicher des Tabs. Der Bildschirm sagt es (*„Lass diesen Bildschirm offen"*), und TUS setzt bei erneuter Auswahl fort — aber wer die Seite neu lädt, wählt die Dateien noch einmal. Ein echter Puffer wäre IndexedDB und ein eigener Bauabschnitt. | Aufgabe 11 |
| **Das Ersetzen eines Tags ist zweischrittig, nicht atomar.** Bricht es dazwischen ab, trägt das Gerät zwei aktive Tags — kein Datenverlust, und ein zweiter Anlauf räumt auf. Atomar ginge es nur als Migration in `bind_tag_to_machine`, und die schließt der Bauabschnitt aus. | Aufgabe 13 |
