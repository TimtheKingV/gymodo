# Satztakt für alle Befestigungsarten — Design

Stand 18. Oktober 2026. Auslöser: das Training vom 18.10. (36 gesicherte Sätze mit Sensor, 16:05–17:10) und Tims Auswertung „immer wenn's falsch war“.

## Worum es geht

Die Wiederholungszahl, die die App am Satzende anbietet, soll **höchstens um 1 neben der Wahrheit liegen**. Tim korrigiert am Rad, wenn nötig. Wo der Zähler unsicher ist, gibt er trotzdem seine beste Schätzung ab: eine unsichere Zahl ist Tim lieber als keine oder eine viel zu kleine. Während des Satzes eine Live-Zahl zu sehen wäre schön, wichtiger ist, dass die Zahl am Ende passt.

## Ausgangslage

Die Live-Zählung (`Zaehler`, ereignisbasiert mit Schwellen) und die Takt-Auswertung (`Satztakt`, „längste Kette sich gleichender Abschnitte“) existieren. `ZaehlerKoordinator` nutzt `Satztakt` **nur bei `kurzhantel`**: am Satzende ersetzt die Takt-Zahl die Live-Zahl, während des Satzes läuft sie höchstens einmal je Sekunde Messzeit abseits des Main Actors (Debug rund 0,8 s je Auswertung bei einem 37-s-Satz).

Heute (18.10.) lag die Live-Zahl so (gezählt / wahr, Wahrheit aus `workout_sets.volume`, Sätze in `data/sensoraufnahmen/saetze-2026-10-18.csv`):

| Gruppe (Profil) | Sätze | Befund |
|---|---|---|
| Kurzhantel: Curl, Seitheben (`kurzhantel/takt2`) | 6 | alle exakt |
| Kurzhantel: Schrägbankdrücken | 3 | 14/15, 8/12, 3/9 |
| Stapel/Kabel mit klarem Takt: Latzug 1, Bauchbeugen ×3, Kabelrudern ×2, Abduktoren 2 und 3 (`stapel/2`) | 8 | alle innerhalb ±1 |
| Stapel: Beinpresse, Waden, Adduktoren 1/3, Abduktoren 1 | 7 | 2–13 statt 15–30 |
| Stapel: Adduktoren 2 | 1 | 32 statt 40 |
| Langhantel: Bankdrücken 1 und 3, Kniebeuge, Rudern (`langhantel/1`) | 8 | 2–4 statt 8–30 |
| Latzug 2 und 3 (App im Hintergrund), Bankdrücken 2 | 3 | keine Live-Zahl |

Rohsignal-Check mit dem Python-Simulator (`tools/sensorik-sim`, Hüllkurven-Zählung auf der Hauptachse, ungetunt, ohne dass diese Sätze zum Abstimmen gedient hätten; Takt 1,2–6 s): In 33 von 36 Sätzen findet sich ein Takt, in 28 davon klar (Korrelation 0,6–0,97); die übrigen drei (Adduktoren/Abduktoren 1,2–1,4 s Takt) liegen unter der unteren Taktgrenze von 1,2 s der Python-Probe. Waden 20/20 und 17/17, Langhantelrudern 30/30, 26/25, 24/25. Beinpresse 16/20 und 16/17, Kniebeuge 26/28 und 25/30, Abduktoren 21/30. Die Hüllkurve verliert an Anfang und Ende Wiederholungen und fällt bei einigen Sätzen auf 2 zurück (alle Schrägbank-Sätze, Rudern 1). Die Wiederholungen **stehen also im Signal**; die schlechte Live-Zahl kommt von der Schwellen-Zählung, nicht vom Sensor.

Die Hintergrund-Sätze (Latzug 2, 3) haben Paketlücken von höchstens 0,7 s: das Signal ist da, nur der Live-Zähler hat nichts geliefert.

## Ziel

- **Hauptziel:** Anteil der Sätze mit |gezählt − wahr| ≤ 1 am Satzende so hoch wie möglich, über alle Befestigungsarten (`stapel`, `langhantel`, `kurzhantel`; `hebelarm`/`kabelgriff`/`koerper` haben kein Material und bleiben, wie sie sind).
- Messlatte für „erreicht“: ≥ 90 % der Sätze im ±1-Band auf einer Blindprüfung (siehe unten). Das ist Tims Qualitätsziel für diese Arbeit und **nicht** das Gütetor aus Spec B 5.5 (exakt ≥ 90 %, ±1 ≥ 98 %, je Art ≥ 20 Sätze aus ≥ 3 Tagen). Das Gütetor entscheidet weiter über die Freigabe und wird nicht angefasst.
- Die Takt-Zahl gilt auch live, sobald sie verlässlich ist (Anzeige am Rad während des Satzes), aber nur, wenn das nicht zu Lasten der Rechenzeit geht (siehe Randbedingungen).

## Nicht-Ziele

- Keine Änderung am Gütetor, an der Produktgrenze („Gymtavo speichert nur, was du bestätigst“) oder am Speichern (`volume_source`, `volume_counted`, `rep_events`).
- Keine neue Sensor-Hardware, keine neue Aufnahme-Funktion.
- Kein Maschinenlernen. Der Zähler bleibt eine reine, offline testbare Funktion (kein Zufall, keine Uhr).
- Kein Umbau der UI am Rad.

