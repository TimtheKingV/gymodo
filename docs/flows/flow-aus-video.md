# Flow aus Video-Link

Anleitung: Wie aus einem Kursvideo ein geführter Follow-along-Flow der Gymtavo-App wird. Geschrieben am echten Beispiel „HIIT 20 Minuten“ (Schlüssel `hiit-20-min`), mitgeschrieben beim Bau am 26. und 27. November 2026. Leser sind Tim und künftige Claude-Sitzungen, die den Weg für den nächsten Flow wiederholen.

**Stand 27.11.2026:** Alles bis einschließlich Katalog, Videos, Flow-Datei und Kamera-Prüfung am Mac ist gebaut und im Zweig `claude/flow-kamera` committet. **Nichts davon liegt auf Supabase-Prod, der Gerätetest am iPhone steht aus** (Abschnitte 8 und 9). Diese Anleitung wird nach dem Gerätetest um dessen Ergebnis ergänzt.

Begriffe, die unten vorkommen:

- **Flow:** eine feste Folge von Schritten mit Arbeitszeit und Pause, die die App per Uhr führt (HIIT 20 Minuten: 20 Schritte, je 40 s Arbeit, 20 s Pause, drei davon Warm-up).
- **Katalog:** die Übungsliste der App in `catalog/gymtavo.json`. Jede Übung hat einen Schlüssel (`catalog_key`, z. B. `bw_pushup`), Name, Beschreibung, Muskeln, optional ein Video.
- **Loop:** das kurze Übungsvideo (3 bis 8 s, 640×640, Endlosschleife), das in der App läuft.
- **Kamera oder Uhr:** Bei einem Kamera-Schritt zählt die App die Wiederholungen über das Kamerabild des Handys. Bei einem Uhr-Schritt zählt nur die Zeit.
- **Prod:** die echte Supabase-Datenbank, die die Mitglieder benutzen.

Alle Befehle laufen aus dem Wurzelordner des Repos (bzw. des Worktrees), sofern nichts anderes dabeisteht.

## Die wichtigste Lehre vorweg

**Eine klare Bewegung je Schritt.** Tim hat das am 27.11.2026 entschieden, nachdem Videos und Kamera-Prüfung zeigten, wie viel Mühe zusammengesetzte Übungen machen. Übungen mit mehreren Teilbewegungen (rechts, links, Mitte; Sprung mit Berührung und Drehung) sind schwer zu filmen, schwer mit der Kamera zu zählen und für Nutzer schwer zu erfassen. Solche Übungen werden vor dem Anlegen gegen einfache getauscht oder aufgeteilt, also schon beim Abgleich mit dem Katalog (Abschnitt 3), nicht erst, wenn Videos und Zählung scheitern. Der Burpee bleibt trotz seiner Teilbewegungen, weil Tim ihn ausdrücklich wollte.

Die zweite Lehre: **erst im Katalog nachsehen, dann neu anlegen.** Drei der fünf Ersatzübungen gab es schon, samt Video und Kamera-Zuordnung, und zählten sofort.

## Überblick: der Weg in neun Schritten

| # | Schritt | Wo | Kostet Geld? |
|---|---|---|---|
| 1 | Link, Transkript | `pnpm flow:transkript` | nein |
| 2 | Entwurf, unsichere Schritte | `tools/flow-import/flows/<flow>.json` | nein |
| 3 | Abgleich mit dem Katalog, Übungen vereinfachen | `catalog/gymtavo.json` durchsuchen | nein |
| 4 | Neue Katalogübungen anlegen | `catalog/gymtavo.json`, Liste für Tim | nein |
| 5 | Videos | Videoserie außerhalb des Repos, OpenRouter | ja |
| 6 | Kamera oder Uhr je Schritt | `data/koerperbild/flow-zuordnung.json` | nein |
| 7 | `uebung` in der Flow-Datei, `flow:sql` | `tools/flow-import` | nein |
| 8 | Einspielen auf Prod mit Freigaben | Supabase, Vercel | nein, aber Tims Ja je Schritt |
| 9 | Probe in der App | iPhone | nein |

## 1. Link und Transkript

Ausgangspunkt ist der Link zu einem Kursvideo auf YouTube. Das Transkript (die Untertitel) liefert die Struktur: welche Übungen, in welcher Reihenfolge, wie lange.

```bash
pnpm flow:transkript <youtube-url> <ausgabeordner>
```

Das Skript (`tools/flow-import/transkript.ts`) ruft `yt-dlp` auf, holt die deutschen Untertitel (`--sub-langs "de.*"`, automatische und echte) und schreibt `transkript.txt` in den Ausgabeordner, eine Zeile je Untertitel im Format `m:ss Text`. Voraussetzung: `yt-dlp` ist installiert.

- Es gibt nur einen Versuch. Antwortet YouTube mit HTTP 429 (zu viele Anfragen), bricht das Skript mit einer klaren Meldung ab. Dann später erneut starten, nicht in einer Schleife.
- Den Ausgabeordner nicht ins Repo legen (Transkripte gehören dem Trainer, siehe die Regel unten).

**Regel zur Quelle:** Übernommen wird nur die abstrakte Struktur (welche Übung, wie lange, welche Reihenfolge). Keine Texte, Namen, Bilder oder Videos des Trainers. Die Quelle (Link und Kanalname) steht in der Flow-Datei unter `quelle`, damit man die Herkunft nachweisen kann. Die App zeigt sie nicht an, und in Dokumenten wie diesem sagt man „das Kursvideo“.

Beim HIIT-Flow: 20 Intervalle zu 40 s Arbeit und 20 s Pause, davon drei Warm-up-Schritte.

## 2. Entwurf und unsichere Schritte

Aus dem Transkript schreibt Claude den Entwurf als Flow-Datei, `tools/flow-import/flows/<key>.json`. Vorbild ist `tools/flow-import/flows/hiit-20-min.json`. Jeder Schritt hat:

| Feld | Bedeutung |
|---|---|
| `name` | Name des Schritts in der App |
| `beschreibung` | eigene, kurze Formulierung (nie vom Trainer übernommen) |
| `workS`, `restS` | Arbeits- und Pausenzeit in Sekunden |
| `istWarmup` | `true` bei Warm-up-Schritten |
| `unsicher` | optional; `true`, wenn der Name aus dem Transkript nicht sicher ist |
| `uebung` | Katalogschlüssel der Übung (Abschnitt 7) |

Die Datei prüft `pruefeFlowEntwurf` (`tools/flow-import/entwurf.ts`) hart: lieber ein klarer Fehler als ein kaputter Flow in der Datenbank.

**Unsichere Schritte:** Automatische Untertitel zerlegen Übungsnamen. Zweifelhafte Schritte bekommen `unsicher: true`. `flow:sql` weigert sich, SQL für einen Flow zu erzeugen, in dem noch ein Schritt `unsicher` ist. Geklärt werden sie über das Intervall-Overlay im Video („Round 7“) oder über Einzelbilder aus dem Video (mit `ffmpeg`); am Ende bestätigt Tim den Namen, dann wird das Flag entfernt. Beim HIIT-Flow waren es Squat-Pulse und der Weitsprung mit Bodenberührung. Die Befehle für die Einzelbilder liegen nicht im Repo; sie wurden beim ersten Flow von Hand abgesetzt und sind hier nicht belegt.

## 3. Abgleich mit dem Katalog

