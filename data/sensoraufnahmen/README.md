# Sensoraufnahmen

Mitschnitte aus dem Debug-Build der Member-App, Format `gymodo.sensoraufnahme/1` (Spec: `docs/superpowers/specs/2026-09-19-sensor-anbindung-aufzeichnung-design.md`, Abschnitt 6). Startmaterial für den Wiederholungszähler (Teilprojekt B).

Die Ordner sind unverändert vom iPhone kopiert. Was die App beim Sichern als Label geschrieben hat, steht in `aufnahme.json`. Wo das nicht stimmt und was wirklich gemacht wurde, steht in `korrekturen.json`; das zählt für B als Wahrheit.

## Stand 8. Oktober 2026

Noch **keine** Aufnahme ist Trainingsmaterial (`fuerZaehler: false` überall):

- **4. Oktober vormittags:** Schnelltest, Gerät mit der Hand bewegt, Wiederholungen nur ungefähr.
- **4. und 5. Oktober:** Geräte-Checkliste und Ratentests (Spec §4.7, §9).
- **8. Oktober:** Probe aller geplanten Übungen mit einer Wasserflasche als Hantel. Sie ist gut, um zu sehen, welche Befestigung ein lesbares Signal gibt, bildet aber weder Stange noch Gewichtsstapel nach.

Erste Beobachtungen aus dem 8. Oktober: Curls sind in der Drehrate um eine Achse sehr deutlich, eine Welle je Wiederholung. Squats und das Absetzen auf dem Stapel zeigen sich in der Beschleunigung. Frei geführte Stapel-Bewegung und der Sensor um den Hals sind kaum zu lesen.

Ab Teilprojekt B gezählt werden nur echte Sätze mit eingetragener Befestigung und korrekt bestätigten Wiederholungen.

## Felder in `korrekturen.json`

- `befestigungsart`: einer von `stapel`, `langhantel`, `kurzhantel`, `hebelarm`, `kabelgriff`, `koerper` oder `null` (Sensor-Spec B 5.4). Der Zähler wählt danach sein Profil; ohne Art läuft die Aufnahme nicht in den Gütebericht.
- `befestigung`: Freitext-Detail wie bisher („oben auf dem Stapel“).
- `repsWahr`: was wirklich gemacht wurde — die Wahrheit für den Zähler.
- `fuerZaehler`: `true` nur für echte Sätze mit eingetragener Art und korrekt bestätigten Wiederholungen. Nur sie zählen für das Gütetor, und nur, wenn sie nach dem `eingefrorenAm` des Profils aufgenommen wurden.

Ab E4 (14. Oktober 2026) schreibt die App `befestigungsart`, `befestigungsartQuelle` (`vorschlag` oder `gewaehlt`) und den `zaehler`-Block (live gezählt, Herkunft, Ereignisse) in `aufnahme.json`. Beim Einlesen: eine gewählte Art gilt; eine vorgeschlagene nur, wenn Notiz und Signal nicht widersprechen, sonst Tim fragen. `zaehler.gezaehlt` gegen das Label zeigt, wie der Live-Zähler mit dem Profil seines Builds lag; der Gütebericht rechnet trotzdem immer mit dem aktuellen Profil neu.

Neue Aufnahmen: Ordner unverändert vom iPhone kopieren, Eintrag hier anlegen, `swift test --package-path apps/ios-member/Packages/Sensorik` laufen lassen und den neuen `guetebericht.md` mit committen.

## Stand 18. Oktober 2026

36 echte Sätze von 16:05 bis 17:10 (iPhone 13 mini, Sensor WT901BLE67, 50 Hz), dazu 21 abgebrochene Aufnahmen ohne Satz. Wahrheit pro Satz steht in `saetze-2026-10-18.csv` (aus `workout_sets.volume`, Zuordnung über `set_id` = `kontext.setId`); `korrekturen.json` ist daraus mit `tools/sensorik-sim/eintragen.py` gefüllt.

- **Kurzhantel** (Curl, Seitheben, Schrägbankdrücken), **Langhantel** (Bankdrücken, High-Bar-Kniebeuge, Rudern), **Stapel** (Latzug, Bauchbeugen, Beinpresse, Waden, Adduktoren/Abduktoren, Kabelrudern).
- Latzug Satz 2 und 3: App im Hintergrund, kein Live-Zähler; die Pakete sind da (Lücken höchstens 0,7 s).
- High-Bar-Kniebeuge Satz 2: kurze Pause im Satz wegen eines Gesprächs.
- `2026-10-18-1702-01` heißt in der App Langhantelrudern Satz 3, ist laut Testnotiz aber High-Bar-Kniebeuge Satz 3.
- Live-Zahl gegen Wahrheit: Kurzhantel-Curl/Seitheben, Bauchbeugen, Kabelrudern, Latzug 1 stimmen; Langhantel, Beinpresse, Waden, Adduktoren 1/3 und Abduktoren 1 liegen bei 2–13 statt 15–30 (siehe `docs/superpowers/specs/2026-10-18-satztakt-alle-befestigungsarten-design.md`).

### Ergebnis: Satztakt für alle Befestigungsarten (18.10.)

Messlatte und Zahlen: `taktbericht.md` (erzeugt von `TaktBerichtTests.berichtSchreiben`), Design und Plan unter `docs/superpowers/specs|plans/2026-10-18-satztakt-alle-befestigungsarten*`.

- Satzende-Zahl aus `Satztakt` jetzt für `stapel`, `langhantel` und `kurzhantel` (`stapel/takt1`, `langhantel/takt1`, `kurzhantel/takt2`); `hebelarm`, `kabelgriff`, `koerper` bleiben bei der Live-Zahl. Rückfall: Ist die Kette zu kurz (unter 70 % der Aktivdauer) oder liegt der Takt außerhalb der Profilgrenzen, zählt die Aktivdauer der Hüllkurve, markiert als unsicher.
- Stapel-Profil: Takt ab 1,0 s und Gleichheit 0,8. Langhantel unverändert auf den Kurzhantel-Werten (an den 6 Abstimmungssätzen traf kein Profil aus 96 alle).
- **±1-Quote:** Abstimmung 94 % gepoolt (32 Sätze), **Blindprüfung 83 % gepoolt (30 Sätze, Baseline 67 %)**. Das Ziel von 90 % ist nicht erreicht. Stapel blind 15/18, Langhantel blind 4/5, Kurzhantel blind 6/7, die 35 Sätze vom 16.10. weiter 100 %.
- Offen: Stapel-Sätze verlieren am Rand 2 bis 3 Wiederholungen (Beinpresse 17 von 20, Adduktoren 12 von 15), Bankdrücken Satz 3 (12 Wiederholungen) liegt bei 7, eine Kniebeuge mit Pause bei 33 statt 30. Mit mehr Aufnahmen je Art (Beinpresse, Waden, Kniebeuge haben 2 bis 4 Sätze) lässt sich das erst belastbar angehen; neue Sätze sind frische Blindprüfung.
- Latzug Satz 2 und 3 (App im Hintergrund): iOS liefert die Pakete nur alle ~0,6 s (je ~30 Werte). Der Live-Zähler wertet >0,5 s als Lücke und zählt nicht (wie in Spec B 9); die Satzende-Zahl trifft beide Sätze (12 und 14).