## Anti-Ziele

Als Fehlschlag gilt, auch wenn es technisch läuft:

- Kurzhantel-Curls und -Seitheben (alle 6 heute exakt, dazu die Sätze vom 16.10.) werden schlechter.
- Stapel-Sätze mit klarem Takt (Bauchbeugen, Kabelrudern, Latzug 1) werden schlechter, nur weil das Takt-Verfahren auf alle Arten umgestellt wurde.
- Die App wird beim Training spürbar langsamer oder hängt (Tims Meldung vom 18.10., 17:13, Hänger nach ca. 1 h 8 min, läuft in einer anderen Session; hier nur: keine neue Last, siehe Randbedingungen).
- An die heutigen Sätze angepasste Zahlen, die nur dort stimmen.

## Entscheidungen (von Tim)

1. Ziel ±1 am Satzende.
2. Lieber eine unsichere Zahl als keine; Tim korrigiert am Rad.
3. Satzende-Zahl hat Vorrang vor der Live-Zahl; beides wäre gut, die Satzende-Zahl ist wichtiger.

## Mein Vorschlag (nicht abgestimmt, Tim kann ablehnen)

Dies sind meine Entscheidungen, keine von Tim:

1. **`Satztakt` wird für alle Arten mit Material benutzt**, je Art mit eigenem Parametersatz (Takt-Grenzen, Kappfaktor, Gleichheitsschwelle). Die Parameter heißen weiter `Satztakt`-Konstanten und werden aus dem Enum in ein kleines Profil je Art gezogen; `kurzhantel` behält seine heutigen Werte unverändert.
2. **Rückfall:** Liefert `Satztakt` kein Ergebnis oder ein offensichtlich zu kleines (z. B. 2 bei einem Satz von 40 s), wird aus Dauer und Takt geschätzt, statt die Live-Zahl zu nehmen. Die genaue Regel ist Sache des Bauenden, geprüft an den Daten.
3. **Rand-Verluste** (Beinpresse 16/20, Abduktoren 21/30) sind der wahrscheinlichste Hebel für das ±1-Ziel: Anfang und Ende des Satzes sind die Stellen, an denen die Kette abreißt. Sie werden als Erstes angesehen.
4. **Schrägbankdrücken und Langhantel-Bankdrücken** haben ein schwaches Signal (Korrelation 0,28–0,6). Dort gilt das ±1-Ziel nur, wenn es sich ohne Überanpassung erreichen lässt. Gelingt es nicht, wird das in der Doku benannt, und der Zähler liefert trotzdem eine Schätzung, ausgewiesen als unsicher (`unsicher`-Grund `signalSchwach`).

## Daten und Prüfmenge

- **Vorhanden:** 35 Sätze vom 16.10. (alle `kurzhantel`, in `data/sensoraufnahmen/`, mit `korrekturen.json`) und 36 Sätze vom 18.10. (`data/sensoraufnahmen/2026-10-18-*`, nur gesicherte, Wahrheit in `saetze-2026-10-18.csv`).
- **Wahrheit:** Reps stehen in `workout_sets.volume` (Supabase, Konto buettner-tim@outlook.de). Das `label.reps` in `aufnahme.json` ist der Stand beim Sichern und weicht bei „korrigiert“ ab; maßgeblich ist `volume`.
- **Vor der Auswertung zu bereinigen** (Tim hat es in der Testnotiz vermerkt): „Langhantelrudern Satz 3“ (170201, Reps 25) gehört zu High-Bar-Kniebeuge Satz 3. Adduktoren/Abduktoren haben doppelte `set_index`-Werte (`korrigiert` und `gemessen` stehen je zweimal); die Zuordnung Aufnahme ↔ Satz läuft über die `setId`, nicht über Name und Index. Latzug 2 und 3 sowie Bankdrücken 2 haben `volume_source = eingegeben`, die Reps stimmen aber (von Tim eingetragen).
- **Aufteilung:** Zum Abstimmen dient je Art ein Teil, der Rest bleibt als Blindprüfung, bevor irgendetwas angesehen wird, und wird nur einmal benutzt. Weil Material je Art knapp ist (Langhantel 9, Beinpresse/Waden 4, Adduktoren/Abduktoren 7 Sätze, alle von einem Tag und einer Person), gilt: Die Aussage „±1 erreicht“ gilt nur für diese Person, diese Geräte und diesen Tag, bis neue Aufnahmen vorliegen. Das steht so im Bericht.
- **Wahrheitslücken:** Sätze mit Pause im Satz (Kniebeuge 2, kurze Unterhaltung) und Marken (`# marke satzbeginn/satzende`) gibt es nur teilweise. Fehlende Marken sind kein Grund, den Satz auszuschließen.

## Randbedingungen

