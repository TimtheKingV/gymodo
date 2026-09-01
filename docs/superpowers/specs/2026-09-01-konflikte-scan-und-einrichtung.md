# Konflikte zwischen „Beitritt durch Scannen" und „Einrichtung am Gerät"

**Stand:** 1. September 2026
**Status:** Befund, nicht entschieden. Keine dieser Fragen ist beantwortet.
**Betrifft:** `2026-09-01-scan-beitritt-design.md` (Runde A) und `2026-09-01-einrichtung-am-geraet-design.md` (Runde B)

---

## Warum dieses Dokument existiert

Beide Runden entstanden am selben Tag, teils parallel. Runde B erklärt im Kopf, sie ändere Runde A in §3 und §6, und Runde A ist darauf nachgezogen. **Dieses Dokument hält fest, was dabei durchgerutscht ist.**

**Nichts davon bricht etwas, das bereits gebaut ist.** Alle Befunde liegen in Specs und im noch nicht ausgeführten Datenbankplan. Die 34 Member-Artboards und die Portal-Artboards sind in sich stimmig, beide `canvas.json` vollständig, kein Artboard doppelt oder verwaist.

**Stand nach der zweiten Runde von „Einrichtung am Gerät" (Foto und Einstellparameter im Gang):** Das Portal zählt jetzt 39 Artboards statt 36 — die Seite *Einrichten am Gerät* hat drei dazubekommen. Die drei großen Befunde unten sind davon unberührt und weiterhin offen.

---

## Drei Befunde, die jemanden das Falsche bauen ließen

### 1. Ein geliefertes Aushangschild kann nie aktiv werden

Runde A kannte genau einen Weg, einen Aushang zu aktivieren: `createTag(kind: 'studio')`, das die Zeile sofort `active` anlegt. **Runde B streicht `createTag` ersatzlos** (§6) und sagt: „Im Portal gibt es dafür keinen Bildschirm" (§1).

Damit bleibt kein Weg übrig. `join_studio_by_tag` und `resolve_tag_fallback` filtern beide auf `status = 'active'` — ein geliefertes Aushangschild ist für beide unsichtbar. Gleichzeitig zeichnet `Tags.dc.html` einen Aushang als *„aktiv · Eingang · Charge 8 · hängt seit …"* mit einer *Sperren*-Aktion: **ein Zustand, den kein Ablauf erreicht, und aus dem nur ein Weg herausführt.**

Zu entscheiden: Wer setzt ein geliefertes Schild auf `active`? Ein Betreiberskript wie bei der Charge, eine Portal-Aktion, oder entsteht es schon aktiv bei der Lieferung?

### 2. Der Sucher hat keine Antwort auf die falsche Tag-Sorte

Runde A führt `kind ∈ machine | studio` ein und verbietet einem `studio`-Tag jede `machine_id`. Runde B entscheidet zugleich (§3): *„Der Vorrat ist eine Zahl, keine Liste … Benennbar wird ein Tag erst durch den Scan"*, und `TelefonKleben.dc.html` sagt dem Trainer: *„Nimm irgendeinen Tag aus der Packung."*

**Der Trainer kann ein Aushangschild vor dem Scan nicht von einem Geräteaufkleber unterscheiden — das ist Absicht.** Scannt er das falsche, ist der einzige angebotene Ausgang *Verbinden*, also `machine_id` setzen. Runde Bs Antworttabelle (§4) nennt sechs Fälle, `TelefonZustaende.dc.html` zeichnet acht Karten. **Keine davon heißt „das ist ein Aushangschild".**

Vor Runde A wäre dieser Fehlscan still durchgelaufen und hätte einen Aushang in einen Gerätetag verwandelt. Nach Migration `0022` wirft er eine Check-Verletzung — ohne gestalteten Bildschirm dahinter. Der Constraint hat recht; es fehlt die siebte Antwort.

### 3. Der Datenbankplan würde den Geräte-Fallback zerstören

`2026-09-01-scan-beitritt-datenbank.md` Task 6 Step 1 behauptet, `resolve_tag_fallback` gebe „heute nur `machine_tag_id`" zurück. **Das stimmt nicht.** `0021_fallback_inhalte.sql` liefert fünf Spalten: `machine_tag_id, machine_label, model_name, photo_path, exercises`.