Hier entscheidet sich, wie viel Arbeit der Flow macht. Für jeden Schritt gilt: **erst suchen, dann neu anlegen, und vorher prüfen, ob die Übung einfach genug ist.**

### 3.1 Suchen

Ein Schlüsselwort gegen Name und Schlüssel, mit Video und Kamera-Zuordnung in einer Zeile (am Repo geprüft; Beispiel „Ausfallschritt“):

```bash
node -e '
const k=require("./catalog/gymtavo.json"), z=require("./data/koerperbild/zuordnung.json");
const q=/lunge|ausfall/i;
for(const e of k.exercises) if(q.test(e.name)||q.test(e.key))
  console.log(e.key,"|",e.name,"|video:",e.video?"ja":"nein","|zuordnung:",z[e.key]?z[e.key].kamera.profil+"/"+z[e.key].kamera.signal:"-");
'
```

Suchbegriffe mehrsprachig und breit wählen (deutsch und englisch, Teilwörter: `kick`, `burpee`, `jack`, `crunch`, `plank`). Körpergewichtsübungen haben den Schlüssel `bw_*` und hängen am Gerätetyp `bodyweight`. Außerdem `bw_*` in `catalog/gymtavo.json` direkt ansehen: dort stehen auch die Namensvarianten.

Zwei Fallen:

- **Namen sind nicht eindeutig.** „Ausfallschritt – rückwärts“ kommt im Katalog viermal vor (`bb_`, `bw_`, `db_`, `kb_reverse_lunge`, je für Langhantel, Körpergewicht, Kurzhantel, Kettlebell). Das hat später echten Ärger gemacht (Abschnitt 6.5). Beim Anlegen neuer Übungen darauf achten, dass der Name im ganzen Katalog nur einmal vorkommt, und beim Wiederverwenden den **Schlüssel** nehmen, nie den Namen.
- Ein Eintrag in `data/koerperbild/zuordnung.json` sagt nur, dass es einen Zuordnungsvorschlag für die Kamera gibt. Was am Ende zählt, entscheidet die Prüfung am Video (Abschnitt 6).

### 3.2 Wann „gleiche Übung“, wann neu

- **Gleiche Übung, nimm die vorhandene:** gleiche Bewegung, gleiche Zählweise (Wiederholungen oder Sekunden). Namen dürfen abweichen; der Flow-Schritt behält seinen eigenen Namen, die Übung ihren.
- **Eigene neue Übung:** wenn sich Bewegung oder Zählweise unterscheiden. Beispiele aus dem HIIT-Flow: „Crunch-Halten“ (Sekunden) gegen „Crunch“ (Wiederholungen); „Kniebeuge mit Bodenberührung“ gegen „Kniebeuge“ (zusätzlich beide Hände zum Boden). Solche Nähe immer in der Liste für Tim ausweisen (Abschnitt 4).
- **Plank mit Knie zur Brust** wurde nicht neu angelegt, sondern nutzt `bw_mountain_climber` (zählt im Katalog Sekunden).

### 3.3 Ist diese Übung einfach genug?

Das gehört in diesen Schritt, vor das Anlegen. Eine Übung ist für einen Flow-Schritt geeignet, wenn alle Fragen mit Ja zu beantworten sind:

1. **Eine Bewegung:** Besteht der Schritt aus genau einer Bewegung, die sich wiederholt? Nicht „rechts, links, Mitte“, nicht „Sprung, Berührung, Drehung“.
2. **Eine Seite oder beide gleich:** Kommt es nicht auf die Reihenfolge der Seiten an?
3. **Ein Standbild pro Umkehrpunkt:** Lässt sich der tiefste und der höchste Punkt in einem Bild zeigen?
4. **Am Platz:** Bleibt die Person an derselben Stelle (kein Weitsprung, kein Wegspringen aus dem Bild)?
5. **Kein winziger Hub:** Ist die Bewegung groß genug, dass ein Videomodell und die Kamera sie sehen (kein Flattern, kein „ein wenig“)?
6. **Ein Blickwinkel:** Ist die Bewegung aus einer Richtung (meist von der Seite) zu sehen, ohne dass Gelenke verdeckt sind?

Eine Übung, die an 1 oder 2 scheitert, wird getauscht oder aufgeteilt. Scheitert sie an 3 bis 6, wird es mit Video oder Kamera schwierig (Abschnitte 5 und 6); dann ist ein Tausch ebenfalls die bessere Wahl, oder der Schritt läuft bewusst auf der Uhr.

### 3.4 Die fünf Tausche beim HIIT-Flow (27.11.2026)

Ursprünglich war der Flow am Transkript entlang gebaut. Nach den Videos und der Kamera-Prüfung hat Tim entschieden: eine Bewegung je Schritt. Fünf Schritte wurden getauscht, der Rest blieb (20 Schritte, 40 s Arbeit, 20 s Pause, drei Warm-up):

| # | Vorher | Problem | Jetzt | Name im Flow | Woher die Übung |
|---|---|---|---|---|---|
| 4 | Toe Touches + Jackknifes (`bw_toe_touch_jackknife`) | zwei Bewegungen im Wechsel, links/rechts/Mitte; das Videomodell bekam die Reihenfolge in drei Anläufen nicht hin | Klappmesser (`bw_v_up`) | Klappmesser | vorhanden, ohne Video; Video neu |
| 9 | Swimmer (`bw_swimmer`) | Arm und Gegenbein im Wechsel in Bauchlage; Video in drei Anläufen falsch | Rückenstrecken – liegend (`bw_back_extension_floor`) | Rückenstrecken | vorhanden, mit Video; zählt mit Kamera |
| 11 | Lunge + Kick (`bw_lunge_kick`) | Ausfallschritt und Kick in einem | Ausfallschritt – rückwärts (`bw_reverse_lunge`) | Ausfallschritt rückwärts | vorhanden, mit Video; zählt mit Kamera |
| 13 | Leg Drop & Pull (`bw_leg_drop_pull`) | mehrteilige Beinbewegung am Boden; die Kamera erkennt die liegende Figur kaum | Beinheben – liegend (`bw_leg_raise_lying`) | Beinheben | vorhanden, mit Video; zählt mit Kamera |
| 14 | Weitsprung mit Bodenberührung (`bw_broad_jump_touch`) | Ortswechsel, Berührung, Rückkehr; Video springt an der Schleifennaht | Strecksprung (`bw_squat_jump`) | Strecksprung | neu angelegt; Video neu |

Drei der fünf Ersatzübungen (9, 11, 13) waren im Katalog schon vorhanden und zählten bei der Prüfung sofort. Bei den zwei anderen musste ein Video her (Schritt 4 wurde mit dem Klappmesser wieder zum Uhr-Schritt, Abschnitt 6).

Die drei ausgetauschten Übungen `bw_lunge_kick`, `bw_leg_drop_pull` und `bw_broad_jump_touch` sind bereits angelegt und haben Videos. Sie bleiben als normale Körpergewichtsübungen im Katalog, sind aber nicht mehr im Flow. `bw_toe_touch_jackknife` und `bw_swimmer` wurden wieder aus dem Katalog genommen (sie hatten kein Video).

## 4. Neue Katalogübungen anlegen

Neue Übungen kommen in `catalog/gymtavo.json` in die Liste `bodyweight`. Alle Pflichtfelder laut Katalogformat (`packages/domain/src/katalog-datei.ts`); als Vorlage dienen die vorhandenen `bw_*`-Einträge:

- `key` (`bw_…`, nur `a-z`, `0-9`, `_`), `name`, `description` (Einstellen, Bewegung, Achte auf; eigene Worte), `volume_kind`, Zielbereich, `muscles` (primär und sekundär), `grip`, `review: "draft"`, `sources: []`.
- `volume_kind`: `seconds` für Halteübungen und Flattern, sonst `reps`.
- **`video: null`** ist ein Pflichtfeld. Fehlt das Feld ganz, besteht die Katalogprüfung nicht (`video: fehlt`). Das Feld `video` wird später vom Einspielskript gesetzt (Abschnitt 5.7).
- Kein `plan`-Block: Dann tauchen die Übungen in keinem Trainingsplan auf. Kein `kamera`: Der Katalog darf noch keine Kameraprofile ausliefern (`FREIGESCHALTETE_PROFILE` in `packages/domain/src/kamera.ts` enthält nur `ohne_kamera`).
- **Sichtbarkeit:** Die neuen Übungen hängen am Gerätetyp `bodyweight` und erscheinen damit in jedem Studio im Freien Training unter „Körpergewicht“. Ein Ausblend-Merkmal gibt es nicht (Tim, 26.11.).

Prüfen, dass der Katalog stimmt:

```bash
pnpm --filter @fitretro/domain test
```

Das läuft unter anderem die Katalogprüfung und die Tests zur Kamera-Zuordnung. Zwei bestehende Tests kennen die Flow-Übungen ausdrücklich (`gymtavo-katalog.test.ts` zählt die Körpergewichtsübungen und weiß, welche bewusst ohne `plan` sind; `kamera-zuordnung.test.ts` nimmt die Wiederholungsübungen des Flows von der Pflicht aus, in `zuordnung.json` zu stehen). Wer neue Flow-Übungen anlegt, muss diese Zählungen mitziehen.

**Liste für Tim:** Bevor irgendetwas Geld kostet oder auf Prod geht, bekommt Tim die Liste der Übungen zur Durchsicht: Name, Schlüssel, neu oder vorhanden, Zählung, die Fälle, in denen eine neue Übung einer vorhandenen nah ist. Beim HIIT-Flow ist das `docs/flows/hiit-20-min-uebungen.md`. Tim hat die Liste am 27.11.2026 mit „Liste passt“ freigegeben. Namenswünsche gehen dann nur noch in Katalog und Flow-Datei, solange noch keine Videos existieren; danach kosten sie Nacharbeit.

**Stand HIIT-Flow:** 14 Übungen sind neu im Katalog (Master hatte 260, der Zweig hat 274). Davon kommen 11 im Flow vor, 3 sind aus dem Flow wieder herausgefallen (siehe 3.4). Der Flow hat 20 Schritte mit 19 verschiedenen Übungen (Burpee in Schritt 2 und 6); 8 davon gab es schon. Tims Entscheidung am 27.11.: `bw_burpee_slow` heißt nur „Burpee“ (der Schlüssel blieb), `bw_burpee_thigh_tap` entfällt, Schritt 6 nutzt dieselbe Übung.

## 5. Videos

Die Übungsvideos entstehen in einer eigenen Serie **außerhalb des Repos**: `~/Documents/gymtavo/3D-Animationen/ki-video-serie/` (kein Git). Dort liegen `beschreiben.py`, `serie.py`, `loop.py`, `pruefen.py`, `uebungen.json` (Beschreibung je Übung), `pakete.json` (Gruppen für die Prüfung), `stand.json` (Zustand je Übung, Anlaufzähler), `kosten.json` (Kostenbuch) und `progress.md` (Protokoll). Erzeugt wird über OpenRouter mit zwei Modellen: ein Bildmodell (Startbild) und `heygen/heygen-video-1` (Video). Der Schlüssel liegt in `~/Documents/gymtavo/3D-Animationen/.env` und wird nie ausgegeben oder irgendwohin kopiert.

Der Look ist fest: graphitgraue Figur ohne Gesicht, schwarzes Shirt mit „G.“, helles Studio. Die Bodenübungen nutzen eine Matte.

### 5.1 Kosten

Echte Zahlen vom 27.11.2026:

| Posten | Kosten |
|---|---|
| Startbild (Bild) | ca. 0,04 $ (Mittelwert 0,043 $) |
| Video 5 s (Hin-und-zurück) | ca. 0,05 $ |
| Video 8 s (ganzer Ablauf, Loop-Art `ganz`) | ca. 0,08 $ |
| Seitenwechsel (`wechsel`: zwei 5-s-Clips) | ca. 0,10 $ |
| Schreiben der Beschreibungen mit dem Sprachmodell | rund 1,2 $ je Durchgang; beim HIIT-Flow von Hand geschrieben, also 0 $ |
| Erste Runde, 19 Übungen | 2,57 $ (im Schnitt 0,135 $ je Übung) |
| Nachzüge nach Tims erster Abnahme | 0,64 $ |
| Letzte Anläufe Swimmer und Toe Touch | 0,34 $ |
| Klappmesser (aus vorhandenem Clip) und Strecksprung | 0,22 $ |
| **Runde gesamt** | **3,77 $ bei einer Grenze von 5 $** |

Schon geplant war ein erwarteter Bereich von 4 bis 6 $ (Spec: 10 $ als Obergrenze). Schlimmster Fall mit drei Anläufen je Übung wären rund 7 $ gewesen.

### 5.2 Vorher: Guthaben, Grenze, Halt

- **Guthaben bei OpenRouter prüfen, bevor etwas läuft.** Beim HIIT-Flow lag es zu Beginn bei 5,61 $, also unter der 10-$-Schwelle des Plans; nach der Runde waren es 1,89 $. Das war knapp. Vor dem Start laden oder die Grenze bewusst niedriger setzen (Tim hat am 27.11. „Ja, bis 5 $“ entschieden).
- **Budget-Halt im Skript:** `ki-video-serie/api.py` führt das Kostenbuch und bricht jeden bezahlten Aufruf ab, sobald die Summe den Halt erreicht (`Kosten(…, halt=…)`, Zeile `KOSTEN = …`). Für die Runde wurde der Halt von 32,40 $ auf 36,35 $ gesetzt (Rundenbeginn 32,05 $ plus 5 $ minus 0,70 $ Puffer, weil acht Aufrufe parallel laufen). Dieser Wert gilt nur für diese Runde; für die nächste Runde neu setzen, sonst stoppt entweder zu früh oder gar nicht.
- Ein bezahltes Video kann bei einem Netzfehler während des Wartens ungebucht verloren gehen; das Kostenbuch zählt dann etwas zu wenig (0,05 bis 0,08 $ je Fall, bekannt und nicht behoben).

### 5.3 Beschreibung je Übung

In `uebungen.json` bekommt jede Übung einen Eintrag mit diesen Feldern: `geraete` (z. B. `["matte"]`), `szene` (Ausgangslage), `kamera` (Blickwinkel), `bewegung`, `langsam` (die langsame Phase), `pruefpunkte` (3 bis 5 prüfbare Fakten zum Startbild) und `ende` (Endlage). Optional `ohne_logo` (Abschnitt 5.6) und für abwechselnde Übungen `bewegung_b`. Die Texte sind eigene, neutrale Formulierungen. Eingabeprüfung: `beschreiben.pruefe_eintrag`.

Die Loop-Art folgt aus der Übung:

