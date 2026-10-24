# Mini-Zirkel – Design

Stand: 21.10.2026 · App: `apps/ios-member` (SwiftUI)

## Absicht und Warum

Tim baut im Training oft kleine Zirkel ein (Beispiel Freihantelbereich: je ein Satz Bizeps-Curls → Seitheben → Schrägbankdrücken, dann Runde 2 und 3 in gleicher Reihenfolge). Heute muss er dafür nach jedem Satz zurück in die Geräteauswahl, die Übung suchen und neu starten. Das ist nervig.

Ziel: Den Zirkel einmal anlegen, danach das Handy zur Seite legen und nur noch Wiederholungen eintragen. Nach der Eingabe läuft eine kurze Pause und der Screen zeigt auf einen Blick, welche Übung als Nächstes kommt.

## Ziele

- Nach der Geräteauswahl gibt es zwei Wege: „Direkt starten" (wie bisher) oder „Mini-Zirkel anlegen".
- Ein Zirkel besteht aus 2 oder mehr Übungen in fester Reihenfolge und einer Rundenzahl (Standard 3).
- Nach jeder Übung im Zirkel läuft eine kurze Pause (Standard 20 s), nach einer vollen Runde die Rundenpause (Standard: Satzpause aus dem Profil, 90 s).
- Der Pausenscreen zeigt die nächste Übung mit Thumbnail/Video, damit man sie auf einen Blick erkennt.
- Nachträglich erweitern, nur in Runde 1:
  - In der Pause nach der **letzten Zirkel-Übung** gibt es „+ Übung zum Zirkel".
  - In der Pause nach **Satz 1 einer Einzelübung** gibt es „Zirkel mit weiterem Gerät". Die aktuelle Übung wird Übung 1 des Zirkels.
- Gewicht und Wiederholungen werden beim Anlegen des Zirkels je Übung festgelegt (Stand 23.10.). Im Zirkel entfällt der Startwerte-Drawer; nur nachträglich hinzugefügte Übungen (Erweitern) fragen ihn noch. In Runde 2 und 3 werden die Werte aus der Vorrunde übernommen. Ändern bleibt möglich.
- Eingetragen wird nach jeder Übung, nicht gesammelt am Rundenende. In Runde 1 erscheint je Übung erst der Startwerte-Drawer (Gewicht), dann das Wiederholungs-Rad. In Runde 2+ entfällt der Drawer: das Wiederholungs-Rad erscheint sofort, das Gewicht ist aus der Vorrunde vorbelegt und über eine kleine Zeile änderbar. Wenn die Sensorerkennung sauber läuft, zählt sie automatisch; das ist ein späterer Schritt und nicht Teil dieses Projekts.

## Nicht-Ziele

