# Testnotizen 15.10. – Cardio-Eingabe und Sensor-Karte

**Quelle:** Sitzung 2026-10-15-2100 (iPhone14,4, iOS 26.6.2, Debug), fünf Notizen, Stand-Commit `18664b6`.
**Vorgehen:** Notiz für Notiz dem Code zugeordnet, Regeln in reine Funktionen gezogen (`CardioEingabe`, `SensorKarte.anzeige`), Tests dazu. Das Skill `finetuning` ist für das Trainerportal geschrieben (Vitest, Next); hier gilt derselbe Ablauf mit Swift Testing.

## Rückfragen (beantwortet)

| Frage | Antwort |
|---|---|
| Sensor-Karte im Release? | Hinter einem Schalter (`Funktionen.sensorKarte`), vorerst nur Debug, später live schaltbar. |
| Tipp auf die Karte | Wie bisher: verbinden, abbrechen, Auswahl, Diagnose, Einstellungen. |
| Cursor-Sprung Zeit | Stunden nach 1 Ziffer, Minuten nach 2, Sekunden bleiben. |

## Etappen

1. **Zeiteingabe (#1, #2)** – `CardioWertSheet`: Stunden/Minuten/Sekunden immer sichtbar, Einheit über jeder Zahl, im Feld mit Cursor kein grauer Platzhalter, in den anderen eine graue 0. Sprungregel `CardioEingabe.springt`. Test: `cursorSpringtNachDerRegel`.
2. **Strecke (#3)** – zwei Felder km und m (statt eines Dezimalfelds), gespeichert bleiben Meter. `CardioEingabe.strecke/streckeTeile`. Test: `streckeAusKilometerUndMeter`.
3. **Einheiten und Zentrierung (#3, #4)** – Einzelwerte zentriert mit Einheit darüber; Kacheln zeigen Zahl und kleine Einheit, auch leer (`Zahlformat.cardioTeile`). Test: `kachelTeileTragenDieEinheit`.
4. **Sensor-Karte (#5)** – `SensorKarte` (Name, Akku-Symbol und Prozent, Zustand, keine Hz) über der Geräteauswahl und anstelle der Debug-Textzeile an jeder Übung. Schalter `Funktionen.sensorKarte`. Test: `SensorKarteAnzeigeTests`.

## Gestaltungsentscheidungen (ohne Rückfrage)

- Stufe zeigt keine Einheit in der Kachel (der Kachelname ist „Stufe“); im Blatt steht „Stufe“ über der Zahl.
- Zeit-Kachel: „min“, ab einer Stunde „h“; leere Strecke zeigt „km“.
- km springt nicht automatisch zu m (nicht notiert, Logik).
- Auf der Geräteauswahl öffnet ein verbundener Sensor nichts (das Diagnoseblatt braucht ein Gerät).

## Geprüft

- **Nicht gelaufen:** In dieser Cloud-Session gibt es keine Swift-Toolchain und kein Xcode. Weder Build noch Tests liefen, auch kein rot→grün. Die neuen Dateien sind von Hand in `project.pbxproj` eingetragen (xcodegen war nicht verfügbar).
- **Am Gerät ansehen:** Zeitblatt (Sprung, Platzhalter, Zentrierung), Streckenblatt, Kacheln, Karte auf Auswahl und Übung in 375 pt Breite.
