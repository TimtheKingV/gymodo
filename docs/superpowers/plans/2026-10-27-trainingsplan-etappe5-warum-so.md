# Trainingsplan Etappe 5: „Warum so?“ Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Die Seite „Warum dein Plan so aussieht“ erklärt in drei kurzen Abschnitten (Aufteilung, Gewicht, Wiederholungen) in ganzen Sätzen, statt Codes zu listen.

**Architecture:** Reine App-Arbeit, kein Server- und kein Datenbankumbau. Ein neuer, reiner Textbaustein-Typ `PlanWarumText` (Swift, versioniert, testbar) setzt die Abschnitte aus `plan.struktur` und `plan.gruende` zusammen; `PlanWarumView` zeigt sie nur an. Die Gewichts- und Wiederholungsabschnitte sind für alle Pläne gleich (allgemein, nicht je Übung).

**Tech Stack:** SwiftUI, Swift Testing, XcodeGen (`apps/ios-member/project.yml`, `FitnessMember.xcodeproj` ist eingecheckt).

**Spec:** `docs/superpowers/specs/2026-10-21-trainingsplan-design.md` Abschnitt 4 („Warum dein Plan so aussieht“, feste Textbausteine, keine KI, versioniert). Hintergrund: `docs/superpowers/plans/2026-10-25-trainingsplan-etappe5-uebergabe.md` (Abschnitt „Schnittstellen für Etappe 5“), Wiederholungsbereiche in `packages/domain/src/trainingsplan-regeln.ts` (`zielprofil`), Startschätzung in `packages/domain/src/plangewicht-start.ts`, grobe Stufen (F13) in `packages/domain/src/plangewicht.ts` (`GROBE_STUFE_EXTRA_WDH`).

## Global Constraints

Entscheidungen von Tim (27.10.2026, Brainstorming):

- Aufbau A: **eine Seite, drei Abschnitte** in dieser Reihenfolge: „Aufteilung“, „Gewicht“, „Wiederholungen“. Kurz, keine lange Erklärung.
- „Gewicht“ ist **allgemein für den ganzen Plan**, nicht je Übung. Wichtigste Aussagen: Startgewicht ist eine Schätzung, danach dynamische Anpassung.
- „Aufteilung“ ist planspezifisch: ein Struktursatz plus je ein Satz für jeden Grund, der im Plan vorkommt.
- „Wiederholungen“ nennt die Bereiche je Ziel (Muskelaufbau 8–12 Mehrgelenk / 10–15 Isolation; Fitness und Abnehmen 10–15) **und** den F13-Satz (grobe Gerätestufen: Steigerung erst bei drei Wiederholungen über dem oberen Wert in allen Sätzen). Kein „Kraft“ und kein „Ausdauer“, das System kennt beides nicht.
- Der Hinweis am Gerät (Etappe 4) bleibt unverändert; die Sprache der neuen Texte passt dazu (Du-Form, kurze Sätze).
- Feste Textbausteine, keine KI. Keine Rohcodes und kein Unterstrich in der Anzeige. Ein Code, den die App nicht kennt (neuerer Server), wird ausgelassen, nicht angezeigt.
- Datenschutz wie bisher: Die Gründe (`beschwerden_*`) bleiben auf dem Gerät, gehen nie in Log, Testnotiz-Kontext oder Analyse. `PlanWarumView` bleibt ohne `testnotizScreen(kontext:)`.
- Die App rechnet nichts (F15): die Zahlen im Text sind feste Wörter und werden zusammen mit `PLAN_REGEL_VERSION`/`PLANGEWICHT_ALGO_VERSION` gepflegt (Kommentar im Code).
- Texte sind **Entwürfe von Claude** und müssen vor dem Merge von Tim gelesen werden (Spec: „fachlich geprüft“).
- Keine Prod-Aktion (Push, PR, Merge) ohne ausdrückliche Freigabe von Tim, jeweils einzeln.

## Review Focus

- Plan von einem alten Server ohne `gruende` (leere Liste): alle drei Abschnitte erscheinen, „Aufteilung“ hat nur den Struktursatz (Task 1, Test `leereGruende`).
- Code eines neueren Servers, den die App nicht kennt: kein Rohcode, kein Absturz, Rest bleibt (Task 1, Test `unbekannterCode`).
- Unbekannte Struktur: der Standardsatz von `PlanStrukturText` erscheint (Task 1, Test `unbekannteStruktur`).
- Jeder Code, den der Generator erzeugt, hat einen Satz und keinen Unterstrich im Text (Task 1, Test `alleGeneratorCodes`); ein neuer Generator-Code ohne Satz fällt hier auf.
- Beide Beschwerden-Codes zugleich und zwei Schwerpunkte zugleich: je ein eigener Satz, Reihenfolge wie im Plan, keine Dopplung (Task 1, Test `mehrereGruende`).

