# Sensor-Aufnahme am Mac mit Metronom und Tasten-Wahrheit (Kurzentwurf)

**Stand:** 23. November 2026 · **Status:** von Tim im Gespräch freigegeben („passt so, bau es“), direkt gebaut ohne eigenen Umsetzungsplan.
**Gehört zu:** `2026-11-23-tempo-modus-design.md` (Tempo-Modus). Dort fehlt eine echte Wahrheit für die Lage der Last; diese Seite liefert sie.

## Warum

Der Tempobericht misst die Lageschätzung nur gegen eine nachträgliche Rechnung. Gebraucht werden Aufnahmen, bei denen die Umkehrzeiten bekannt sind. Am iPhone wäre ein Metronom nicht mit der Aufnahme gekoppelt.

## Was

Eine einzelne HTML-Seite (`tools/sensorik-aufnahme/index.html`, ohne Abhängigkeiten, Chrome am Mac):

- verbindet sich über Web Bluetooth direkt mit dem WitMotion-Sensor (Dienst `FFE5`, Daten `FFE4`, Befehle `FFE9`, Paketformat wie `WitMotionPaket.swift`), stellt 50 Hz ein;
- gibt den Takt vor: bewegter Punkt und Ton (hoch = oben, tief = unten), Tempo wählbar (1,5/2,5 · 2/2 · 1/1 · 3/3 · 4/4 s, oder ohne Takt), Start unten oder oben;
- hält Tastendrücke fest: ↑ = oben angekommen, ↓ = unten angekommen (auch Bild auf/ab für Presenter); Leertaste startet und beendet, Esc verwirft;
- je 5 s Ruhe vor und nach dem Satz;
- schreibt je Satz einen Ordner `JJJJ-MM-TT-HHMM-NN/` mit `aufnahme.json` und `messwerte.csv` im Format `gymodo.sensoraufnahme/1` in einen einmal gewählten Ordner (`data/sensoraufnahmen`).

Takt, Tasten und Messwerte laufen auf derselben Uhr (`performance.now()`), `t` in Sekunden ab Aufnahmebeginn.

## Zusätze zum Format

Der vorhandene Leser überliest unbekannte `#`-Zeilen und unbekannte JSON-Schlüssel; Güte- und Taktbericht laufen unverändert.

- `messwerte.csv`: `# los <t>`, `# takt oben|unten <t>` (Soll), `# umkehr oben|unten <t>` (Tastendruck), `# ende <t>`. Bewusst nicht `# marke`, weil der Leser dort nur `satzbeginn`/`satzende` kennt.
- `aufnahme.json`: Block `tempo` mit `kraftwegS`, `ablassenS`, `startetOben`, `ohneTakt`, `tasten` (`selbst`/`helfer`), `ruheS`, `losBei`.
- `label.reps` = Zahl der vollständigen Wiederholungen aus den Tastendrücken, vor dem Speichern korrigierbar. `befestigungsartQuelle` = `gewaehlt`.
- **Wiederholungs-Vorschlag (Stand 24.11.):** mit Tastendrücken deren Zahl; ohne Tastendruck die Zahl der Taktgipfel bis zum Ende (`# takt oben` bis `# ende`: so oft sollte gehoben werden), nicht mehr `floor((ende − los) / periode)`; ohne Takt leer. `tempo.repsQuelle` hält fest, woher `label.reps` kommt: `tasten`, `takt` oder `hand` (der Wert wurde vor dem Speichern geändert). Ohne Tasten ist `label.reps` damit eine Soll-Zahl von der Uhr, keine Zählung; die Aufnahmen vom 23.11. tragen noch die alte Vorbelegung und kein `repsQuelle`.
- `geraet.model`: „Mac (Brücke)“ über `bruecke.py`, sonst „Mac (Web Bluetooth)“. `statistik.verworfeneBytes` zählt je Aufnahme, nicht seit Verbindungsbeginn.

## Brücke für Safari

Safari kann kein Web Bluetooth. `tools/sensorik-aufnahme/bruecke.py` (`uv run --with bleak python tools/sensorik-aufnahme/bruecke.py`) verbindet sich selbst mit dem Sensor, liefert die Seite unter `http://127.0.0.1:8765/` aus, reicht jede Notification als Server-Sent Events über `/strom` weiter und speichert Sätze über `POST /speichern` in `data/sensoraufnahmen`. Die Seite erkennt die Brücke an `/bruecke` und blendet dann „Sensor verbinden“ und „Ordner wählen“ aus.

Schutz der Brücke: Der Server hört nur auf 127.0.0.1. `/strom` und `/speichern` antworten nur, wenn `Host` `127.0.0.1:<port>` oder `localhost:<port>` ist und ein gesetzter `Origin` dazu passt (sonst 403; gegen fremde Seiten im selben Browser und DNS-Rebinding). `/speichern` verlangt `Content-Type: application/json`, höchstens 20 MB und einen Ordnernamen `JJJJ-MM-TT-HHMM` (ganz, per `fullmatch`). Kommt eine Seite nicht hinterher (Warteschlange voll), schickt die Brücke ihr `event: abgehaengt` und schließt die Verbindung; die Seite zeigt „Brücke hat die Verbindung getrennt“ und verbindet nicht still neu.

## Wege

Eigene Mac-App (würde den Swift-Code wiederverwenden, aber viel Bau für ein Werkzeug) und ein Terminal-Skript (keine Taktanzeige) wurden verworfen. Gewählt: HTML-Seite, wie von Tim vorgeschlagen.

## Grenzen

- Die Tastenzeit trägt die Reaktionszeit des Drückenden (geschätzt 0,1–0,2 s). Soll-Takt und Tastendruck werden deshalb beide gespeichert.
- Ton über Bluetooth-Kopfhörer kommt verzögert; Lautsprecher oder Kabel benutzen.
- Der Mac bündelt Bluetooth-Pakete anders als das iPhone; die Empfangsabstände stehen wie gewohnt in der Statistik.
- Bei beidhändigen Übungen drückt eine zweite Person (Tim).

## Prüfung

Die Paket-Auswertung wird gegen die Testbytes aus `WitMotionPaketTests.swift` geprüft (`?selbsttest=1`). Ein Probelauf ohne Sensor (`?demo=1`) erzeugt eine Aufnahme, die `SensorAufnahmeLeser` lesen muss.
