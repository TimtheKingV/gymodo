# Ablauf im geplanten Training: Design

Stand: 2026-10-28. Entwürfe: https://claude.ai/artifact/7c3gp1LtFwYQfWqBDyaRuZ (5 Bildschirme; Quelle der Optik, nicht der Logik).

## Anlass

Tim hat mit dem Trainingsplan trainiert (freies Training, kein Studio) und fünf Dinge erlebt:

1. Eine Übung, die ihm nicht gefiel, wurde nur "optional"; die Ersatzübung zählte als zusätzlich. Erwartet war: Ersetzen im Plan.
2. Unter dem Plan stehen "Aus Katalog wählen" und "Zuletzt trainiert". Im Planmodus stört das.
3. Die Reihenfolge ließ sich nicht ändern (Gerät belegt).
4. Nach zwei von drei Sätzen kam er nicht mehr in die Übung zurück.
5. Nach "Übung starten" musste er noch ein Gerät wählen, obwohl es meist egal ist.

## Ziel

Der Plan ist beim Training der Rahmen, nicht das Gerüst: Tim kann ersetzen, ergänzen, umsortieren, jederzeit in eine angefangene Übung zurück und startet ohne Umweg.

## Nicht-Ziele

- Rotation/Variation der Pläne, Mini-Zirkel in Einheiten, "Übung wird wieder Option, wenn sie doch gemacht wird". Eigenes Vorhaben (Memory `plan-rotation-offen`).
- Kein Umbau der Gewichtsvorschläge, des Kalenders oder der Planerstellung.
- Keine Änderung der Reihenfolge im gespeicherten Plan.

## Verhalten

### Plan im Training (Entwurf 1)
- Läuft ein Training mit Plan, entfallen unter der Plankarte die Bereiche "Aus Katalog wählen" und "Zuletzt trainiert" (Geräte-/Block-Liste des Tabs). Ohne Plan bleibt der Tab wie heute.
- Unter der Karte steht "Übung hinzufügen" (gestrichelter Rand) und darunter "Training beenden".
- Jede Planzeile (offen oder erledigt) hat rechts einen Griff (drei Balken, 44 pt Tippfläche) zum Umsortieren. Umsortiert wird nur am Griff: 0,15 s gedrückt halten, dann ziehen; für VoiceOver gibt es Aktionen "Nach oben/unten". Zusatz-Zeilen sind nicht verschiebbar, aber antippbar (öffnet ihren Block wieder).
- Die Reihenfolge gilt nur für diese Session und lebt app-lokal in `PlanLauf` (nicht im gespiegelten `AblaufZustand`, kein Server-Feld). Der gespeicherte Plan bleibt unverändert.
- Fortschrittsmarke: erledigt = Haken, angefangen = "2/3" in Akzent, offen = leerer Kreis.

### Übung antippen (Entwurf 2)
Sheet mit Name, Fortschrittszeile ("2 von 3 Sätzen gemacht · 3 × 8–12") und zwei Aktionen. Übergaben (Start, Auswahl) laufen in `onDismiss` des Sheets:
- **Weiter mit Satz X** (bei null Sätzen "Übung starten"): startet direkt in der Übung (über `PlanStart.ziel`), auch wenn schon Sätze da sind (Fix für Punkt 4). Kein Zwischenschritt, keine Gerätewahl, sofern keine Wahl nötig ist (siehe Gerät).
- **Andere Übung wählen**: öffnet die normale Auswahl.

