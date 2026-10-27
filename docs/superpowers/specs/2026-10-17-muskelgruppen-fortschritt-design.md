# Fortschritt nach Muskelgruppen – Design

Stand 17.10.2026 · Gesprächsergebnis mit Tim · Umfang: iOS-Member-App (Home)

## Wozu

Auf der Home-Seite zeigt „Übungsfortschritt“ heute Übung für Übung, ob es vorwärts geht. Tim will zusätzlich eine Sicht pro **Muskelgruppe**, die zwei Dinge leistet:

1. **Motivation:** auf einen Blick sehen, dass es vorwärts geht.
2. **Ausgewogenheit:** sehen, was man vernachlässigt hat, damit man gesund und ausgeglichen trainiert. Erst auf Ebene Brust / Rücken / Schultern / Arme / Rumpf / Beine, dann innerhalb einer Gruppe bei den Teilmuskeln.

Die Darstellung ist **schematisch mit den vorhandenen Muskel-SVGs** (Körper vorne und hinten), nicht nur Text.

Visueller Entwurf (von Tim gewählt: A als Start, C als Detail): `.superpowers/brainstorm/*/content/muskelgruppen-entwurf.html` (lokal, nicht eingecheckt).

## Ziele

- Toggle ganz oben im Bereich Übungsfortschritt: **Muskelgruppen | Übungen**. „Übungen“ ist die heutige Ansicht, unverändert (inklusive der Gruppen-Bullets).
- **Startansicht Muskelgruppen (Entwurf A):**
  - Ausgewogenheits-Zahl (Prozent) mit einem Satz, was fehlt. Der Satz nennt höchstens zwei bis drei Stellen.
  - Körperfigur vorne und hinten, jeder Muskel nach seiner Trainingshäufigkeit eingefärbt (siehe Farben).
  - Liste der sechs Gruppen, je mit Fortschritt in Prozent und einem Balken für die Trainingshäufigkeit. Eine Zeile öffnet das Detail.
- **Detail einer Gruppe (Entwurf C):**
  - Figur mit nur dieser Gruppe hervorgehoben (Rücken: Rückansicht; Brust, Schultern, Arme, Rumpf, Beine: Vorderansicht – Builder prüft, welche Ansicht je Gruppe passt, etwa bei Schultern).
  - Gesamtfortschritt der Gruppe in Prozent und ein Statuschip.
  - Hinweiskarte, wenn ein Teilmuskel zu kurz kommt.
  - Teilmuskeln als Zeilen, je mit eigenem Fortschritt und eigenem Trainingsbalken.
  - Button „Passende Übungen ansehen“ zur bestehenden Übungsliste nach Muskel.
- **Neue Nutzer:** Hat jemand noch nicht genug Training für eine Auswertung, bleiben die Felder grau und es steht dort sinngemäß, dass es noch Trainings für die Analyse braucht.

## Nicht-Ziele

- **Kein Tippen auf einen Muskel in der Figur.** Das Detail öffnet nur über die Gruppenliste.
- Keine Server-, Datenbank- oder Portal-Änderung. Alles wird in der App aus Daten berechnet, die dort schon liegen (Verlauf, Übungsfortschritt, Muskeln der Übungen aus dem Bootstrap).
- Keine Ziele, Empfehlungs-Engine oder Trainingsplan. Der Hinweis nennt, was zu kurz kommt, und verweist auf die Übungsliste.
- Keine medizinische Aussage. Wie bei der Muskelkarte in der Einweisung gilt: schematisch, keine Messung von Aktivierung.

## Anti-Ziele (wäre ein Misserfolg, auch wenn es technisch läuft)

- Eine Ansicht, die schlechtes Gewissen macht oder Druck aufbaut. Hinweise sind ruhig formuliert.
- Zahlen, die sich ohne ausreichende Datenlage hochrechnen und dann falsch wirken. Lieber grau und „braucht noch Training“.
- Zwei Zahlen, die der Nutzer verwechselt. Fortschritt und Trainingshäufigkeit bleiben sichtbar getrennt (Zahl vs. Balken/Farbe).

## Die zwei Messgrößen

Tim hat „ausgewogen“ so festgelegt: **Muskelgruppen werden ähnlich oft trainiert.** Feinschliff folgt später. Alles Weitere unten sind Annahmen von Claude, die er nicht widersprochen, aber auch nicht einzeln bestätigt hat.