| Art | Wann | Beispiel |
|---|---|---|
| Hin-und-zurück | eine wiederholbare Bewegung | Jumping Jack, Kniebeuge mit Bodenberührung |
| `wechsel` | zwei Seiten abwechselnd; zwei 5-s-Clips aus demselben Startbild | Russian Twist, Skater Jump (frontal, die zweite Seite gespiegelt) |
| `ganz` | ein Ablauf aus mehreren Phasen, 8-s-Clip | Burpee |

**Beim nächsten Mal:** Je einfacher die Übung (Abschnitt 3.3), desto öfter reicht Hin-und-zurück und desto billiger wird es.

### 5.4 Erzeugen und prüfen (Reihenfolge)

Die Befehle laufen im Ordner `ki-video-serie`. Sie sind hier aus den Skripten und dem Protokoll belegt (`serie.py`, `pruefen.py`):

```bash
cd ~/Documents/gymtavo/3D-Animationen/ki-video-serie

# 1. Nur Startbilder erzeugen (billig, ca. 0,04 $ je Bild)
python3 serie.py start <key> <key> ...
# 2. Startbilder groß ansehen und gegen die Prüfpunkte halten
python3 pruefen.py starts <name> <key> ...
# 3. Erst wenn die Startbilder stimmen: Video und Loop erzeugen
python3 serie.py erzeuge <key> <key> ...
# 4. Umkehrbild und Endlage groß prüfen
python3 pruefen.py paare <name> <key> ...
# 5. Prüfseite für Tim bauen und öffnen
python3 -c "import json,pruefen; k=json.load(open('<pfad-zum-katalog>/catalog/gymtavo.json')); print(pruefen.seite(11, pruefen.pakete()[10], {u['key']: u['name']+' · Körpergewicht' for u in k['exercises']}))"
open seiten/paket-11.html
```

Bei Schritt 5 steht `11` für die Nummer des Pakets (beim HIIT-Flow das elfte); `<pfad-zum-katalog>` ist der Worktree mit dem aktuellen Katalog. Dieser Umweg ist nötig, weil `pruefen.py seite` die Namen aus der Katalogkopie der Serie liest, und die kennt neue Übungen nicht und nur Wiederholungsübungen. Weitere nützliche Aufrufe: `python3 pruefen.py stand` (Zustand je Übung und Kosten gesamt), `python3 serie.py neu <key> "Notiz"` (neuen Anlauf vorbereiten), `python3 serie.py ok <key> ...` (nach Tims Abnahme auf ok setzen).

**Ablauf:** zuerst alle Startbilder erzeugen und groß prüfen, dann die Videos. Ein Fehler im Startbild kostet 0,04 $, im Video 0,09 $ oder mehr, und ein Sprachmodell-Durchgang gar 1,2 $.

### 5.5 Abnahme: nur Tim, und nur über die Prüfseite

**Claude sieht Videos nur als Standbilder** (Kontaktbögen und Umkehrbilder). Ob eine Bewegung stimmt, sagt Standbild-Prüfung nur halb: Seitenwechsel, Tempo, Ruck an der Schleifennaht sieht man nicht. Deshalb nimmt **ausschließlich Tim** die Bewegung auf der Prüfseite `seiten/paket-<n>.html` ab. Er sagt je Video, ob es stimmt, ob es schneller laufen soll oder was falsch ist. Claude nennt in der Rückmeldung an Tim zusätzlich seine eigene Standbildprüfung und was darin unsicher war.

Nach Tims erster Abnahme am 27.11.2026: 8 Videos ok, 3 „15 % schneller“, 8 neu, eines gestrichen. Nach der zweiten: alle ok bis auf Swimmer und Toe Touch.

### 5.6 Typische Fehler und was sie kosten

| Fehler | Beobachtet bei | Was hilft |
|---|---|---|
| **Seitenungleiche Bewegung im Liegen** (Hand zum gegenüberliegenden Fuß) wird symmetrisch | Toe Touch: beide Hände zu beiden Füßen statt über Kreuz, in drei Anläufen | Übung tauschen (Abschnitt 3.3) oder ohne Video planen. Spiegeln hilft nur, wenn der Grundclip schon stimmt. |
| **Kleine Gegenbewegung in Bauchlage** (Arm und Gegenbein „ein wenig“) wird übergroß oder gleichseitig | Swimmer: Bein fast senkrecht, Arm derselben Seite | wie oben |
| **Sehr kleiner Hub** wird zur vollen Wiederholung | Squat-Pulse: die Figur richtet sich halb auf statt klein zu federn; alle drei Anläufe verbraucht | Schritt als Uhr führen oder anderes Video in Kauf nehmen |
| **Ortswechsel** ohne Rückkehr zum Startplatz | Weitsprung: Figur springt an der Schleifennaht | Sprung am Platz wählen (Strecksprung) |
| **Zu große Figur, Hände über dem Bildrand** | Strecksprung: im ersten Anlauf | Bewegung begrenzen, z. B. Armschwung nur bis Schulterhöhe |
| **Figur dreht sich zur Kamera** wegen des Logo-Satzes im Prompt | Bauch- und Rückenlage | `ohne_logo` im Eintrag von Anfang an für Bodenübungen setzen |
| **Phasen gleicher Größe** werden nach der ersten abgeschnitten | Toe Touch links/rechts/Mitte in Loop-Art `ganz` | Zahl der Ausschläge einstellbar machen oder von Hand bauen (so beim Toe-Touch-Loop geschehen, das war ein einmaliger Eingriff) |
| **Abwechselnde Sprünge** | Skater Jump | Hin-und-zurück zwischen den zwei Landelagen ergibt den Wechsel ohne Zwischenschritt |
| **Platzierung im Bild** („am linken Rand“) wird ignoriert | Startbild | ausdrücklich dazuschreiben, dass der Rest des Bildes leer bleibt |
| **Kontaktbogen von `pruefen.py`** zeigt nur die ersten 5 s | Loop-Art `ganz` (8 s) | eigenen Streifen über die ganze Länge bauen |

Ein Bildmodell verkleinert die Figur kaum, auch wenn der Text es verlangt; Sprünge brauchen deshalb Spielraum im Bild.

### 5.7 Tricks ohne Kosten

- **Schneller abspielen:** Wirkt das Video zu langsam (Tim: „15 % schneller“), wird es mit `ffmpeg` beschleunigt, ohne neuen Aufruf: Filter `setpts=PTS/1.15`. Format danach unverändert (640×640, 24 Bilder/s, h264, yuv420p). Das Original bleibt in `alt-hiit/`. Beim HIIT-Flow betraf das High Kicks, Burpee, Jumping Jack. Der genaue Befehl steht nicht im Protokoll, nur der Filter; der Rest ist hier nicht belegt.
- **Standbild für Halteübungen:** Plank hält nur. Ein Clip hat dann keinen Umkehrpunkt und bricht mit `KeinUmkehrpunkt` ab. Besser: ein ruhender Loop (4 s) aus dem Umkehrbild des Rohclips, kostet nichts und ist sauberer.
- **Halteübungen bekommen sonst eine Bewegung in die Haltung hinein** (Hochkommen, Halten, Ablegen), Flatterübungen zwei Gegenlagen (Start in der einen, Umkehr in der anderen).
- **Eine Aufnahme aus dem Rohmaterial wiederverwenden:** Das Klappmesser-Video ist aus einem Clip eines früheren Toe-Touch-Anlaufs gebaut (kein neuer Aufruf).

