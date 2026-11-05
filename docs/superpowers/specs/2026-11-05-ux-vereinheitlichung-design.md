# UX-Vereinheitlichung Member-App – Design

Stand: 2026-11-05 · Grundlage: Audit auf `origin/master` (c5fa810c) · iOS-App `apps/ios-member`

## Warum

Mit Trainingsplan, Wochenplan-Tab, Mini-Zirkel, Cardio und Tracker sind in kurzer Zeit viele Module dazugekommen. Dabei sind gleiche Dinge mehrfach und verschieden gebaut worden: drei Wochenansichten auf Home plus eine im Plan-Tab, drei Darstellungen derselben Plan-Einheit, zwei Pausen-Screens, zwei Übungsauswahlen, eine Trainingsuhr in drei Größen, die im Zirkel verschwindet. Man weiß nicht immer, wo man ist und wohin man kommt.

Ziel: Für gleiche Themen gibt es überall dieselbe Darstellung. Die App wird übersichtlicher, ohne neu auszusehen.

## Prämissen

1. **Kein Redesign.** Der Look bleibt. Wo es zwei Varianten gibt, gewinnt die bessere vorhandene und wird überall verwendet.
2. **Ein Thema, ein Baustein.** Kalenderzelle, Einheiten-/Trainingskarte, Detail-Kopf, Pausen-Screen, Übungsauswahl, Trainingsuhr, Ablaufzeile existieren je einmal.
3. **Home ist Kurzansicht, Plan-Tab ist der Trainingskalender.** Alles Planerische auf Home springt in den Plan-Tab; Home hat keine eigene Detail-Logik.
4. **Eine Einheit sieht überall gleich aus** – Name, Muskelmännchen, Kurzinfo –, egal ob vergangenes Training oder geplante Einheit. Unterschied ist nur der Zustand (erledigt / geplant / verpasst).
5. **Im Training ein Ablauf, Modi sind Varianten.** Frei, Plan, Zirkel, Cardio unterscheiden sich im Inhalt, nicht in Form und Position von Pause, Uhr, Satzeingabe.
6. **Jede Information nur einmal pro Screen.** Kein doppeltes Zählen, kein doppeltes „Zahl prüfen“, ein Hauptknopf.

## Nicht-Ziele

- Neues visuelles Design, neue Farben, neue Typografie.
- Einheiten selbst umbenennen (bewusst weggelassen).
- Adaptive Planung (siehe „Später“).
- Produkt-Hinweise auf den Tracker.
- Änderungen am Trainings-Abschluss-Screen (`TrainingAbschlussView`).

## Anti-Ziele (wäre ein Fehlschlag, auch wenn es technisch läuft)

- Ein neuer Baustein, der neben dem alten weiterlebt – danach gibt es wieder zwei.
- Eine Information wandert und taucht danach an zwei Stellen auf.
- Mitglieder ohne Tracker sehen irgendetwas zum Tracker im Training.
- Zwei Einheiten auf einem Tag durch das Verschieben.

---

## Paket 1 – Home, Plan, Einheit

### 1.1 Home (von oben nach unten)

1. **Streak-Woche** (`HomeSerieView.wochenstreifen`) bleibt: Serie, Ziel, Hantel an trainierten Tagen. Neu: geplante Tage (Kraft, Cardio, Kurs) bekommen eine dezente Markierung, mit denselben Symbolen wie im Plan-Tab.
   - Tipp auf vergangenen Tag: dessen Trainings erscheinen darunter (wie heute).
   - Tipp auf heutigen oder künftigen Tag: Sprung in den Plan-Tab auf genau diesen Tag (`PlanSprung.tag`).
2. **Trainings der Woche** als Trainingskarte (siehe 1.4) darunter, wie heute. Tipp → Training-Detail.
3. **Nächste Einheit**: eine Karte mit Name und Tag, z. B. „Schulter & Bauch · Freitag“. Ersetzt „Heute dran“ (`HeuteDranZeile`) und „Als nächstes“ (`HomeNaechsterKarte`).
   - Tipp → Plan-Tab, Einheiten-Detail dieser Einheit.
   - Ist die Einheit heute geplant: zusätzlich Knopf „Training starten“. Sonst kein Start-Knopf auf Home.
   - Vorziehen geht über Plan-Tab oder Training-Tab.
   - Ist der nächste Termin ein Kurs oder Cardio, zeigt die Karte diesen (wie `HomeNaechsterKarte` heute).
