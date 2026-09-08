# iOS Member-App — Training & Kurse (Sub-Projekt 3 von 4)

**Stand:** 8. September 2026
**Status:** Entschieden, bereit für Umsetzungsplan.
**Vorbedingung:** Sub-Projekt 1 (Fundament + Zugang) und Sub-Projekt 2 (Gerät-Kernflow) sind gebaut und in `master` gemergt. `TrainingRootView`, `WorkoutSessionStore`, `CatalogStore`, `APIClient`, `DesignSystem` und die Navigations-Hülle stehen.
**Zitierweise:** `§n` ohne Dokumentangabe verweist auf `2026-08-30-designsystem.md`; Verweise innerhalb dieses Dokuments stehen als „Abschnitt n".
**Verhältnis zu anderen Dokumenten:** untergeordnet gegenüber `2026-08-28-fitness-retrofit-m1-design.md` (Produktverhalten) und `2026-08-30-designsystem.md` (Aussehen, Bewegung). Dieses Dokument bestimmt, *wie* Sub-Projekt 3 gebaut wird, und hält fest, wo es von beiden begründet abweicht.

---

## 1. Zwei Hälften in einem Sub-Projekt

Sieben Screens, die außer der Tab-Leiste und dem Designsystem nichts teilen:

| Gruppe | Screens |
| --- | --- |
| Training | `TrainingLeer`, `TrainingLaeuft`, `TrainingScan`, `TrainingAbschluss` |
| Kurse | `Kurse`, `KursDetail`, `KurseMeine` |

Training führt zu Ende, was Sub-Projekt 2 als Rumpf hinterlassen hat: `TrainingRootView` hat heute einen Scan-Knopf, eine schlichte Blockliste und „Training beenden", weil der Kernflow sonst nicht schließbar gewesen wäre. Kurse ist ein eigenständiges Feature mit eigenem Serververtrag.

Sie stehen deshalb in getrennten Abschnitten (4 und 5). Wer später eine Kurse-Änderung liest, muss den Trainingsteil nicht mitlesen.

---

## 2. Scope

**Enthalten:**

- Server: `POST /workout-sessions/{id}/complete` um Vorschläge je Block erweitern (Abschnitt 3.1); `CourseWeek` um `cancellationDeadlineHours` erweitern (Abschnitt 3.2)
- Die vier Training-Screens, inklusive der zwei Zustände der bestehenden Wurzel
- Ein gemeinsames, parametrisiertes Scanner-Sheet statt zweier
- Die drei Kurse-Screens samt Buchen, Abmelden und Warteliste
- Ein kleiner Offline-Cache **ausschließlich** für die eigenen Buchungen
- Die vier fehlenden Zustände der Kurse-Gruppe (Skelett, Leer, Offline, Fehler)

**Nicht enthalten** (Sub-Projekt 4):

- `SessionDetail`, `Uebungsfortschritt`, `Home`, `HomeLeer`
- Der Rest von `Profil` (Produktgrenze-Text, RIR-Schalter)
- Push-Benachrichtigungen — sie existieren nicht, und kein Text in diesem Sub-Projekt verspricht sie

---

## 3. Server-Anteil

Zwei Änderungen. Beide klein, beide additiv, keine Migration.

### 3.1 `complete` liefert die Vorschläge je Block

`TrainingAbschluss` zeigt unter „Beim nächsten Mal" je Block einen Progressionsvorschlag — „+2,5 kg", „Gewicht halten", „Kein Vorschlag" bei gemeldetem Problem. Dafür gibt es heute keine Quelle: `suggestNextWeight` wird **ausschließlich** in `getTagContext` aufgerufen, also wenn ein Gerät angetippt wird. `GET /me/sessions` liefert Blöcke und Sätze, aber keinen Vorschlag.

```text
POST /api/v1/workout-sessions/{sessionId}/complete
  → { id, startedAt, completedAt, completedReason,
      vorschlaege: [ { machineId, exerciseId, resultWeightKg,
                       deltaKg, reasonCode, algoVersion } ] }
```

Berechnet mit derselben reinen Funktion, die `getTagContext` nutzt, und in derselben Anfrage in `progression_suggestions` festgehalten — exakt das Muster aus M1-Spec §8.4: Nachvollziehbarkeit ohne Queue. Der `reasonCode` trägt die Fälle, die der Screen unterscheiden muss.

Kein neuer Endpoint. `progression_suggestions` steht seit Migration `0015`.

### 3.2 `CourseWeek` liefert die Abmeldefrist

