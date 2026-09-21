# Testnotizen im Trainerportal — Umsetzung

**Ziel:** Was die Member-App seit dem 14. September kann, kann jetzt auch das
Portal: Wer am Rechner testet, hält einen Fund mit zwei Klicks fest —
Ausschnitt ziehen oder Element anklicken, Notiz tippen — und bekommt einen
Ordner, den Claude Code ohne Nachfragen abarbeitet. Screenshot, Ausschnitt,
Seite samt Quelldatei, Element samt Kennung, Konsole der letzten Minuten.

**Spec:** `docs/superpowers/specs/2026-09-14-testnotiz-format.md`, Abschnitt
„Web“. Derselbe Ordner, dasselbe `sitzung.md` — nur `platform: "web"`.

**Stand:** 2026-09-21, umgesetzt und im Dev-Server geprüft (Abschnitt
„Geprüft“).

---

## Architektur

Drei Teile, und der mittlere ist der einzige, den es auf iOS nicht gibt.

**Die Oberfläche** (`apps/web/app/testnotiz/`) entspricht dem Overlay-Fenster
der App: ein `position: fixed`-Feld über allem. In Ruhe lässt es jeden Klick
zur Seite durch und zeigt nur den Knopf am rechten Rand; in jedem anderen
Modus fängt es alles — so kann sich die Seite zwischen Foto und Sichern nicht
mehr ändern, genau wie in der App.

**Das Foto** kommt aus der Bildschirmfreigabe des Tabs
(`getDisplayMedia`, `preferCurrentTab`). Eine Seite kann sich nicht selbst
abmalen; der andere Weg wäre, das DOM in ein SVG zu gießen, und der ist bei
Schriften, Filtern und fremden Bildern regelmäßig falsch. Gefragt wird einmal
je Sitzung, der Datenstrom bleibt offen, jedes weitere Foto kostet keinen
Dialog. Für die Aufnahme wird die Oberfläche des Moduls unsichtbar geschaltet
— wie das Overlay-Fenster beim `snapshot` ausgelassen wird.

**Die Ablage** ist der Dev-Server. Der Browser schickt Bild und Werte an
`POST /api/testnotiz`, Node schreibt `apps/web/testnotizen/<sitzung>/`. Der
Zustand steht dabei in der Datei, nicht im Prozess: `sitzung.json` ist die
Wahrheit über Nummer und Anzahl. Ein Neuladen der Seite — im Browser die
Regel — setzt die Sitzung deshalb fort, ein Serverneustart ebenfalls.

### Was das Web leichter kann als iOS

**Die Screen-Erkennung braucht keine Markierung.** In der App meldet ein
Modifier an jeder Screen-Wurzel seine Datei (`#filePath`); 26 Screens tragen
ihn. Im App-Router steht dieselbe Angabe schon im Verzeichnisbaum: eine URL
führt auf genau eine `page.tsx`, die Hüllen darüber sind ihre Ebenen. Der
Server löst den Pfad beim Sichern gegen `apps/web/app/` auf — mit
Klammergruppen, dynamischen Segmenten und Sammelsegmenten — und bekommt
Datei, Ebenen und die Werte der Segmente (`studioId`, `modelId`) geschenkt.
Keine Seite im Portal musste dafür angefasst werden.

**Der Weg zu Claude Code ist keiner.** Die App braucht AirDrop oder ein Kabel;
hier liegt der Ordner schon im Arbeitsverzeichnis. Das Sitzungsblatt zeigt nur
noch den Auftragssatz zum Kopieren.

### Was das Web schlechter kann als iOS

**Datei und Zeile eines Elements.** React 19 führt keine Quellangabe mehr an
den Fasern. Das Modul nimmt deshalb den Namen der Komponente, aus der das
Element stammt (`ProbeKnopf`, `EinstellungRad`), und für server-gerendertes
Markup die Rolle (`button`); Bausteine des Routers (`SegmentViewNode`,
`OuterLayoutRouter` …) zählen nicht als Angabe. Die Fundstelle steht
stattdessen in `screen.file`. Wer eine genaue Zeile braucht, schreibt
`data-testnotiz-datei` und `-zeile` ans Markup.

**Sprachnotizen** gibt es nicht — am Rechner ist das Tippen der kürzere Weg.
`audio` und `transcript` bleiben Teil des Vertrags und stehen auf `null`.

---

## Kein Byte im Release

Das iOS-Modul steht unter `#if DEBUG`. Das Gegenstück hier sind drei Riegel:

1. `TestnotizMontage` hält den Import hinter `process.env.NODE_ENV` —
   ein Zweig, den Webpack beim Übersetzen auflöst. Im Produktionsbau fällt er
   weg, **bevor** der Import gelesen wird; die Oberfläche steht in keinem
   Stück des Bündels. Geprüft mit einer Suche nach ihren Texten in
   `.next/static` und `.next/server`: kein Treffer.
2. `POST /api/testnotiz` antwortet im Produktionsbau mit 404, auch wenn
   jemand die Route von Hand aufruft.