4. Rest von Home unverändert.

**Entfällt auf Home:** Monatsansicht (`monatsgitter`, Umschalter), Karte „Diese Woche“ (`HomeWocheKarte`), „Heute dran“.

### 1.2 Plan-Tab als Trainingskalender

- Wochenstreifen (`KurseWochenstreifen`) wie heute, wischbar jetzt auch in die Vergangenheit.
- Umschalter Woche/Monat. Das Monatsgitter zieht von Home hierher um (nicht neu bauen).
- Alle Kalender (Home-Streak-Woche, Plan-Woche, Plan-Monat, Kurse) nutzen `Kalenderzelle` mit denselben Marken für trainiert, geplant, Kurs, Cardio, verpasst.
- Inhalt unter dem gewählten Tag:
  - **Vergangen:** erledigte Trainings als Trainingskarte → Training-Detail (dieselbe View wie von Home, im Plan-Stack). Verpasste Termine als „verpasst“ (bei Kraft/Cardio mit „verschoben auf <Tag>“).
  - **Heute:** Erledigtes und Geplantes gemischt.
  - **Künftig:** geplante Einheiten, Cardio, Kurse. Einheiten als Einheitenkarte → Einheiten-Detail.

### 1.3 Verschieben verpasster Termine

Grundsatz aus der Plan-Spec bleibt: Die Einheiten sind eine **Folge**, kein Kalender; es gibt keine Nachholschuld. Neu ist, dass der Kalender diese Folge auf die kommenden Slots abbildet.

- **Slot** = ein Trainingstag des Wochenrasters (`Rasterplatz`) des passenden Typs, nicht der nächste Kalendertag.
- **Krafteinheiten** verteilen sich in Reihenfolge auf die kommenden **Kraft-Slots**. Wird eine verpasst, rückt sie auf den nächsten Kraft-Slot, alle folgenden rücken je einen Kraft-Slot weiter. Cardio-Slots werden dabei nicht belegt.
  - Beispiel: Kraft Mo/Di/Do, Cardio Sa. Di verpasst, heute Mi → Di-Einheit auf Do, Do-Einheit auf Mo nächster Woche. Sa bleibt Cardio.
- **Cardio** bleibt auf seinem Slot. Eine verpasste Cardio-Einheit rückt auf den nächsten Cardio-Slot (Annahme, nach derselben Logik).
- **Kurse** haben feste Termine, verschieben sich nie; nicht besucht = „verpasst“.
- Nie zwei Einheiten an einem Tag.
- Wird eine Einheit an einem Nicht-Slot-Tag trainiert, gilt sie als erledigt (F5); die nächste bleibt auf ihrem Slot.
- Ein freies Training ohne Plan an einem Kraft-Tag: Der Tag gilt als trainiert, nicht als verpasst. Die Einheit bleibt offen und rückt auf den nächsten Kraft-Slot (Entscheidung Claude).
- „Verpasst“ wird ab Erstellung des aktuellen Plans angezeigt, ohne Begrenzung nach hinten; vor dem Plan gibt es keine Slots (Entscheidung Claude).
- Der verpasste Tag bleibt sichtbar: ausgegraut, „verpasst · verschoben auf Do“.
- **Folge vor Raster (Entscheidung Claude, aus dem Gespräch abgeleitet):** Die feste Zuordnung `Rasterplatz.einheitKey` ist nur noch die Startbelegung. Angezeigt wird die Folge ab `naechsteEinheitKey`, gelegt auf die kommenden Kraft-Slots. Onboarding und Plan-Vorschau zeigen weiter die Startbelegung.
- **Daten:** Heute kennt die App nur die Zahl `einheitenErledigt`, nicht „welche Einheit an welchem Tag“. Für „Erledigt“ an der richtigen Karte, „verpasst“ und den Blick zurück braucht es eine Liste Datum → erledigte Einheit. Woher sie kommt (Server-Feld vs. Auswertung der `plan`-Momentaufnahme der Sätze), entscheidet der Builder; eine API-Änderung ist zulässig.

