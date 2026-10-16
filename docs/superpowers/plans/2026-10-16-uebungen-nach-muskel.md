# Übungsliste nach Muskel gruppieren – Plan

**Ziel:** Am Gerät (z. B. Kurzhantel mit 40 Übungen) lässt sich die Übungsliste zwischen **Muskel** und **Zuletzt** umschalten. „Muskel“ gruppiert nach Hauptgruppe, darunter stehen gleiche Muskeln beieinander.

**Umfang:** Nur die iOS-Member-App. Kein Server-, kein Portal-Änderung – `muscles` liefern Bootstrap und Gerätekontext schon.

## Entscheidungen (mit Tim abgestimmt)

- Schalter als kleine Pille neben der Überschrift, Reihenfolge **Muskel | Zuletzt** (Variante B).
- „Zuletzt“ = bisherige Reihenfolge (`sortierteUebungen`: dieses Training, Häufigkeit, Rest).
- „Muskel“: Abschnitte mit Überschrift nur für die Hauptgruppen **Brust, Rücken, Schultern, Arme, Beine, Rumpf**. Keine Unter-Überschriften; innerhalb eines Abschnitts stehen gleiche Muskeln zusammen (Rücken: Latissimus, oberer Rücken, unterer Rücken).
- Die Übung steht in der Gruppe ihres ersten darstellbaren Hauptmuskels (`role == primary`).

## Annahmen (Claude, von Tim bestätigt durch „passt“)

1. Standard ist „Muskel“. 2. Die Wahl wird gemerkt (`UserDefaults`). 3. Schalter auf „Gerät erkannt“ und im Sheet „Weitere Übung“, eine gemeinsame Wahl. 4. In einer Muskelgruppe gilt die „Zuletzt“-Reihenfolge. 5. Ohne darstellbaren Muskel: Abschnitt „Weitere“ am Ende. 6. Bis 5 Übungen kein Schalter, es gilt „Zuletzt“. 7. Der Nacken hat im Modell keinen eigenen Muskel und fällt unter „oberer Rücken“.

## Zuordnung der Muskelschlüssel

| Gruppe | Schlüssel in Feinreihenfolge |
|---|---|
| Brust | pectorals, serratus_anterior |
| Rücken | lats, upper_back, erectors |
| Schultern | deltoid_anterior, deltoid_lateral, deltoid_posterior, rotator_cuff |
| Arme | biceps, triceps, forearms |
| Beine | quads, hamstrings, glutes, adductors, abductors, calves, tibialis, fibularis |
| Rumpf | abs, obliques |

Unbekannte Schlüssel (z. B. `deep_core`) zählen nicht; hat eine Übung nur solche, kommt sie nach „Weitere“.

## Aufgaben

- [ ] **1. Tests + Gruppierung** (`Workout/UebungsGruppierung.swift`, `FitnessMemberTests/UebungsGruppierungTests.swift`): `MuskelHauptgruppe`, `UebungsGruppierung.gruppieren(_:)` (stabil, Eingabe ist schon in „Zuletzt“-Reihenfolge). `GeraetUebung` bekommt `muscles` (Default `[]`), `GeraetModel.uebungen` füllt es.
- [ ] **2. Einstellung** (`Einstellungen.uebungsansichtKey`, Lesefunktion mit Vorgabe „muskel“; Test in `EinstellungenTests`).
- [ ] **3. Schalter + Ansicht** (`Screens/Geraet/UebungsAnsichtSchalter.swift`; `GeraetErkanntView` und `UebungWechselnSheet` nutzen ihn; Abschnitts-Überschrift im Label-Stil). Schalter nur ab 6 Übungen.
- [ ] **4. Prüfen:** `xcodebuild test` für die betroffenen Tests, App im Simulator ansehen, committen.

## Review-Fokus

- Übung ohne `muscles` (alter Server, Offline-Bootstrap) → „Weitere“, kein Absturz.
- Reihenfolge in der Gruppe bleibt stabil, wenn mehrere Übungen denselben Muskel haben.
- Beide Stellen zeigen dieselbe Wahl.