### 5.8 Maximal drei Anläufe

Höchstens drei Anläufe je Übung (`MAX_ANLAEUFE = 3` in `serie.py`; jeder Anlauf nutzt einen eigenen Startwert, damit sich gleiche Fehler nicht wiederholen). Was dann nicht passt, bleibt ohne Video, und der Schritt zeigt in der App den Ring wie ohne Verweis. Beim HIIT-Flow gingen Swimmer und Toe Touch durch alle drei Anläufe, ohne dass es stimmte; beides ist inzwischen aus dem Flow getauscht.

### 5.9 In den Katalog übernehmen

Die fertigen Loops aus `ki-video-serie/loops/` haben schon das Katalogformat (kein Umrechnen, byte-gleich kopiert). Ein Skript im Repo prüft und trägt sie ein:

```bash
pnpm catalog:videos <ordner-mit-den-mp4>              # nur Bericht, schreibt nichts
pnpm catalog:videos <ordner-mit-den-mp4> --ja         # schreibt nach catalog/media/videos/ und setzt `video`
pnpm catalog:videos <ordner-mit-den-mp4> --auch-zeit        # Bericht, auch Übungen mit Sekunden
pnpm catalog:videos <ordner-mit-den-mp4> --auch-zeit --ja   # schreibt, auch Übungen mit Sekunden
```

Der Dateiname ist `<key>.mp4`. Das Skript prüft 640×640 und keine Tonspur per `ffprobe`. Ohne `--auch-zeit` lehnt es Übungen mit Zeitvorgabe ab (`--auch-zeit` ist beim HIIT-Flow neu dazugekommen, sechs Übungen brauchten es). Geschrieben wird nur mit `--ja`, auch zusammen mit `--auch-zeit`. Danach `pnpm --filter @fitretro/domain test`, denn die Katalog- und Medienprüfung schaut nach den Dateien.

Ergebnis HIIT-Flow: 18 neue Videodateien im Katalog (14 neue Übungen plus Plank, Russian Twist, Mountain Climber, Klappmesser), alle 2 bis 8 s, `bw_burpee_slow` dient für beide Burpee-Schritte.

## 6. Kamera oder Uhr je Schritt

Die Kamera darf einen Schritt nur zählen, wenn sie es am Video nachweislich kann. Aus der Kamera-Spec für diesen Flow:

**Regel: Ein Schritt steht in der Flow-Zuordnung (`data/koerperbild/flow-zuordnung.json`) genau dann, wenn die Zählung am Mac gegen das erzeugte Video stimmt.** Stimmt sie nicht, läuft der Schritt mit Uhr. Das ist kein Scheitern, nur eine Entscheidung.

### 6.1 Was von vornherein auf die Uhr gehört

- **Halten** (Plank, Crunch-Halten): nichts zu zählen.
- **Flattern** (Scissor Kicks, Flutter Kicks): kleine Bewegung ohne klaren Gelenkwinkel.
- **Abwechselnde Seiten** (High Kicks, Skater Jumps, Mountain Climber): die Kamera zählt Wiederholungen einer Seite, kein Hin und Her.
- **Drehungen** (Russian Twist): kein Gelenkwinkel.

### 6.2 Was die Prüfung tut

Die Prüfung läuft am Mac, ohne Simulator (`docs/flows/hiit-20-min-kamera-bericht.md`):

```bash
cd apps/ios-member/Packages/Koerperbild
swift run skelette-rechnen <Ordner mit den mp4> ../../../../data/koerperbild/skelette
swift test --filter FlowZaehlerAbspielTests
```

1. `skelette-rechnen` (Apples Vision, `VNDetectHumanBodyPoseRequest`) legt je Video eine Skelettdatei ab: `data/koerperbild/skelette/<key>.skelett.json`.
2. Der Test `FlowZaehlerAbspielTests` schickt diese Skelette durch den `FlowZaehler`, so wie die App es in 40 s Arbeitsphase tut: das Video in Schleife, nur ganze Durchläufe, Tempo 1 s senken / 0 halten / 1 s heben. Die Testausgabe enthält je Übung eine Zeile `FlowZaehlerAbspiel <key> gezaehlt … erwartet … erkannt … Skelett …`.
3. Erwartet wird: Wiederholungen im Loop mal Durchläufe. Jedes der Videos zeigt genau eine Wiederholung; das wird unabhängig vom Zähler bestimmt, aus dem Winkelverlauf des Signals und aus einem Kontaktbogen (3 bis 6 Bilder je Sekunde) Bild für Bild.
4. **Bestanden**, wenn die Abweichung höchstens `max(1, erwartet / 10)` beträgt: höchstens 1, ab 20 erwarteten Wiederholungen höchstens ein Zehntel. (Die erste Lesart „± 1 je Durchlauf“ und auch „unter 1 je Durchlauf“ ließen bei einer Wiederholung je Loop fast jede Zahl durch, etwa 1 statt 13; geändert am 27.11.2026 bei der Schlussprüfung, Ergebnis der acht bestandenen und der drei durchgefallenen dadurch unverändert.)
5. Wer besteht, kommt mit Profil, Signal, „beginnt mit“ und Tempo in `flow-zuordnung.json`. Dann erzeugt `python3 tools/kamera-zuordnung/testprofile.py` die Datei `apps/ios-member/FitnessMember/Resources/KameraTestprofile.json` neu, die der Debug-Build liest.

### 6.3 Ergebnis HIIT-Flow: 8 von 20 Schritten zählen mit Kamera

| # | Schritt | Schlüssel | Ergebnis |
|---|---|---|---|
| 3 | Jumping Jacks | `bw_jumping_jack` | Kamera, bestanden (17 von 17) |
| 7 | Squat-Pulse | `bw_squat_pulse` | Kamera, bestanden (15 von 15), Vorbehalt |
| 9 | Rückenstrecken | `bw_back_extension_floor` | Kamera, bestanden (13 von 13), Vorbehalt |
| 11 | Ausfallschritt rückwärts | `bw_reverse_lunge` | Kamera, bestanden (14 von 14), Vorbehalt |
| 12 | Liegestütze | `bw_pushup` | Kamera, bestanden (11 von 11) |
| 13 | Beinheben | `bw_leg_raise_lying` | Kamera, bestanden (12 von 13), Vorbehalt |
| 14 | Strecksprung | `bw_squat_jump` | Kamera, bestanden (17 von 18), Vorbehalt |
| 15 | Squat mit Händen zum Boden | `bw_squat_floor_touch` | Kamera, bestanden (12 von 12) |
| 2, 6, 20 | Burpee, Burpee mit Strecksprung | `bw_burpee_slow`, `bw_burpee_jump` | Uhr, durchgefallen: doppelt gezählt |
| 4 | Klappmesser | `bw_v_up` | Uhr, durchgefallen: Hüfte nicht zu sehen |
| 1, 5, 8, 10, 16, 17, 18, 19 | alle übrigen | | Uhr (Abschnitt 6.1) |

Das sind 8 Schritte mit Kamera und 12 auf der Uhr.

### 6.4 Warum welche durchfallen

