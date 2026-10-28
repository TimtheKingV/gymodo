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
- Unter der Karte steht "Übung hinzufügen" (gestrichelter Rand). Einen eigenen Knopf "Training beenden" gibt es dort nicht; beendet wird wie bisher über den Pausenknopf im Kopf ("Pausieren / Training beenden").
- Jede Planzeile (offen oder erledigt) hat rechts einen Griff (drei Balken, 44 pt Tippfläche) zum Umsortieren. Umsortiert wird nur am Griff: 0,15 s gedrückt halten, dann ziehen; für VoiceOver gibt es Aktionen "Nach oben/unten". Zusatz-Zeilen sind nicht verschiebbar, aber antippbar (öffnet ihren Block wieder).
- Die Reihenfolge gilt nur für diese Session. Sie ist die Reihenfolge von `PlanLauf.zustand.positionen` (der gespiegelte `AblaufZustand`, kein eigenes Feld) und geht in dieser Reihenfolge mit jeder Momentaufnahme raus. Für den Server ist das harmlos: `record_session_plan` speichert eine Zeile je Schlüssel. Der gespeicherte Plan bleibt unverändert.
- Fortschrittsmarke: offen = leerer Kreis; angefangen = "n/m" in Akzent, solange 0 < gemachte Sätze < Vorgabe (Kraft, jeder Status außer ausgelassen; der Ablauf hakt die Position schon mit dem ersten Satz ab, die Zeile ist dann weder durchgestrichen noch gedimmt); ab n = m der normale Erledigt-Look (Haken, durchgestrichen).

### Übung antippen (Entwurf 2)
Sheet mit Name, Fortschrittszeile ("2 von 3 Sätzen gemacht · 3 × 8–12") und zwei Aktionen. Übergaben (Start, Auswahl) laufen in `onDismiss` des Sheets:
- **Weiter mit Satz X** (bei null Sätzen "Übung starten"): gibt es schon einen Block der Übung in der Session, öffnet sie den neuesten wieder (Fix für Punkt 4; derselbe Weg wie eine Zusatz-Zeile). Sonst Start über `PlanStart.ziel` (siehe Gerät).
- **Andere Übung wählen**: öffnet die normale Auswahl. Nur an Positionen, die heute noch tauschbar sind (offen oder heute getauscht); eine angefangene Position (nach dem ersten Satz erledigt) bietet es nicht an.

### Andere Übung wählen (Entwurf 3 und 4)
- Auswahl wie die bestehende (Kategorie → Gerät → Übung). Oben "Passend zum Plan" (Kandidaten desselben Bausteins, wie die heutige Tauschliste) und "Ohne Ersatz auslassen".
- Nach der Wahl (oder "Ohne Ersatz auslassen") kommt die Frage "Warum wechselst du?" mit genau drei Optionen, ohne Erklärtexte:
  - **Heute auslassen** und **Belegt**: gleiches Verhalten, gilt nur heute. Die Position wird heute durch die gewählte Übung ersetzt (bei "ohne Ersatz": heute ausgeblendet, zählt nicht). Keine Wirkung auf den Plan oder künftige Einheiten.
  - **Übung gefällt mir nicht**: gibt es nur zusammen mit einem Ersatz, denn der Server kennt kein Entfernen einer Position, nur Tauschen. Wie der heutige dauerhafte Tausch mit `grund: gefaellt_nicht` (neue Planversion, alte Übung auf die Merkliste). Ohne Ersatz zeigt die Frage nur "Heute auslassen" und "Belegt".
  - Der Server prüft, dass ein dauerhafter Ersatz zum Baustein der Position passt (422 "passt nicht an diese Stelle"). Dann zeigt das Sheet den Fehler und bietet "Nur heute" an.
  - Dieselbe Übung wie die heutige der Position ist nicht wählbar (Hinweis "Das ist schon die Übung von heute."), ebenso eine Übung, die schon an einer anderen Position der Einheit steht, geplant oder heute getauscht (Hinweis "Diese Übung steht schon in deinem Plan.").
  - Ein Ersatz erscheint in derselben Zeile ("Heute: X"), nicht als neue Zeile.
  - "Gefällt mir nicht" mitten in der Einheit: die laufende Einheit behält ihre Planversion, die Zeile wechselt aber heute schon auf den Ersatz (wie "Heute auslassen" mit Ersatz). Vor dem ersten Satz ersetzt die neue Version den Ablauf; heutige Tausche, Auslassungen und die Reihenfolge gehen mit (bekannte Schlüssel in alter Reihenfolge, neue hinten an, unbekannte fallen weg).
