# Testnotiz-Format — Spec

**Stand:** 2026-09-22. **Version:** `gymodo.testnotiz/1` (iOS), `/2` (Web).
Der Unterschied ist ein einziges Feld, siehe „Versionierung".
**Umsetzung iOS:** `docs/superpowers/plans/2026-09-13-ios-testnotizen.md`.
**Umsetzung Web:** `docs/superpowers/plans/2026-09-21-web-testnotizen.md`
(Trainerportal), fortgeschrieben in `docs/superpowers/plans/2026-09-22-testnotizen-handy.md`
(Handy und Vorschau). Der Abschnitt „Web“ unten nennt die Abweichungen.
**Verbindliches Beispiel:** `apps/ios-member/FitnessMemberTests/Fixtures/testnotiz-beispiel.json`
(entsteht in Aufgabe 2 des Plans; der Test `TestnotizEintragTests` liest es).

## Zweck

Wer die App am Gerät testet, hält Funde fest. Am Ende steht ein Ordner, den
Claude Code ohne Rückfrage abarbeiten kann. Dieser Ordner ist ein Vertrag
zwischen Plattformen: die iOS-App schreibt ihn heute, das Trainerportal im
Dev-Server schreibt ihn genauso, eine spätere Android-App ebenso, und ein
Leser prüft alle mit einem Schema.

## Ordner

```
Testnotizen/
  2026-09-13-1412/          Sitzung: Startzeit yyyy-MM-dd-HHmm, lokale Zeitzone
    sitzung.md              für Menschen und Claude Code; neueste Einträge unten
    sitzung.json            dieselben Einträge als Daten
    01-voll.png             Vollbild zum Zeitpunkt des Knopf-Tipps
    01-ausschnitt.png       nur bei kind = crop
    01-notiz.m4a            nur mit Sprachnotiz (AAC, 44,1 kHz, mono)
    02-voll.png
    …
```

- Startet eine zweite Sitzung in derselben Minute, heißt ihr Ordner
  `2026-09-13-1412-2`, dann `-3`. `session.id` ist immer der Ordnername.
- Dateinamen tragen die zweistellige Eintragsnummer. Alle Pfade in
  `sitzung.json` und `sitzung.md` sind relativ zum Sitzungsordner.
- Nach jedem Eintrag werden `sitzung.json` und `sitzung.md` vollständig neu
  geschrieben. Ein Leser darf jederzeit lesen.

## sitzung.json

Ein Objekt. **Jedes Feld steht immer da.** Was nicht zutrifft, ist `null`,
nie weggelassen. Zeitpunkte sind ISO 8601 mit Offset der Gerätezeitzone
(`2026-09-13T14:12:03+02:00`), ohne Sekundenbruchteile.