3. `NEXT_PUBLIC_TESTNOTIZ=aus` schaltet es auch im Dev-Server ab, und unter
   Fernsteuerung (`navigator.webdriver`, also Playwright) rendert die
   Oberfläche nichts — sonst finge der Knopf Klicks, die einem Test gehören.

---

## Dateistruktur

### Modul — `apps/web/app/testnotiz/`

| Datei | Verantwortung |
| --- | --- |
| `TestnotizMontage.tsx` | Server-Komponente: die drei Riegel, `angemeldet` als einziger Wert aus der Sitzung |
| `TestnotizOberflaeche.tsx` | Modus, Entwurf, Ablauf vom Klick bis zum Sichern |
| `TestnotizKnopf.tsx` | Kreis am rechten Rand, senkrecht verschiebbar, Höhe gemerkt |
| `TestnotizMenue.tsx` | Ausschnitt, Seite, Element, Nur Notiz, Sitzung |
| `AuswahlOverlay.tsx` | Rechteck ziehen oder Element anklicken |
| `NotizBlatt.tsx` | Vorschau, Textfeld, Sichern (auch ⌘↵) |
| `SitzungBlatt.tsx` | Zähler, Auftrag kopieren, neue Sitzung, Freigabe beenden |
| `bildschirmfoto.ts` | Freigabe, Aufnahme ohne die eigene Oberfläche, Ausschnitt in beiden Maßen |
| `element.ts` | DOM-Knoten → `element` des Formats; Kennung, Beschriftung, Komponentenname |
| `protokoll.ts` | Ring über `console` und unbehandelte Fehler, letzte fünf Minuten |
| `sitzung.ts` | gemerkte Sitzung, Browser- und Gerätewerte, Absenden |
| `testnotiz.module.css` | Gestaltung aus den Tokens des Portals |

### Format und Ablage — `apps/web/lib/testnotiz/`

| Datei | Verantwortung |
| --- | --- |
| `format.ts` | die Werte des Vertrags, `sitzungJson` (eingerückt, sortierte Schlüssel) |
| `zeit.ts` | Zeitstempel mit Offset, Ordnername, Uhrzeiten — ohne Locale |
| `markdown.ts` | `sitzung.md`, Regel für Regel wie `TestnotizMarkdown.swift` |
| `seitendatei.ts` | URL → `page.tsx`, Hüllen und Segmentwerte |
| `ablage.ts` | Ordner anlegen, Nummern vergeben, Dateien schreiben |

### Übriges

| Datei | Änderung |
| --- | --- |
| `apps/web/app/api/testnotiz/route.ts` **(neu)** | der Eingang, nur im Dev-Server |
| `apps/web/app/portal/layout.tsx` **(neu)** | hängt `TestnotizMontage` über das ganze Portal |
| `apps/web/testnotizen/README.md` **(neu)** | der Eingang für Claude Code |
| `.gitignore` | `apps/web/testnotizen/*` außer der README |
| Spec | Abschnitt „Web“ |

---

## Geprüft

- **Einheitentests** (Vitest, 47 neue): Zeitstempel mit Offset,
  `sitzung.md` Regel für Regel, Ordner und Nummernvergabe samt zweier
  gleichzeitiger Einträge, Routenauflösung (Klammergruppe, dynamisch,
  Sammelsegment, `..` führt nicht aus dem Verzeichnis), Element-Angaben
  und der Faser-Weg. `pnpm --filter @fitretro/web test`: 91 grün.
- **Typen und Bau:** `typecheck` grün, `build` grün.
- **Ende zu Ende im Dev-Server**, mit einer Wegwerf-Seite unter `/portal` und
  Chromium mit automatisch erteilter Freigabe: Knopf, Menü, Ausschnitt ziehen,
  Notiz, Sichern; danach Element anklicken und sichern; danach das
  Sitzungsblatt. Ergebnis: zwei Einträge, beide Bilder mit echtem Seiteninhalt
  und **ohne** die Oberfläche des Moduls im Bild, der Ausschnitt genau das
  gezogene Rechteck, `screen.file` die echte `page.tsx` samt vier Hüllen,
  `element.type` der Name der Client-Komponente, die Konsolenzeile im
  Protokoll. Die Wegwerf-Seite ist wieder entfernt.
- **Nicht geprüft**, weil es nur ein Browser am Rechner zeigt: der
  Freigabedialog selbst (Auswahl des Tabs), Safari und Firefox — dort kennt
  `getDisplayMedia` die Option `preferCurrentTab` nicht, der Tab ist also von
  Hand zu wählen (das Modul fällt darauf zurück).

---

## Offen

- **Mehr Kontext je Seite.** `screen.context` trägt heute die Segmente der
  URL und die Abfrage. Ein Haken, mit dem eine Seite eigene Werte meldet
  (offener Dialog, Reiter, gewählte Zeile), wäre die nächste Stufe — die
  Schnittstelle dafür steht schon (`kontext` im Feld `ort`).
- **Android** bleibt wie in der Spec beschrieben offen.
