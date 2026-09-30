# Testnotizen am Handy — Umsetzung

**Ziel:** Testen, wo das Portal benutzt wird. Der Weg vom 21. September lief
nur im Dev-Server am Rechner; wer am Handy einen Fund hat oder wem ein Kollege
etwas zeigen soll, konnte ihn nicht festhalten. Jetzt läuft das Modul auch in
einer Vercel-Vorschau, und die Sitzung geht als Zip heraus statt in einen
Ordner, den ein Server schreibt.

**Spec:** `docs/superpowers/specs/2026-09-14-testnotiz-format.md`, Abschnitt
„Web“. Der Ordner ist derselbe; die Web-Fassung zählt auf
`gymodo.testnotiz/2`, weil `screenshot` nullbar wurde.

**Stand:** 2026-09-22, umgesetzt und gegen einen Produktionsbau geprüft
(Abschnitt „Geprüft“).

---

## Die drei Entscheidungen

**Bild am Handy: der Tester hängt seinen eigenen Screenshot an.**
`getDisplayMedia` gibt es dort nicht — weder iOS-Safari noch Chrome für
Android kennen die Schnittstelle. Ein DOM-Abbild wäre der einzige
automatische Weg gewesen, hätte aber genau das verfehlt, worum es geht: die
Gerätefotos kommen als fremde Quelle aus dem Storage und wären leer. Der
Screenshot des Betriebssystems ist pixelgenau und kostet zwei Taps. Der
Baustein dafür stand schon im Portal (`DateiKnopf`).

**Alles über Zip, auch lokal.** Ein Weg statt zweier: der Browser sammelt,
am Ende entsteht eine Zip, die entpackt genau den Ordner ergibt. Am Rechner
kostet das einen Schritt mehr als vorher; dafür gibt es keinen zweiten
Mechanismus, der nur in einer Lage funktioniert. Die Zip entsteht ohne
Fremdbibliothek (`lib/testnotiz/zip.ts`, Verfahren „store“).

**Sichtbar in der Vorschau, nie in Produktion.** Vercel meldet die Umgebung
selbst (`NEXT_PUBLIC_VERCEL_ENV`), einzustellen ist nichts.

---

## Was daran heikel war

**Der Riegel gegen die Produktionsfassung ist zerbrechlicher als er aussieht.**
Die erste Fassung fragte `process.env.NEXT_PUBLIC_VERCEL_ENV` im Quelltext ab
— und plötzlich stand das ganze Modul im Produktionsbündel. Grund: Next
ersetzt `process.env.NEXT_PUBLIC_…` nur für Variablen, die beim Bauen
**gesetzt sind**. Eine nicht gesetzte bleibt als Ausdruck stehen, Webpack kann
den Zweig nicht als tot erkennen und behält den Import. Der Schalter heißt
deshalb `__TESTNOTIZ_AN__` und wird in `next.config.mjs` per DefinePlugin
gesetzt — ein Wert, der beim Übersetzen immer feststeht. Dieselbe Falle gilt
für eine Zwischenvariable: die Bedingung muss wörtlich an der Stelle stehen,
an der auch der Import steht.

**Der Knopf war am Handy tot.** Er hing an `pointerup`, weil er sich auch
ziehen lässt. Ein Fingertipp erzeugt aber nicht verlässlich ein `pointerup`
am Knopf — die Handy-Nachbildung im Test hat das gefunden. Jetzt öffnet der
Klick das Menü (der kommt von Maus, Finger und Tastatur gleichermaßen), und
ein vorangegangener Zug unterdrückt ihn.

**Die Screen-Erkennung braucht kein Dateisystem mehr.** Der Verzeichnisbaum
wird zur Bauzeit gelesen (`lib/testnotiz/routenkarte.mjs`) und als Wert ins
Bündel gelegt; die Zuordnung URL → `page.tsx` rechnet danach im Browser
(`lib/testnotiz/seitendatei.ts`, rein und geprüft). **Vorbehalt:**
`next.config.mjs` wird nur beim Start gelesen — eine Route, die während einer
laufenden `next dev`-Sitzung entsteht, steht erst nach einem Neustart in der
Karte.

---

## Dateien