### Andere Übung wählen (Entwurf 3 und 4)
- Auswahl wie die bestehende (Kategorie → Gerät → Übung). Oben "Passend zum Plan" (Kandidaten desselben Bausteins, wie die heutige Tauschliste) und "Ohne Ersatz auslassen".
- Nach der Wahl (oder "Ohne Ersatz auslassen") kommt die Frage "Warum wechselst du?" mit genau drei Optionen, ohne Erklärtexte:
  - **Heute auslassen** und **Belegt**: gleiches Verhalten, gilt nur heute. Die Position wird heute durch die gewählte Übung ersetzt (bei "ohne Ersatz": heute ausgeblendet, zählt nicht). Keine Wirkung auf den Plan oder künftige Einheiten.
  - **Übung gefällt mir nicht**: gibt es nur zusammen mit einem Ersatz, denn der Server kennt kein Entfernen einer Position, nur Tauschen. Wie der heutige dauerhafte Tausch mit `grund: gefaellt_nicht` (neue Planversion, alte Übung auf die Merkliste). Ohne Ersatz zeigt die Frage nur "Heute auslassen" und "Belegt".
  - Der Server prüft, dass ein dauerhafter Ersatz zum Baustein der Position passt (422 "passt nicht an diese Stelle"). Dann zeigt das Sheet den Fehler und bietet "Nur heute" an.
  - Dieselbe Übung wie die heutige der Position ist nicht wählbar (Hinweis "Das ist schon die Übung von heute.").
- Der Zustand "optional" aus dem Überspringen entfällt für diesen Weg: Ersetzen statt Zuzählen (Punkt 1).
- "Belegt" setzt bewusst nicht mehr `nicht_vorhanden` für den Plan; es hat keine dauerhafte Wirkung.

### Übung hinzufügen
- Öffnet dieselbe Auswahl. Die Übung wird als heutige Zusatzübung geführt (wie "Zusätzlich gemacht" heute) und kommt nicht in den Plan. Nach dem Auswählen startet sie direkt.
- Zusatz-Zeilen werden nicht umsortiert; sie stehen unter dem Plan und lassen sich antippen.
- Im Planmodus (Session mit Plan) sind die Listen Kategorien/Zuletzt ausgeblendet.

### Gerät
- Hat die Übung für den Ort nur kein oder genau ein Gerät: keine Gerätewahl, direkt hinein.
- Gibt es mehrere Geräte: Auswahl der Geräte, mit Scan/QR als Alternative (wie der bestehende Einstieg).
- Ohne Studio (freies Training) hat Tim "meist egal"; die Regel oben gilt auch dort.
- Welches Gerät bei der Annahme "nur eins" verwendet wird, ist das einzige (oder das Katalogmodell der Position, `modelId`).

## Randfälle (zu prüfen durch den Builder)
- Offline: Sofortige Wirkung nur heute (Ablaufzustand) funktioniert offline; die dauerhafte Wirkung braucht Verbindung wie der bestehende Tausch (`PlanTauschSitzung`: online prüfen, Fehlerzustand).
- Eine bereits begonnene Position (Sätze gespeichert) wird ersetzt: die gemachten Sätze bleiben gespeichert und zählen als Zusatz.
- Planwechsel/neue Planversion während der Session: bestehende Regeln der Ablaufstores gelten weiter.

## Annahmen, die Tim bestätigen soll
1. Erledigte Planzeilen sind verschiebbar; Zusatz-Zeilen nicht (so umgesetzt).
2. "Gefällt mir nicht" gibt es nur mit Ersatz (so umgesetzt; ein reines Entfernen kennt der Server nicht).
3. Wählbare Auswahlmenge im Tauschweg: Kandidaten wie bisher (gleicher Baustein, Studio-/Ortsbestand) oben, danach der volle Katalog.