| Pfad | Typ | Bedeutung |
| --- | --- | --- |
| `format` | String | `gymodo.testnotiz/1` (iOS, Android) oder `/2` (Web). Leser prüfen den String und lehnen Unbekanntes ab. |
| `platform` | String | `ios`, `android` oder `web` |
| `session.id` | String | Ordnername |
| `session.startedAt` | Zeitpunkt | Anlage des Ordners, also der erste Eintrag |
| `session.app` | Objekt | `bundleId`, `version`, `build`, `configuration` (immer `Debug`) |
| `session.device` | Objekt | `model` (Hardware-Kennung wie `iPhone14,4`, Web: Browser wie `Chrome 143`), `os` (`iOS 26.6.1`, Web: `macOS`), `screen` (`width`, `height` in Punkten bzw. CSS-Pixeln, `scale`) |
| `entries[]` | Array | chronologisch |
| `entries[].id` | UUID | |
| `entries[].index` | Int | 1, 2, 3 … lückenlos, entspricht dem Dateipräfix |
| `entries[].createdAt` | Zeitpunkt | Tipp auf den Knopf, nicht das Sichern |
| `entries[].kind` | String | `crop`, `element` oder `note` |
| `entries[].screen` | Objekt oder `null` | `null`, wenn sich kein Screen gemeldet hat |
| `entries[].screen.name` | String | Dateiname ohne Endung; Web: das Routenmuster (`portal/[studioId]/geraete`), weil dort jede Seite `page.tsx` heißt |
| `entries[].screen.file` | String | Repo-relativer Pfad der Quelldatei |
| `entries[].screen.stack` | String[] | Sichtbare Ebenen von unten nach oben, als Dateipfade. Ein Push ersetzt die unterste Ebene; Sheets und Cover liegen darüber. Das ist **kein** Navigationsverlauf. |
| `entries[].screen.context` | Objekt | String → String, z. B. `machineId`, `exerciseId`, `phase`, `sessionId` |
| `entries[].screenshot` | String oder `null` | Dateiname des Vollbilds. Ab `/2` nullbar: am Handy hängt der Tester sein Bild selbst an, und eine reine Notiz hat keines. In `/1` steht dort immer ein Name. |
| `entries[].crop` | String oder `null` | Dateiname des Ausschnitts |
| `entries[].cropRect` | Objekt oder `null` | `points` und `pixels`, je `x`, `y`, `width`, `height`. Pixel sind nach außen auf ganze Pixel gerundet und aufs Bild beschnitten. |
| `entries[].element` | Objekt oder `null` | nur bei `kind = element`; `null`, wenn unter dem Finger nichts lag |
| `entries[].element.source` | String | `accessibility` (iOS-Accessibility-Baum), `semantics` (Android-Semantics-Baum) oder `dom` (Web) |
| `entries[].element.identifier` | String oder `null` | Kennung im Code (`geraet.satz-sichern`); iOS: `accessibilityIdentifier`, Android: `testTag` |
| `entries[].element.label` | String oder `null` | Was ein Screenreader vorliest |
| `entries[].element.type` | String | Komponente aus dem Code (`PrimaryButton`), sonst die Rolle (`Button`, `Text`, `Adjustable`, `Header`, `Image`, `Link`) |
| `entries[].element.frame` | Objekt | Bildschirmrahmen in Punkten |
| `entries[].element.file`, `.line` | String / Int oder `null` | Fundstelle der Markierung im Code; `null` ohne Markierung |
| `entries[].note` | String oder `null` | getippter Text, getrimmt; leer wird `null` |
| `entries[].audio` | String oder `null` | Dateiname der Sprachnotiz |
| `entries[].transcript` | String oder `null` | nur auf dem Gerät erkannt; kommt Sekunden nach dem Eintrag nachträglich hinzu; `null` ohne On-Device-Modell |
| `entries[].runtime` | Objekt | `online` (Bool), `pendingWrites` (Int), `signedIn` (Bool), `studioId` (String oder `null`) |
| `entries[].log[]` | Array | Protokollzeilen der letzten fünf Minuten: `at`, `level` (`debug`, `info`, `notice`, `error`, `fault`, `undefined`), `category`, `message` |

### Datenschutz

- Kein Feld trägt **automatisch erhobene** E-Mail, Access-Token oder
  Anzeigenamen. `signedIn` und `studioId` genügen. `element.label` und `note`
  geben wieder, was auf dem Bildschirm stand oder der Tester schrieb — tippt
  er auf eine Profilzeile, steht deren Text im Label. Sie fallen deshalb wie
  die Screenshots unter „nie ins Repository“.
- `log` übernimmt nur Kategorien aus einer festen Liste, deren Zeilen
  nachweislich keine Personendaten tragen (iOS: `tag`). Im eigenen Prozess
  schwärzt das System private Werte nicht; die Liste ist deshalb die einzige
  Schranke.
- Die Screenshots zeigen, was auf dem Bildschirm stand. Der Ordner gehört
  deshalb nie ins Repository.

### Beispiel

```json
{
  "format": "gymodo.testnotiz/1",
  "platform": "ios",
  "session": {
    "id": "2026-09-13-1412",
    "startedAt": "2026-09-13T14:12:03+02:00",
    "app": { "bundleId": "de.gymtaro.member", "version": "1.0", "build": "42", "configuration": "Debug" },
    "device": { "model": "iPhone14,4", "os": "iOS 26.6.1", "screen": { "width": 375, "height": 812, "scale": 3 } }
  },
  "entries": [
    {
      "id": "8F0C2A4E-6B1D-4C3A-9E7F-1A2B3C4D5E6F",
      "index": 1,
      "createdAt": "2026-09-13T14:13:41+02:00",
      "kind": "crop",
      "screen": {
        "name": "GeraetView",
        "file": "apps/ios-member/FitnessMember/Screens/Geraet/GeraetView.swift",
        "stack": ["apps/ios-member/FitnessMember/Screens/Geraet/GeraetView.swift"],
        "context": { "machineId": "m_123", "exerciseId": "e_456", "phase": "eingabe" }
      },
      "screenshot": "01-voll.png",
      "crop": "01-ausschnitt.png",
      "cropRect": {
        "points": { "x": 20, "y": 412, "width": 335, "height": 96 },
        "pixels": { "x": 60, "y": 1236, "width": 1005, "height": 288 }
      },
      "element": null,
      "note": "Das Gewicht wird abgeschnitten wenn 100,5",
      "audio": "01-notiz.m4a",
      "transcript": "Das Gewicht wird abgeschnitten wenn hundert komma fünf drinsteht",
      "runtime": { "online": true, "pendingWrites": 0, "signedIn": true, "studioId": "s_789" },
      "log": [
        { "at": "2026-09-13T14:13:02+02:00", "level": "info", "category": "tag", "message": "Tab-Wechsel auf Training wegen offenem Tag-Eingang" }
      ]
    },
    {
      "id": "0B7E9C1D-2F3A-4B5C-8D6E-7F8091A2B3C4",
      "index": 2,
      "createdAt": "2026-09-13T14:15:10+02:00",
      "kind": "element",
      "screen": {
        "name": "UebungWechselnSheet",
        "file": "apps/ios-member/FitnessMember/Screens/Geraet/UebungWechselnSheet.swift",
        "stack": [
          "apps/ios-member/FitnessMember/Screens/Geraet/GeraetView.swift",
          "apps/ios-member/FitnessMember/Screens/Geraet/UebungWechselnSheet.swift"
        ],
        "context": { "machineId": "m_123" }
      },
      "screenshot": "02-voll.png",
      "crop": null,
      "cropRect": null,
      "element": {
        "source": "accessibility",
        "identifier": "geraet.satz-sichern",
        "label": "Satz 2 sichern, 42,5 Kilogramm",
        "type": "Button",
        "frame": { "x": 20, "y": 640, "width": 335, "height": 64 },
        "file": "apps/ios-member/FitnessMember/Screens/Geraet/GeraetView.swift",
        "line": 212
      },
      "note": "Knopf bleibt nach dem Tipp einen Moment grau",
      "audio": null,
      "transcript": null,
      "runtime": { "online": false, "pendingWrites": 2, "signedIn": true, "studioId": null },
      "log": []
    }
  ]
}
```