| Datei | Änderung |
| --- | --- |
| `lib/testnotiz/zip.ts` **(neu)** | Zip im Verfahren „store“: Kopfsätze, zentrales Verzeichnis, CRC32 |
| `lib/testnotiz/routenkarte.mjs` **(neu)** | der Verzeichnisbaum, zur Bauzeit gelesen |
| `lib/testnotiz/seitendatei.ts` | nur noch Rechnen auf der Karte, dazu `screenBauen` |
| `lib/testnotiz/format.ts` | `screenshot` nullbar, Kennung `/2` |
| `lib/testnotiz/markdown.ts` | ohne Bild keine Bildzeile |
| `app/testnotiz/speicher.ts` **(neu)** | IndexedDB: Sitzung und Einträge samt Blobs |
| `app/testnotiz/teilen.ts` **(neu)** | Zip bündeln, Share-Sheet oder Download |
| `app/testnotiz/routen.ts` **(neu)** | die eingesetzte Routenkarte |
| `app/testnotiz/TestnotizMontage.tsx` | Schalter `__TESTNOTIZ_AN__` statt `NODE_ENV` allein |
| `app/testnotiz/TestnotizKnopf.tsx` | öffnet per Klick, nicht per Zeiger |
| `app/testnotiz/TestnotizMenue.tsx` | ohne Freigabe: Notiz und Element |
| `app/testnotiz/NotizBlatt.tsx` | „Bild anhängen“ über `DateiKnopf` |
| `app/testnotiz/SitzungBlatt.tsx` | „Sitzung teilen“, Größenwarnung, Auftragssatz |
| `app/testnotiz/TestnotizOberflaeche.tsx` | Sitzung aus der Datenbank statt vom Server |
| `app/testnotiz/sitzung.ts` | Kopfdaten im Browser, Zweig und Commit der Vorschau |
| `next.config.mjs` | Routenkarte und Schalter per DefinePlugin |
| `turbo.json` | die bauzeitrelevanten `NEXT_PUBLIC_*` in `build.env` |
| `app/api/testnotiz/route.ts` **(weg)** | kein Server mehr im Spiel |
| `lib/testnotiz/ablage.ts` **(weg)** | ersetzt durch `speicher.ts` und `teilen.ts` |

---

## Geprüft

- **Einheitentests:** 95 grün, darunter neu der Zip-Schreiber (CRC32 gegen
  bekannte Werte, Versätze über das zentrale Verzeichnis zurückgelesen, UTF-8-
  Namen, leere Sitzung) und die aufgeteilte Routenauflösung samt `screenBauen`.
- **Typen und Bau:** `typecheck` grün, `build` grün.
- **Produktionsfassung ist leer:** nach `next build` ohne Vorschau-Variable
  findet eine Suche nach „Was stimmt hier nicht“, „Sitzung teilen“,
  `testnotiz_wurzel` und `gymodo.web.portal` in `.next/static` und
  `.next/server` **keinen** Treffer; mit `NEXT_PUBLIC_VERCEL_ENV=preview`
  stehen Modul und Routenkarte drin.
- **Ende zu Ende gegen `next start`** (Produktionsbau mit Vorschau-Variable,
  Chromium, Wegwerf-Seite unter `/portal`, danach entfernt):
  - *Rechner:* Freigabe, Ausschnitt ziehen, Notiz, Sichern; **Neuladen**, der
    Zähler am Knopf steht weiter auf 1 (IndexedDB); Teilen → Download → die
    Zip besteht `unzip -t` und enthält `01-voll.png`, `01-ausschnitt.png`,
    `sitzung.json`, `sitzung.md`; `screen.file` ist die echte `page.tsx`, die
    Kopfzeile nennt Zweig und Commit.
  - *Handy* (iPhone-Nachbildung, `getDisplayMedia` entfernt): das Menü zeigt
    „Notiz · Element“, ein angehängtes PNG landet als `01-voll.png` im
    Eintrag, ein zweiter Eintrag ohne Bild trägt `screenshot: null`, und
    `sitzung.md` lässt bei ihm die Bildzeile weg.
- **Nicht geprüft**, weil es nur ein echtes Gerät zeigt: das Share-Sheet
  selbst, die Fotomediathek und der Speicherplatz der IndexedDB auf dem
  Telefon.

---

## Offen

- **Ausschnitt am Handy** gibt es nicht; zuschneiden macht die Fotos-App,
  bevor das Bild angehängt wird.
- **Mehr Kontext je Seite:** `screen.context` trägt die Segmente der URL und
  die Abfrage. Ein Haken, mit dem eine Seite eigene Werte meldet, wäre die
  nächste Stufe — die Schnittstelle dafür steht (`kontext` in `screenBauen`).
