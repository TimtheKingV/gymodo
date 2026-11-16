# Testnotizen 10.11. (und 19.10.) – Paketliste

**Quelle:** Testsitzungen `2026-11-10-1823` (15 Notizen) und `2026-10-19-1004` (4 Notizen), gymodo Member, iPhone 13 mini (iPhone14,4), iOS 26.6.2. Dazu 24 Sensoraufnahmen vom 10.11. (18:20–18:54) und das Sensorprotokoll.

**Wo die Dateien liegen** (gitignoriert bzw. nicht committet, daher absolute Pfade in den Haupt-Checkout – in Worktrees nicht vorhanden):

- Notizen: `/Users/timbuttner/Documents/gymtavo/fitness-app/apps/ios-member/testnotizen/2026-11-10-1823/sitzung.md` (Screenshots `NN-voll.png` daneben)
- Notizen 19.10.: `/Users/timbuttner/Documents/gymtavo/fitness-app/apps/ios-member/testnotizen/2026-10-19-1004/sitzung.md`
- Sensoraufnahmen: `/Users/timbuttner/Documents/gymtavo/fitness-app/data/sensoraufnahmen/2026-11-10-*` und `.../protokoll-2026-11-10.log`

**Vorgehen je Paket:** eigene Session, eigener Worktree von `origin/master`, Superpowers (brainstorming → writing-plans → test-driven-development → verification → finishing-a-development-branch). Rückfragen zur Logik gebündelt an Tim, bevor umgesetzt wird. Plan unter `docs/superpowers/plans/2026-11-10-<paket>.md` im Worktree. Am Ende die Statuszeile unten hier (in dieser Datei im Haupt-Checkout) aktualisieren.

**Reihenfolge:** P1, P5, P6 parallel (getrennte Dateien). P2 → P4 → P3 nacheinander (gleiche Plan-/Trainings-Screens, P3 hängt an P2).

## Status