### Trainingshäufigkeit (Farbe der Figur, Balken, Ausgewogenheit)

*Claude-Entscheidung, weil Tim „ähnlich **oft**“ gesagt hat: gezählt wird nicht die Satzmenge, sondern wie viele **Trainingseinheiten** der letzten 28 Tage einen Muskel oder eine Gruppe trainiert haben.* Rohe Satzsummen würden große Gruppen (Beine, Arme) immer bevorzugen und Rumpf und Schultern dauernd orange färben.

- Eine Einheit zählt für einen Muskel, wenn sie mindestens einen Satz einer Übung enthält, die ihn als **Hauptmuskel** hat. Als unterstützender Muskel zählt sie, wenn mindestens zwei Sätze daran hängen (Claude-Annahme, Builder darf nachschärfen).
- Eine Gruppe zählt eine Einheit, wenn irgendein Muskel der Gruppe sie bekommt. Zuordnung der Schlüssel zu Gruppen wie in `UebungsGruppierung`. Unbekannte Schlüssel wie `deep_core` zählen nicht.
- **Ausgewogenheit** = wie ähnlich die sechs Gruppen in ihrer Häufigkeit untereinander sind (Abstand zum Mittel). Gleiche Gewichtung für alle sechs, keine Richtgrößen. Formel: Builder, erklärbar und mit festgeschriebenen Testbeispielen.
- **Zu wenig** = deutlich unter dem Mittel der Gruppen (Startwert: unter der Hälfte). Teilmuskeln vergleicht man mit dem Mittel ihrer eigenen Gruppe. **Auch null Einheiten gelten als Nachholbedarf (orange), sobald genug Daten für eine Auswertung da sind.**
- **Katalogabdeckung (Korrektur 26.10.2026):** Schon eine Kraftübung mit Haupt- oder Nebenmuskelzuordnung reicht für die Häufigkeitsauswertung. Rückenstrecker, Adduktoren, Abduktoren, Rotatorenmanschette und Serratus werden regulär bewertet. Nur dargestellte Muskeln ohne Kraftübung (aktuell Tibialis und Fibularis, nur Cardio-Zuordnungen) bleiben grau mit „keine Kraftübung im Katalog“ und lösen keine Hinweise aus. Ein automatischer Vertragstest gleicht diese Ausnahme mit Katalog und Grafik ab.
- Cardio-Sätze zählen nicht.
- Legende der Figur: Nachholbedarf (orange) · ok · viel (Lime-Skala, mehr = heller) · keine Auswertung (grau).

### Fortschritt (große Prozentzahl)

- Bezug: Entwicklung der **Höchstlast** je Übung im Zeitraum von **3 Monaten** *(Annahme)*, bezogen auf die Übungen, die den Muskel als **Hauptmuskel** haben. Gruppenfortschritt = Mittel über ihre Muskeln. Quelle ist der bestehende Übungsfortschritt (`ExerciseProgress`, `points`).
- Je Übung: beste Last der letzten 30 Tage gegenüber der besten Last der ersten 30 Tage des Zeitraums (bzw. ab dem ersten Messpunkt, wenn die Übung jünger ist). Jede Übung zählt gleich. *(Claude-Entscheidung.)*
- **Rückgang wird ehrlich gezeigt**, aber neutral: grau statt rot, kein Alarmton. Alles zwischen −3 % und +3 % steht als „stabil“. *(Claude-Entscheidung.)*
- Reine Nebenmuskeln haben nach dieser Fortschrittslogik keinen eigenen Lastfortschritt. Für sie wird kein „braucht noch Trainings“ versprochen; ihre Trainingshäufigkeit wird trotzdem ausgewertet.
- Prozent relativ zur Last am Anfang des Zeitraums, damit unterschiedliche Einheiten keine Rolle spielen. Übungen ohne Last (Körpergewicht, Zeit) fallen heraus; dann ist „kein Wert“ ehrlicher als eine erfundene Zahl.
- Ist nichts Auswertbares da, zeigt die Zeile statt einer Zahl einen Strich und den Hinweis „braucht noch Trainings“.

## Farben und Texte