### 1.4 Einheiten- und Trainingskarte (ein Baustein)

Ein Kartenbaustein für vergangenes Training und geplante Einheit, Grundlage ist die heutige `tageskarte` (`HomeSerieView.swift:452`):

- Name, Kurzinfo, kleines Muskelmännchen (`MuskelFigur`, kompakt).
- Kurzinfo Training: Dauer · Sätze, Uhrzeit · Geräte (wie heute).
- Kurzinfo Einheit: „6 Übungen · ca. 50 Min“, bzw. Fortschritt / „Erledigt“.
- Zustand: erledigt / geplant / verpasst.

Ersetzt: `einheitKarte` (`PlanTagListe.swift:88`), `HeuteDranZeile`, `HomeNaechsterKarte` (Inhalt), Kopf von `PlanKarte` im Training-Tab.

### 1.5 Namen

- „Einheit A/B“ und „Oberkörper A“ (`EinheitName`) fallen weg.
- Der Name kommt immer automatisch aus den Muskeln der Übungen, mit derselben Logik wie bei vergangenen Trainings (`TrainingsProfil`, Titel-Logik `TrainingsProfil.swift:90–110`): „Ganzkörper“, „Oberkörper“, „Brust, Trizeps“, „Schulter, Bauch“ …
- Tausch einer Übung ändert den Namen mit.
- Kein eigenes Umbenennen.
- Ergeben zwei Einheiten eines Plans denselben Namen (z. B. zweimal „Ganzkörper“), bekommt jede einen Zusatz mit ihrem stärksten Baustein: „Ganzkörper · Schwerpunkt Beine“ (Entscheidung Claude, Tim hat „so umsetzen“ freigegeben).
- Texte, die heute A/B nennen (`PlanStrukturText`, Hinweis in `PlanEinheitView`), werden auf die neuen Namen umgestellt.

### 1.6 Detail-Screens

Training-Detail (`SessionDetailView`) und Einheiten-Detail (`PlanEinheitView`) bekommen denselben Kopf:

- Name, Kurzinfo, großes Muskelmännchen (volle Breite, Vorder- und Rückseite, Farben und Legende wie Fortschritt › Muskulatur, `MuskelgruppenUebersichtView`).
- Training: zeigt, was belastet wurde. Einheit: zeigt, was belastet wird.
- Darunter: Training → Blöcke mit tatsächlichen Sätzen (wie heute). Einheit → Übungsliste mit Vorgaben, „Warum diese Einheit so aussieht“, Bearbeiten/Tauschen, Start.

### 1.7 Bug: „Erledigt“ bei Einheiten

`einheitenErledigt` ist fest `[]` (`HomeWocheKarte.swift:144`, `PlanRootView.swift:134`). Erledigte Einheiten werden nirgends als erledigt angezeigt. Wird mit Paket 1 behoben.

### 1.8 Navigation

- Home springt per `beiPlanZeigen(PlanSprung)` in den Plan-Tab (vorhanden, wird weiterverwendet).
- `SessionDetailView` muss zusätzlich im Plan-Stack erreichbar sein.
- Doppelte Route `KursDetailView` (Home- und Haupt-Stack) aufräumen – Entscheidung des Builders, ob zusammenlegen.

---

## Paket 2 – Trainingsablauf

### 2.1 Ein Pausen-Screen für alle Modi

Ersetzt `PausenRad` in `GeraetView` (frei, Plan) und `ZirkelPauseView` (Zirkel). Vorbild ist der Zirkel-Screen.