`KursDetail` schreibt „Abmelden ist bis 2 Stunden vor Beginn möglich", `KurseMeine` schreibt „Abmelden bis 16:00 möglich". Beides braucht die Frist — und die steht in `studios.cancellation_deadline_hours` (Migration `0032`), ist also **je Studio verschieden**. Der Client erfährt sie heute nur aus der Fehlermeldung *nach* einem gescheiterten Versuch.

`CourseWeek` bekommt `cancellationDeadlineHours` auf Hüllenebene — dort, wo bereits `timezone` steht, weil beides Studio-Eigenschaften sind und nicht Termin-Eigenschaften.

Die hartkodierten „2 Stunden" im Artboard sind damit eine dokumentierte Abweichung (Abschnitt 6).

### 3.3 Was der Client rechnet, nicht der Server

Die Zahlen des Abschlusses — Dauer, Geräteanzahl, Satzanzahl, Gewicht und Satzzahl je Block — kommen aus der `LokaleSession`. Die App ist die einzige Instanz, die alle Sätze sicher kennt, solange welche in der Schreib-Warteschlange liegen. Ein serverseitig gerechneter Abschluss zeigte nach einem Offline-Training **zu wenig** — ausgerechnet dort, wo das Mitglied am ehesten nachsieht, ob alles angekommen ist.

### 3.4 Eine Korrektur am Designsystem

§11 sagt: „**Kurse ist gestaltet, aber nicht gebaut.** Es gibt dafür weder Tabelle noch Endpoint." Das war beim Schreiben richtig und ist es seit Phase 4 nicht mehr: Migrationen `0035`–`0038`, `courses.ts` mit Buchungs- und Nachrücklogik unter Zeilensperre, und zwei Endpoints unter `/api/v1`.

Der Absatz wird richtiggestellt. **Der Satz daneben bleibt gültig und wird eingehalten:** Benachrichtigungen existieren nicht, und kein Text in diesem Sub-Projekt darf eine versprechen.

---

## 4. Training

### 4.1 `TrainingLeer` und `TrainingLaeuft` sind ein Screen

Die Wurzel des Training-Tabs hat zwei Zustände, leer und laufend. Sub-Projekt 2 hat sie als Rumpf gebaut; hier bekommt sie ihre Gestalt.

**Leer.** NFC dominant mit Zeichnung und eigener Überschrift, QR als kleinerer, aber sichtbarer zweiter Weg — Design-Challenge-Entscheidung #3 (NFC als visueller Standard, bis der Trefferquoten-Test aus M0 Task 8 vorliegt) mit `TrainingLeer` ausdrücklich als Vorbild. Der Satz „Auf jedem Aufkleber ist beides — antippen oder scannen, gleiches Ergebnis" bleibt wörtlich; er trägt die Gleichwertigkeit, die die Optik allein nicht zeigt.

Hier steht auch der stille Satz zum automatischen Ende (Abschnitt 4.4).

**Laufend.** Vollständig aus der `LokaleSession`, ohne Netz. Die verstrichene Zeit läuft über `TimelineView` gegen `startedAt`, nicht über einen Zähler — dasselbe Muster wie der Resttimer aus Sub-Projekt 2. Blöcke tragen das „gemeldet"-Kennzeichen aus `problemFlag`.

Zwei Sätze, die die Design-Challenge angemahnt hat:

- **Der implizite Start braucht eine Erklärung.** Es gibt keinen Startknopf (M1-Spec §5.6), also weiß niemand, warum plötzlich ein Training läuft. Unter der verstrichenen Zeit steht „seit 18:04".
- **Das automatische Ende gehört neben „Training beenden":** „Ohne neuen Satz endet das Training nach vier Stunden von selbst." Dort, wo es zählt — als Erklärung, was passiert, wenn man den Knopf nicht drückt.

