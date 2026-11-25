# iOS Member-App — Kamera-Tracking und Tempo-Welle im Übungsablauf

**Stand:** 24. November 2026
**Status:** Am 24. November 2026 von Tim abgenommen („Ja, abgenommen“), einschließlich Entscheidung 19 (Kamera-Sätze als `eingegeben`). Die als „Annahme“ und „Vorschlag“ markierten Punkte gelten damit, bleiben aber gekennzeichnet. Nächster Schritt: Umsetzungsplan.
**Vorbedingung:** Sensorik-Grundlage des Tempo-Modus ist auf `master` (PR #115: `Tempovorgabe`, `Sollwelle`, `Tempoauswertung`, `Lage` im Package `Sensorik`). Übungsvideos sind im Katalog (PR #114).
**Bildentwürfe:** https://claude.ai/artifact/3SURiD3JyZqS52RMKNUVZ3 (privat, nur für Tim), von Tim abgenommen („ok sieht gut aus“). Maßgeblich sind die Bilder 1–7 der ersten Reihe und „Profil Oberkörper · Bizeps-Curl“. Das Bild „Liegestütz (quer)“ ist überholt: alles wird hochkant gebaut (Entscheidung 4).
**Bezug:** `2026-11-23-tempo-modus-design.md` („Tempo-Spec“). Dieses Projekt ersetzt sie nicht; es nutzt ihre Wellen-Logik mit der Kamera als Signalquelle.
**Wer was entschieden hat:** „Tim“ heißt im Gespräch entschieden. „Annahme“ heißt von Claude gesetzt, Tim genannt, von ihm nicht widersprochen, aber nicht ausdrücklich bestätigt. „Vorschlag“ heißt von Claude festgelegt und Tim noch nicht genannt. Annahmen und Vorschläge beim Lesen prüfen.

---

## 1. Warum und was

Mitglieder sollen Kraftübungen im sauberen Tempo ausführen. Der Versuch mit der Kamera (Worktree `kamera-versuch`) hat gezeigt, dass das iPhone den Körper live erkennt und Wiederholungen aus Gelenkwinkeln ablesen kann, auch bei Übungen, bei denen der Bewegungssensor nichts sieht (Stapel, Drücken, Kniebeuge).

Dieses Projekt bringt beides in den normalen Trainingsablauf: Startet das Mitglied eine Übung, läuft kurz das Übungsvideo. Danach stellt es das Handy auf, die App prüft, ob der Körper sauber erkannt wird, und im Satz liegt die Tempo-Welle über dem Livebild. Ein Punkt folgt der eigenen Bewegung; wer ihn auf der Welle hält, trainiert im richtigen Tempo. Die Wiederholungen zählt die Kamera. Am Satzende steht ein Rückblick auf das Tempo.

**Erfolg heißt:** Tim trainiert im Studio eine Einheit mit mindestens einer Übung je freigeschaltetem Kameraprofil. Der Aufstell-Check führt ihn ohne Nachdenken in eine brauchbare Position, der Punkt folgt der Bewegung ohne spürbare Verzögerung, die gezählten Wiederholungen stimmen (höchstens eine daneben), und der Satz landet wie gewohnt in der Einheit.

## 2. Entscheidungen

| # | Frage | Entscheidung | Von |
|---|---|---|---|
| 1 | Ablauf und Aussehen | Sieben Schritte laut Canvas: Video → Aufstellen → Erkannt/Countdown → Satz im Takt → Satz neben dem Takt → Tracking verloren → Satzende | Tim |
| 2 | Regeln je Übung | Kameraprofile: jede Übung bekommt im Katalog ein Profil statt Einzelregeln (Abschnitt 5) | Tim |
| 3 | Umfang | Gesamtpaket: alle sechs Profile, Katalogfelder mit Migration, Import und Portal-Pflege | Tim |
| 4 | Ausrichtung | Alles hochkant. Kein Querformat, auch nicht für Übungen am Boden | Tim |
| 5 | Tempo | Je Übung im Katalog: senken, halten, heben in Sekunden; fehlt die Angabe, gilt ein Standard | Tim |
| 6 | Sichtbarkeit | Direkt für Mitglieder, nicht hinter `#if DEBUG`. Die App ist noch nicht live | Tim |
| 7 | Bauweise | Eigener Vollbild-Ablauf über der bestehenden Übungsansicht; übergibt am Satzende nur das Ergebnis an den bestehenden Weg zum Sichern (Weg 1, Abschnitt 6) | Tim |
| 8 | Signalquelle | Welle und Wiederholungszahl kommen in diesem Ablauf allein aus dem Kamerabild. Der Sensor-Tempo-Modus bleibt ein eigenes Projekt | Annahme |
| 9 | Ohne Kamera | Wer „Ohne Kamera“ wählt oder die Kamera nicht erlaubt, trainiert den Satz genau wie heute | Annahme |
| 10 | Tempo verstellen | Das Mitglied verstellt in dieser Stufe nichts; es gilt der Katalog | Annahme |
| 11 | Handy zwischen Übungen | Vor jedem Satz läuft der Aufstell-Check. Sind die Pflichtgelenke schon im Bild, geht es direkt zum Countdown. „Ohne Kamera“ gilt nur für die laufende Übung | Annahme |
| 12 | Freischaltung | Ein Profil wird erst Übungen zugewiesen, wenn es den Gütetest bestanden hat (Abschnitt 10). Ein schwaches Profil hält die anderen nicht auf | Annahme |
| 13 | Tempo je Planposition durch den Trainer | Spätere Stufe, nicht Teil dieses Projekts | Annahme |
| 14 | Kamera | Immer die Frontkamera, Bild gespiegelt; das Mitglied muss den Bildschirm sehen | Vorschlag |
| 15 | Zirkel | Kein Kamera-Ablauf im Zirkel | Vorschlag |
| 16 | Übungen auf Zeit (Halten) | Kein Kamera-Ablauf und keine Welle; nur Übungen mit Wiederholungen | Vorschlag |
| 17 | Rückblick speichern | Nichts vom Tempo-Rückblick wird gespeichert oder gesendet (wie Tempo-Spec) | Vorschlag |
| 18 | Bilder | Kein Kamerabild und kein Skelett wird gespeichert oder verlässt das Handy | Vorschlag |
| 19 | Herkunft der Wiederholungszahl | Ein Kamera-Satz wird wie ein von Hand eingetragener gesichert (`eingegeben`); kein Eingriff in `herkunft.ts`, keine Zeiten je Wiederholung an den Server (Abschnitt 7.6) | Vorschlag, offen (13.1) |
| 20 | Pausenende | Läuft die Pause ab, öffnet sich der Kamera-Ablauf von selbst beim Aufstell-Check bzw. Countdown, solange die Übung mit Kamera läuft (wie Tempo-Spec, Entscheidung 21) | Vorschlag |
| 21 | Sensor während des Kamera-Ablaufs | Zähler und Satzautomatik des Bewegungssensors sind für diesen Satz stillgelegt: Sie starten, zählen und sichern nichts | Vorschlag |
| 22 | Einseitige und abwechselnde Übungen | Einseitig: Es führt die Seite mit der größeren Bewegung. Abwechselnd links/rechts: zunächst `ohne_kamera` (Abschnitt 8.2) | Vorschlag |
| 23 | Wo „bestanden“ steht | Eine Liste der freigeschalteten Profile im Domänenpaket; Katalogprüfung, API und Portal lassen nur diese zu (Abschnitt 9) | Vorschlag |

## 3. Ziele, Nicht-Ziele, Anti-Ziele

**Ziele**
- Der Weg von „Übung starten“ bis zur ersten Wiederholung kommt ohne Lesen längerer Texte aus: je Schritt eine Anweisung.
- Der Punkt folgt der echten Bewegung des Gelenks, das das Profil vorgibt.
- Die Anzeige ist aus 1,5 bis 3 m Abstand lesbar.
- Das normale Training ohne Kamera bleibt unverändert und ist aus jedem Schritt mit einem Tipp erreichbar.

**Nicht-Ziele**
- Bewertung der Technik (Haltung, Gelenkstellung, Tiefe). Gemessen wird nur das Tempo.
- Welle aus dem Bewegungssensor in diesem Ablauf; Verschmelzen von Sensor und Kamera.
- Tempo je Planposition, Tempo aus einem Trainingsziel, Verstellen durch das Mitglied.
- Tempo-Ergebnisse speichern, im Verlauf oder im Trainerportal zeigen.
- Querformat, Rückkamera, externe Bildschirme.
- Zirkel, Cardio, Übungen auf Zeit.

**Anti-Ziele**
- Ein Kamera-Fehler darf nie einen Satz verlieren oder das Sichern blockieren.
- Ein Punkt, der bei sauberem Training neben der Welle liegt. Lieber bekommt eine Übung kein Profil.
- Ein Aufstell-Check, der das Mitglied festhält: „Ohne Kamera“ ist immer sichtbar.
- „Tracking verloren“, nur weil ein für die Übung unwichtiges Körperteil aus dem Bild ist.

## 4. Was heute da ist

**Kamera-Versuch** (Worktree `.claude/worktrees/kamera-versuch`, Branch `worktree-kamera-versuch`, **uncommittet**, als Wegwerf-Versuch geschrieben):
- `apps/ios-member/Packages/KameraVersuch`: `PoseKern` (`Skelett` mit 15 Gelenken, `PoseErkenner` über Apples `VNDetectHumanBodyPoseRequest`, `WendeZaehler` und `Bewegungsauswertung` über acht Gelenkwinkel) und die Ansicht `KameraVersuchView` (Livebild über `AVSampleBufferDisplayLayer`, Strichfigur, Zähler). Gezählt wird am Gelenk mit dem größten Hub; das wechselt von selbst.
- `tools/kamera-versuch/ergebnis/`: Lauf über die 189 Übungsvideos. 170 zählen richtig, 9 zu wenig, 8 zu viel, 2 nicht erkannt. Die Erkennung kostet am Mac 6,8 ms je Bild. Je Video steht in `ergebnis.csv` das führende Gelenk und sein Hub.
- Nicht gemessen: echte Menschen im Studio außer Tims eigenem Test, schlechtes Licht, mehrere Personen im Bild, Übungen am Boden und im Liegen, Rechenzeit und Wärme auf dem iPhone über eine ganze Einheit.

**Wellen-Logik** (`apps/ios-member/Packages/Sensorik`, auf `master`):
- `Tempovorgabe(kraftweg:ablassen:)`: zwei Zeiten, je 1–4 s in Schritten von 0,5 s, Standard 1,5 / 2,5 s. **Keine Haltephase.**
- `Sollwelle`: Soll-Lage 0…1 als reine Funktion der Zeit seit der Los-Marke, beginnt immer mit dem Kraftweg (0 → 1), Bahn ±0,2, Taktmarken.
- `Tempoauswertung`: nimmt `Lage`-Werte entgegen, liefert Trefferquote und ein Urteil je Wellenperiode und je Weg.
- `Lage` (`t`, `lage`, `richtung`, `sicher`) ist die einzige Eingabe; woher sie kommt, ist der Logik gleich.
- Eine Anzeige der Welle gibt es noch nicht.

**Übungsablauf** (`apps/ios-member/FitnessMember/Screens/Geraet`):
- `UebungsstartSheet`: Einweisung (mit Video beim Erstkontakt) → Startwerte → „Übung starten“.
- `GeraetModel.uebungStarten(mit:mitCountdown:)` setzt die Phase `bereit` (Countdown), danach `eingabe` (Räder, „Satz N sichern“) → `pause` → `abschluss`. Gesichert wird über `satzSichern(problemFlag:problemReason:)`.
- Übungsvideos: `UebungsVideoVorrat` (signierte Adressen aus `me/exercise-videos`), Wiedergabe über `Schleifenvideo`.

**Katalog:**
- Tabelle `public.exercises`; Gymtavo-Übungen kommen aus `catalog/gymtavo.json` (Format und Prüfung in `packages/domain/src/katalog-datei.ts`, Import in `katalog-import.ts`). Zuletzt so ergänzt: `geraet_label` (Migration 0076) bis in die App (`BootstrapResponse`).
- Studioeigene Übungen pflegt das Portal über `UebungFormular.tsx`. Den Gymtavo-Katalog pflegt niemand im Portal; seine Quelle ist die Datei.
- Erlaubnistext der Kamera (`project.yml`, `NSCameraUsageDescription`) nennt heute nur den QR-Scan.

## 5. Kameraprofile

Ein Profil legt fest, was die Kamera für eine Übung sehen muss und wie das Mitglied das Handy aufstellt.

| Profil (Schlüssel) | Beispiele | Pflichtgelenke | Übliches Wellensignal | Blick | Aufstellung (hochkant) |
|---|---|---|---|---|---|
| `ganzkoerper_stehend` | Kniebeuge, Kreuzheben, Ausfallschritt | Schulter, Hüfte, Knie, Fuß | Knie- oder Hüftwinkel | seitlich oder schräg | angelehnt am Boden oder auf Kniehöhe, ganzer Körper im Bild |
| `oberkoerper` | Bizeps-Curl, Schulterdrücken, Seitheben | Schulter, Ellbogen, Hand | Ellbogen- oder Schulterwinkel | von vorn | auf Hüfthöhe, Beine müssen nicht ins Bild |
| `stuetz_boden` | Liegestütz und Varianten | Schulter, Ellbogen, Hand, Hüfte | Ellbogenwinkel | seitlich | am Boden angelehnt, Füße müssen nicht ins Bild |
| `liegend` | Bankdrücken, Crunch, Beinheben | je nach Signal Arme oder Hüfte und Knie | Ellbogen- oder Hüftwinkel | seitlich | niedrig, auf Höhe der Bank oder am Boden |
| `zug_haengend` | Klimmzug, Latzug | Schulter, Ellbogen, Hand | Ellbogenwinkel | von vorn oder hinten | auf Hüfthöhe oder höher, Hände müssen oben im Bild bleiben |
| `ohne_kamera` | Gerät verdeckt den Körper | – | – | – | Welle nur als Vorgabe (Abschnitt 7.8) |

**Regeln**
- Pflichtgelenke hängen am Profil **und** am Wellensignal: Die drei Gelenke, die den Winkel des Wellensignals bilden, sind immer Pflicht, auch wenn das Profil sie nicht nennt.
- Bei „links/rechts“ genügt die Körperseite, die das Signal führt (Abschnitt 8.2).
- Abstände in den Anweisungen (1,5 m, 2 m) sind geschätzt und werden im Gütetest je Profil festgelegt. Bei `stuetz_boden` und `liegend` liegt der Körper quer im hochkanten Bild; der nötige Abstand ist dort größer und ungemessen.
- Die Texte und der Rahmen im Aufstell-Schritt kommen aus dem Profil, nicht aus der Übung.

## 6. Wege

**Weg 1 – Eigener Vollbild-Ablauf über der Übungsansicht.** Video, Aufstellen, Countdown, Welle und Rückblick sind ein eigener Ablauf, der sich über die Übungsansicht legt und ihr am Satzende das Ergebnis übergibt. Die bestehende Ansicht mit Rädern, Pause und Sichern bleibt unverändert. Preis: zwei Oberflächen für den Satz.

**Weg 2 – Neue Phasen in der bestehenden Übungsansicht.** Ein Ablauf ohne Übergabe. Preis: `GeraetModel` trägt schon Sichern, Offline, Sensor-Automatik und Zirkel; jeder Kamera-Fehler könnte dort das normale Training treffen.

**Weg 3 – Gemeinsame Welle für Kamera und Sensor.** Wie Weg 1, zusätzlich wird der Sensor-Tempo-Modus mitgebaut. Preis: deutlich mehr Umfang, und die Sensor-Seite hat offene Schwächen (Tempo-Spec N9).

**Gewählt: Weg 1** (Tim). Die Welle bekommt als Eingang nur `Lage`; damit kann der Sensor später andocken, ohne dass Weg 3 jetzt gebaut wird.

## 7. Ablauf, Bildschirm für Bildschirm

Der Kamera-Ablauf startet, wenn alle Bedingungen gelten: Die Übung zählt Wiederholungen, sie hat im Katalog ein Kameraprofil, sie läuft nicht im Zirkel. Sonst bleibt alles wie heute.

Er beginnt nach „Übung starten“ im `UebungsstartSheet` an der Stelle, an der heute der Countdown (`bereit`) läuft. Gewicht und Soll-Wiederholungen stehen zu diesem Zeitpunkt fest (Startwerte). Die bestehende Übungsansicht liegt darunter in der Phase `eingabe`.

### 7.1 Übung startet: Video (Bild 1)

- Kopf: „Übung n von m“, Name, Gerät · Sätze · Wiederholungen.
- Das Übungsvideo läuft einmal durch und bleibt auf dem letzten Bild stehen; Antippen spielt es erneut. Ohne Video (offline, keins vorhanden) steht dort das Vorschaubild oder ein Platzhalter.
- Darunter „Dein Tempo“ mit einer Vorschau der Welle und dem Tempo in Worten in der Reihenfolge der Bewegung („3 s senken · 1 s halten · 2 s heben“).
- Ein Satz Erklärung: „Gleich siehst du dich selbst im Bild. Der Punkt folgt deiner Bewegung, halte ihn auf der Welle.“
- Knöpfe: „Handy aufstellen“ (weiter zu 7.2) und „Ohne Kamera trainieren“ (schließt den Ablauf, 7.7).
- Dieses Bild erscheint nur vor dem ersten Satz einer Übung. Ab dem zweiten Satz beginnt der Ablauf bei 7.2.
- Beim ersten „Handy aufstellen“ fragt iOS nach der Kamera, falls noch nicht erlaubt (Abschnitt 11).

### 7.2 Aufstellen (Bild 2 und Profilbilder)

- Vollbild Livebild der Frontkamera, gespiegelt. Darüber ein Rahmen, der zeigt, wo der Körper stehen soll, und die Strichfigur der erkannten Gelenke.
- Oben eine Zeile aus dem Profil („Lehn das Handy an und stell dich in den Rahmen.“).
- Eine Checkliste der Pflichtgelenke in Gruppen („Kopf und Schultern erkannt“, „Hüfte und Knie erkannt“, „Füße fehlen im Bild“). Körperteile, die das Profil nicht braucht, stehen als Entlastung dabei („Beine müssen nicht ins Bild“).
- Unten **genau eine** Anweisung, die wichtigste: „Geh einen Schritt zurück“, „Geh etwas nach links/rechts“, „Dreh dich zur Seite“ (bei seitlichen Profilen), „Mehr Licht oder näher ran“ (Gelenke unsicher).
- „Ohne Kamera“ oben rechts, jederzeit.
- **Bestanden** ist der Check, wenn alle Pflichtgelenke 1 s lang durchgehend sicher erkannt sind (Vorschlag) und der Körper mit etwas Rand im Bild liegt. Dann wechselt die Ansicht von selbst zu 7.3.
- Ist der Check beim Öffnen schon bestanden (zweiter Satz, Handy steht noch), wird 7.2 übersprungen.
- Sind mehrere Personen im Bild, gilt die größte (wie im Versuch). Offener Punkt, Abschnitt 13.

### 7.3 Erkannt: Countdown (Bild 3)

- Rahmen und Strichfigur in Akzentfarbe, „Du bist ganz im Bild“, darunter „Geh in die Startposition und bleib kurz ruhig stehen.“
- „Los in 3“ zählt herunter. Der Countdown beginnt erst, wenn das Signalgelenk 0,5 s ruhig ist (Vorschlag); die Stellung in diesem Moment ist die **Startposition** (Lage 0, Abschnitt 8.2).
- Geht während des Countdowns ein Pflichtgelenk verloren, zurück zu 7.2.
- „Abbrechen“ führt zu 7.2; von dort mit „Ohne Kamera“ hinaus.
- Bei null beginnt der Satz: die Los-Marke der Welle.

### 7.4 Satz läuft (Bild 4 und 5)

- Livebild im Vollbild, darüber die Strichfigur, dezent.
- Die Welle liegt als Band über dem Bild (Lage im Bild laut Canvas). Sie läuft von rechts nach links. Die Soll-Linie ist weiß, die eigene Spur und der Punkt in Akzentfarbe; der Punkt steht an einer festen Jetzt-Linie und bewegt sich nur auf und ab.
- Phasenwort groß („SENKEN“, „HALTEN“, „HEBEN“) nach der Soll-Welle.
- Zähler „5 von 8 Wdh.“ (Ist aus der Kamera, Soll aus den Startwerten; ohne Soll nur die Ist-Zahl).
- Eine Pille zeigt den Zustand: „Im Takt“; liegt der Punkt länger als 0,5 s vor oder hinter der Bahn (Vorschlag), wechseln Spur und Pille auf die Warnfarbe mit einem Satz: „Zu schnell, langsamer senken“ bzw. „Zu langsam, zügiger heben“ (Wort je nach Phase).
- Knöpfe: „Satz beenden“ und ein Knopf, der das Übungsvideo klein einblendet. Solange das Video offen ist, laufen Welle und Zählung weiter.
- Die Welle ist feste Zeitvorgabe ab der Los-Marke und passt sich nicht an (wie Tempo-Spec 7.1). Nach der Soll-Zahl läuft sie gedämpft weiter; das Erreichen der Soll-Zahl beendet den Satz nicht.

### 7.5 Tracking verloren (Bild 6)

- Auslöser: Mindestens ein Pflichtgelenk ist länger als 1 s nicht sicher erkannt (Vorschlag). Kürzere Aussetzer überbrückt die Anzeige; der Punkt wird in dieser Zeit blass, die Zeit zählt nicht in den Rückblick.
- Der Satz pausiert: Welle und Satzuhr stehen. Text: „Wir sehen dich nicht mehr. Die Welle wartet. Deine n Wiederholungen bleiben gezählt. Stell dich wieder in den Rahmen, dann geht es von allein weiter.“
- Sind die Pflichtgelenke wieder 1 s sicher erkannt, läuft ein kurzer Vorlauf (2 s, Vorschlag) mit neuer Los-Marke, dann setzt die Welle am Beginn einer Wiederholung wieder ein. Die Zählung läuft weiter; eine angefangene Wiederholung zählt nur, wenn die Kamera sie zu Ende sieht.
- Knöpfe: „Ohne Kamera weiterzählen“ (7.7, die gezählten Wiederholungen stehen im Rad) und „Satz bei n Wdh. beenden“ (7.6).
- Kommt niemand zurück, bleibt das Bild stehen; es gibt keinen stillen Abbruch.

### 7.6 Satzende: Rückblick (Bild 7)

- Der Satz endet durch „Satz beenden“, durch „Satz bei n Wdh. beenden“ oder nach 8 s ohne Bewegung des Signalgelenks, sofern mindestens eine Wiederholung gezählt ist (Vorschlag, wie die 8-s-Regel der Satzautomatik).
- Der Satz wird **sofort** auf dem bestehenden Weg gesichert (`satzSichern`), mit der gezählten Wiederholungszahl und dem Gewicht der Startwerte, und die Pause beginnt wie heute. Die Zahl geht als `eingegeben` an den Server, so als hätte das Mitglied sie am Rad eingestellt (Entscheidung 19): Die Herkunft `gemessen` verlangt heute Zeiten und Ausschlag je Wiederholung und eine Befestigungsart des Sensors (`packages/domain/src/herkunft.ts`); das widerspräche Entscheidung 18 und bräuchte Server-Arbeit. Der Kamera-Ablauf hält das Sichern nie auf; schlägt es fehl, greifen die bestehenden Wege (Offline-Warteschlange, Fehlermeldung der Übungsansicht).
- Über der laufenden Pause liegt der Rückblick: „Satz geschafft“, Wiederholungen, „Im Takt 6 von 8“, ein Balken je Wiederholung, ein Satz zu den Ausreißern („Bei Wdh. 4 und 7 warst du beim Senken zu schnell. Lass dir unten die vollen 3 Sekunden.“), die Pausenuhr.
- Knöpfe: „Satz n starten“ (zurück zu 7.2 bzw. direkt 7.3) und „Wdh. korrigieren“ (öffnet die bestehende Korrektur der Übungsansicht).
- Läuft die Pause ab, ohne dass getippt wurde, öffnet sich der Kamera-Ablauf von selbst bei 7.2 bzw. 7.3 (Entscheidung 20). Die Übungsansicht darunter wechselt wie heute nach `eingabe`. Die Naht zu `GeraetModel` geht deshalb in beide Richtungen: Der Ablauf übergibt das Satzergebnis, die Übungsansicht meldet Pausenende und ob die Übung mit Kamera läuft.
- **Sensor:** Solange der Kamera-Ablauf einen Satz führt, sind Zähler und Satzautomatik des Bewegungssensors stillgelegt (Entscheidung 21); kein Satz wird doppelt oder mit der Zahl des Sensors gesichert. Nach „Ohne Kamera“ gelten sie wieder wie heute. Ein Debug-Mitschnitt darf weiterlaufen, löst aber nichts aus.
- Gewicht ändern zwischen den Sätzen: über die bestehende Pausenansicht. Der Rückblick lässt sich dafür schließen; „Satz n starten“ gibt es danach auch dort (Vorschlag, Abschnitt 13).
- Nach dem letzten geplanten Satz steht statt „Satz n starten“ der Weg der bestehenden Phase `abschluss` („Gerät abschließen“ / „Weiterer Satz“).
- Bei weniger als drei gezählten Wiederholungen zeigt der Rückblick keine Tempo-Zahlen, nur „Zu kurz für einen Rückblick“.

### 7.7 Ohne Kamera

- „Ohne Kamera“ in 7.1–7.3 schließt den Ablauf; darunter liegt die Übungsansicht in `eingabe`, wie heute nach dem Countdown.
- „Ohne Kamera weiterzählen“ in 7.5 schließt ihn ebenso; das Wiederholungsrad steht auf der bisher gezählten Zahl, das Mitglied sichert den Satz selbst.
- Die Wahl gilt für die laufende Übung: Weitere Sätze dieser Übung starten ohne Kamera. In der Pausenansicht gibt es einen Knopf „Mit Kamera“, der in 7.2 einsteigt. Die nächste Übung beginnt wieder mit 7.1.

### 7.8 Profil `ohne_kamera`: Welle als Vorgabe

- 7.1 ohne den Erklärsatz zur Kamera; Knöpfe „Mit Welle trainieren“ und „Ohne Welle trainieren“.
- Kein Aufstellen. Countdown „Los in 3“, dann die Welle im Vollbild ohne Livebild und ohne eigenen Punkt, mit Phasenwort und der Soll-Wiederholung als Zähler.
- „Satz beenden“ führt in die Übungsansicht (`eingabe`); das Mitglied trägt die Wiederholungen wie heute ein. Kein Rückblick.

## 8. Vom Bild zur Lage

### 8.1 Erkennung

- Apples `VNDetectHumanBodyPoseRequest` auf dem Bild der Frontkamera, wie im Versuch. Ein Gelenk gilt als sicher ab einer Sicherheit von 0,3 (Wert des Versuchs; im Gütetest nachzuschärfen).
- Die Erkennung läuft nur, solange der Kamera-Ablauf ein Livebild zeigt (7.2–7.5). In Rückblick und Pause ist die Kamera aus.

### 8.2 Signal und Lage

- Das **Wellensignal** einer Übung ist ein Gelenkwinkel aus dem Katalog: `ellbogen`, `schulter`, `huefte` oder `knie` (die Winkel des Versuchs). Das von selbst wechselnde „führende Gelenk“ des Versuchs entfällt.
- **Seite:** `links`, `rechts` oder `beide`. Bei `beide` gilt in der ersten Wiederholung die Körperseite, deren Signalwinkel sich stärker bewegt; sind beide gleichauf (beidseitige Übung), die sicherer erkannte. Die Seite steht nach der ersten Wiederholung für den Satz fest. So folgt die Welle bei einarmigen und einbeinigen Übungen dem arbeitenden Arm oder Bein, ohne dass das Mitglied eine Seite wählt; der Katalog kennt heute kein Merkmal „einseitig“ und braucht auch keins. `links`/`rechts` im Katalog ist nur für Übungen gedacht, bei denen eine Seite verdeckt ist.
- **Abwechselnde Übungen** (links, rechts, links …): Ein Signal einer Seite sähe nur die halbe Zahl. Sie starten als `ohne_kamera`; ein Zählen über beide Seiten ist nicht Teil dieses Projekts (Entscheidung 22).
- **Lage** = (Winkel − Winkel der Startposition) / Hub, mit dem Vorzeichen des ersten Wegs. Lage 0 ist die Startposition aus 7.3, Lage 1 der Umkehrpunkt.
- **Hub:** je Übung lokal gemerkt (nicht je Station; das Handy steht jedes Mal anders, der Gelenkwinkel hängt daran weniger als ein Sensorwinkel). Ohne gemerkten Wert wächst er in den ersten zwei Wiederholungen aus den Umkehrpunkten; die Lage gilt so lange als nicht sicher. Danach folgt er nur noch langsam (wie Tempo-Spec N9).
- **Wiederholungen:** Umkehrpunkte des Signals mit einer Schwelle, die mit dem Hub wächst (Ansatz des `WendeZaehler`). Eine Wiederholung zählt mit der Rückkehr zur Startposition.
- **Glättung:** kurz (im Versuch 0,08 s), damit der Punkt nicht zittert und nicht nachhinkt.
- Das Ergebnis ist eine `Lage` wie aus dem Sensor; `Sollwelle` und `Tempoauswertung` werden damit gespeist.

### 8.3 Welle und Tempo

- `Tempovorgabe` bekommt eine Haltezeit am Umkehrpunkt (0–3 s in Schritten von 0,5 s, Standard 0) und `Sollwelle` ein flaches Stück dort. Mit Haltezeit 0 verhält sich alles wie heute; die bestehenden Tests bleiben grün.
- Die Welle beginnt immer mit dem Weg aus der Startposition. Ob das „senken“ oder „heben“ ist, sagt der Katalog (`beginnt_mit`); davon hängen die Zuordnung der Sekunden (senken/heben auf Hin- und Rückweg) und die Phasenworte ab.
- Ohne Tempo im Katalog gilt der Standard der `Tempovorgabe` (1,5 s heben, 2,5 s senken, kein Halten).
- **Rückblick je gezählter Wiederholung.** „n“ in „Im Takt x von n“ ist die Zahl der von der Kamera gezählten Wiederholungen, dieselbe Zahl, die gesichert wird; je gezählter Wiederholung ein Balken. Anders als in der Tempo-Spec wird hier nicht in Perioden der Soll-Welle gerechnet: Dort gibt es keine Pause mitten im Satz, hier schon (7.5).
  - Eine Wiederholung gilt als im Takt, wenn der Punkt in mindestens 70 % ihrer eigenen Dauer (von ihrem Beginn bis zur Rückkehr in die Startposition) in der Bahn lag (Vorschlag). Zeit mit nicht sicherer Lage zählt nicht mit; besteht eine Wiederholung überwiegend daraus, bekommt sie einen leeren Balken und zählt weder für x noch für n des Takts.
  - „Zu schnell“ / „zu langsam“ je Weg einer Wiederholung: gemessene Dauer des Wegs gegen die Soll-Dauer, mit einer Toleranz von 25 % (Vorschlag). Daraus entsteht der Satz zu den Ausreißern.
  - Die ersten zwei Wiederholungen werden nur bewertet, wenn der Hub gemerkt war.
  - Nach einer Pause (7.5) beginnt die Soll-Zeit an der neuen Los-Marke neu.
  - `Tempoauswertung` kann das heute nicht (sie überspringt die ersten zwei Perioden immer, urteilt je Weg nur über den ganzen Satz und kennt keine Pause). Ob sie erweitert wird oder eine eigene Auswertung daneben entsteht, entscheidet der Bauende; das Verhalten für den Sensor und seine Tests bleiben unverändert.
- Die Bahnbreite bleibt ±0,2 als Startwert und wird am Gerät eingestellt.

## 9. Katalog, API, Portal

**Neue Angaben an der Übung** (alle optional; ohne `kamera_profil` gibt es keinen Kamera-Ablauf):

| Feld | Werte |
|---|---|
| `kamera_profil` | einer der sechs Schlüssel aus Abschnitt 5 |
| `kamera_signal` | `ellbogen`, `schulter`, `huefte`, `knie`; Pflicht, außer bei `ohne_kamera` |
| `kamera_seite` | `links`, `rechts`, `beide` (Standard `beide`) |
| `tempo_senken_s`, `tempo_halten_s`, `tempo_heben_s` | Sekunden in Schritten von 0,5; alle drei oder keins |
| `tempo_beginnt_mit` | `senken` oder `heben`; Pflicht, sobald ein Profil gesetzt ist |

- **Datenbank:** eine Migration, neue Spalten an `public.exercises` mit Prüfregeln, nach dem Muster von 0076. Keine neue Policy. **Auf Prod nur nach Tims ausdrücklicher Freigabe.**
- **Katalogdatei:** `uebungSchema` in `katalog-datei.ts` bekommt zwei optionale Objekte `kamera` und `tempo`; der Import schreibt sie.
- **API und App:** Die Felder laufen denselben Weg wie `geraet_label` bis in `BootstrapResponse`.
- **Portal:** `UebungFormular.tsx` (studioeigene Übungen) bekommt einen Abschnitt „Kamera und Tempo“: Profil, Signal, Seite, drei Zeiten, Beginn. Der Gymtavo-Katalog wird weiter über die Datei gepflegt.
- **Zuordnung der rund 260 Katalog-Übungen:** Ein Vorschlag wird erzeugt aus Gerätetyp, Übungstyp und dem führenden Gelenk je Video (`ergebnis.csv`), als Liste unter `docs/`, die Tim durchsieht. Übungen, deren Video im Versuch falsch zählte oder nicht erkannt wurde, starten als `ohne_kamera`. Tempowerte: ein Vorschlag je Übungstyp in derselben Liste.
- **Freigeschaltete Profile:** Im Domänenpaket steht eine Liste der Profile, die den Gütetest bestanden haben (anfangs nur `ohne_kamera`). Die Prüfung der Katalogdatei, die API beim Speichern einer Übung und die Auswahl im Portal lassen nur Profile aus dieser Liste zu; die Prüfregel der Datenbank kennt alle sechs. Besteht ein Profil, wird es dort ergänzt und ausgeliefert. Die App braucht keine eigene Sperrliste. Bis dahin stehen die betroffenen Übungen auf `ohne_kamera` oder ohne Profil.

## 10. Gütetest je Profil

Zwei Stufen, beide müssen bestehen, bevor ein Profil Übungen zugewiesen wird.

**Stufe 1, am Mac über die Übungsvideos:** Die neue Auswertung läuft mit dem festen Signal aus dem Zuordnungsvorschlag über alle Videos des Profils (Skelette am Mac vorgerechnet, wie im Versuch) und schreibt einen Bericht. Bestanden, wenn in mindestens 90 % der Videos des Profils die Wiederholungszahl stimmt und die Pflichtgelenke in mindestens 95 % der Bilder erkannt sind (Vorschlag). Die Videos zeigen saubere Kunstfiguren; das ist eine untere Hürde, kein Beweis.

**Stufe 2, im Studio durch Tim:** Je Profil drei Übungen, je ein echter Satz mit dem Aufstell-Check. Bestanden, wenn der Check ohne Hilfe von außen zu einer Aufstellung führt, die Zählung höchstens eine Wiederholung danebenliegt und höchstens einmal je Satz „Tracking verloren“ erscheint. Dabei werden die Abstände für die Anweisungstexte festgelegt.

Erwartung: `ganzkoerper_stehend` und `oberkoerper` bestehen. `stuetz_boden`, `liegend` und `zug_haengend` sind offen. Besteht ein Profil nicht, bleiben seine Übungen auf `ohne_kamera`; das ist kein Scheitern des Projekts.

## 11. Erlaubnis und Datenschutz

- `NSCameraUsageDescription` wird ergänzt: QR-Scan und Erkennung der Bewegung beim Training, Bilder bleiben auf dem Gerät.
- Kamera noch nicht gefragt: iOS fragt bei „Handy aufstellen“. Abgelehnt oder gesperrt: 7.1 zeigt statt „Handy aufstellen“ den Hinweis „Kamera ist nicht erlaubt“ mit „In den Einstellungen erlauben“ und „Ohne Kamera trainieren“.
- Kein Bild, kein Skelett und kein Gelenkwinkel wird gespeichert oder gesendet. Lokal gemerkt wird nur der Hub je Übung.
- Der Bildschirm bleibt während des Kamera-Ablaufs an. Musik anderer Apps läuft weiter (`AudioSitzung`).
- Datenschutztext der App und des Studios: Prüfung durch Tim, Abschnitt 13.

## 12. Fehlerfälle

| Fall | Verhalten |
|---|---|
| Kamera nicht erlaubt | 7.1 mit Hinweis und Weg in die Einstellungen; „Ohne Kamera“ |
| Kamera nicht verfügbar (anderes Programm, Fehler beim Start) | Hinweis im Aufstell-Schritt, „Ohne Kamera“; kein Absturz, kein leerer Bildschirm |
| Kein Übungsvideo | Vorschaubild oder Platzhalter; der Ablauf geht weiter |
| Pflichtgelenk im Countdown verloren | zurück zum Aufstellen |
| Pflichtgelenk im Satz länger als 1 s verloren | 7.5 |
| Bewegung zu klein für das Signal (Hub nach zwei Wiederholungen unter 20°, Vorschlag) | Hinweis „Wir erkennen die Bewegung nicht sicher“, weiter wie „Ohne Kamera weiterzählen“ |
| Mitglied bewegt sich nach der Los-Marke nicht (zwei Wellenperioden) | Welle stoppt, „Bereit? Tippen zum Neustart“; kein Satz begonnen, nichts gesichert |
| Zweite Person läuft durchs Bild | größte Person gilt; springt die Figur, greift die Regel für verlorene Pflichtgelenke |
| App geht in den Hintergrund, Anruf | Satz pausiert wie in 7.5; beim Zurückkommen Aufstell-Check |
| Sichern schlägt fehl | bestehendes Verhalten der Übungsansicht; der Rückblick wird trotzdem gezeigt |
| Handy wird heiß oder langsam (Bildrate unter 15 je Sekunde über 3 s, Vorschlag) | Hinweis und Angebot „Ohne Kamera weiterzählen“ |
| Übung ohne Profil, im Zirkel, auf Zeit | kein Kamera-Ablauf, alles wie heute |

## 13. Offene Punkte

Von Tim zu entscheiden oder zu prüfen:
1. Herkunft der Zahl (Entscheidung 19): `eingegeben` wie vorgeschlagen, oder soll der Server Kamera-Sätze als gemessen erkennen können? Das Zweite braucht eine neue Herkunft in Domäne, API und ggf. Datenbank, ein API-Deploy vor der App und eine Entscheidung, ob Zeiten je Wiederholung gesendet werden.
1a. Annahmen 8–13 und Vorschläge 14–23 aus Abschnitt 2 bestätigen oder ändern.
2. Gewicht zwischen den Sätzen ändern: über die bestehende Pausenansicht (7.6) oder mit einem eigenen Gewichtsrad im Rückblick?
3. Soll „Ohne Kamera“ bei einer Kamera-Übung die Welle als reine Vorgabe anbieten (wie 7.8) oder wirklich alles wie heute lassen (Annahme 9)?
4. Datenschutztext für Mitglieder und Studios zur Kameranutzung.
5. Zuordnungsliste der Übungen zu Profilen, Signal und Tempo durchsehen (entsteht in der Umsetzung).

In der Umsetzung zu messen:
6. Abstände je Profil; ob `stuetz_boden` und `liegend` hochkant tragen.
7. Mehrere Personen im Bild im vollen Studio; ob „größte Person“ reicht.
8. Rechenzeit, Wärme und Akku auf dem iPhone über eine ganze Einheit; ältestes Gerät, auf dem es flüssig läuft.
9. Alle Schwellen, die als „Vorschlag“ markiert sind (1 s, 0,5 s, 70 %, 20°, 8 s).
10. Handhöhe, Schulterhöhe oder Kopfhöhe als Wellensignal, falls ein Gelenkwinkel bei einem Profil nicht trägt. Nicht Teil des ersten Baus.

## 14. Etappen

| Etappe | Inhalt | Fertig, wenn |
|---|---|---|
| E1 | Kern ohne Oberfläche: Skelett → Lage und Zählung mit festem Signal, Pflichtgelenk-Prüfung, Haltephase in `Tempovorgabe` und `Sollwelle`, Rückblick je Wiederholung; Bericht Stufe 1 über die Videos. Die vorgerechneten Skelette liegen noch nicht vor; `loops-pruefen` im Versuch schreibt sie mit `SKELETTE=<Ordner>` | Bericht liegt vor, bestehende Sensorik-Tests grün |
| E2 | Katalog: Migration (lokal), Dateiformat, Import, API, App-Modell; Zuordnungsvorschlag als Liste | Tim hat die Liste durchgesehen |
| E3 | Kamera-Ablauf 7.1–7.4 für `ganzkoerper_stehend` und `oberkoerper`, im Simulator mit vorgerechneten Videos sichtbar | Tim hat den Ablauf im Simulator gesehen |
| E4 | Tracking verloren, Satzende mit Sichern und Rückblick, „Ohne Kamera“, Erlaubnis, alle Fehlerfälle | Ein Satz am iPhone mit Kamera trainiert und gesichert |
| E5 | Übrige Profile, `ohne_kamera`-Welle, Gütetest Stufe 2 je Profil, Abstände und Texte | Je Profil bestanden oder bewusst auf `ohne_kamera` gesetzt |
| E6 | Portal-Formular; Migration und Katalogdaten auf Prod nach Tims Freigabe | Studioeigene Übung mit Profil im Portal angelegt und in der App trainiert |

## 15. Tests

- Kern als reine Logik im Package, am Mac testbar: künstliche Skelettfolgen (saubere Bewegung, Stocken, Gelenk fällt aus, Seitenwechsel, zu kleiner Hub) und Abspieltests über die vorgerechneten Skelette der Übungsvideos mit Bericht.
- `Sollwelle` und `Tempovorgabe` mit Haltezeit als reine Funktionen der Zeit.
- Ablauf als Zustandsmaschine ohne Kamera getestet: jeder Übergang aus Abschnitt 7 und jeder Fall aus Abschnitt 12, mit einer Bildquelle, die Skelette aus einer Datei liefert.
- App-Tests nach dem Muster der vorhandenen: Satz wird mit der gezählten Zahl gesichert; „Ohne Kamera“ lässt die Übungsansicht unverändert; Sichern schlägt fehl.
- Domain und API: Prüfung der neuen Katalogfelder, Import, Ausgabe.
- Portal: Formular-Tests wie bei `UebungFormular.test.tsx`.

## 16. Dem Bauenden überlassen

- Name und Zuschnitt des neuen Packages; was aus `KameraVersuch` übernommen und was neu geschrieben wird. Der Versuch wird nicht als Ganzes gemergt.
- Wie der Ablauf technisch über der Übungsansicht liegt und wie er das Ergebnis übergibt, solange `GeraetModel` nur eine schmale, immer vorhandene Naht bekommt (Muster `SatzZaehler`).
- Filter und Schwellen der Zählung, Regel für den Seitenwechsel, Glättung der Anzeige.
- Genaue Texte, sofern sie dem Canvas entsprechen; Verhalten bei „Bewegung reduzieren“; Feinheiten der Animation.
- Spaltennamen und Prüfregeln der Migration, Form der Objekte in der Katalogdatei.
- Aufbau des Aufstell-Rahmens je Profil.

## 17. Nicht enthalten

- Sensor als Quelle der Welle, Sensor-Tempo-Modus (eigenes Projekt, Tempo-Spec).
- Technik-Bewertung, Tiefenmessung, 3D-Erkennung.
- Tempo je Planposition, Verstellen durch das Mitglied.
- Speichern, Verlauf oder Portal-Ansicht der Tempo-Ergebnisse; Punktestand und Spielmechanik.
- Zirkel, Cardio, Übungen auf Zeit, Querformat, Rückkamera.