## sitzung.md

Die Datei, die Claude Code liest. Ein Kopf, dann ein Abschnitt je Eintrag,
Absätze durch Leerzeilen getrennt. Uhrzeiten in der Gerätezeitzone.

```markdown
# Testsitzung 2026-09-13 14:12 — gymodo Member 1.0 (42), iPhone14,4, iOS 26.6.1

## 1 · 14:13 · Ausschnitt · GeraetView

**Screen:** `apps/ios-member/FitnessMember/Screens/Geraet/GeraetView.swift` (exerciseId e_456, machineId m_123, phase eingabe)

**Notiz:** Das Gewicht wird abgeschnitten wenn 100,5

**Gesprochen:** Das Gewicht wird abgeschnitten wenn hundert komma fünf drinsteht ([Audio](01-notiz.m4a))

![Ausschnitt](01-ausschnitt.png)
![Vollbild](01-voll.png)

<details><summary>Protokoll (letzte 5 min, 1 Zeile)</summary>

14:13:02 info tag — Tab-Wechsel auf Training wegen offenem Tag-Eingang

</details>
```

Regeln, die ein Leser voraussetzen darf:

| Teil | Regel |
| --- | --- |
| Überschrift | `## <index> · <HH:mm> · <Ausschnitt/Element/Notiz> · <screen.name oder "unbekannter Screen">` |
| `**Screen:**` | Pfad in Backticks, Kontext nach Schlüssel sortiert in Klammern; ohne Screen: `unbekannt — kein Screen hat sich gemeldet` |
| `**Ebenen:**` | nur bei mehr als einer Ebene, Namen mit ` → ` |
| `**Element:**` | `` `kennung` — „label“, type, `datei:zeile` ``; fehlende Teile entfallen |
| `**Notiz:**` | nur mit Text |
| `**Gesprochen:**` | mit Transkript: `text ([Audio](datei))`; ohne: `Transkript fehlt, Audio liegt bei: [datei](datei)` |
| Bilder | Ausschnitt vor Vollbild |
| Protokoll | nur mit Zeilen, in `<details>`, je Zeile `HH:mm:ss level category — message` |

## Web, seit 2026-09-21

Das Trainerportal schreibt denselben Ordner — nur schreibt ihn niemand auf
einen Server: der Browser sammelt die Einträge und gibt am Ende eine **Zip**
heraus, die entpackt genau diesen Ordner ergibt. Weitergabe per Share-Sheet
(Handy) oder Download (Rechner); der Empfänger entpackt nach
`apps/web/testnotizen/`. Nichts davon berührt eine Datenbank.

Das Modul läuft im **Dev-Server** und in einer **Vercel-Vorschau**
(`NEXT_PUBLIC_VERCEL_ENV=preview`) — damit auch ein Kollege am eigenen Gerät
testen kann. In der Produktionsfassung ist es restlos aus dem Bündel
entfernt.

Dieselben Felder, die Eigenheiten der Plattform:

| Feld | Web |
| --- | --- |
| `format` | `gymodo.testnotiz/2` |
| `platform` | `web` |
| `session.app` | `bundleId` `gymodo.web.portal`; `version` der Git-Zweig der Vorschau (lokal `lokal`), `build` der kurze Commit (lokal `dev`) — so steht im Ordner, welcher Stand getestet wurde; `configuration` `Debug` |
| `session.device` | `model` ist der Browser (`Chrome 143`), `os` die Plattform (`macOS`, `iOS`), `screen` das Sichtfenster in CSS-Pixeln samt `devicePixelRatio` als `scale` |
| `screen.name` | das Routenmuster ohne Klammergruppen: `portal/[studioId]/geraete/[modelId]` |
| `screen.file` | die `page.tsx` der Route, aufgelöst gegen eine zur Bauzeit gelesene Routenkarte — keine Seite trägt eine Markierung |
| `screen.stack` | die Hüllen von außen nach innen, zuletzt die Seite |
| `screen.context` | die aufgelösten dynamischen Segmente plus die Abfrage der URL |
| `element.source` | `dom` |
| `element.identifier` | `data-testnotiz`, sonst `data-testid`, sonst `id` |
| `element.type` | der Name der React-Komponente; bei server-gerendertem Markup die Rolle (`button`, `input[type=number]`) |
| `element.file`, `.line` | `null`, außer das Markup trägt `data-testnotiz-datei` und `-zeile`: React 19 führt keine Quellangabe mehr. Die Fundstelle steht in `screen.file`. |
| `screenshot` | am Rechner das Bild der Tab-Freigabe (`.png`); am Handy der angehängte Screenshot, dessen Endung dem Typ folgt (`.png`, aus der Fotomediathek auch `.jpg`); **`null`**, wenn der Tester keines angehängt hat |
| `cropRect` | `points` in CSS-Pixeln des Sichtfensters, `pixels` im Bild der Freigabe; am Handy gibt es keinen Ausschnitt (zuschneiden macht die Fotos-App) |
| `runtime.pendingWrites` | immer `0` — das Portal schreibt unmittelbar gegen den Server |
| `audio`, `transcript` | immer `null` |
| `log[].category` | `console` (übernommene Konsolenzeile) oder `fehler` (unbehandelter Fehler, `level` `fault`) |

Am Rechner kommt das Foto aus der Bildschirmfreigabe des Tabs
(`getDisplayMedia`), einmal je Sitzung erteilt; die Oberfläche des Moduls ist
für die Aufnahme unsichtbar. Am Handy gibt es diese Schnittstelle nicht —
weder iOS-Safari noch Chrome für Android kennen sie —, dort hängt der Tester
seinen eigenen Screenshot an.

Die Sitzung liegt bis zum Teilen in der IndexedDB des Browsers und übersteht
damit Seitenwechsel, Anmeldung und Neuladen.

**Datenschutz, zusätzlich:** anders als OSLog kennt die Konsole keine
Kategorien, an denen sich Personendaten ausschließen ließen. Was das Portal in
die Konsole schreibt, steht im Ordner. Und eine Vorschau zeigt echte Daten:
die Zip liegt beim Tester und geht nur an den, dem er sie schickt — kein
Server speichert sie. Entpackt gehört sie in den gitignorierten Eingang
`apps/web/testnotizen/`.

## Versionierung

Jede Änderung, die einen bestehenden Leser bricht, zählt `format` hoch
(`/2`). Neue Felder mit `null` als Vorgabe brechen nichts und bleiben bei `/1`,
wenn dieses Dokument und die Beispieldatei sie im selben Commit aufnehmen.
Dasselbe gilt für neue Werte in `platform` und `element.source`: ein Leser
prüft beide gegen die Liste dieses Dokuments, nicht gegen eine eigene.

**`/2` gibt es seit dem 22. September und nur im Web.** Der Grund ist ein
einziges Feld: `screenshot` darf dort `null` sein, weil ein Eintrag am Handy
ohne Bild entstehen kann. Ein Leser, der `/1` strikt prüft, bricht daran —
deshalb die neue Zahl. iOS schreibt unverändert `/1`, und beide Ordner sehen
in `sitzung.md` gleich aus.

## Android, später

Native Android, kein Flutter. Die Kotlin-Fassung erfüllt denselben Vertrag mit
eigenen Bausteinen: ein Compose-Overlay im Activity-Fenster für den Knopf,
`PixelCopy` für das Foto, der Semantics-Baum mit `testTag` und
`testTagsAsResourceId` für Elemente (`source = semantics`), `MediaRecorder` und
`SpeechRecognizer` für die Notiz. Der Ordner liegt unter `getExternalFilesDir`
und kommt per Share-Intent auf den Rechner. Die Beispieldatei oben ist die
Testvorlage.