| Paket | Status | Branch / PR |
|---|---|---|
| P1 Sensorik Auto-Start im Zirkel | PR offen (lokal Sensorik + 1967 App-Tests grün); Studio-Test (Zirkel 3 Runden) offen | `claude/sensorik-zirkel-autostart`, [PR #104](https://github.com/TimtheKingV/gymodo/pull/104) |
| P2 Wochenplan-Logik | PR offen, wartet auf Freigabe (Domain 674, Web 311, iOS 1963 grün); Migration 0072 auf Prod direkt vor dem Merge nötig; Simulatorprüfung nach Deploy offen | `claude/p2-wochenplan-logik`, [PR #105](https://github.com/TimtheKingV/gymodo/pull/105) |
| P3 Trainings-Startseite | kann starten (P2 im PR) | |
| P4 Einheit ansehen/bearbeiten | kann starten (P2 im PR) | |
| P5 Zirkel & Übungswahl | PR offen, wartet auf Freigabe (Suite 1973/1973 grün; Sichtprüfung auf dem iPhone offen) | `claude/p5-zirkel-uebungswahl`, [PR #103](https://github.com/TimtheKingV/gymodo/pull/103) |
| P6 Notizen 19.10. | gemergt 16.11. (alle 4 Notizen umgesetzt, #4 Variante A; CI grün); offen: Bullets bei „Zuletzt bei dir“ auf dem iPhone mit Katalog-Studio prüfen | `claude/p6-notizen-1019`, [PR #107](https://github.com/TimtheKingV/gymodo/pull/107) |

---

## P1 · Sensorik: Auto-Start im Zirkel

**Notiz 10.11. #2 (18:34, GeraeteAuswahlView):** „Beim kurzhantel zirkel 2. mit bankdrücken und rudern hat es Sätze automatisch falsch gestartet. Die müssen wir vorsichtig sehen die erste Runde hat gepasst bei 2. und 3. runde war die App auf Autopilot. Nimm das auf in die Analyse.“ – Screenshot `02-voll.png`

**Befestigungsnotiz in allen Aufnahmen (diktiert):** „… wir müssen hier wohl Anfang und Ende rausfiltern. Satz 1 links, Satz 2 rechts“ (einarmiges Rudern: Satz 1 linker, Satz 2 rechter Arm).

**Befund aus Aufnahmen und Protokoll (Claude, 10.11.):**

Zirkel 2 (Bankdrücken ↔ Kurzhantelrudern einarmig), Session `644F08F2-D1A0-4AAD-B2A0-F191A4665688`:

| Aufnahme | Übung (kontext) | Dauer | Ergebnis |
|---|---|---|---|
| 1828-01 | Bankdrücken S1 | 42 s | gesichert, Label 16, live 15 |
| 1829-01 | Bankdrücken (!) | 14 s | abgebrochen – 11 s nach dem Sichern startet nochmal Bankdrücken statt Rudern |
| 1830-01 | Rudern S1 | 44 s | gesichert, 16/16 |
| 1830-02 | Bankdrücken | 1 s | abgebrochen, sofort weiter |
| 1830-03 | Rudern S2 | 81 s | gesichert 16/16, Wiederholungen erst ab s 21 → Bankdrücken S2 hat keine eigene Aufnahme, steckt vermutlich hier drin |
| 1832-01 | Bankdrücken | 1 s | abgebrochen |
| 1832-02 | Bankdrücken | **22 min** | nie gesichert, läuft bis zum Ruderergometer 18:54 („Autopilot“) |
| – | Rudern S3 | – | fehlt ganz |

Zirkel 1 (Curl / Schulterdrücken / Trizeps über Kopf), 18:20–18:27: Bei jedem Übungswechsel startet zuerst die falsche Übung und wird in derselben Sekunde abgebrochen, dann startet die richtige. Curl S1 ist doppelt da (1820-01 Label 12, 1822-01 Label 10, beide `setIndex` 1). Live gegen Label: Curl S3 7/10, Trizeps S3 8/10, Schulterdrücken S2/S3 3/4.

**Erledigt (10.11.):** Wahrheit aus Prod gelesen (`saetze-2026-11-10.csv`), Ursachen und Fix siehe `docs/superpowers/plans/2026-11-10-p1-sensorik-zirkel.md` im Branch. Kurz: (1) die vorige Zirkel-Station nahm Sensor/Zähler zurück → falsche Namen, verworfene Automatik; (2) „Zirkel beenden“ gab den Besitzer nicht frei → 22-min-Aufnahme; (3) Automatik startete auf Hantieren mit Ausschlag 0 → Schwelle 0,01. Anfang/Ende-Filter fürs einarmige Rudern nicht angefasst.

**Ziel:** Ursache der Satzautomatik im Zirkel finden (falsche Übung beim Auto-Start, Sofort-Abbruch, Endlosaufnahme ohne Satzende), testgetrieben beheben; Anfang/Ende-Filter für Kurzhantel prüfen.

---

## P2 · Wochenplan-Logik neu denken

**#8 (19:01, PlanRootView):** „Allgemein zum Trainingsplan. Ich glaube wirklich Tage festzulegen ist ein bisschen verkopft. Lass uns einfach festlegen welche Einheiten diese Woche anstehen. Dann planen wir eigentlich gleich legen aber nicht fest wann was ist. Ausnahme sind in dem Sinne die Kurse die sind an nem festen Tag. Sonst einfach: diese Woche: Dann z.b. 2 Krafttraining und einmal Cardio. Wenn ich 1 Training abgeschlossen habe dann Haken dran einfach. Auch bei Cardio würde ich einfach planen z.b je nach Präferenz. 30 min Cardio. Wenn jemand in einer Trainingseinheit dann noch 30 min Cardio macht dann auch Haken dran. Dann haben wir auch nicht das verpasst Ding. Auch Ende der Woche wenn es an nem Sonntag nicht mehr möglich ist eigentlich lassen wir es stehen und am Montag startet es von vorne.“ – `08-voll.png`

**#9 (19:05, PlanRootView):** „Einheiten lass uns Kraft nennen.“ – `09-voll.png`

**#10 (19:05, PlanRootView):** „Kalendersprüche [Kalender] würde ich dennoch beibehalten hier tauchen dann einfach nur die geleisteten Einheiten auf. Und halt Kurse.“ – `10-voll.png`

**Kontext:** Widerspricht dem gerade gemergten Wochenplan-Tab mit festen Kurs-/Cardio-/Kraft-Tagen (PR #96, `c5fa810c`) und berührt die offene Plan-Rotation (siehe Memory). Logikfragen (was zählt als erledigt, Cardio-Minuten innerhalb einer Kraft-Einheit, Wochenwechsel, Streak/Home, Datenmodell/Migration) vor dem Umsetzen mit Tim klären. Designvorschläge für die Wochenansicht.

---

## P3 · Trainings-Startseite (hängt an P2)

**#11 (19:06, TrainingRootView):** „Hier bitte auch die Bilder der Muskelgruppen anzeigen (links) dann Name der Einheit je Trainingseinheit. Wochentag fällt dann ja eh weg.“ – `11-voll.png`

**#12 (19:07, TrainingRootView):** „Dementsprechend wenn ich auf eine Einheit gehe dann soll die Preview kommen so wie bei Plan die eigene Seite für die Einheit dann auch mit Option bearbeiten oder starten. Der Starten Button fällt dann weg. Bei Cardio bitte das Cardio Symbol, allerdings auch in dem Akzent grün.“ – `12-voll.png`

**#13 (19:09, TrainingRootView):** „Bitte alle Karten einheitlich. Freies Training dann einfach eine Hantel als Symbol. Bitte nicht gruppieren sondern alle einzeln.“ – `13-voll.png`

**Ziel:** einheitliche Karten (Muskelgruppen-Bild bzw. Symbol links, Name), Tipp → Einheit-Seite (`PlanEinheitView`) mit Bearbeiten/Starten. Designvorschläge zuerst. Gleiche Zeilen-/Kartenbausteine wie P4 nutzen.

---

## P4 · Einheit ansehen und bearbeiten (nach P2)

**#3 (18:55, PlanEinheitBearbeitenView):** „Wenn ich runter scrolle soll die gesamte Seite scrollen nicht nur der Bereich der Übungen. Die Übungen sollten in Cards sein mit Rändern.“ – `03-voll.png`

**#4 (18:56, PlanEinheitBearbeitenView):** „Unten hätte ich gerne einen Button Übung hinzufügen. Schau mal wie wir das bei dem Mini Zirkel machen so ähnlich stelle ich mir das auch vor. Wie bekommen wir hier eine einheitliche Ansicht hin.“ – `04-voll.png`

**#5 (18:57, PlanEinheitBearbeitenView, Element „STATT REVERSE BUTTERFLY – NEUTRALGRIFF“):** „Wenn ich Übung wechseln klicke. Finde ich es gut dass ich einen Vorschlag bekomme. Allerdings wär’s cool wenn ich darunter auch andere klicken kann und dann im Standard Suchprozess wie beim freien Training auswählen kann. Oben irgendwie ein Indikator dass ich tausche gegen die aktuelle Übung im Plan.“ – `05-voll.png`

**#6 (18:59, PlanEinheitBearbeitenView) – Bug:** „Hier zum Beispiel was geändert und speichern hat nicht funktioniert woran liegt das?“ – `06-voll.png`

**#7 (19:00, PlanEinheitView):** „Hier sehen die Übungen auch wieder anders aus. Übungen sollen immer links das Thumbnail haben dann Titel daneben. Wie wir rechts anzeigen wie viele Sätze und Wiederholungen im Plan dafür nochmal neuen Designvorschlag. Zum Beispiel mit Icons irgendwie.“ – `07-voll.png`

**Ziel:** Bug #6 zuerst (systematic-debugging). Dann eine einheitliche Übungszeile/-karte (Thumbnail links, Titel, Sätze×Wdh mit Icons – Designvorschläge), ganze Seite scrollt, „Übung hinzufügen“ wie Mini-Zirkel, Tauschen mit Vorschlag + Standardsuche + Indikator „tauscht gegen …“.

---

## P5 · Zirkel und Übungswahl

**#1 (18:23, ZirkelPauseView):** „Alle Bilder links sind gleich, entsprechen nicht den Bildern/Videos der Übung.“ – `01-voll.png`

**#14 (19:10, ZirkelPlanungSheet):** „Wenn ich bei Mini Zirkel bin und dann bei einem Gerät bei den Übungen auf Favorit gehe ist die Liste leer. Wenn ich standardmäßig eine Übung wähle im Freien Training funktioniert der Filter.“ – `14-voll.png`

**#15 (19:11, ZirkelPlanungSheet):** „Wenn ich auf der Ansicht eines Gerätes bin und dann eine Übung wählen soll. Dann fehlt die Suchfunktion. Wenn über 3 Übungen an einem Gerät sind dann sollte die Suche da sein.“ – `15-voll.png`

**Ziel:** zwei Bugs (#1, #14) mit Ursache und rotem Test, #15 Suche ab > 3 Übungen.

---

## P6 · Notizen vom 19.10. (erst prüfen, ob noch aktuell)

Seit dem 19.10. kamen die UX-Vereinheitlichung (PR #99–#101) und der Wochenplan-Tab. Je Notiz zuerst prüfen, ob sie auf `origin/master` noch zutrifft; erledigte/obsolete markieren.

**#1 (10:04, HomeRootView, Element „Mittwoch, 21. Kein Training.“):** „Beim Kalender würde ich gerne auch nach links rechts wischen können um in den Wochen hin und her zu springen. 1 vor 1 zurück.“ – `01-voll.png` (Achtung: berührt den Kalender, den P2 behalten will)

**#2 (10:06, SessionDetailView):** „Warum steht hier rechts teilweise +3,7 kg bei anderen +0 obwohl das Gewicht gleich geblieben ist und immer 12 kg ist in dem Satz. Das eine ist ein Durchschnitt oder? Dann lass uns einfach nur den Durchschnitt festhalten. Ein Feld rechts, nicht pro Satz.“ – `02-ausschnitt.png`, `02-voll.png` (heute: `Satzvergleich` in `SessionDetailView.swift`)

**#3 (10:16, GeraeteAuswahlView, „ZULETZT BEI DIR“):** „Hier auf der Trainingsseite etwas mehr Padding zwischen der unteren Kartenständer und den Headers, so wirkt das reingequetscht. Auf Home sieht es aufgeräumter aus.“ – `03-voll.png`

**#4 (10:18, GeraeteAuswahlView, „ZULETZT BEI DIR“):** „Können wir zuletzt bei dir auch Filter hinzufügen. Die Bullets. Alle, Bauch, Rücken, etc.“ – `04-voll.png`