- **Kopfzeile:** wie am Gerät (2.3).
- **Ablaufzeile** (2.4).
- **Pausen-Ring:** kleiner als heute (Zirkel-Größe, heute 140 pt), „+30 s“ direkt am Ring.
- **Ablauf-Liste:** die letzten 1–2 erledigten Übungen mit Sätzen darüber, die nächsten 1–2 darunter, „Alle anzeigen“ klappt den Rest aus. Gilt in allen Modi; im freien Training gibt es nur „erledigt“ und den nächsten Satz. Jede Zeile mit kleinem Standbild der Übung (wie die Planzeilen in `PlanKarte`), kein Video. Ersetzt die Rundenzusammenfassung im Zirkel.
- **Knöpfe, immer:**
  - Ein Hauptknopf für das, was als Nächstes dran ist: „Satz 3 starten“ bzw. „Beinpresse starten“. Er beendet die Pause; ein eigenes „Pause überspringen“ gibt es nicht.
  - „± Gewicht“ (heute `GewichtAendernSheet`), jetzt auch im Zirkel.
  - „Übung abschließen“ / „Nächste Übung“: Sätze reichen, weiter.
- **Nur frei:** „Zirkel mit weiterem Gerät“.
- **Nur Zirkel:** „Überspringen“ (nächste Station überspringen), „+ Übung zum Zirkel“, „Zirkel beenden“ (alle Stationen beenden, Training läuft weiter).
- **Entfällt:** „Letztes Mal“, Übungsvideo, die zwei übereinander stehenden Primary-Knöpfe.
- **Ziel erreicht (Plan):** Sind die geplanten Sätze geschafft, wird der Hauptknopf zu „Nächste Übung: <Name>“, „Weiterer Satz“ bleibt als zweiter Knopf. „Übung abschließen“ entfällt in diesem Zustand, damit keine zwei Knöpfe dasselbe tun (Entscheidung Claude). Jeder Weg aus einer Übung läuft über die Abfrage aus 2.6.

### 2.2 Trainingsuhr

- Am Gerät, in der Pause, in Zirkel-Pause und Zirkel-Übersicht immer in derselben Kopfzeile, in derselben Form (`TrainingsuhrText` + `Laufpunkt`).
- Antippen → Steuerungs-Sheet mit „Training beenden“ (wie heute am Gerät).
- Home und Training-Tab behalten ihre Darstellung (Übersicht, nicht Arbeitsansicht).

### 2.3 Kopfzeile am Gerät und in der Pause

Ort · Tracker-Symbol (nur wenn Tracker eingerichtet, 3.2) · Trainingsuhr. Ein Baustein für Gerät und Pause.

### 2.4 Ablaufzeile

Direkt unter dem Übungsnamen am Gerät und über der Ablauf-Liste in der Pause:

| Modus | Text |
|---|---|
| Plan | Übung 3 von 6 · Satz 2 von 3 |
| Zirkel | Station 2 von 4 · Runde 1 von 3 |
| Frei | Satz 2 |

- Das Plan-**Ziel** steht nicht in der Ablaufzeile, sondern an den Rädern: „Ziel 8–10“ am Wiederholungsrad (dort steht heute schon ein Ziel), „Plan 40 kg“ als Kontextzeile am Gewichtsrad.
- Antippen klappt die Ablauf-Liste aus (wie in der Pause). Zunächst nur als Ansicht, ohne Springen in eine andere Übung (Entscheidung Claude, hält Paket 2 klein; Springen kann später kommen).

### 2.5 Übungsauswahl

`ZirkelUebungswahlSheet` und `PlanTauschListe` nutzen dieselben Bausteine wie die normale Übungsauswahl (`UebungsAnsichtBereich`, `UebungsGruppierung`, `FilterBausteine`): Muskelgruppen-Abschnitte, Segment Muskeln/Favoriten, „letzter Satz“ (`UebungsUntertitel`), Sortierung nach Verlauf. Beim Plan-Tausch bleibt die Kandidatenmenge aus `PlanTausch.kandidaten`, nur die Darstellung wird vereinheitlicht. Die Geräteauswahl (`GeraeteAuswahlView`) ist schon einheitlich.

### 2.6 Abschluss einer Übung