---

### Task 1: `PlanWarumText` (Textbausteine)

**Files:**
- Create: `apps/ios-member/FitnessMember/Workout/PlanWarumText.swift`
- Create: `apps/ios-member/FitnessMemberTests/PlanWarumTextTests.swift`
- Modify: `apps/ios-member/FitnessMember.xcodeproj/project.pbxproj` (durch `xcodegen generate`)

Vorab: Arbeitsbranch `claude/trainingsplan-etappe5` von `claude/trainingsplan-etappe4` abzweigen (`git switch -c claude/trainingsplan-etappe5`), damit Etappe 4 unverändert bleibt.

**Interfaces:**
- Consumes: `PlanStrukturText.text(_ struktur: String) -> String` (`Workout/PlanNamen.swift`).
- Produces:
  ```swift
  enum PlanWarumText {
      static let version = "1.0.0"
      struct Abschnitt: Equatable { let titel: String; let absaetze: [String] }
      /// Immer drei Abschnitte: "Aufteilung", "Gewicht", "Wiederholungen".
      static func abschnitte(struktur: String, gruende: [String]) -> [Abschnitt]
  }
  ```

**Texte (Entwurf, exakt so übernehmen):**

Aufteilung: erster Absatz immer `PlanStrukturText.text(struktur)`. Danach je Code in der Reihenfolge von `gruende`, doppelte Codes einmal, `struktur_*` und unbekannte Codes ohne Satz:

| Code | Satz |
|---|---|
| `zeit_uebungen` | Wie viele Übungen du pro Training machst, richtet sich nach der Zeit, die du angegeben hast. |
| `zeit_saetze_reduziert` | Damit es in deine Zeit passt, haben einige Übungen einen Satz weniger. |
| `zeit_ergaenzung_entfallen` | Ergänzungsübungen sind weggefallen, damit die Hauptübungen in deine Zeit passen. |
| `zeit_aufwaermen_entfallen` | Fürs Aufwärmen ist im Plan keine Zeit eingeplant. Wärm dich trotzdem kurz auf. |
| `zeit_budget_nicht_ausgeschoepft` | Dein Studio hat nicht genug passende Übungen für die ganze Zeit. Einige Trainings sind deshalb kürzer als angegeben. |
| `fokus_<bereich>` | Dein Schwerpunkt „<Bereich>“ bekommt in jedem Training eine eigene Übung. (brust → Brust, ruecken → Rücken, schultern → Schultern, arme → Arme, po → Po, beine → Beine, bauch → Bauch; anderer Bereich: ausgelassen) |
| `fokus_zweiter_entfallen` | Für einen zweiten Schwerpunkt reicht die Zeit nicht, deshalb gilt nur der erste. |
| `abnehmen_cardio_zone` | Zum Abnehmen gehört Cardio im ruhigen Tempo, bei dem du dich noch unterhalten kannst. |
| `abnehmen_cardio_gekuerzt` | Das Cardio ist kürzer, sonst fehlt die Zeit fürs Krafttraining. |
| `abnehmen_kein_cardio_geraet` | Dein Studio hat kein Cardio-Gerät in der App, deshalb ist kein Cardio eingeplant. |
| `abnehmen_alltag` | Abnehmen entscheidet sich vor allem im Alltag, bei Ernährung und Bewegung. Das Training unterstützt dich dabei. |
| `bauch_kein_fettabbau` | Bauchübungen kräftigen den Bauch, bauen aber kein Fett am Bauch ab. |
| `anfaenger_reserve` | Am Anfang lässt du bewusst mehr Luft nach oben, damit du zuerst die Technik lernst. |
| `beschwerden_meiden` | Übungen, die deine Beschwerden belasten, haben wir weggelassen. |
| `beschwerden_vorsichtig` | Wo du vorsichtig sein willst, haben wir schonendere Übungen gewählt. |