- Keine Zirkel mit festen Zeiten („Station 40 s, Wechsel 20 s").
- Keine gespeicherten Zirkel-Vorlagen und kein Trainingsplan. Ein Zirkel lebt nur in der laufenden Einheit.
- Keine Änderung der Sensorerkennung.
- Keine neue Auswertung im Web/Trainerportal. Die Sätze werden wie normale Sätze gespeichert.

## Anti-Ziele (wäre ein Fehlschlag, auch wenn es technisch läuft)

- Der Zirkel darf den normalen Ablauf „Direkt starten" nicht verlangsamen oder verkomplizieren.
- Der Pausenscreen darf nicht überladen sein: Die Uhr wird kleiner, die nächste Übung ist das Wichtigste.
- Gesicherte Sätze dürfen nie verloren gehen, auch wenn der Zirkel abgebrochen wird.

## Entscheidungen von Tim

1. Auswahl nach Geräte-Wahl: zwei Buttons „Direkt starten" / „Mini-Zirkel anlegen".
2. Planungs-Screen als eigene Liste (Variante A): Übungen mit Umsortieren, „+ Übung hinzufügen", Rundenzahl, Pausen, Button „Zirkel starten".
3. Beim Anlegen sind **beide** Pausen frei wählbar: Pause zwischen Übungen und Rundenpause.
4. Profil: Neben „Pause zwischen Sätzen" kommt eine zweite Standard-Einstellung „Pause zwischen Übungen im Zirkel" (Vorgabe 20 s).
5. Pausenscreen im Zirkel: kleinere Uhr, „Als Nächstes" mit Thumbnail/Video.
6. Rundenpause: eigene Pause mit Zusammenfassung der Runde und Thumbnail der ersten Übung der nächsten Runde.
7. Nach der letzten Runde: dieselbe Übersicht wie nach dem letzten Satz einer Übung, Tim klickt auf „Weiter".
8. Eintragen nach jeder Übung (nicht gesammelt am Rundenende).
9. Gewicht und Wiederholungen je Übung werden beim Anlegen des Zirkels festgelegt (Drawer in der Planung). Im Zirkel gibt es keinen Startwerte-Drawer mehr; Runde 2+ übernimmt die Werte der Vorrunde. (Geändert 23.10.; vorher: Drawer je Übung in Runde 1.)

## Meine Annahmen (bitte prüfen)

- Rundenpause-Standard ist die Satzpause aus dem Profil.
- Jeder Satz im Zirkel wird wie ein normaler Satz der jeweiligen Übung gespeichert (ein Block je Übung in der Einheit, ein Satz je Runde). Es gibt keine neue Server-Tabelle für Zirkel.
- Im Zirkel gibt es „Übung überspringen" und „Zirkel beenden". Beenden behält alle bisher gesicherten Sätze und führt zur Übersicht.
- Fehlt das Video, zeigt der Pausenscreen das Geräte-/Übungsfoto oder ein Platzhalter-Symbol.
- Rundenzahl: 2–6, Standard 3.
- Die Abschlussübersicht nach der letzten Runde ist **eine** gemeinsame Zirkel-Übersicht (alle Übungen und Runden) mit einem „Weiter", nicht eine Übersicht je Übung. (Prüfer-Frage, meine Entscheidung.)
- „Übung überspringen" gilt nur für die aktuelle Runde. Es wird kein Satz gespeichert. Der Zirkel bleibt bestehen, auch wenn nur noch eine Übung übrig bleibt. (Meine Entscheidung.)
- Beim Erweitern läuft die laufende Pause weiter, während die Übung gewählt wird. Die neue Übung beginnt mit dem Startwerte-Drawer. Beim Erweitern gibt es keinen Planungs-Screen: Pausen kommen aus den Profil-Standards, die Rundenzahl ist 3 (beim Erweitern nach Satz 1 einer Einzelübung) bzw. die des bestehenden Zirkels. Die Zirkel-Übersicht lässt sich danach ändern. (Meine Entscheidung.)
- Der Builder muss prüfen, ob `GeraetModel` pro Übung neu erzeugt werden kann, ohne dass Sensor/Kopplung neu aufgebaut werden muss. Der Wechsel soll das Handy-Weglegen nicht unterbrechen.
- Beim Erweitern in Runde 1 gilt die neu hinzugefügte Übung ab der nächsten Runde als feste Zirkel-Übung; ihr erster Satz in Runde 1 wird sofort gemacht.

## Bestehender Code (Orientierung)

- `Screens/Geraet/GeraetModel.swift` und `GeraetView.swift`: Eine Übung pro Screen, Phasen `bereit`/`eingabe`/`pause`/`abschluss`. Die Pause kommt heute immer nach einem Satz derselben Übung.
- `DesignSystem/Components/PausenRad.swift`: Pausenanzeige.
- `Workout/Resttimer.swift`: Timer über Endzeitpunkt.
- `Einstellungen.swift` und `Screens/Profil/ProfilRootView.swift`: Schlüssel `resttimerSekunden`, Stufen 10–180 s, Vorgabe 90.
- `Workout/UebungsVideos.swift`: Videos je Übung, optional.
- `Workout/GeraeteAuswahl.swift`, `Workout/Uebungsstart.swift`, `Workout/WorkoutSessionStore.swift`: Auswahl, Start, Blöcke der Einheit.
- Neu nötig: eine Zirkel-Ablaufebene oberhalb des Geräte-Screens, die Reihenfolge, Runde und Pausen steuert.

## Dem Builder überlassen

Datenmodell der Zirkel-Ebene, Navigation zwischen den Übungen, Gestaltung im Detail (Abstände, Animation), Tests, Reihenfolge der Umsetzung, Umgang mit App-Neustart mitten im Zirkel (Verhalten soll zu „Training fortsetzen" passen).