Dieselbe Abfrage in allen Modi: „n Sätze geschafft“ plus Reserve-Frage (`ReserveSkala`). Im Zirkel einmal pro Station am Zirkelende, nicht nach jeder Runde (Annahme). Der Trainings-Abschluss bleibt unverändert.

---

## Paket 3 – Gerät mit Tracker

### 3.1 Einrichtung im Profil

- Der Tracker wird einmalig im Profil verbunden.
- Erst wenn ein Tracker gemerkt ist (`BluetoothSensorQuelle.hatGemerktenSensor`), erscheint im Training irgendetwas zum Tracker. Ohne Tracker: nichts.

### 3.2 Im Training

- Die große `SensorKarte`/`SensorZeile` wird zu einem Tracker-Symbol in der Kopfzeile: grün = verbunden, grau = nicht verbunden. Kein Rot.
- Antippen → kleines Blatt mit Verbindungsstatus und Schalter „Sätze automatisch starten und sichern“. Sonst nichts.
- Automatik aus: Der Tracker startet und sichert keine Sätze und zählt nicht ins Rad; Sätze werden wie ohne Tracker von Hand gesichert. Sensordaten werden weiter aufgezeichnet (Entscheidung Claude).
- **Entfällt:**
  - „zählt · n“ (das Wiederholungsrad dreht live mit).
  - Knöpfe „Satz Start“ / „Satz Ende“.
  - Doppeltes „Zahl prüfen“ in der Sensorzeile; es bleibt nur am Rad (`WertZeile`).
  - Befestigungsmenü; die Befestigung ergibt sich aus der Übung (`Befestigungsart.vorschlag`). Schon gespeicherte Wahlen bleiben gültig; liefert eine Übung keinen Vorschlag, zählt der Tracker dort still nicht, und die Übung wird für die Zuordnung protokolliert (Entscheidung Claude).
  - Sensor-Einstellungen und -Diagnose hinter der Karte.
  - Sensorblock in der Pause.
- **Bleibt:** „Sichern nach Ruhe · n s“, solange an der Erkennung gearbeitet wird.
- Sensordaten werden weiter gespeichert; Abweichungen korrigiert man von Hand am Rad.

### 3.3 Übungsvideo am Gerät

Das große Übungsvideo oben im Gerät-Screen fällt weg (alle Modi). Stattdessen ein kleines Vorschaubild links neben dem Übungsnamen; Antippen öffnet das Video. (Tim, 05.11.)

### 3.4 Plan-Kontext am Gerät

Siehe Ablaufzeile (2.4) und Ziel an den Rädern.

---

## Mockups

Design-Canvas „Gymtavo UX-Vereinheitlichung“: https://claude.ai/artifact/6wzr9m7KFANPy2Ap5tKBEK (Home, Plan-Tab, Einheiten-Detail, Gerät, Pause Plan, Pause Zirkel). Das Muskelmännchen dort ist ein Platzhalter für die vorhandene `MuskelFigur`.

## Später (nicht jetzt bauen)

- **Adaptive Planung:** Nach einer verpassten Einheit oder einem anderen Training als geplant (z. B. Cardio statt Brust/Trizeps) passen sich die nächsten Tage an: keine Doppelung, ggf. Regeneration oder leichtere Einheit.
- **Tracker-Hinweise:** gelegentlich ein dezenter Hinweis mit Link zum Produkt für Mitglieder ohne Tracker.

## Reihenfolge

Paket 1 → Paket 2 → Paket 3, jeweils als eigener Plan und eigener PR. Paket 3 ist weitgehend unabhängig und kann vorgezogen werden.

## Dem Builder überlassen

- Technischer Zuschnitt der gemeinsamen Bausteine und deren Dateiablage.
- Wie die Slot-Verschiebung berechnet wird (App oder Server), solange die Regeln aus 1.3 gelten.
- Genaue Größen innerhalb des vorhandenen Design-Systems.
- Testaufbau; bestehende Tests der ersetzten Views werden auf die neuen Bausteine umgezogen, nicht gelöscht.