- **Burpee: doppelt gezählt.** Das Signal ist der Hüftwinkel. In einem Burpee beugt die Hüfte zweimal tief: beim Absetzen in die Hocke und beim Zurückkommen aus der Stütze. Dazwischen ist sie in der Stütze gestreckt wie im Stand. Für den Zähler sind das zwei Wiederholungen. Das liegt an der Übung, nicht an der Erkennung. Beim Burpee mit Strecksprung kommt eine leichte Beugung bei der Landung dazu. Ein anderes Signal (etwa Knie) wäre eine eigene Entscheidung.
- **Übungen aus ungünstigem Blickwinkel:** Das Klappmesser-Video zeigt die Figur vom Kopfende. Die Hüften findet Vision in keinem der 67 Bilder sicher genug, der Zähler führt die Person nur in 7,3 % der Zeit als erkannt. Ohne Hüfte kein Hüftwinkel. Gleiches Muster beim früheren Leg Drop & Pull (liegende Figur, in 36,5 % der Bilder erkannt, 0 von 5 gezählt).
- **Beim nächsten Mal:** Das Video einer Kamera-Übung gleich in der **Blickrichtung des Profils** erzeugen, also **seitlich**, mit der ganzen Figur im Bild. Jedes erzeugte Video hat seinen eigenen passenden Winkel; die Prüfung am Mac beweist deshalb nicht, dass die Zählung mit nur einem Aufstellort des Handys am iPhone klappt. Das zeigt erst der Gerätetest.

### 6.5 Falle: doppelte Übungsnamen (Ausfallschritt rückwärts)

Die Kamera-Testprofile (`KameraTestprofile`) werden **nach Übungsnamen** nachgeschlagen, nicht nach Schlüssel (der Bootstrap der App kennt den Katalogschlüssel nicht). Der Name „Ausfallschritt – rückwärts“ gibt es im Katalog viermal, und der erste Treffer in der Datei war `bb_reverse_lunge` (Langhantel, Tempo 3/1/2). Dadurch bekam Flow-Schritt 11 das falsche Tempo und im Simulator das falsche Video und Skelett. Der Fehler fiel erst bei der Durchsicht des Codes auf, nicht bei den Tests.

Die Lösung (Commit `b3954b9a`): Einträge aus `flow-zuordnung.json` tragen in `KameraTestprofile.json` `"flow": true`. Im Flow gewinnt ein Eintrag mit diesem Flag bei gleichem Namen, und der Flow reicht seinen Katalogschlüssel an die Abspielquelle weiter. Im normalen Debug-Training gewinnt bei „Ausfallschritt – rückwärts“ weiter `bb_reverse_lunge`. Unverändert ist das normale Debug-Training aber nicht ganz: `testprofile.py` nimmt die Flow-Einträge unabhängig vom Profil-Filter auf, und das normale Training liest dieselbe Datei. Dadurch bekommen dort auch Liegestütz (`stuetz_boden`), Rückenstrecken und Beinheben (`liegend`) ein Testprofil mit Flow-Tempo 1/0/1, die vorher wegen ihres Bodenprofils keins hatten (seit Task 9; der App-Test `flowUebungenHabenEinTestprofil` prüft den Liegestütz über `eintraege`). Umgekehrt nutzt der Flow seit der Schlussprüfung (27.11.2026) **nur** Einträge mit `"flow": true`: Ein Vorschlagsprofil ohne Prüfung am Video (etwa Dips) gibt im Flow keine Kamera mehr. Keiner der acht Kamera-Schritte des HIIT-Flows verliert dadurch seine Kamera. Ein App-Test prüft, dass jede Flow-Zuordnung auf ihren eigenen Schlüssel auflöst. Von den acht Zuordnungen hatte nur `bw_reverse_lunge` einen mehrfach vergebenen Namen.

**Beim nächsten Mal:** Beim Hinzufügen einer Kamera-Übung zur Flow-Zuordnung prüfen, ob ihr Name im Katalog mehrfach vorkommt (Suche aus Abschnitt 3.1). Wenn ja, dafür sorgen, dass der Test für jede Flow-Zuordnung auf den eigenen Schlüssel auflöst.

### 6.6 Wo die Zählung heute läuft

Die Zählung im Flow läuft **bisher nur im Debug-Build** über die Testprofile. Im Katalog ist nur „ohne Kamera“ freigeschaltet (`FREIGESCHALTETE_PROFILE`). Im Release- und TestFlight-Build laufen deshalb alle Schritte mit Uhr und Video. Die Testprofile schaltet man im Profil der App ein („Kamera-Testprofile“, nur im Debug-Build sichtbar).

### 6.7 Vorbehalte der bestandenen Schritte

Am Video bestanden heißt nicht: im Studio bestanden.

- **Squat-Pulse:** Im Video richtet sich die Figur halb auf. Federt jemand in Wirklichkeit nur wenige Grad, liegt der Hub unter der Untergrenze von 20° und es wird nichts gezählt.
- **Rückenstrecken:** Der Hüftwinkel ändert sich nur um etwa 22°, knapp über der Untergrenze. Wer den Oberkörper flacher hebt, wird nicht gezählt. Vision sieht nur die der Kamera zugewandte Körperseite.
- **Ausfallschritt rückwärts:** Das Video zeigt nur eine Seite. Wer die Seiten wechselt, ist ungeprüft.
- **Strecksprung und Beinheben:** je eine Wiederholung zu wenig (innerhalb der Toleranz), Ursache nicht untersucht. Beim Sprung kann man oben aus dem Bild kommen; beim Beinheben ist die Hüfte in den ersten ca. 0,5 s jedes Durchlaufs unsicher.
- **Liegestütz:** Das Video zeigt die Figur von der Seite, im Flow steht die Kamera aber vorn. Erkennung von vorn ungeprüft; die linke Körperseite ist in der Tiefe verdeckt.

## 7. `uebung` in der Flow-Datei, `flow:sql`

Jeder Schritt der Flow-Datei bekommt `uebung`: den Katalogschlüssel (Muster `^[a-z0-9_]+$`). Die Schritt-Namen im Flow bleiben, wie sie sind (außer den Burpee-Schritten und den getauschten); die Katalogübung kann anders heißen.

SQL erzeugen:

```bash
pnpm --silent flow:sql tools/flow-import/flows/<flow>.json --studio 00000000-0000-4000-8000-000000000001
```

`00000000-0000-4000-8000-000000000001` ist das Gymtavo-Katalogstudio (Migrationen 0047 und 0079). `--silent` unterdrückt die pnpm-Kopfzeile, damit nur SQL auf dem Bildschirm steht. Das Skript

- prüft jeden `uebung`-Schlüssel gegen `catalog/gymtavo.json` und bricht ab, wenn einer fehlt („Unbekannte Katalogschlüssel: …“);
- löst den Schlüssel im SQL per Unterabfrage auf die Katalogübung des Gymtavo-Studios auf (`select id from public.exercises where studio_id = … and catalog_key = '…'`);
- schreibt eine Sicherung hinter die Inserts (`raise exception`), die das Ganze zurückrollt, wenn nicht alle Schritte mit `uebung` auch eine `exercise_id` bekommen haben;
- ist idempotent: Der Flow wird mit `on conflict (studio_id, key) do update` angelegt, seine Schritte werden gelöscht und neu geschrieben, alles in einer Transaktion. Mitglieder-Läufe (`flow_runs`) bleiben dabei bestehen;
- weigert sich, solange ein Schritt `unsicher: true` hat.