- Alle Änderungen im Package `apps/ios-member/Packages/Sensorik` (reines Swift, `swift test` auf dem Mac) und in `ZaehlerKoordinator`. Python (`tools/sensorik-sim`) ist die Werkbank zum Probieren; maßgeblich sind die Zahlen aus dem Swift-Code (der Python-Tiefpass weicht in einzelnen Sätzen ab).
- Rechenzeit: Eine Takt-Auswertung braucht heute 0,8 s (Debug, 37-s-Satz), und die Kosten wachsen mit der Satzlänge (die heutigen Sätze dauern bis 89 s). Auf alle Arten ausgeweitet darf das die App nicht langsamer machen: höchstens eine Auswertung zugleich, abseits des Main Actors, `satzMesswerte` darf nicht unbegrenzt wachsen. Ob die Live-Takt-Zahl bei langen Sätzen seltener läuft, entscheidet der Bauende nach Messung.
- Das Aufnahmeformat (`gymodo.sensoraufnahme/1`) und `RepEvents` bleiben kompatibel; für die Takt-Auswertung wird die `algo`-Kennung je Art vergeben (heute `kurzhantel/takt2`).
- Konventionen aus `docs/superpowers/plans/2026-10-10-sensor-wiederholungszaehler.md`: Commits deutsch mit ae/oe/ue, Swift-Kommentare ASCII mit Begründung statt Beschreibung, Swift Testing, nicht pushen ohne Tims Ansage, eigener Worktree, `xcodegen generate` nach Änderungen an Targets.
- Neue Aufnahmen gelangen laut `data/sensoraufnahmen/README.md` ins Repo: Ordner unverändert kopieren, Eintrag in `korrekturen.json` und README anlegen, `swift test --package-path apps/ios-member/Packages/Sensorik` laufen lassen, den neuen `guetebericht.md` mit committen. Die 57 Ordner vom 18.10. sind kopiert, aber noch nicht eingetragen oder committet (davon sind 21 `abgebrochen` und ohne Wahrheit).

## Festlegungen aus der Prüfung

Aus dem Projekt beantwortet:

- **Wahrheit:** `saetze-2026-10-18.csv` ist bereits bereinigt und nach `set_id` (= `setId` in `aufnahme.json`) geführt. Die Zeile `1C0DD9A1…` (Aufnahme 170201, 25 Reps) ist die Kniebeuge Satz 3, auch wenn die App sie noch „Langhantelrudern“ nennt. Name und `set_index` aus Supabase nicht zum Zuordnen benutzen.
- **`signalSchwach`** (und `luecke`, `taktUnregelmaessig`) gibt es schon in den `RepEvents`-Typen. Der Grund wird nur gespeichert, am Rad wird er nicht angezeigt. Kein neuer Enum-Fall nötig, das Aufnahmeformat bleibt unverändert.
- **Sätze ohne Live-Zahl** (Latzug 2 und 3, Bankdrücken 2): `Satztakt` läuft am Satzende immer auf dem ganzen Satz, unabhängig vom Live-Pfad. Diese Sätze gehören in die Prüfung. Warum der Live-Zähler dort nichts lieferte, klärt der Bauende im `ZaehlerKoordinator` (die Pakete sind da, Lücken höchstens 0,7 s); ist es ein Fehler im Hintergrund-Pfad, wird er behoben, sonst nicht.

Meine Entscheidungen (Tim kann sie ändern):

- **Aufteilung:** feste, dokumentierte Regel statt Zufall, z. B. jeder zweite Satz je Art zum Abstimmen, der Rest blind. Bei Arten mit nur 2–4 Sätzen (Beinpresse, Waden, Kniebeuge) ist die Blindprüfung nur ein Hinweis, keine Aussage; das steht so im Bericht. Das 90-%-±1-Ziel gilt **gepoolt und je Art berichtet**, damit eine schwache Art (Langhantel-Bankdrücken, Schrägbank) nicht von starken versteckt wird.
- **Fehlerart:** zu viel und zu wenig zählen gleich. Eine Verdopplung durch den Oberton ist ein Fehlschlag wie ein verpasster Satz. Eine Takt-Untergrenze unter 1,2 s (für Adduktoren/Abduktoren mit 1,2–1,4 s) ist erlaubt, wenn die Blindprüfung keine Verdopplungen zeigt.
- **Überanpassung:** je Art höchstens 3 abgestimmte Parameter, der Rest wird mit den anderen Arten geteilt.

## Was dem Bauenden überlassen bleibt

- Parameter und Zuschnitt der Profile je Art, die genaue Rückfallregel, Behandlung der Satzränder, Reihenfolge der Arten.
- Ob ein neues Verfahren neben der Kette nötig ist (z. B. für Beinpresse oder Waden) oder ob Parameter genügen. Gewinnt etwas Neues, wird es an der Blindprüfung bestätigt, nicht am Abstimmungsteil.
- Wie die Live-Anzeige technisch aussieht.

## Erfolg

- Bericht (`guetebericht.md` oder daneben) mit ±1-Anteil je Art, getrennt nach Abstimmung und Blindprüfung, und der ehrlichen Aussage über die Grenzen des Materials.
- Kurzhantel und klare Stapel-Sätze nicht schlechter als vorher (Anti-Ziel).
- Tim trainiert mit dem Build und sagt, ob die Zahl am Satzende passt.
