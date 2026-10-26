# Muskelabdeckung und Graudarstellung – 26.10.2026

Basis: `master` / `a3c89bf2190a52e1fb86195bcdffdf59e422a593`.
Geprüft wurden die GitHub-Katalogdatei und die iOS-Auswertung, keine Live-Datenbank.
Der Katalog enthält weiterhin 162 eindeutige Übungen: 152 Kraftübungen und 10 Cardioübungen.

## Anzeige

Die alte Regel blendete Muskeln mit höchstens zwei Hauptübungen grundsätzlich grau aus.
Rückenstrecker, Adduktoren, Abduktoren und Rotatorenmanschette werden nun regulär bewertet.
Auch Serratus ist nach den ergänzten Nebenmuskelzuordnungen auswertbar.
Die Startübersicht übernimmt weiterhin die Gruppenfarbe; das Detail bewertet die einzelnen Muskeln.
Eine grüne Fläche in der Startübersicht belegt deshalb nicht, dass genau dieser Teilmuskel trainiert wurde.

Nur Tibialis und Fibularis bleiben als dargestellte Muskeln ohne Kraftübung grau.
Der Detailtext lautet jetzt „keine Kraftübung im Katalog“.
Die Liste `Ausgewogenheit.ohneKraftuebung` wird durch einen Vertragstest gegen den echten
Katalog und alle vier Modellansichten geprüft. Haupt- und Nebenrollen zählen bei dieser
Abdeckungsprüfung gleichermaßen. Neue Kraftzuordnungen erfordern die entsprechende
Anpassung dieser Liste; andernfalls schlägt der Test fehl.

Die Regeln für aufgezeichnete Trainings bleiben bestehen: mindestens drei auswertbare
Einheiten, 28-Tage-Fenster, Hauptmuskel ab einem Satz, Nebenmuskel ab zwei Sätzen pro Einheit.
Cardio-Sätze zählen nicht zur Kraftauswertung. Anatomische Detailflächen (Kopf, Hände,
Füße, Sehnen usw.) bleiben neutral. `deep_core`, `hip_flexors`, `pelvic_floor` und `neck`
haben weiterhin keine eigene Modellfläche und sind nicht Teil der sechs Auswertungsgruppen.

Der Lastfortschritt berücksichtigt weiterhin nur Hauptmuskeln. Reine Nebenmuskeln wie
Serratus bekommen deshalb keinen irreführenden Hinweis „braucht noch Trainings“,
wenn prinzipbedingt kein eigener Fortschrittswert entstehen kann.

## Ergänzte Zuordnungen

Alle Ergänzungen sind `secondary`; die Hauptmuskeln, Übungsabläufe, Videos und Plankategorien
bleiben bestehen. `fibularis` wurde als fehlender Muskelschlüssel registriert.
Die Übungsdatensätze bleiben `review: draft`, es wird keine fachliche Freigabe behauptet.

| Vorhandene Übung | Ergänzte Nebenmuskeln |
|---|---|
| Kurzhantel-Schulterdrücken – sitzend (`db_shoulder_press_seated`) | serratus_anterior |
| Kurzhantel-Schulterdrücken – stehend (`db_press_standing`) | serratus_anterior |
| Langhantel-Schulterdrücken – sitzend (`bb_seated_press`) | serratus_anterior |
| Laufband – Gehen (`cardio_treadmill_walk`) | tibialis, hip_flexors, fibularis |
| Laufband – Laufen (`cardio_treadmill_run`) | tibialis, hip_flexors |

## Begründung und Grenzen der Zuordnungen