Aus dem Designsystem (§13.1 Muskelkarte) und `MuskelFigur`:
- Lime-Skala (`#5E7220` bis `#D4FF3F`) = trainiert, mehr Menge heller.
- **Orange** = Nachholbedarf. Nachholbedarf nimmt das vorhandene `DesignSystem.Color.warn` (`#FFB020`); kein neuer Farbwert.
- Grau (`#383D47`) = nicht angesprochen oder noch keine Auswertung.
- Legende unter der Figur: Nachholbedarf · ok · viel · nicht trainiert.
- Sprache Deutsch, ruhiger Ton, wie in den bestehenden Texten der App. Beispiele aus dem Entwurf: „Gut dabei“, „Eher viel“, „Hinten zu wenig“.

## Neuer Nutzer / zu wenig Daten

- Gruppen und Teilmuskeln ohne genug Daten werden grau.
- Der Text auf der Startansicht: sinngemäß „Für die Analyse braucht es noch ein paar Trainings.“
- Ab wie vielen Einheiten bzw. Tagen die Auswertung beginnt, entscheidet der Builder (Startwert: mindestens drei Trainingseinheiten in den letzten 28 Tagen für Trainingshäufigkeit, mindestens zwei Messpunkte im Abstand von zwei Wochen für Fortschritt). Fortschritt und Trainingshäufigkeit können unabhängig voneinander „noch nicht auswertbar“ sein.

## Was im Code schon da ist (Hinweise für den Builder)

- Muskelfiguren: `DesignSystem/Components/MuskelModell.swift`, `MuskelKarte.swift` (`MuskelFigur`), Pfade in `Resources/muskelmodell.json`, Quelle `assets/muskelmodell`. Die Figur färbt bisher nur nach Rolle (Haupt/Unterstützend). Hier braucht es eine Färbung je Muskel mit freien Farben und ein Ausblenden/Abdunkeln der übrigen Muskeln für das Detail.
- Gruppen und Reihenfolge der Muskelschlüssel: `Workout/UebungsGruppierung.swift` (`MuskelHauptgruppe`, Feinreihenfolge je Gruppe).
- Muskeln je Übung: `HomeZeilen.muskelnJeUebung(katalog.bootstrap)`.
- Verlauf: `VerlaufStore` hält `sessions` (mit Sätzen je Block und `exerciseId`) und `fortschritt`. Der Verlauf reicht laut Kommentar im DTO weiter zurück als der Prefetch; Builder prüft, ob die 28 Tage vollständig im Speicher liegen.
- Einbau: `Screens/Home/HomeRootView.swift`, Bereich `fortschritt` (Überschrift ÜBUNGSFORTSCHRITT). Der Toggle sitzt dort oben.
- Katalogdaten: im Katalog (`catalog/gymtavo.json`) haben alle 162 Übungen Muskeln. Einige Muskeln kommen als Hauptmuskel selten vor (Rückenstrecker 1, Abduktoren 2, Adduktoren 2, Rotatorenmanschette 2, Bauch 4). Die geringe Zahl angebotener Übungen ist kein Grund, vorhandene Trainingsdaten auszublenden (Korrektur 26.10.2026).

## Dem Builder überlassen

- Genaue Formeln und Schwellen (Ausgewogenheit, „zu wenig“, „viel“), solange sie erklärbar und getestet sind.
- Welche Ansicht (vorne/hinten) und welcher Bildausschnitt je Gruppe im Detail. Hat eine Gruppe Teilmuskeln auf beiden Seiten (Schultern, Arme), zeigt das Detail beide Ansichten nebeneinander. *(Claude-Entscheidung.)*
- Ob die 28 Tage Sätze und die 3 Monate Verlauf lückenlos im `VerlaufStore` liegen. Wenn nicht, darf der Builder die **bestehenden** Abfragen mit größerem Zeitraum nutzen (z. B. `since` im Progress-Endpunkt). Neuen Servercode gibt es nicht; wäre er nötig, zurück zu Tim.
- Wahl und Merken des Toggles (Vorgabe: Muskelgruppen, gemerkt wie bei der Übungsansicht am Gerät).
- Wortlaut der Hinweise, im Ton wie oben.
- Die Teilmuskel-Anzeige, wenn eine Gruppe nur einen darstellbaren Muskel hat.
- Wie ein Hinweis den Weg zur passenden Übungsliste findet (bestehende Muskelliste am Gerät/Katalog).
- Tests, Aufteilung in Etappen und Reihenfolge.

## Offen für später (Feinschliff)

- Richtgrößen je Gruppe statt „alle gleich“.
- Tippen auf einen Muskel in der Figur.
- Umschalten der Zeiträume (28 Tage / 3 Monate).