Gewicht (immer, zwei Absätze):
1. „Das erste Gewicht an einem Gerät schätzen wir vorsichtig aus deinen Angaben im Profil, oder aus einer ähnlichen Übung, die du schon gemacht hast. Es ist ein Startwert, keine Vorgabe. Lieber etwas zu leicht als zu schwer.“
2. „Danach passen wir es laufend an. Nach jedem Training rechnen wir neu: Schaffst du in allen Sätzen den oberen Wiederholungswert, wird es schwerer. Verfehlst du den unteren oder meldest ein Problem, wird es leichter. Kommt dir ein Gewicht zu leicht oder zu schwer vor, nimm einfach das passende. Wir rechnen ab dem, was du wirklich gemacht hast. Nach einer längeren Pause starten wir wieder etwas leichter.“

Wiederholungen (immer, zwei Absätze):
1. „Wie viele Wiederholungen du machst, hängt von deinem Ziel ab. Für Muskelaufbau sind es 8–12 bei Grundübungen und 10–15 bei Einzelübungen. Für Fitness und Abnehmen sind es 10–15, also etwas mehr.“
2. „Bei Geräten mit groben Gewichtsstufen steigt das Gewicht erst, wenn du in allen Sätzen drei Wiederholungen mehr schaffst als den oberen Wert.“

- [ ] **Step 1: Failing tests schreiben** in `PlanWarumTextTests.swift` (`@Suite("PlanWarumText")`, Swift Testing, Stil wie `PlanAnzeigeTests`). Tests und Zusicherungen:
  - `dreiAbschnitte`: Titel sind `["Aufteilung", "Gewicht", "Wiederholungen"]`, auch bei `gruende: []`.
  - `leereGruende`: `struktur: "gk_ab"`, `gruende: []` → Aufteilung hat genau einen Absatz, gleich `PlanStrukturText.text("gk_ab")`.
  - `unbekannteStruktur`: `struktur: "xyz"` → erster Absatz gleich `PlanStrukturText.text("xyz")`.
  - `unbekannterCode`: `gruende: ["struktur_ganzkoerper_ab", "zeit_neuer_code", "fokus_xyz", "zeit_uebungen"]` → Aufteilung hat genau zwei Absätze (Struktursatz plus Satz von `zeit_uebungen`); kein Absatz enthält „struktur_“ oder „zeit_neuer“.
  - `mehrereGruende`: `gruende: ["fokus_po", "fokus_arme", "beschwerden_meiden", "beschwerden_vorsichtig", "fokus_po"]` → Absätze in dieser Reihenfolge nach dem Struktursatz, vier Stück (zweites `fokus_po` entfällt), der erste enthält „Po“, der zweite „Arme“.
  - `alleGeneratorCodes`: Liste aller Codes aus `trainingsplan-generator.ts` (`zeit_uebungen`, `zeit_saetze_reduziert`, `zeit_ergaenzung_entfallen`, `zeit_aufwaermen_entfallen`, `zeit_budget_nicht_ausgeschoepft`, `fokus_brust`, `fokus_ruecken`, `fokus_schultern`, `fokus_arme`, `fokus_po`, `fokus_beine`, `fokus_bauch`, `fokus_zweiter_entfallen`, `abnehmen_cardio_zone`, `abnehmen_cardio_gekuerzt`, `abnehmen_kein_cardio_geraet`, `abnehmen_alltag`, `bauch_kein_fettabbau`, `anfaenger_reserve`, `beschwerden_meiden`, `beschwerden_vorsichtig`): jeder einzeln ergibt genau einen Zusatzabsatz; über alle Abschnitte enthält kein Absatz ein „_“.
  - `gewichtUndWiederholungen`: Gewicht enthält „Schätzung“ und „nach jedem Training“; Wiederholungen enthält „8–12“, „10–15“ und „drei Wiederholungen mehr“.
- [ ] **Step 2: Test laufen lassen, muss fehlschlagen (Typ fehlt)**

  Run: `cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/PlanWarumText 2>&1 | tail -20`
  Expected: Build-Fehler „cannot find 'PlanWarumText'“.