- **Serratus:** [Błażkiewicz/Hadamus 2022](https://pubmed.ncbi.nlm.nih.gov/36560129/)
  untersuchten unter anderem den Serratus beim sitzenden Kurzhanteldrücken;
  [Büll et al. 2001](https://pubmed.ncbi.nlm.nih.gov/11572186/) untersuchten ihn
  bei Varianten des Military Press. Die Übertragung auf die stehende Kurzhantelvariante
  ist eine anatomische Ableitung aus dem vergleichbaren Überkopfbewegungsmuster,
  keine separat gemessene Aktivierung exakt unseres Übungsdatensatzes.
- **Tibialis:** [Studie 2016](https://pubmed.ncbi.nlm.nih.gov/27400020/)
  erfasste diesen Muskel beim Gehen, Joggen und Laufen auch auf motorisierten Laufbändern.
- **Hüftbeuger:** [Andersson et al. 1997](https://pubmed.ncbi.nlm.nih.gov/9401589/)
  zeichneten unter anderem Iliacus und Psoas beim Gehen und Laufen auf dem Laufband auf.
- **Fibularis:** [Kim et al. 2015](https://pubmed.ncbi.nlm.nih.gov/26834363/)
  erfassten den Peroneus longus beim Gehen auf dem Laufband. Deshalb zunächst nur
  dort ergänzt; aus dieser Studie wird keine zusätzliche Lauf- oder Kraftzuordnung abgeleitet.

Die Rollen sind eine schematische Katalogeinordnung. EMG-Beteiligung wird weder als
quantifizierter Trainingsreiz noch als Nachweis gleichwertigen Muskelaufbaus interpretiert.
Es wurden keine Muskeln allein zur Einfärbung der Grafik ergänzt.

## Weiter offene Lücken

- **Halsmuskulatur und Beckenboden:** weiterhin keine zugeordneten Übungen.
  Aus allgemeiner Stabilisation bei bestehenden Übungen wird hier keine spezifische
  Trainingszuordnung abgeleitet. Der Nacken/Trapezius unter `upper_back` ist nicht
  mit einer gezielten Übung für `neck` gleichzusetzen.
- **Tibialis, Fibularis, Hüftbeuger:** jetzt belegte Cardio-Beteiligung, weiterhin
  keine gezielte Kraftübung im Katalog. Eine spätere Erweiterung braucht passende
  Übung, Anleitung und Visualisierung, statt bestehende Videos umzubenennen.
- **Serratus:** drei Nebenmuskelzuordnungen, noch keine primäre Zielübung.
- **Tiefe Rumpfmuskulatur:** elf bestehende Nebenmuskelzuordnungen, weiterhin ohne
  eigene Grafikfläche. Keine neue Anatomie gezeichnet.

## Vollständige Zählung nach Änderung

Pro Muskel wird eine Übungs-ID höchstens einmal gezählt. Eine Übung darf in mehreren
Muskelzeilen stehen. „Kraft gesamt“ schließt die zehn Cardioübungen aus.

| Muskel | Hauptmuskel | Nebenmuskel | Gesamt inkl. Cardio | Kraft gesamt |
|---|---:|---:|---:|---:|
| Brust | 22 | 9 | 31 | 29 |
| Vordere Schulter | 8 | 26 | 34 | 33 |
| Seitliche Schulter | 10 | 0 | 10 | 10 |
| Hintere Schulter | 4 | 17 | 21 | 21 |
| Oberarmbeuger (Bizeps / Brachialis) | 20 | 27 | 47 | 45 |
| Trizeps | 17 | 21 | 38 | 36 |
| Unterarme | 8 | 19 | 27 | 27 |
| Latissimus | 27 | 5 | 32 | 28 |
| Oberer Rücken | 21 | 16 | 37 | 36 |
| Rückenstrecker | 1 | 7 | 8 | 7 |
| Gerader Bauchmuskel | 4 | 4 | 8 | 7 |
| Seitliche Bauchmuskeln | 6 | 2 | 8 | 8 |
| Großer Gesäßmuskel | 31 | 4 | 35 | 25 |
| Seitliche Hüfte | 2 | 0 | 2 | 2 |
| Oberschenkel innen | 2 | 11 | 13 | 13 |
| Oberschenkel vorne | 26 | 2 | 28 | 18 |
| Oberschenkel hinten | 7 | 17 | 24 | 14 |
| Waden | 7 | 11 | 18 | 10 |
| Schienbeinmuskel | 0 | 2 | 2 | 0 |
| Wadenbeinmuskulatur (Fibularis) | 0 | 1 | 1 | 0 |
| Hüftbeuger | 0 | 2 | 2 | 0 |
| Vorderer Sägemuskel (Serratus) | 0 | 3 | 3 | 3 |
| Rotatorenmanschette | 2 | 0 | 2 | 2 |
| Tiefe Rumpfmuskulatur | 0 | 11 | 11 | 4 |
| Beckenboden | 0 | 0 | 0 | 0 |
| Halsmuskulatur | 0 | 0 | 0 | 0 |

## Validierung

- `pnpm --filter @fitretro/domain test`: **450 Tests in 36 Dateien bestanden**,
  inklusive Katalogvalidierung, Importplanung und Trainingsplangenerator.
- `pnpm --filter @fitretro/domain typecheck`: bestanden.
- `git diff --check`: bestanden.
- iOS-Regressionstests angepasst/ergänzt: aktive und untrainierte bisher ausgeschlossene
  Muskeln, Mindestdatenmenge, Farben, Hinweise, Serratus als Nebenmuskel,
  Cardio-Ausschluss sowie fehlender Lastfortschritt bei reinen Nebenmuskeln.
- **iOS-Tests und Simulatorprüfung noch offen:** diese Linux-Umgebung hat kein
  Swift/Xcode/iOS-SDK. Auch die bestehende GitHub-CI führt nur das separate
  Sensorik-Swift-Paket aus, nicht `FitnessMemberTests`.

## Lokale Übernahme und Nachprüfung (Mac, 26.10.2026)

- Alle 15 Paketdateien konfliktfrei übernommen und vor dieser Ergänzung gegen die
  SHA-256-Prüfsummen des Manifests geprüft. Bestehende Sensorik-Änderungen liegen
  in anderen Dateien und wurden nicht verändert.
- Fehlende lokale Node-Abhängigkeiten mit `pnpm install --frozen-lockfile` ergänzt;
  anschließend 450 Domain-Tests in 36 Dateien sowie Domain-Typprüfung bestanden.
- iOS-App erfolgreich gebaut; alle 43 Tests aus `AusgewogenheitTests`,
  `HaeufigkeitTests`, `MuskelAuswertungTests`, `MuskelFarbenTests` und
  `MuskelHinweiseTests` im iPhone-17-Pro-Simulator (iOS 26.3) bestanden.
- `git diff --check` erfolgreich. Eine manuelle Sichtprüfung von Übersicht und
  Detail mit Trainingsdaten bleibt offen.
- Kein Live-Katalogimport oder Deployment durchgeführt.

## Übernahme

1. Pull Request prüfen; `FitnessMemberTests` auf einem Mac mit Xcode ausführen und
   Übersicht/Detail im Simulator prüfen.
2. Nach Übernahme den vorhandenen Katalogimport zuerst als Trockenlauf ausführen:
   `pnpm catalog:import --dry-run` (benötigt die bestehende Supabase-Umgebung).
   Bei identischem Ausgangsstand werden fünf Übungsdatensätze geändert; die
   Quellennachweise bleiben in der versionierten Katalogdatei.
3. Geprüften Import über den bestehenden Prozess ausführen:
   `pnpm catalog:import --ja` für das bewusst ausgewählte nicht-lokale Ziel.
   In dieser Bearbeitung wurde kein Live-Import ausgeführt.
4. Neuen iOS-Build nutzen und Bootstrap/Katalog neu laden. Ohne Katalogimport
   fehlen dem Server weiterhin die ergänzten Nebenmuskelzuordnungen.