- Der Zustand "optional" aus dem Überspringen entfällt für diesen Weg: Ersetzen statt Zuzählen (Punkt 1).
- "Belegt" setzt bewusst nicht mehr `nicht_vorhanden` für den Plan; es hat keine dauerhafte Wirkung.

### Übung hinzufügen
- Öffnet dieselbe Auswahl. Die Übung wird als heutige Zusatzübung geführt (wie "Zusätzlich gemacht" heute) und kommt nicht in den Plan. Nach dem Auswählen startet sie direkt.
- Zusatz-Zeilen werden nicht umsortiert; sie stehen unter dem Plan und lassen sich antippen.
- Im Planmodus (Session mit Plan) sind die Listen Kategorien/Zuletzt ausgeblendet.

### Gerät
- Hat die Übung am Ort genau ein Gerät: keine Gerätewahl, direkt hinein. Ohne Gerät (`.keine`) gibt es keinen Direktstart: die Auswahl öffnet mit ihrem Leerzustand.
- Gibt es mehrere Geräte: Auswahl der Geräte, mit Scan/QR als Alternative (wie der bestehende Einstieg).
- Ohne Studio (freies Training) hat Tim "meist egal"; die Regel oben gilt auch dort.
- Welches Gerät bei der Annahme "nur eins" verwendet wird, ist das einzige.

## Randfälle (zu prüfen durch den Builder)
- Offline: Sofortige Wirkung nur heute (Ablaufzustand) funktioniert offline; die dauerhafte Wirkung braucht Verbindung wie der bestehende Tausch (`PlanTauschSitzung`: online prüfen, Fehlerzustand).
- Eine bereits begonnene Position (nach dem ersten Satz erledigt) ist nicht ersetzbar (`tauschbar` false).
- Neue Planversion während der Session: ein gebundener Lauf (ab dem ersten Satz) behält seine Version; ein Abgleich der Schlüssel findet dort nicht statt.

## Annahmen, die Tim bestätigen soll
1. Erledigte Planzeilen sind verschiebbar; Zusatz-Zeilen nicht (so umgesetzt).
2. "Gefällt mir nicht" gibt es nur mit Ersatz (so umgesetzt; ein reines Entfernen kennt der Server nicht).
3. Wählbare Auswahlmenge im Tauschweg: Kandidaten wie bisher (gleicher Baustein, Studio-/Ortsbestand) oben, danach der volle Katalog.

## Entscheidungen von Claude (nach Prüfung, bitte gegenlesen)
1. **Altes "Überspringen":** Die eigene Skip-Aktion entfällt überall; "Heute auslassen" im Grund-Dialog ersetzt sie. Die Regel "ungeplante Übung gemacht → genau eine verwandte offene Position wird optional" bleibt unverändert (sie greift, wenn Tim ohne Menü etwas anderes trainiert). Status `optional` bleibt im Modell, keine Migration.
2. **Freies Training:** "Geräte der Übung" sind die Katalogmodelle der Übung am aktuellen Ort. Gibt es genau eins, wird ohne Wahl gestartet; bei 0 öffnet die Auswahl mit Leerzustand. Gibt es mehrere, kommt Auswahl mit Scan/QR. Ob das Gerät im Satzmodell optional werden muss, klärt der Builder; Vorgabe ist: nicht, das Katalogmodell der Position genügt.
3. **Ersetzen:** Nur offene oder heute getauschte Positionen (Status `getauscht`, Zeile "Heute: X"). Eine angefangene Position ist schon erledigt und wird nicht ersetzt.
4. **Reihenfolge:** die Reihenfolge von `PlanLauf.zustand.positionen` (ohne Zusatzübungen). Abgleich nur vor dem ersten Satz, wenn eine neue Version den Lauf ersetzt (siehe oben); ein gebundener Lauf behält seine Version.
5. **"Ohne Ersatz auslassen":** Die Zeile bleibt gedimmt und durchgestrichen mit "ausgelassen" sichtbar. Antippen öffnet das Sheet, dort kann der Auslass zurückgenommen werden ("Doch machen"). "Ausgelassen" lebt app-lokal in `PlanLauf` und zählt nicht in "x von N", die Restminuten und den Abschluss (so umgesetzt; bisher stand hier "zählt als erledigt").
6. **Hinzufügen:** Die Auswahl zeigt ohne "Passend zum Plan", ohne "Ohne Ersatz auslassen" und ohne Grund-Frage. Eine Zusatz-Zeile öffnet beim Antippen direkt ihren Block (kein Sheet); erledigte Planzeilen haben im Sheet nur "Weiter mit Satz X".
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