Tests dazu: `pnpm vitest run tools/flow-import` (34 Tests am 27.11.). Ein Test prüft außerdem, dass alle Schlüssel der Flow-Datei im Katalog stehen und dass `flow-zuordnung.json` nur Übungen des Flows nennt.

## 8. Einspielen und Freigaben

> **Stand 27.11.2026: steht aus.** Nichts davon ist ausgeführt. Der Abschnitt ist eine Anleitung, kein Bericht. **Jeder Schritt geht nur mit Tims ausdrücklichem Ja für genau diesen Schritt**, im Chat gegeben, nicht abgeleitet aus einer früheren Freigabe. Zwischen den Schritten prüfen und das Ergebnis an Tim zurückmelden. Die Prod-Schlüssel gehören in die Umgebung (nie in den Chat, in Dokumente oder Commits).

Vor dem Prod-Teil: lokal alle Tests grün (`pnpm typecheck && pnpm test && pnpm test:integration`, `swift test` im Package, App-Tests), PR geöffnet und Tims Ja zum Push, CI grün.

**Migration 0080 MUSS auf Prod sein, bevor der PR gemergt und die API ausgeliefert wird.** Die neue API fragt in `listFlows` (`packages/domain/src/flows.ts`) die Spalte `flow_steps.exercise_id` ab. Fehlt sie auf Prod, schlägt die Abfrage fehl und `GET /me/flows` liefert für **alle** Mitglieder einen Fehler 500. Die App zeigt dann nur noch eine zwischengespeicherte Flow-Liste; Mitglieder ohne Zwischenspeicher sehen gar keine Flows.

Ob ein Merge nach `master` die API automatisch ausliefert, ist **nicht am Repo belegbar**: Im Repo gibt es keine `vercel.json` und keinen Deploy-Schritt in `.github/workflows/ci.yml` (die CI baut und testet nur); die Git-Anbindung von Vercel ist eine Projekteinstellung außerhalb des Repos. Deshalb so behandeln, als liefere der Merge sofort aus: erst Schritt a, dann Schritt b.

Reihenfolge, **jeweils nur nach Tims Ja:**

| # | Schritt | Befehl oder Weg | Danach prüfen |
|---|---|---|---|
| a | Migration `0080_flow_steps_uebung.sql` auf Prod anwenden (Spalte `flow_steps.exercise_id`). **Vor** dem Merge, sonst Fehler 500 bei `GET /me/flows` | Supabase-Connector, Migration anwenden | Spalte vorhanden; bestehende Flows unverändert |
| b | PR mergen (nach grüner CI), API-Deploy über Vercel | Merge, Vercel-Deploy | `GET /me/flows` liefert `exerciseId` je Schritt (zunächst `null`, weil der Flow noch ohne Verweise liegt) |
| c | Katalog einspielen: die **14 neuen Übungen mit ihren Videos** | `pnpm catalog:import --dry-run`, dann `pnpm catalog:import --ja` | Trockenlauf zeigt 14 neue Übungen und die neuen Videos; danach 274 Übungen im Gymtavo-Katalog |
| d | (entfällt in der Regel) nur Videos nachziehen | `pnpm catalog:import --nur-videos --dry-run` | Nach c sollte der Trockenlauf keine neuen Videos mehr zeigen |
| e | Flow neu einspielen | `pnpm --silent flow:sql tools/flow-import/flows/hiit-20-min.json --studio 00000000-0000-4000-8000-000000000001`, SQL über den Supabase-Connector ausführen | per SQL zählen: **20 Schritte, 20 mit `exercise_id`** |

Zu den Zahlen: Im Plan standen anfangs 16 neue Übungen, dann 15 (Burpee/Tap entfällt), nach der Vereinfachung **14**. Gezählt ist am 27.11.2026 der Unterschied der Schlüssel zwischen `master` (260 Übungen) und dem Zweig (274). Der Trockenlauf zeigt die Zahl, die tatsächlich geschrieben würde; stimmt sie nicht mit 14 überein, stoppen und nachsehen.

Hinweise:

- `catalog:import` verlangt außerhalb von 127.0.0.1 ein `--ja` und nennt sein Ziel. Es braucht `SUPABASE_URL` und `SUPABASE_SERVICE_ROLE_KEY` aus der Umgebung. Wie die Prod-Werte im konkreten Fall gesetzt werden, steht hier nicht; das ist Tims Sache.
- Der volle Import in Schritt c enthält die Videos schon: `importiereKatalog` (`packages/domain/src/katalog-import.ts`) plant alles, auch die Videos; `--nur-videos` engt diesen Plan nur ein (`nurVideos` in `katalog-plan.ts`) und bricht sogar ab, wenn ein Video eine Verknüpfung braucht, die es noch nicht gibt (also bei neuen Übungen). Schritt d ist deshalb nur ein Nachweis per Trockenlauf; der Trockenlauf von c zeigt, welche Videos neu sind.
- Reihenfolge ist wichtig: Erst a, dann b (die Datenbank hat die Spalte, bevor die API sie abfragt), dann c (die Übungen und Videos existieren), erst zuletzt e (die Schritte verweisen auf Übungen, die es geben muss; sonst scheitert die Sicherung im SQL).
- Rückweg bei Problemen: der Flow lässt sich mit demselben Befehl neu einspielen (idempotent).

**Offene Frage aus der Arbeit:** Was `catalog:import` mit Übungen macht, die aus der Datei entfernt wurden, wurde nicht gegen Prod geprüft. Im Code (`packages/domain/src/katalog-plan.ts`) steht, dass der Import nie löscht und solche Übungen nur meldet („Nur in der Datenbank, nicht gelöscht“). Das betrifft hier `bw_toe_touch_jackknife` und `bw_swimmer`; sie waren aber nie auf `master` und nach dem Stand der Arbeit nie auf Prod. Vor Schritt c im Trockenlauf nachsehen, ob die Meldung etwas aufführt.

## 9. Probe in der App

> **Stand 27.11.2026: steht aus.** Der Gerätetest am iPhone ist noch nicht gemacht. Die Sichtprüfung der Kamera-Phase im Simulator wurde bewusst nicht vom Agenten gemacht, sondern Tim überlassen (der Simulator-Login geht gegen Prod, den macht Tim). Layoutfehler der Kamera-Phase fallen deshalb erst beim Test auf.

**Aufbau:** Ein signierter Debug-Build direkt aus Xcode auf Tims iPhone. Nur dort gibt es die Testprofile; Release und TestFlight zählen nichts. Im Profil der App den Schalter „Kamera-Testprofile“ einschalten. Der Build läuft gegen Prod und braucht daher die Schritte a bis e aus Abschnitt 8 (sonst hat der Flow keine Übungsverweise und zeigt den Ring). Das Handy einmal aufstellen: Der Aufstell-Bildschirm vor dem Start verlangt, dass man stehend und liegend ganz im Bild ist.

**Ablauf des Flows:** Pause zeigt das Video der nächsten Übung (Restzeit oben rechts), bei Kamera-Schritten dazu eine Zeile „Stell dich seitlich zur Kamera“ oder „Schau zur Kamera“, abgeleitet aus dem Profil. Die Arbeitsphase zeigt bei Kamera-Schritten Livebild, Strichfigur, Welle und Zahl; bei Uhr-Schritten wie die Pause. Sieht die Kamera dich nicht, läuft die Uhr weiter, eine Zeile weist darauf hin, die Zahl bleibt stehen, die Kamera probiert es weiter. Das Fertig-Bild listet die gezählten Schritte mit Zahl; die Zahlen bleiben auf dem Handy.