- [ ] **Step 3: `PlanWarumText` in `Workout/PlanWarumText.swift` umsetzen** (Signatur oben, Texte aus den Tabellen). Fokus-Bereichsnamen und Code-Sätze als `switch`/Wörterbuch; die Wiederholungszahlen mit Kommentar versehen: „gleich `zielprofil` in `packages/domain/src/trainingsplan-regeln.ts` und `GROBE_STUFE_EXTRA_WDH` in `plangewicht.ts` halten, bei Änderung `version` erhöhen“. Stil der Datei wie `PlanNamen.swift` (deutscher Kommentar, `enum` mit statischen Funktionen).
- [ ] **Step 4: Tests laufen lassen, müssen grün sein**

  Run: wie Step 2 (ohne `xcodegen generate`).
  Expected: alle Tests der Suite `PlanWarumText` PASS.
- [ ] **Step 5: Commit**

  ```bash
  git add apps/ios-member/FitnessMember/Workout/PlanWarumText.swift apps/ios-member/FitnessMemberTests/PlanWarumTextTests.swift apps/ios-member/FitnessMember.xcodeproj/project.pbxproj
  git commit -m "feat(ios): Textbausteine fuer Warum so (Etappe 5)"
  ```

---

### Task 2: `PlanWarumView` zeigt die Abschnitte

**Files:**
- Modify: `apps/ios-member/FitnessMember/Screens/Training/PlanWarumView.swift`
- Modify: `apps/ios-member/FitnessMember/Screens/Training/PlanKarte.swift:110`

**Interfaces:**
- Consumes: `PlanWarumText.abschnitte(struktur:gruende:) -> [PlanWarumText.Abschnitt]` (Task 1).
- Produces: `PlanWarumView(struktur: String, gruende: [String])` (neuer erster Parameter).

- [ ] **Step 1: `PlanWarumView` umbauen.** Init `struktur: String, gruende: [String]`. Unter dem bestehenden Titel „Warum dein Plan so aussieht“ je `Abschnitt` eine Überschrift (Trait `.isHeader`, Stil wie die Abschnittsüberschriften in `PlanKarte`) und die Absätze als `Text` in `DesignSystem.Typography.fliesstext` mit `DesignSystem.Color.text`; Abstände aus `DesignSystem.Spacing`. Die Zeile „Die Erklärungen zu jedem Punkt folgen bald.“ und die Code-Liste samt `Card` entfallen. Der Doc-Kommentar nennt die Seite nicht mehr Platzhalter, der Datenschutz-Absatz und der Kommentar „Bewusst ohne testnotizScreen“ bleiben. `#Preview` mit `struktur: "gk_ab"` und Gründen `["struktur_ganzkoerper_ab", "zeit_uebungen", "fokus_po"]`.
- [ ] **Step 2: Aufruf in `PlanKarte.swift:110`** auf `PlanWarumView(struktur: plan.struktur, gruende: plan.gruende)` ändern.
- [ ] **Step 3: Bauen und die Plan-Tests laufen lassen**

  Run: `cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/PlanWarumText -only-testing:FitnessMemberTests/PlanAnzeige 2>&1 | tail -20`
  Expected: Build ok, beide Suiten PASS.
- [ ] **Step 4: Sichtprüfung im Simulator** (Debug-Build zeigt auf Prod: **nur Testkonto**): Training-Tab → Plankarte → „Warum so?“. Erwartet: drei Abschnitte, keine Codes, Überschriften mit VoiceOver als Überschrift, größte Dynamic-Type-Stufe bricht nicht ab. Ergebnis kurz im Commit-Text oder an Tim melden.
- [ ] **Step 5: Gesamte Swift-Suite laufen lassen**

  Run: `cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test 2>&1 | tail -30`
  Expected: `** TEST SUCCEEDED **` (Stand Etappe 4: 1655 Tests, dazu die neuen).
- [ ] **Step 6: Commit**

  ```bash
  git add apps/ios-member/FitnessMember/Screens/Training/PlanWarumView.swift apps/ios-member/FitnessMember/Screens/Training/PlanKarte.swift
  git commit -m "feat(ios): Warum so zeigt Aufteilung, Gewicht und Wiederholungen"
  ```

---

## Nicht Teil dieser Etappe

- Gewichtsgrund je Übung auf der Seite (Tim: „allgemein passt“). Die Gewichtsgründe (`korridor_oben_erreicht`, …) bleiben im Hinweis am Gerät.
- Hinweis auch auf der Satzseite, Design des `im_korridor`-Hinweises, Wochenvolumen-Prüfung und alle anderen offenen Punkte aus der Übergabe.
- Server, Datenbank, Migrationen. Prod-Deploy: unverändert wie in der Etappe-4-Übergabe, alles nur mit Freigabe.
