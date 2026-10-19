# Testnotizen 18.10. – iOS-Member-App – Plan

**Quelle:** Testsitzungen 2026-10-18 08:37, 16:15, 17:13 (gymodo Member, iPhone14,4, iOS 26.6.2). Ausgenommen auf Wunsch (laufen in einer anderen Session): Hintergrund-Lücken, Kniebeuge-Pause, Label Rudern↔Kniebeuge.

**Vorgehen:** Reinfunktionen und Tests zuerst (Swift Testing, `swift test` im Package Sensorik), keine neuen Xcode-Dateien.

**Rückfragen (beantwortet):** #5 „Anzahl Stufen“ als volle Kette (Migration, Domain, Katalog, iOS).

## Etappen

| # | Notiz | Ursache | Änderung | Test zuerst rot |
|---|---|---|---|---|
| 1 (08:37 #1) | „Fortschritt“ über dem Toggle, „Muskulatur“ | Überschrift hing nur an der Übungsansicht | `fortschritt` trägt die Überschrift „FORTSCHRITT“; `Fortschrittsansicht.muskelgruppen.titel` = „Muskulatur“ | `FortschrittsansichtEinstellungTests.schalterTitel…` |
| 2 (08:37 #2) | Rumpf grün im Detail, „zu wenig“ in der Übersicht | Muskeln wurden am Mittel der **eigenen** Gruppe gemessen, Balken an ihrem größten Muskel | `Ausgewogenheit.status(muskel:)` misst am Mittel aller Gruppen; Balken im Detail relativ zur größten Gruppe (`groessteGruppe`) | `AusgewogenheitTests.schwacheGruppeFaerbtIhreMuskelnNichtGruen` |
| 3 (16:15 #1) | Toast „gesendet“ raus | `WarteschlangeKarte` zeigte nach dem Leerlaufen zwei Sekunden „GESENDET“ | Zustand, Timer und Beschriftung entfernt; die Karte steht nur, solange etwas wartet | Verhalten in View, ohne Test |
| 4 (17:13 #2) | Kategorien über den gemachten Übungen | Die Übungen standen im Kopf, die Kacheln darunter | Zweiter Slot `trainingsinhalt`: Kopf (Sensor, Uhr) → Kategorien → gemachte Übungen → Zuletzt | Layout, ohne Test |
| 5 (17:13 #3) | Treppen: Anzahl Stufen | Es gab nur `stufe` (Widerstandslevel) | Neuer Cardio-Wert `stufenanzahl` (1–10000, ganz): Migration 0057, `cardio.ts`, Katalog (`stair_climber`), Portal-Beschriftung, `CardioWert.stufenanzahl` samt Formatierung | `cardio.test.ts`, `CardioTests.anzahlStufenAmTreppensteiger` |
| 6 (17:13 #4) | Tipp auf Übung öffnet Übungsfortschritt | Kopf der Blockkarte war reiner Text | `NavigationLink(value: .uebungsfortschritt)` am Kopf | Navigation, ohne Test |
| 7 (17:13 #1) | Hänger nach ca. 1 h 8 min | `SensorStatistik` hinter `gesamt` (lebt, solange der Sensor verbunden ist) hängte jeden Paketabstand an und sortierte alle einmal je Sekunde auf dem Hauptthread: nach 1 h bei 100 Hz ~360 000 Werte, im Debug-Build füllt das den Hauptthread | Fenster von 30 000 Abständen (blockweises Kappen), Maximum separat exakt | `SensorStatistikTests.derSpeicherWaechstNichtMitDerVerbindungsdauer`, `dasMaximumBleibt…` |

## Entscheidungen (Claude, zu bestätigen)

- #2: Das Mittel der sechs Gruppen ist der Maßstab für Farbe **und** Balken, Teilmuskeln sind daher nie besser als ihre Gruppe. Der Hinweis „Muskel kam nur n× dran“ greift deshalb auch in einer sonst grünen Gruppe nur bei Muskeln unter der halben Gruppenmitte aller Gruppen.
- #4: Kategorien stehen unter Uhr und Sensor, nicht über der Uhr (die Uhr mit Pause-Knopf bleibt oben).
- #5: Schlüssel `stufenanzahl`, Beschriftung „Anzahl Stufen“, Einheit „Stufen“, Reihenfolge direkt nach `stufe`. Nur der Katalog-Typ `stair_climber` bietet ihn an.
- #7: Die Sensoraufnahme ist DEBUG-only; der Hänger betraf den Testbuild. Ohne Änderung am Dateischreiben (je Paket ein Schreibaufruf, nur während eines Satzes).

## Geprüft

- Gelaufen: `xcodebuild test` (1367 Tests grün), `swift test` im Package Sensorik (93 Tests grün), `vitest` in packages/domain (368 grün; `sticker.test.ts` lädt wegen fehlendem `@resvg/resvg-js` nicht, unabhängig von dieser Änderung).
- Nicht gelaufen: Migration 0057 und die Integrationstests (`tests/integration`, brauchen lokales Supabase) – die Tests sind angepasst, aber nicht gesehen. `catalog:import` danach ausführen.
- Am Gerät ansehen: Home (Überschrift in beiden Ansichten), Muskelgruppen-Detail Rumpf (gelb), Training-Wurzel mit laufendem Training (Reihenfolge), Treppen-Gerät (Knopf „Anzahl Stufen“), Session-Detail (Tipp auf Übung), eine Stunde Training mit Sensor.