Der Zirkel-Hinweis („Tipp auf den Block statt neu zu scannen") bleibt wie im Artboard. Er beschreibt den Fall, für den die Wurzel überhaupt existiert (M1-Spec §5.3).

### 4.2 `TrainingScan` — ein Sheet für beide Wege

`MemberScannerView` aus Sub-Projekt 1 wird parametrisiert statt verdoppelt: Titel, Hinweistext und der NFC-Satz kommen von außen; Kamera-, Erkennungs- und Schließmechanik bleiben eine. Die Design-Challenge fand an diesem Screen drei Mängel — an einer Stelle behoben, wirken sie für beide Wege, und der Beitritts-Scan steht im selben schummrigen Keller.

Zwei davon werden behoben: das Schließen-Ziel auf 44 pt (§4) und ein sichtbares Erfolgs-Feedback beim Erkennen (§6: Haptik nie als einzige Rückmeldung).

**Eine Taschenlampe wird bewusst nicht gebaut.** Die Design-Challenge hatte sie angeregt; entschieden wurde dagegen.

**Eine Abgrenzung, die den neutralen Antwortpfad schützt:** Das Sheet erkennt einen Code und reicht ihn weiter, mehr nicht. Ob ein Tag unbekannt, ungültig oder gesperrt ist, entscheidet der Weg dahinter — und antwortet dort für alle drei gleich (M1-Spec §10.4). Ein eigener Fehlerzustand im Sheet würde genau die Unterscheidung wieder einführen, die der Server bewusst vermeidet. Das Sheet zeigt nur den Fehler, den es allein kennt: keine Kameraerlaubnis.

### 4.3 `TrainingAbschluss`

Push innerhalb des Training-Tabs nach „Training beenden"; die Tab-Leiste bleibt.

**Die Reihenfolge ist heikel und wird festgeschrieben: erst die Zusammenfassung aus der `LokaleSession` festhalten, dann beenden.** Andersherum sind die Zahlen weg, bevor der Screen sie zeigt.

- **Zahlen** kommen lokal und stehen immer.
- **„Beim nächsten Mal"** kommt aus der erweiterten `complete`-Antwort (Abschnitt 3.1). Ohne Empfang steht dort stattdessen: „Vorschläge brauchen Empfang. Deine Sätze sind gespeichert und gehen raus, sobald du wieder Netz hast."
- Der Satz „Vorschläge entstehen aus deiner Historie und dem Zielkorridor deines Studios. Sie sind eine Rechnung, keine Empfehlung — du entscheidest." bleibt wörtlich (§10).
- **„Training im Detail ansehen" entfällt.** Es führt zu `SessionDetail`, und das gehört zu Sub-Projekt 4. Ein Link, der nichts tut, ist schlechter als kein Link; er kommt zurück, wenn sein Ziel existiert.

### 4.4 Die Einheit, die von selbst endet

Vergessenes Beenden ist laut M1-Spec §5.2 **der Regelfall**, nicht die Ausnahme. Der Server wertet das träge aus und setzt `completed_at` dabei auf den **letzten Satz**, nicht auf jetzt — sonst hätte eine vergessene Einheit rückwirkend Stunden gedauert, in denen niemand trainiert hat. Die Dauer ist damit auch dort ehrlich.

In der App:

- **Auf `TrainingLaeuft`** steht der Satz neben „Training beenden" (Abschnitt 4.1), damit niemand überrascht wird.
- **Auf dem leeren Tab** steht danach einmal: „Dein letztes Training wurde automatisch beendet." Er beantwortet genau die Frage, die sonst offenbleibt — ob das Training angekommen ist.
- **Kein Abschluss-Screen dafür.** Er poppte einen Tag später aus dem Zusammenhang gerissen auf, und sein Hauptinhalt — der Vorschlag — erscheint beim nächsten Antippen des Geräts ohnehin.

Der Zustand ist lokal erkennbar und kostet keinen Server: `WorkoutSessionStore` behält die abgelaufene Einheit, `aktiveSession()` filtert sie nur heraus.

---

## 5. Kurse

### 5.1 Datenquelle

`GET /api/v1/me/courses?studio=<id>&from=&to=` liefert `CourseWeek` — Termine, Belegung als Zahl, eigener Buchungsstatus, Wartelistenposition, abgesagte Termine. Gebucht wird mit `PUT`, storniert mit `DELETE` auf `/course-sessions/{id}/booking`. Das Studio kommt aus `CatalogStore.activeStudioId`.

**`KurseMeine` braucht keinen eigenen Endpoint:** dieselbe Abfrage mit größerem Fenster (jetzt bis +14 Tage), gefiltert auf `ownStatus != nil`. Das deckt auch den „Nächste Woche"-Abschnitt ab.

### 5.2 Offline: nur die eigenen Buchungen

Die App ist offline-first, Kurse bricht damit — eine Buchung ist ein Wettlauf um einen knappen Platz, und die Belegung ist eine Live-Zahl.

**Buchen offline in die Warteschlange zu legen scheidet aus.** Das wäre dieselbe Unwahrheit wie „gespeichert, wird gesendet" bei einem Platz, den es längst nicht mehr gibt.

Beim Lesen wird getrennt:

- **Die eigenen Buchungen werden persistiert.** „Wann ist mein Kurs, wo, und bis wann kann ich absagen" ist stabile Information und genau das, was man ohne Empfang wissen will. Ohne Netz zeigt „Meine Kurse" den letzten Stand mit Zeitangabe.
- **Der Wochenplan wird nicht gecacht.** „12 von 16" veraltet binnen Minuten; es ohne Netz anzuzeigen, als wäre es aktuell, ist dieselbe Sorte Unwahrheit, die beim Satz-Status vermieden wird. Ohne Empfang zeigt der Wochenplan den Offline-Zustand aus §5.

### 5.3 Die sechs Zustände von `KursDetail`

Die Design-Challenge fand, dass nur einer gezeigt wird, obwohl der Screen laut Titel „Detail **und Anmeldung**" leistet. Alle sechs fallen aus `CourseWeekSession`:

| Bedingung | Hauptaktion |
| --- | --- |
| `status == "cancelled"` | keine — Hinweis, dass das Studio abgesagt hat |
| `startsAt` in der Vergangenheit | keine — „vorbei" |
| `ownStatus == "booked"` | „Abmelden", darunter die Frist als konkrete Uhrzeit |
| `ownStatus == "waitlisted"` | „Warteliste verlassen", darunter die Position |
| `freeSeats > 0` | „Anmelden" |
| `freeSeats == 0` | „Auf die Warteliste" |

Die Reihenfolge ist die Auswertungsreihenfolge: abgesagt schlägt vorbei, vorbei schlägt jeden eigenen Status.

### 5.4 Die Warteliste verspricht nichts

Der Satz bleibt wörtlich: „Rückt jemand ab, bekommst du den Platz automatisch. Du siehst es hier unter Meine Kurse. Bis dahin ist nichts reserviert."

Er verspricht ausdrücklich **keine** Benachrichtigung — korrekt, denn es gibt keine. Das Nachrücken passiert serverseitig stumm und unter Zeilensperre (Migration `0038`); das Mitglied erfährt es beim nächsten Öffnen. Genau so, wie der Satz es sagt.

### 5.5 Die vier fehlenden Zustände

Die Design-Challenge fand: „Kurse: Kein Skelett-, Leer-, Offline- oder Fehlerzustand über alle drei Screens." Sie werden hier entworfen, nach §5:

- **Skelett** nur für den Wochenplan beim ersten Laden — nie über einer Zahl.
- **Leer:** „Für diesen Tag hat dein Studio keinen Kurs eingetragen." Überschrift plus nächster Schritt, keine leere Statistik mit Nullen.
- **Offline:** Wochenplan mit `danger`-Umriss auf 10 % `danger`-Fläche; „Meine Kurse" aus dem Cache mit Stand.
- **Fehler:** Servertext wörtlich. Bei einer abgelehnten Buchung weiß nur der Server, ob der Platz weg ist oder die Frist vorbei — er formuliert beides, und der Client formuliert es nicht um.

---

## 6. Abweichungen vom Artboard

Swift wird gegen Artboard **plus** diese Tabelle abgenommen. Die HTML-Dateien bleiben unangetastet.

| Artboard | Zeigt | Swift baut | Warum |
| --- | --- | --- | --- |
| `TrainingLaeuft` | kein automatisches Ende | Satz neben „Training beenden" | M1 §5.2 nennt vergessenes Beenden den Regelfall |
| `TrainingLaeuft` | keinen Hinweis auf den impliziten Start | „seit 18:04" | ohne Startknopf sonst unerklärlich |
| `TrainingScan` | QR dominant | NFC dominant, nach Vorbild `TrainingLeer` | Design-Challenge-Entscheidung #3 |
| `TrainingScan` | Schließen 34 px | 44 pt | §4 |
| `TrainingScan` | kein Erfolgs-Feedback | sichtbare Bestätigung | §6 |
| `TrainingAbschluss` | „Training im Detail ansehen" | entfällt | Ziel gehört zu Sub-Projekt 4 |
| `TrainingAbschluss` | Problemmeldung anders als auf `Läuft` | vereinheitlicht | dieselbe Sache, dieselbe Form |
| `Kurse` | warngelb gefüllter Wartelisten-Balken | entfällt ganz | §2, `warn` nie als Fläche; die Zahl sagt dasselbe |
| `Kurse` | vier Akzentflächen | eine, auf dem gewählten Tag | §2 |
| `Kurse` | Chip-Radius 6 px | Pille | §4 |
| `Kurse` | Chevron auf einer von vier Zeilen | auf allen | einheitliche Affordance |
| `KursDetail` | zwei Akzentflächen | eine, auf der Hauptaktion | §2 |
| `KursDetail` | einen Zustand | sechs (Abschnitt 5.3) | der Screen leistet „Detail und Anmeldung" |
| `KursDetail` | „bis 2 Stunden" hartkodiert | aus `cancellationDeadlineHours` | die Frist setzt das Studio |
| `KurseMeine` | wichtigsten Satz in `text-faint` | `text-muted` | §2, `text-faint` nur für nicht-tragende Information |
| `KurseMeine` | „Abmelden bis 16:00" | berechnet aus Frist und Zeitzone | dieselbe Quelle |

---

## 7. Tests

Die Logik liegt in reinen Funktionen, damit sie ohne View prüfbar ist.

**Swift Testing:**

- Zusammenfassung aus `LokaleSession`: Dauer, Geräte, Sätze, Blöcke — auch mit gemeldetem Problem
- Erkennung „letzte Einheit lief automatisch aus" für den Satz auf dem leeren Tab
- `KursDetail`-Zustandsentscheidung: ein Test je Zeile der Tabelle aus Abschnitt 5.3, inklusive der Vorrangregel
- Abmeldefrist als konkrete Uhrzeit aus `startsAt` minus Frist, in der Studio-Zeitzone
- „Meine Kurse" als Filter über `CourseWeek`, inklusive Wochengrenze
- Offline-Cache: nur eigene Buchungen, Roundtrip über einen simulierten Prozess-Neustart

**Vitest:**

- `complete` liefert je Block einen Vorschlag mit `reasonCode`, inklusive „kein Vorschlag bei gemeldetem Problem"
- `CourseWeek` trägt `cancellationDeadlineHours`

**Manuell:** jeder Screen gegen Artboard plus Abweichungstabelle; VoiceOver; Dynamic Type bis XXL; Reduce Motion; ein Flugmodus-Durchgang über beide Hälften.

**Kaltbau ist Pflicht.** In Sub-Projekt 2 verdeckten warme Builds sowohl einen Übersetzungsfehler als auch sieben Warnungen. Jede Verifikation läuft mit isoliertem `-derivedDataPath`, und die Verzeichnisse werden danach gelöscht: in Sub-Projekt 2 belegten die stehengebliebenen am Ende 5,2 GB und liessen den letzten Testlauf an einer vollen Platte scheitern.

---

## 8. Selbstprüfung

- Keine Platzhalter oder offenen Punkte im Dokument.
- Kein Widerspruch zu `designsystem.md`, außer der in Abschnitt 3.4 benannten und richtiggestellten Aussage über den Baustand von Kurse.
- Zwei Abweichungen von der M1-Spec sind benannt und begründet: die Erweiterung von `complete` (Abschnitt 3.1) und die von `CourseWeek` (Abschnitt 3.2). Beide sind additiv; die Architekturaussage „screenorientiert, keine Fachlogik im Client" bleibt unangetastet.
- Scope ist eng genug für einen Umsetzungsplan: zwei kleine Server-Änderungen, ein zusammengeführtes Scanner-Sheet, zwei Zustände einer bestehenden Wurzel, zwei neue Training-Screens, drei Kurse-Screens, ein kleiner Cache.
- Die offenen Befunde der Design-Challenge für diese Gruppe sind alle adressiert: NFC/QR-Bias, „auto beendet", Übergangs-Feedback beim impliziten Start, Schließen-Trefferfläche, Scan-Feedback, Akzent- und Warn-Regelbrüche in Kurse, die fehlenden Zustände von `KursDetail`, der Kontrast auf `KurseMeine`.

---

## 9. Nächste Schritte

Nach Freigabe: `writing-plans`-Skill für den Umsetzungsplan, danach `subagent-driven-development`. Sub-Projekt 4 (Home, `SessionDetail`, `Uebungsfortschritt`, Profil-Rest) bekommt eine eigene Brainstorming-Runde.

**Offen aus Sub-Projekt 2, nicht Teil dieses Dokuments:** die manuelle Abnahme des Gerät-Kernflows (`docs/superpowers/plans/2026-09-08-geraet-kernflow-abnahme.md`) steht noch aus. Ihr wichtigster Punkt — das verschachtelte Scrollen im Wertrad — betrifft eine Komponente, die dieses Sub-Projekt nicht anfasst; die beiden Arbeiten blockieren einander nicht.