**Was Tim je Kamera-Schritt beobachtet:** zählt / zählt nicht / Blickrichtung (Pause sagt „seitlich“ oder „zur Kamera“; passte es?). Der Test ist ein Versuch; Tim entscheidet, was daraus für den nächsten Flow folgt. Seine Beobachtungen werden in `docs/flows/hiit-20-min-kamera-bericht.md` nachgetragen.

| # | Schritt | Blickrichtung laut Profil | Zählt? | Passt die Blickrichtung? | Notiz |
|---|---|---|---|---|---|
| 3 | Jumping Jacks | zur Kamera (Oberkörper) | | | |
| 7 | Squat-Pulse | seitlich | | | echter Hub vielleicht zu klein |
| 9 | Rückenstrecken | seitlich, liegend | | | Hub knapp über 20° |
| 11 | Ausfallschritt rückwärts | seitlich | | | Seitenwechsel ungeprüft |
| 12 | Liegestütze | seitlich (Boden) | | | Kamera im Flow vorn? |
| 13 | Beinheben | seitlich, liegend | | | Hüfte am Anfang unsicher |
| 14 | Strecksprung | seitlich | | | oben aus dem Bild? |
| 15 | Squat mit Händen zum Boden | seitlich | | | |

Bekannte Vorbehalte aus der Prüfung am Mac stehen in Abschnitt 6.7. Bodenübungen (Profile `stuetz_boden` und `liegend`) sind am iPhone insgesamt ungeprüft; die Aufstellprüfung bleibt stehend, eine zweite im Liegen gibt es nicht. Auch Wärme und Akku über 20 Minuten Kamerabetrieb sind ungemessen (die Kamera ist deshalb nur in den Kamera-Schritten an, ca. 5 s vor Arbeitsbeginn bis Arbeitsende).

**Ergebnis des Gerätetests:** folgt (hier nachtragen, plus was daraus für den nächsten Flow folgt).

## Was schiefging oder Zeit gekostet hat

| Was | Folge | Beim nächsten Mal |
|---|---|---|
| **Platte voll.** Xcode-Builds, Testläufe und der Simulator füllten das Laufwerk; zeitweise waren nur noch 165 MB frei. Ein Auftrag blieb dabei halb stehen, Teile waren nur als Zwischenstand gesichert und ungeprüft. | Aufräumen auf Tims Auswahl (DerivedData, pnpm-Speicher, Caches, Simulator zurücksetzen, ein alter Arbeitsordner): von 295 MB auf 6,6 GB frei. Der Release-Build musste mehrfach aufgeschoben werden. | Vor jedem Build und jedem vollen Testlauf freien Platz prüfen (Grenze 1,2 GB). Bei knappem Platz zuerst aufräumen (`clean-disk`), nicht trotzdem starten. |
| **Docker/Colima nach dem Volllaufen defekt.** Die Docker-VM meldete danach Lesefehler (`docker images`, `psql` im Datenbank-Container), das lokale Supabase ging nicht mehr. | Integrationstests und lokaler Katalog-Import (`--dry-run` gegen lokal) liefen nicht. Das lokale Supabase war außerdem mit dem Hauptordner geteilt, Integrationsläufe dürfen nie parallel laufen. | Nach dem Aufräumen die Docker-VM neu starten und prüfen, bevor man sich auf Integrationstests verlässt. Fehlende Läufe im Bericht als „nicht gelaufen“ nennen, nie als grün. |
| **Guthaben zu knapp.** Bei Start der Videos lagen 5,61 $ bei OpenRouter, der Plan verlangte 10 $; der Budget-Halt im Skript stand noch auf dem alten Wert und hätte nach 0,35 $ gestoppt. | Der Lauf stand, bis Tim entschied („Ja, bis 5 $“). Nach der Runde blieben 1,89 $, die Reserve für die letzte Korrektur war knapp. | Guthaben und Halt vor dem Planen prüfen, Rundengrenze mit Tim festlegen, den Halt nur für diese Runde anheben und danach wieder zurückstellen. |
| **Drei vergebliche Anläufe bei zwei Übungen** (Toe Touch, Swimmer): zweimal nach der Abnahme nachgezogen, beim letzten Anlauf trotzdem falsch. | Rund 0,5 $ und eine Abnahmerunde für Übungen, die am Ende aus dem Flow flogen. | Übungen, die an Frage 1 oder 2 der Prüfliste (3.3) scheitern, gar nicht erst als Video versuchen. Anläufe zählen, nach dem dritten aufhören. |
| **Später Umbau auf einfache Übungen.** Erst nach Katalog, 19 Videos und Kamera-Prüfung kam am 27.11. die Entscheidung „eine Bewegung je Schritt“; fünf Schritte wurden getauscht, Videos und Prüfung für zwei Übungen kamen noch einmal. | Katalog, Flow-Datei, Zuordnung, Testprofile, Tests und zwei Dokumente mussten nachgezogen werden (ein ganzer Arbeitsgang, `feat(flows): HIIT-Flow vereinfacht, eine Bewegung je Schritt`). | Prüfliste „einfach genug?“ (3.3) und Katalogsuche (3.1) stehen jetzt **vor** dem Anlegen. Tim sieht die vereinfachte Liste, bevor das erste Video entsteht. |
| **Namensfehler Ausfallschritt rückwärts.** Vier Übungen heißen gleich, die Testprofile suchen nach Namen; Flow-Schritt 11 hätte das Langhantel-Tempo und -Video bekommen. | Eine eigene Fix-Runde (Abschnitt 6.5); ohne Review wäre es durchgerutscht. | Beim Anlegen und Zuordnen Doppelnamen suchen und auf Schlüssel statt Namen auflösen. |
| **Neue Übungen fehlten der Katalogkopie der Serie.** Prüfseite und zwei Serien-Tests gehen von der Kopie aus, die nur Wiederholungsübungen kennt. | 2 Tests rot, Namen auf der Prüfseite fehlten; Umweg mit eigenem Namensverzeichnis. | Zusatzliste für die Serien-Tests (`tests/hiit_keys.py` mit `ENTFALLEN`) anlegen und die Prüfseite mit dem Namensverzeichnis aus dem Katalog des Worktrees bauen (5.4). |
| **Toleranzgrenze der Kamera-Prüfung zu locker.** „± 1 je Durchlauf“ ließ bei einer Wiederholung je Loop sowohl „0 gezählt“ als auch „doppelt gezählt“ durch. | Auslegung zweimal geändert: erst „unter 1 je Durchlauf“, bei der Schlussprüfung dann „höchstens max(1, erwartet / 10)“, weil auch die erste Änderung bei einer Wiederholung je Loop fast alles durchließ. | Die Toleranz an der erwarteten Gesamtzahl festmachen, nicht an den Durchläufen. |
| **Videoprompt mit Logo-Satz** ließ liegende Figuren zur Kamera drehen. | Mehrere Startbilder und Videos waren umsonst. | `ohne_logo` von Anfang an bei Boden- und Rückenlage. |
| **Burpee zählt doppelt.** Tim wollte ihn trotz Teilbewegungen behalten; die Kamera-Zählung fällt durch. | Drei Schritte (2, 6, 20) laufen auf der Uhr. | Burpee-artige Übungen von vornherein als Uhr-Schritt planen oder ein anderes Signal als eigene Entscheidung prüfen. |
