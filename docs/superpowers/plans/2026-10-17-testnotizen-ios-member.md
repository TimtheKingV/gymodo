# Testnotizen 17.10. – iOS-Member-App – Plan

**Quelle:** Testsitzung 2026-10-17 00:20, gymodo Member, iPhone14,4, iOS 26.6.2 (6 Notizen). Stand-Commit: Kopf von `claude/new-session-1mu7zo`.

**Vorgehen:** Notiz für Notiz; Logik in Reinfunktionen, dazu Swift-Testing-Tests. Keine neuen Dateien (das Xcode-Projekt ist eingecheckt). Die Sitzung betrifft die App, nicht das Portal.

**Rückfragen:** keine gestellt, die Entscheidungen unten sind Annahmen von Claude und zu bestätigen.

## Etappen

| # | Notiz | Ursache | Änderung | Test zuerst rot |
|---|---|---|---|---|
| 1 | Verlauf statt Höher/tiefer-Icon | `HomeZeilen.sparkWerte` lieferte bei einem Trainingstag `[]`, die Zeile zeigte dann nur das Trendsymbol | `sparkWerte` ab einem Punkt; Symbol samt `symbol(_:)` entfernt, der Trendtext bleibt | `HomeZeilenTests.sparkWerteGibtEsAbEinemPunkt` |
| 2 | Übungsfortschritt nach Muskeln | Liste war flach; der Server-Fortschritt führt keine Muskeln | `UebungsGruppierung.abschnitte` (generisch), `HomeZeilen.muskelnJeUebung` (Bootstrap: Geräte + Katalog), `MuskelAbschnitte` und `GruppenLeiste` wie an den Geräten; Bullets ab zwei Gruppen | `UebungsGruppierungTests`, `HomeZeilenTests.muskelnJeUebung…` |
| 3 | „Gymtavo Tracker“ statt WT901… | Karte zeigte den Bluetooth-Namen | `SensorName.anzeige`, nur Anzeige (Karte, Auswahlblatt); Diagnose und Aufnahme behalten den echten Namen | `SensorKarteAnzeigeTests` |
| 4 | Übung öffnet immer die Übersicht | Bekannte Übungen (Cardio ohnehin) starteten ohne Drawer | `Uebungsstart.schritte(uebersicht:)`: auch bekannte Übungen beginnen mit der Einweisung (Muskeln, Beschreibung). `TrainingRootView` öffnet den Drawer immer, `direktStart` dort entfällt. „Kenne ich schon“ nur beim Erstkontakt | `UebungsstartTests.mitUebersicht…` |
| 5 | Kopf, Hände, Füße hell; Nacken | `detail`-Pfade wurden in `muskelHaut` gefüllt | `MuskelFigur.detailFuellung` = `muskelInaktiv`; sie werden nie grün | `MuskelModellTests.detailpfadeSindHell` |
| 6 | Geräteseite: kleines Bild | 180 pt hohes Foto über dem Namen | `Geraetefoto(breite:)`, 56 pt links neben dem Namen wie das Video in der Übung | nur Layout, ohne Test: kein Verhalten, am Gerät ansehen |

## Antworten auf Fragen der Notizen

- **#5 Nacken:** Die Stränge am Hals sind im Modell Detailflächen (Rev. 4: „Sehnen, Gelenke, Hände, Füße und Kopf bleiben neutral“). Es gibt keinen Nackenmuskel-Schlüssel, also auch keine Übung dazu; Nackenübungen laufen in der Gruppierung unter `upper_back`. Jetzt hell wie die unbeanspruchten Muskeln. Ein eigener Nackenmuskel bräuchte Schlüssel, Katalog und Fläche (Server und Modell, eigene Aufgabe).
- Die Kniescheiben (ebenfalls `detail`) werden mit hell.

## Annahmen (Claude, zu bestätigen)

1. #4 gilt für alle Wege über den Drawer: Liste, Suchtreffer, Scan, Direktsprung bei einem Gerät mit einer Übung. „Weitere Übung“ während des Trainings bleibt wie es war.
2. #4 zeigt für eine bekannte Übung die vorhandene Einweisung als Übersicht, keine neue Seite.
3. #2 hat keinen Schalter Muskel/Zuletzt, nur Alle und Gruppen. Reihenfolge je Gruppe wie vom Server. Übungen ohne Muskeln im Bootstrap stehen unter „Weitere“.
4. #1: bei einem einzigen Tag zeigt die Kurve nur den Punkt.

## Geprüft

- Nicht gelaufen: kein Swift-Toolchain in dieser Cloud-Sitzung (`xcodebuild`/`swift` fehlen). Weder Build noch Tests liefen; die Tests sind geschrieben, aber nicht rot/grün gesehen.
- Zu tun am Mac: `xcodebuild test -scheme FitnessMember` für `HomeZeilenTests`, `UebungsGruppierungTests`, `UebungsstartTests`, `SensorKarteAnzeigeTests`, `MuskelModellTests`.
- Am Gerät ansehen: Home (Bullets, Zeile mit einem Tag), Einweisung (Figur), Geräteseite (kleines Bild, lange Gerätenamen), „Gerät wählen“ → Ruderergometer (Übersicht vor dem Start).
- Die Figur wurde als SVG in Chromium gegengeprüft: alle `detail`-Pfade sind Kopf, Hals, Hände, Füße, Knie (männlich/weiblich, vorne/hinten); bei der Frau außerdem Haare und zwei Rumpflinien.