## Entscheidungen von Claude (nach Prüfung, bitte gegenlesen)
1. **Altes "Überspringen":** Die eigene Skip-Aktion entfällt überall; "Heute auslassen" im Grund-Dialog ersetzt sie. Die Regel "ungeplante Übung gemacht → genau eine verwandte offene Position wird optional" bleibt unverändert (sie greift, wenn Tim ohne Menü etwas anderes trainiert). Status `optional` bleibt im Modell, keine Migration.
2. **Freies Training:** "Geräte der Übung" sind die Katalogmodelle der Übung am aktuellen Ort. Gibt es 0 oder 1, wird ohne Wahl gestartet; bei 0 mit dem Katalogmodell der Position (`modelId`). Gibt es mehrere, kommt Auswahl mit Scan/QR. Ob das Gerät im Satzmodell optional werden muss, klärt der Builder; Vorgabe ist: nicht, das Katalogmodell der Position genügt.
3. **Ersetzte Position mit schon gemachten Sätzen:** Die Zeile zeigt "heute getauscht" (vorhandener Status `getauscht`); die Ersatzübung erscheint als neue Zeile an gleicher Stelle mit 0 von N. Bereits gespeicherte Sätze der alten Übung bleiben unter "Zusätzlich gemacht".
4. **Reihenfolge:** `PlanLauf` hält die Reihenfolge der Positionsschlüssel (ohne Zusatzübungen). Bei neuer Planversion mitten in der Session werden Schlüssel abgeglichen: unbekannte verschwinden, neue kommen ans Ende.
5. **"Ohne Ersatz auslassen":** Die Zeile bleibt gedimmt und durchgestrichen mit "ausgelassen" sichtbar. Antippen öffnet das Sheet, dort kann der Auslass zurückgenommen werden ("Doch machen"). "Ausgelassen" lebt app-lokal in `PlanLauf` und zählt nicht in "x von N", die Restminuten und den Abschluss (so umgesetzt; bisher stand hier "zählt als erledigt").
6. **Hinzufügen:** Die Auswahl zeigt ohne "Passend zum Plan", ohne "Ohne Ersatz auslassen" und ohne Grund-Frage. Das Sheet einer Zusatzzeile hat nur "Weiter mit Satz X"; erledigte Planzeilen haben dieselben zwei Aktionen wie offene.
7. **Server:** Der Ablaufstatus wird schon mitgesynct. Reihenfolge und Auslassen bleiben App-lokal; es gibt keine neuen Serverfelder. Der noch offene API-Deploy (siehe Memory `trainingsplan-stand`) wird dabei nicht vorausgesetzt.

## Bekannte Grenzen
- Kein Auto-Scroll beim Ziehen nahe den Rändern.
- Die Card beschneidet den Schatten der angehobenen Zeile.
- Der per UI nicht erreichbare `dauerhaft`-Schalterpfad (`dauerhaftSetzen`, `PlanTauschSchalter`, `dauerhaftHinweis`) bleibt im Code.
- Das SwiftUI-Timing der `onDismiss`-Übergaben und das Zusammenspiel von Ziehen und ScrollView sind nur durch Lesen geprüft, nicht auf einem Gerät. Manuelle Prüfung mit echtem Plan nötig: Direktstart mit einer Station, Picker-Kopf, Umsortieren, Zusatz-Zeile wieder öffnen.

## Dem Builder überlassen
- Konkrete Aufteilung in Etappen, Animationen des Verschiebens, Haptik.
- Wie der Zustand "heute ersetzt" im Ablaufspeicher modelliert wird (vorhanden: Status `getauscht`).
- Ob der Server für heutiges Umsortieren/Ersetzen etwas speichern muss (Ablaufstatus wird heute beim Sync mitgeschickt).

## Anhaltspunkte im Code (nicht verbindlich)
`Screens/Training/PlanKarte.swift`, `PlanZeile.swift`, `PlanPositionSheet.swift`, `Workout/PlanTausch.swift`, `TrainingsplanAblauf(Store).swift`, `Workout/GeraeteAuswahl.swift`, `Uebungsstart.swift`, `GeraetEinstieg.swift`, `Screens/Training/TrainingRootView.swift`; Server: `apps/web/app/api/v1/me/plans/[id]/swap/route.ts`. Bestehende Spec: `2026-10-21-trainingsplan-design.md` Abschnitt 5 ("Ungeplante Übung gemacht → optional", "Situativer Austausch") wird für diesen Weg überholt.