Das vorgeschlagene `0025` ersetzt sie durch `(machine_tag_id, kind, studio_name)` und wirft damit vier Spalten weg, die `apps/web/app/t/[token]/page.tsx` und `tests/integration/fallback-inhalt.test.ts` benutzen. Step 2s Beruhigung („nur die Spaltenzahl ändert sich") ist doppelt falsch.

Korrekt wäre: die vier Spalten behalten und `kind` plus `studio_name` **ergänzen**, und `join machines` zu einem Left Join machen — sonst liefert ein Aushang null Zeilen und landet auf *„Dieser Code ist nicht aktiv."* Ebenfalls offen: `0021` filtert `m.status = 'active'`, was für einen Tag ohne Gerät keine Bedeutung hat.

---

## Kleinere Widersprüche

| | Befund |
| --- | --- |
| **Heimatlos** | Der Satz in *Einstellungen → Studio*, der den Studio-Code zum zweiten Weg erklärt, wurde von Runde A an „den Plan aus Runde B" übergeben. **Runde Bs Spec erwähnt Einstellungen und den Studio-Code nirgends.** Der Punkt gehört niemandem. |
| **Alter Stand** | `EinstellungenStudio.dc.html` sagt noch *„Mit diesem Code treten Mitglieder eurem Studio bei"* — die abgelöste Regel. Und es nennt Papieraushänge „Aushänge", während in beiden Runden ein *Aushang* ein geliefertes Schild mit Token ist. Ein Wort, zwei Produkte, benachbarte Bildschirme. |
| **Notiz gegen Bildschirm** | Runde B schrieb die Portal-Notiz `note-einstieg` auf *„das kommt über den Scan eines Aushangs, ersatzweise über den Studio-Code"* — `KeinStudio.dc.html` darunter sagt weiter *„Gib den Code ein"*. Die Notiz hat recht. |
| **Migrationsnummer** | Der Datenbankplan reserviert `0022`–`0025`. Runde B braucht „eine Migration, eine nullable Spalte" für die Charge, ohne Nummer. Auf Platte endet es bei `0021`. Wer zweitschreibt, nimmt eine belegte Nummer. |
| **Beispielbestand** | Dasselbe Gerät heißt in der Member-App *Gerät 07 · Technogym Selection · Kraftbereich* und im Portal *Beinpresse 7 · Gym80 · Fensterseite*. |
| **Rail-Zahl** | Vier Portal-Artboards zeigen noch *„Tags · 1 vorrätig"* statt *97*: `EinstellungenKonto`, `EinstellungenStudio`, `LeuteMitarbeiter`, `LeuteMitglieder`. Der Stimmigkeits-Durchgang `b66febe` hat sie übersprungen, die zweite Runde ebenfalls — sie liegen in `gen_verwaltung.py` und `gen_einstieg.py`, außerhalb ihres Umfangs. |

**Kleinkram:** Runde As Spec nummeriert Home als 22/23, die Canvas führt 20/21. Sie nennt einmal ein Studio *„Nordstraße"*, das nirgends sonst existiert. Der Datenbankplan verweist auf ein „Task 7", das es nicht gibt. ~~Runde Bs Bildschirmtabelle zählt 15 neu, markiert aber 14 mit `+`.~~ **Erledigt** in der zweiten Runde: die Tabelle zählt jetzt 18 Artboards, davon 17 neu und eines ersetzt.

---

## Der Datenbankplan, Aufgabe für Aufgabe

Er ist noch nicht ausgeführt. Nach Runde B gilt:

| Aufgabe | Stand |
| --- | --- |
| **1 · `tag_kind` und Constraint-Umbau** | **Gültig.** Runde B übernimmt `kind` ausdrücklich und braucht es für die Unterscheidung Gerätetags/Aushangschilder. Nur die Migrationsnummer ist zu klären. |
| **2 · `join_studio_by_tag`** | **Gültig.** Runde B zitiert die Funktion zustimmend. `on conflict do nothing` deckt genau den Fall ab, den *„Probe scannen"* erzeugt. |
| **3 · Selbstaustritt-Policy** | **Gültig.** Von Runde B unberührt. |
| **4 · Fachschicht** | **Halb tot.** Step 3 (`createTag` erweitern) ist gestrichen — und schlimmer als vorzeitig: er verdrahtet „ein Aushang ist immer sofort aktiv", während `Tags.dc.html` vier vorrätige Aushänge zeichnet. Die ersten zwei Tests kodieren dieselbe falsche Regel. **Steps 4–6 (`CatalogTag.kind`) bleiben nötig** — ohne sie kann die Tags-Seite die Sorten nicht trennen. |
| **5 · Portal-Aushang** | **Tot, richtig gestrichen.** |
| **6 · Web-Fallback** | **Step 1 und 2 sind fehlerhaft** (Befund 3 oben). **Steps 3–6 bleiben gültig**, die Artboards dafür stehen. |

---

## Was stimmig ist

Der Tokenraum, `join_studio_by_tag`, die Selbstaustritt-Policy, `kind` selbst, beide Canvases mit ihren Zählungen und Dateilisten, und die Übernahme von Runde As §1 durch Runde B. **Der Bruch liegt nicht zwischen den Runden, sondern in der Lücke, die beide für die jeweils andere offen gelassen haben.**
