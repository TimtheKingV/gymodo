# iOS Member-App — Bewegungssensor: Wiederholungszähler (Teilprojekt B)

**Stand:** 10. Oktober 2026
**Status:** Entschieden, bereit für den Umsetzungsplan. Abschnitt 6.6 (Hintergrund am iPhone) wird im ersten Schritt von E4 ausgefüllt.
**Umgesetzt:** E1, E2, E3 auf Branch `claude/sensor-wiederholungszaehler-spec` (10. Oktober 2026). E4/E5: eigener Plan; Gymtavo-Katalog Etappe 4 ist inzwischen gemergt.
**Vorbedingung:** Teilprojekt A ist auf `master` (`2026-09-19-sensor-anbindung-aufzeichnung-design.md`, im Folgenden „Spec A“). Für E4 zusätzlich: Gymtavo-Katalog Etappe 4 (iOS) ist gemergt, weil beide `GeraetModel` ändern.
**Verhältnis zu anderen Dokumenten:** untergeordnet gegenüber `2026-08-28-fitness-retrofit-m1-design.md` und `2026-08-30-designsystem.md` — mit einer Ausnahme: **Diese Spec ändert die Produktgrenze** aus Blueprint §2.3, M1 §4.3 und Designsystem §10 (Abschnitt 3). Die Nachträge dort verweisen hierher.

---

## 1. Warum und was

Die Member-App zählt Wiederholungen aus dem Signal des Bewegungssensors (WitMotion WT9011DCL-BT50, Spec A §3). Die Zahl erscheint live im Wiederholungsrad; das Mitglied bestätigt sie mit „Satz sichern“ oder korrigiert sie am Rad. Am Satz wird gespeichert, woher die Zahl kommt, und je Wiederholung ein paar Kennzahlen, auf denen Teilprojekt C (Tempo) und D (Spiel) später aufbauen.

Die Grundsatzentscheidung steht vor dieser Spec: **Die Grenze „Gymtavo misst nichts“ fällt.** Die App darf messen. Teil von B ist, die Grenze überall herauszunehmen, wo sie festgeschrieben ist (Abschnitt 3).

**Erfolg heißt:** Der Zähler erreicht je Befestigungsart ein messbares Gütetor (Abschnitt 5.5) und wird erst dann für Mitglieder eingeschaltet — Art für Art.

## 2. Entscheidungen

| # | Frage | Entscheidung |
|---|---|---|
| 1 | Rolle der gezählten Zahl | Das Rad folgt live; „Satz sichern“ bestätigt; Drehen am Rad nach der ersten gezählten Wiederholung ist die Korrektur. Kein Extra-Tipp. |
| 2 | Herkunft am Satz | `volume_source` (`eingegeben` / `gemessen` / `korrigiert`), `volume_counted` (Zählerstand) |
| 3 | Sichtbarkeit der Herkunft | Nirgends angezeigt — weder Trainerportal noch iOS-Verlauf. Gespeichert für spätere Auswertung. |
| 4 | Rücknahme | Nicht anwendbar → Zähler startet nicht. Lücke oder unsicheres Signal → Zähler hält sichtbar an („Zahl prüfen“), Rad bleibt stehen, zählt in diesem Satz nicht weiter. Sichern ohne Drehen ist erlaubt. |
| 5 | Hintergrund | `bluetooth-central` an; vorher am iPhone gemessen (6.6) |
| 6 | Befestigung | Feste Liste aus sechs Arten, gemerkt je Gerät + Übung, kein NFC |
| 7 | Debug/Release, Texte | Grenze fällt sofort in Docs und Texten (E1). Das Gütetor gilt nur für das Einschalten des Zählers für Mitglieder (E5). Die App wird erst mit funktionierendem Zähler veröffentlicht. |
| 8 | Code-Ort | Lokales Swift-Package `Sensorik`, `swift test` auf dem Mac über alle Aufnahmen |
| 9 | Gütetor | exakt ≥ 90 %, ±1 ≥ 98 %, Rücknahmen ≤ 10 %; je Art 20 frische Sätze aus 3 Trainingstagen |
| 10 | Abgrenzung C/D | Zähler liefert Ereignisse je Wiederholung mit Kennzahlen; gespeichert in `aufnahme.json` (Debug) **und** als `rep_events` am Satz. Keine Rohdaten zum Server, keine Anzeige von Tempo in B. |
| — | Algorithmus | Regelbasiert je Befestigungsart, eine Erkennungskette (Abschnitt 5.3). Periodizität höchstens später als Plausibilitätsprüfung, Core ML frühestens nach dem Tor. |

## 3. Die Produktgrenze fällt

### 3.1 Neue Regel

Ersetzt Blueprint §2.3 und M1 §4.3 (als datierter Nachtrag, die alte Fassung bleibt durchgestrichen sichtbar):

> Die Plattform speichert nur, was das Mitglied bestätigt. Messen darf sie nur über den Bewegungssensor und nur, was ein Zähler mit nachgewiesener Güte erfasst — heute die Wiederholungen. Gewicht, Ausführungsqualität und Körperdaten misst sie nicht und behauptet es nicht. Jede gezählte Zahl trägt ihre Herkunft am Satz.

M1 §4.2 „jede Form von Sensorik“ wird ergänzt: „in M1; der Bewegungssensor folgt mit Teilprojekt B (`2026-10-10-sensor-wiederholungszaehler-design.md`)“.

### 3.2 Neue Texte

Designsystem §10 ist die eine Quelle; App und Web übernehmen wörtlich.

| Ort | Heute | Neu |
|---|---|---|
| Kanonisch: Einweisung (neu `Produktgrenze.kanonisch` im Designsystem, gelesen von `GeraetModel.produktgrenze`, gezeigt in `EinweisungSchritt`), `/t/[token]`, Landeseite Fuß (`PRODUKTGRENZE`), FAQ-Antwort „Was misst Gymtavo?“ | „Gymtavo misst nichts. Angezeigt wird ausschließlich, was du selbst bestätigt hast. Einweisungsvideos und Einstellhinweise sind Inhalte deines Studios, keine Trainings- oder Gesundheitsempfehlung von Gymtavo.“ | „Gymtavo speichert nur, was du bestätigst. Mit Sensor zählt Gymtavo deine Wiederholungen mit — du siehst die Zahl und entscheidest. Einweisungsvideos und Einstellhinweise sind Inhalte deines Studios, keine Trainings- oder Gesundheitsempfehlung von Gymtavo.“ |
| `/t/[token]` (Kurzfassung ohne ersten Satz) | „Gymtavo misst nichts. Einweisungsvideos …“ | kanonischer Satz wie oben |
| FAQ „Wann kommt der Sensor?“ | „Er ist in Entwicklung …“ | bleibt bis E5, dann angepasst |
| Home leer (`HomeRootView`) | „Gymtavo misst nichts. Es zeigt, was du bestätigst.“ | „Gymtavo zeigt, was du bestätigst.“ |
| Profil (`ProfilRootView`) | „Gymtavo misst nichts. Gespeichert wird nur, was du selbst bestätigst — Einstellwerte, Sätze, ob ein Trainer dabei war.“ | „Gespeichert wird nur, was du selbst bestätigst — Einstellwerte, Sätze, ob ein Trainer dabei war. Vom Sensor gezählte Wiederholungen zählen erst, wenn du den Satz sicherst.“ |
| Profil, Körperdaten | Zusatzsatz der Ziele-Spec | bleibt; „misst“ nur entfernt, wo es steht. Körperdaten bleiben reine Eingabe, kein HealthKit. |
| Bluetooth-Berechtigung (`project.yml`, gilt auch im Release) | „… um Wiederholungen zu erfassen.“ | „Gymtavo verbindet sich mit deinem Bewegungssensor, um deine Wiederholungen zu zählen.“ |

### 3.3 Fundstellen und was sich ändert

Gesucht am 9. Oktober 2026 auf `master` (`64595c0`) nach „misst nichts“, „Produktgrenze“, „Messung“, „gemessen“ und Verwandtem in `docs/`, `apps/`, `packages/`, `e2e/`, `supabase/`. In `supabase/`, `README*` und Lokalisierungsdateien gibt es keine Treffer. Die Specs und Artboards sagen noch „gymodo“, der ausgelieferte Code „Gymtavo“.

**(a) Normative Quellen — Nachtrag mit Datum, alte Fassung durchgestrichen:**

| Fundstelle | Änderung |
|---|---|
| `fitness-retrofit-technical-blueprint.md:99–101` §2.3 | neue Regel 3.1 |
| `…:1254` Risikotabelle „klare Produktgrenze“ | Verweis auf neue Regel |
| `specs/2026-08-28-fitness-retrofit-m1-design.md:112` §4.2 | Ergänzung wie 3.1 |
| `…:114–118` §4.3 | neue Regel 3.1 |
| `…:609` Risiko „Produktgrenze in der UI“ | Verweis |
| `specs/2026-08-30-designsystem.md:180–182` §10 | neuer kanonischer Satz 3.2 |
| `…:228` §13 „weil die Plattform nichts misst“ | „weil nur Bestätigtes gespeichert wird“ |
| `…:151` „Vorschlag ohne Daten wäre eine Trainingsempfehlung“ | bleibt (betrifft Empfehlungen, nicht Messung) |

**(a) Specs mit Verweisen — je eine Nachtrag-Zeile:**

| Fundstelle | Änderung |
|---|---|
| `specs/2026-09-19-sensor-anbindung-aufzeichnung-design.md:6, 42, 338` | Grenze in B gefallen; §11.2 als erledigt mit Verweis |
| `specs/2026-10-03-landeseite-neu-gpath-referenz.md:100, 125–147, 184, 294, 319, 333, 336` | Widerspruch Z. 319 aufgelöst; neuer Wortlaut 3.2 statt des Vorschlags in Z. 100; der Umzug „überall zusammen“ (Z. 336) ist mit E1 erfüllt |
| `specs/2026-09-13-ziele-und-fortschritt-design.md:21, 42, 252, 349` | Körperdaten bleiben strenger: keine Messung, kein HealthKit — Verweis auf neue Regel statt auf „misst nichts“ |
| `specs/2026-09-09-ios-home-profil-design.md:157, 175, 197` | neue Texte |
| `specs/2026-09-10-ios-geraet-ohne-scan-design.md:236` | Regel bleibt sinngemäß („kein Wort behauptet eine Messung, wo keine stattfand“), Verweis auf neue Regel |
| `specs/2026-09-21-cardio-geraete-design.md:433, 437` | Nebenwerte und Timer: das Mitglied liest die Anzeige ab; Grund ist jetzt „der Sensor zählt nur Wiederholungen“ |

**(e) Unverändert, weil Geschichte:** abgeschlossene Pläne (u. a. Schnitt 1–4, Cardio Schnitt 3, Kernflow, Home/Profil, Training/Kurse, Portal-Frontend, Studio-Einstellungen, Branding, Landeseite Etappe 1, Testnotizen) und alle Artboards unter `docs/superpowers/design/`. Ebenso die Befund-Specs `2026-09-03-portal-frontend-design.md` (Befund 19), `2026-09-07-member-app-design-challenge.md`, `2026-09-08-ios-training-kurse-design.md`.

**(b) Texte für Mitglieder — neu nach 3.2:**

| Fundstelle |
|---|
| `apps/ios-member/FitnessMember/Screens/Geraet/GeraetModel.swift:529–533` (`produktgrenze`) |
| `apps/ios-member/FitnessMember/Screens/Home/HomeRootView.swift:354` |
| `apps/ios-member/FitnessMember/Screens/Profil/ProfilRootView.swift:278` |
| `apps/ios-member/project.yml:39` (Bluetooth-Text; danach `xcodegen generate`) |
| `apps/web/app/landung/texte.ts:100–120` (`PRODUKTGRENZE`, FAQ) |
| `apps/web/app/t/[token]/page.tsx:249–250` |

`TrainingAbschlussView.swift:316/320` (`produktgrenzeHinweis`, „eine Rechnung, keine Empfehlung“) betrifft Empfehlungen und bleibt; nur der Bezeichner darf bleiben.

**(c) Code-Kommentare — „die App misst nichts“ durch den eigentlichen Grund ersetzen:**

| Fundstelle | neuer Grund |
|---|---|
| `Screens/Training/TrainingRootView.swift:356` | keine Zahl ohne bestätigten Satz |
| `Screens/Training/TrainingStartView.swift:11` | dito |
| `Verlauf/HomeZeilen.swift:240` | dito |
| `Screens/Home/UebungsfortschrittView.swift:145` | die Kurve fasst bestätigte Sätze zusammen und muss nachprüfbar bleiben |
| `Screens/Geraet/WertZeile.swift:125` | Minuten und Meter liest das Mitglied von der Geräteanzeige ab; der Sensor zählt nur Wiederholungen |
| `Screens/Profil/ProfilRootView.swift:284` | Verweis auf neue Regel |
| `packages/domain/src/progression.ts:9` | Vorschläge rechnen auf bestätigten Sätzen |
| `apps/web/app/landung/Fuss.tsx:5`, `t/[token]/fallback.module.css:184` | Verweis „Produktgrenze“ bleibt als Name des Bausteins |

**(d) Tests:**

| Fundstelle | Änderung |
|---|---|
| `e2e/wurzel.spec.ts:60–65` | sucht `/Gymtavo speichert nur, was du bestätigst/` |
| `e2e/tag-fallback.spec.ts:253–255` | dito |
| `e2e/schreibtisch.spec.ts:71–82` | prüft weiter das Fehlen im Portal-Überblick, neues Muster |
| `FitnessMemberTests/GeraetEinstiegsartTests.swift:8–21` | Prüfung bleibt (ERKANNT/AUSGEWÄHLT behauptet keine Messung), Kommentar verweist auf neue Regel |
| neu | iOS-Test: `Produktgrenze.kanonisch` ist der Satz aus 3.2 |

**Nicht betroffen:** Körperdaten (`body_measurements`, iOS-DTO `Messwert`, `GewichtEintragenSheet` usw.) — reine Eingabe. „gemessen“ im Sinne von Layout oder Laufzeit (`next.config.mjs`, Kaufleiste, Portal-Seiten). Der Debug-Sensorcode aus A („Messwert“ für Rohdaten).

## 4. Etappen

| # | Etappe | Hängt ab von | Für Mitglieder sichtbar |
|---|---|---|---|
| **E1** | Produktgrenze fällt (Abschnitt 3) | — | ja, nur Texte |
| **E2** | Package `Sensorik`, Zähler, Offline-Tests, Gütebericht (Abschnitt 5) | — | nein |
| **E3** | Herkunft am Satz: Migration, Domäne, API, iOS-DTO; App sendet immer `eingegeben` (Abschnitt 6.1–6.3) | — | nein |
| **E4** | Zähler live im Satzpfad, Befestigungsart, Hintergrundmodus — alles `#if DEBUG` (Abschnitt 6.4–6.7) | E2, E3, Gymtavo-Katalog Etappe 4 | nein |
| **E5** | Release hinter dem Gütetor, Art für Art (Abschnitt 7) | E4, Tor je Art | ja |

E1, E2 und E3 sind unabhängig und können sofort beginnen, jede in eigenem Worktree und PR. E2 beginnt mit den Wasserflaschen-Aufnahmen vom 8. Oktober als Rauchtest; das Tor wartet auf echte Sätze, die parallel beim Training entstehen. E5 ist kein Termin, sondern wird je Befestigungsart ausgelöst.

**Endzustand Datenfluss:** Sensor → `BluetoothSensorQuelle` → Messwert-Strom → `ZaehlerKoordinator` (App) → `Zaehler` (Package) → `ZaehlerEreignis` → Meldung ans `GeraetModel` → Rad. Beim Sichern gehen `volume`, `volumeSource`, `volumeCounted`, `repEvents` mit dem PUT. Im Debug hört der `SensorAufnahmeKoordinator` parallel mit und schreibt Aufnahme plus `zaehler`-Block.

## 5. Package `Sensorik` und Zähler (E2)

### 5.1 Ort und Aufbau

`apps/ios-member/Packages/Sensorik/`, eingebunden in `project.yml` als lokales Package (danach `xcodegen generate`). Plattformen iOS 17 und macOS 14, Swift 6, Library `Sensorik`, Testziel `SensorikTests`. Nicht hinter `#if DEBUG`: im Release liegt es ungenutzt bei, bis E5 es braucht.

`swift test --package-path apps/ios-member/Packages/Sensorik` läuft auf dem Mac ohne Simulator und ohne `xcodebuild` — schnelle Iterationen, kein Konflikt mit parallelen iOS-Builds anderer Sessions.

### 5.2 Was hineinwandert, was neu ist

**Aus A, nach `public`, Verhalten unverändert:** `Vektor3`, `SensorMesswert`, `WitMotionPaket`/`WitMotionParser`, `WitMotionBefehl`, `SensorRate`, `SensorStatistik`, das Aufnahmeformat komplett (`SensorAufnahmeDatei` samt Ratentest, `SensorAufnahmeLeser`, Schreiber `SensorAufnahme`). Der Leser bekommt einen eigenen Decoder statt `JSONDecoder.testnotiz()` (Datumsformat wie Spec A §6.3). Die zugehörigen Tests ziehen mit ins Package. Im App-Target bleiben Bluetooth, `AbspielSensorQuelle`, `SensorProtokoll`, `SensorAufnahmeKoordinator`, Oberfläche.

**Neu:**

| Typ | Aufgabe |
|---|---|
| `Befestigungsart` | `stapel, langhantel, kurzhantel, hebelarm, kabelgriff, koerper`; `Codable`, Rohwerte wie hier geschrieben. `static let freigegeben: Set<Befestigungsart>` (anfangs leer, Abschnitt 7). |
| `Wiederholung` | `nummer`, `beginn`, `umkehr`, `ende` (Messwertzeit in s), `ausschlag` (Betrag des Spitzenwerts im Profil-Signal: °/s oder m/s), `sicherheit` 0…1; berechnet: `dauerKonzentrisch`, `dauerExzentrisch`, `pauseDavor` |
| `UnsicherGrund` | `luecke`, `signalSchwach`, `taktUnregelmaessig` |
| `ZaehlerEreignis` | `.wiederholung(Wiederholung)`, `.unsicher(UnsicherGrund)`, `.zuende` |
| `ZaehlerProfil` | je Befestigungsart: `version` (Int), `eingefrorenAm` (Datum oder `nil`), Signalwahl, Filter- und Schwellenparameter als Konstanten. `algo`-Kennung `"<art>/<version>"`. |
| `Zaehler` | `struct`; `init(profil:rateHz:)` — gefiltert wird mit der Sollrate statt mit Zeitstempel-Differenzen, weil gebündelte Messwerte denselben Zeitstempel tragen (Spec A §4.7); `mutating func verarbeite(_: SensorMesswert) -> [ZaehlerEreignis]`; `mutating func luecke(von:bis:) -> [ZaehlerEreignis]`; `mutating func abschliessen() -> [ZaehlerEreignis]`. Rein: keine Uhr, keine Nebenläufigkeit, kein Zufall. Offline und live derselbe Code. |
| `RepEvents` | `Codable`-Abbild für Server und Aufnahme (6.2) mit `init(ereignisse:profil:satzbeginn:)` |

### 5.3 Erkennungskette

1. **Ruhe und Achse.** Solange keine Bewegung über einer Ruheschwelle liegt, mittelt der Zähler die Beschleunigung zur Schwerkraftrichtung. Der Ruhevorlauf (Sensor anbringen, zum Telefon greifen; Spec A §6.4) zählt nie. Die Bewegungsachse ist die dominante Achse der ersten Bewegung im Profil-Signal.
2. **Signal je Profil.** Drehrate für `langhantel`, `kurzhantel`, `hebelarm`, `kabelgriff` (Achse mit der größten Streuung im Achsenfenster); für `stapel` und `koerper` die Geschwindigkeit entlang der Schwerkraft, aus der Beschleunigung ohne Schwerkraft mit leckender Integration. Beides sind Geschwindigkeiten: eine Wiederholung ist eine volle Welle (hin positiv, zurück negativ). Dann Tiefpass.
3. **Wellen mit Hysterese.** Eine Wiederholung braucht Hin- und Rückweg über eine obere und eine untere Schwelle und eine Mindestdauer. Die Schwellen setzen sich nach der ersten Wiederholung relativ zu deren Ausschlag. `beginn`, `umkehr`, `ende` sind die Nulldurchgänge vor der ersten Halbwelle, zwischen den Halbwellen (Geschwindigkeit null = Umkehrpunkt) und der Zeitpunkt, an dem die zweite Halbwelle abgeschlossen ist. Welche Halbwelle die konzentrische ist, legt die erste Wiederholung fest (vorzeichenunabhängig).
4. **Unsicher.** Messwertabstand über 0,5 s oder ein expliziter `luecke`-Aufruf → `.unsicher(.luecke)`. Ausschlag unter dem Profil-Minimum → `.signalSchwach`. Dauer einer Wiederholung außerhalb eines Bandes um den Median der bisherigen → `.taktUnregelmaessig`. **Nach `.unsicher` liefert der Zähler in diesem Satz keine Wiederholungen mehr** (Entscheidung 4).
5. **Bündelung.** Mehrere Messwerte mit gleichem Zeitstempel (30-ms-Raster, Spec A §4.7) sind normal und ändern das Ergebnis nicht.

Alle Zahlen (0,5 s, Schwellen, Filter, Band) sind Startwerte und werden in E2 an den Aufnahmen abgestimmt; die Profil-Konstanten tragen eine kurze ASCII-Begründung.

### 5.4 Korrekturen

`data/sensoraufnahmen/korrekturen.json` (Format bleibt `gymodo.sensorkorrektur/1`) bekommt je Aufnahme `befestigungsart` (Rohwert aus 5.2 oder `null`). `befestigung` bleibt als Freitext-Detail. Für die bestehenden Aufnahmen wird die Art aus dem Freitext nachgetragen (Wasserflasche als Langhantel → `langhantel` usw.); `fuerZaehler` bleibt `false`. Das README beschreibt das Feld. Der Korrekturen-Leser liegt im Testziel, nicht in der Library.

### 5.5 Tests und Gütebericht

Swift Testing im Testziel `SensorikTests`.

- **Synthetisch:** Sinus mit n Perioden → genau n; nur Ruhe → 0; Lücke mitten im Satz → `.unsicher(.luecke)` und danach keine Wiederholung; gleiche Zeitstempel im 30-ms-Raster → gleiche Zahl; Determinismus; Ruhevorlauf und Nachlauf zählen nicht.
- **Über alle Aufnahmen**, parametrisiert über jeden Ordner in `data/sensoraufnahmen` mit `repsWahr ≠ null` (Pfad über `#filePath`): läuft ohne Absturz, deterministisch, Ereignisse stimmig (Nummern lückenlos ab 1, `beginn < umkehr < ende`, aufsteigend).
- **Gütebericht:** ein Test rechnet je Befestigungsart
  - exakt-Quote (gezählt = `repsWahr`), ±1-Quote, Rücknahme-Quote (Satz endete mit `.unsicher`);
  - getrennt für **Entwicklungsset** (alle mit `repsWahr`) und **Torset** (`fuerZaehler: true`, `repsWahr` gesetzt, `startedAt` nach `eingefrorenAm` des Profils);
  - und schreibt `data/sensoraufnahmen/guetebericht.md` (eingecheckt, damit jede Iteration im Diff sichtbar ist): Tabelle je Art mit Anzahl Sätze, Trainingstagen und den drei Quoten, darunter je Satz gezählt / wahr / Grund.
- **Gütetor** (Entscheidung 9): je Art im Torset mindestens 20 Sätze aus mindestens 3 Trainingstagen, exakt ≥ 90 %, ±1 ≥ 98 %, Rücknahmen ≤ 10 %. Rücknahmen zählen für exakt und ±1 nicht als Fehlzählung, aber als eigene Quote. **Der Test schlägt fehl, wenn eine Art in `Befestigungsart.freigegeben` das Tor nicht hält.**
- **Überanpassung:** abstimmen → Profil mit `eingefrorenAm` einfrieren → trainieren → prüfen. Jede Parameteränderung erhöht `version` und setzt `eingefrorenAm` neu; das Torset beginnt damit von vorn.

Das volle Testset (Spec A §9) bekommt `swift test --package-path apps/ios-member/Packages/Sensorik` dazu, lokal und in CI.

## 6. Herkunft am Satz und Live-Zählung (E3, E4)

### 6.1 Migration (E3)

Nächste freie Nummer bei der Umsetzung (heute wäre es `0048`), an `public.workout_sets`:

```sql
alter table public.workout_sets
  add column volume_source text not null default 'eingegeben'
    constraint workout_sets_volume_source_check
    check (volume_source in ('eingegeben', 'gemessen', 'korrigiert')),
  add column volume_counted int
    constraint workout_sets_volume_counted_check
    check (volume_counted is null or volume_counted between 1 and 1000),
  add column rep_events jsonb,
  add constraint workout_sets_herkunft_consistent check (
    (volume_source = 'eingegeben' and volume_counted is null and rep_events is null)
    or (volume_source = 'gemessen' and volume_counted = volume and rep_events is not null)
    or (volume_source = 'korrigiert' and volume_counted <> volume and rep_events is not null));
```

Bestand und alte Clients landen über den Default bei `eingegeben`. `volume_counted ≥ 1`, weil der Zähler erst nach der ersten gezählten Wiederholung ins Rad schreibt. Keine neue RLS-Policy: die Spalten gehören zur Zeile und fallen unter dieselbe Sichtbarkeit und Löschung (Satz, Session, Konto).

### 6.2 `rep_events`

```json
{ "algo": "langhantel/3", "befestigungsart": "langhantel", "unsicher": null,
  "wiederholungen": [
    { "beginn": 3.42, "umkehr": 4.61, "ende": 5.98, "ausschlag": 112.4, "sicherheit": 0.93 } ] }
```

Zeiten in Sekunden seit Satzbeginn (Eintritt in `.eingabe`), zwei Nachkommastellen. Die Einheit von `ausschlag` folgt aus dem Profil (°/s oder m/s). Phasendauern und Pausen sind ableitbar und stehen nicht drin. `unsicher` ist der Grund oder `null`. Etwa 1 KB bei 15 Wiederholungen. Dasselbe Objekt steht in `aufnahme.json` (6.5).

### 6.3 Domäne, API, iOS-DTO (E3)

- **Domäne** (`packages/domain/src/workout.ts`): `recordSetInputSchema` bekommt `volumeSource` (Default `eingegeben`), `volumeCounted`, `repEvents` mit eigenem Zod-Schema (höchstens 1000 Einträge, Zeiten ≥ 0 und je Eintrag `beginn ≤ umkehr ≤ ende`, Einträge aufsteigend, `sicherheit` in 0…1, `befestigungsart` aus der Liste). `recordSet` prüft zusätzlich: Herkunft ≠ `eingegeben` nur bei `volume_kind = 'reps'`; `wiederholungen.length = volumeCounted`; die Konsistenz aus 6.1. Verstöße → `validation_failed` mit Klartext wie `volumeZuGross`. `RecordedSet` gibt `volumeSource` und `volumeCounted` zurück, nicht `repEvents`. Lesepfade (Bootstrap `lastSets`, Sessions, Fortschritt, Abschluss) bleiben unverändert.
- **API:** der PUT-Satz-Endpunkt reicht die Felder durch; der PUT bleibt idempotent.
- **iOS** (`Networking/DTOs/WorkoutSet.swift`, Offline-Warteschlange): `VolumeSource`-Enum, `volumeCounted: Int?`, `repEvents: RepEvents?` (Typ aus dem Package). Fehlende Schlüssel decodieren zu `eingegeben`/`nil`, damit Warteschlangen-Einträge älterer Builds lesbar bleiben. In E3 sendet `GeraetModel` immer `eingegeben`.
- **Tests:** Vitest für Schema und Konsistenz; Integration: PUT mit allen drei Herkünften, Constraint-Verstöße, `seconds`-Übung mit `gemessen` wird abgelehnt, Client ohne die Felder ergibt `eingegeben`; RLS: fremde Sätze bleiben samt `rep_events` unsichtbar; iOS: DTO-Roundtrip und alter Warteschlangen-Eintrag.

### 6.4 Naht `SatzZaehler` und `ZaehlerKoordinator` (E4)

Neue Naht, immer kompiliert wie `SatzMitschnitt` (das Einbahn-Protokoll für die Aufnahme bleibt, wie es ist):

```swift
struct SatzZaehlerKontext: Equatable, Sendable {
    let machineId: String?
    let exerciseId: String
    let volumeKind: VolumeKind
}

enum ZaehlerMeldung: Equatable, Sendable {
    case zaehltNicht(ZaehltNichtGrund)   // keinSensor, keineWiederholungen, keineBefestigung, nichtFreigegeben
    case bereit
    case stand(Int)
    case pruefen(Int, UnsicherGrund)
}

struct ZaehlerErgebnis: Equatable, Sendable {
    let gezaehlt: Int
    let repEvents: RepEvents
}

@MainActor protocol SatzZaehler: AnyObject {
    func satzBeginnt(_ kontext: SatzZaehlerKontext, melde: @escaping @MainActor (ZaehlerMeldung) -> Void)
    /// Beim Sichern abgeholt; beendet den Satz. nil, wenn nichts gezaehlt wurde.
    func ergebnis() -> ZaehlerErgebnis?
    func satzVerworfen()
}
```

`ZaehlerKoordinator` (App-Target, in E4 `#if DEBUG`) erfüllt die Naht: er abonniert den Messwert-Strom der `SensorQuelle`, liest die Befestigungsart für den Kontext, baut einen `Zaehler` mit dem Profil, füttert ihn und übersetzt Ereignisse in Meldungen. Den Zustand der Quelle (`getrennt`) übersetzt er in `luecke`. Er ist unabhängig vom `SensorAufnahmeKoordinator`; beide hören parallel. Die genaue Form des Abonnements (ein Strom je Abonnent) folgt der bestehenden `SensorQuelle`.

**Anwendbar** (sonst `.zaehltNicht` mit Grund): Sensor verbunden; `volumeKind == .reps`; Befestigungsart gesetzt; im Release zusätzlich Art in `freigegeben`.

### 6.5 `GeraetModel` und Rad (E4)

`GeraetModel.init` bekommt `zaehler: (any SatzZaehler)? = nil`. Im Release (bis E5) und in allen bestehenden Tests `nil`; das Verhalten ändert sich nicht.

| Zustand | Bedeutung | Rad |
|---|---|---|
| `aus` | kein Zähler oder nicht anwendbar | wie heute |
| `bereit` | wartet auf die erste Wiederholung | vorbelegt; Drehen ist keine Korrektur |
| `zaehlt(n)` | Rad steht auf n und springt je Wiederholung weiter; kurzes haptisches Signal je Wiederholung | folgt |
| `pruefen(n)` | Lücke oder Unsicherheit, Zähler steht | bleibt auf n, Markierung „Zahl prüfen“ am Rad und in der Sensor-Zeile |
| `vonHand(n)` | nach der ersten Zählung wurde gedreht | gehört der Hand, keine Sprünge mehr |

- Der Umfangs-Setter aus der Oberfläche schaltet bei `zaehlt`/`pruefen` auf `vonHand`. Der Zähler schreibt über einen eigenen Weg, der nicht als Hand zählt.
- `satzBeginnt` beim Eintritt in `.eingabe` und nach Übungswechsel; `satzVerworfen` bei Übungswechsel und beim Verlassen des Screens. In der Pause wird nicht gezählt.
- **Beim Sichern:** `ergebnis()` abholen. Ohne Ergebnis → `eingegeben`. Mit Ergebnis → `gemessen`, wenn `umfang == gezaehlt`, sonst `korrigiert` (zurückgedreht auf denselben Wert ist also `gemessen`). `volumeCounted` und `repEvents` gehen mit dem PUT.
- `GesicherterSatz` (an den `SatzMitschnitt`) bekommt `volumeSource` und `repEvents`, damit die Aufnahme sie schreiben kann, ohne die Koordinatoren zu koppeln.
- **Der Zähler gefährdet nie den Satz** (wie Spec A §7.3): nichts wirft in den Satzpfad, nichts wird abgewartet, `ergebnis()` ist synchron.
- Testnotiz-Kontext des Geräte-Screens bekommt `zaehler: <Zustand>`.

### 6.6 Hintergrundmodus (E4, erster Schritt)

`project.yml` bekommt `UIBackgroundModes: [bluetooth-central]` für das App-Target. Der Bildschirm bleibt wie bisher wach, solange der Geräte-Screen sichtbar und der Sensor verbunden ist.

**Erster Schritt von E4:** Messung am iPhone wie Spec A §4.7 — Aufnahme bei 50 Hz, je 60 s mit gesperrtem Bildschirm und mit der App im Hintergrund (Handy in der Tasche). Pakete, Ist-Rate, Abstand Median / p95 / Maximum. Das Ergebnis wird hier eingetragen. Zeigt sich Drosselung oder ein Abriss, greift die 0,5-s-Lücke aus 5.3 (der Zähler hält an), und dieser Abschnitt bekommt einen Nachtrag.

**Ergebnis:** _wird im ersten Schritt von E4 eingetragen._

### 6.7 Befestigungsart und Aufnahme (E4)

- **Auswahl:** Ist für den Kontext keine Art gemerkt, zeigt die Sensor-Zeile „Befestigung wählen“ mit den sechs Arten. Gemerkt in `UserDefaults` je `machineId + exerciseId`, ohne Gerät je `exerciseId`. Danach zeigt die Zeile z. B. „Langhantel · zählt“ bzw. „zählt hier nicht: Sekundenübung“; ein Tipp auf die Art ändert sie. Der Freitext `befestigung` aus A wird optionales Detail im Diagnose-Blatt.
- **Aufnahme:** `aufnahme.json` bekommt `befestigungsart` (Rohwert oder `null`) und `zaehler` = `{ "algo", "gezaehlt", "herkunft", "ereignisse": <RepEvents> }` oder `null`, wenn kein Zähler lief. Die Formatkennung bleibt `gymodo.sensoraufnahme/1`; der Leser kennt beide Felder als optional, ältere Aufnahmen bleiben lesbar. Das verbindliche Beispiel in den Fixtures bekommt beide Felder.

### 6.8 Tests (E4)

- **`ZaehlerKoordinatorTests`** mit `AbspielSensorQuelle` und einer Aufnahme: Meldungen `bereit` → `stand(1…n)`; Lücke → `pruefen`; nicht anwendbar → `zaehltNicht` mit richtigem Grund; `ergebnis()` passt zu den Meldungen; `satzVerworfen` setzt zurück.
- **`GeraetModelTests`** mit einem Zähler-Double: Rad folgt; Drehen in `bereit` ist keine Korrektur; Drehen in `zaehlt` → `vonHand`; Herkunft und Zählerwert beim Sichern in allen drei Fällen; Zurückdrehen → `gemessen`; Übungswechsel verwirft; ohne Zähler alles wie heute; ein fehlgeschlagenes Sichern meldet nichts an den Mitschnitt.
- **Aufnahme:** `zaehler`-Block und `befestigungsart` in `aufnahme.json`; ältere Aufnahme ohne die Felder bleibt lesbar.
- **Geräte-Checkliste am iPhone:**
  1. Befestigung wählen, Sätze je verfügbarer Art; Rad folgt, Haptik je Wiederholung
  2. Drehen nach der ersten Zählung → keine Sprünge mehr; gesicherter Satz hat `korrigiert`
  3. Handy in der Tasche (gesperrt) während des Satzes; Zahl beim Zurückkommen
  4. Sensor im Satz aus → „Zahl prüfen“, Satz lässt sich sichern
  5. Bluetooth aus → „zählt hier nicht“, Satzpfad wie heute
  6. Sekundenübung → „zählt hier nicht: Sekundenübung“
  7. Release-Build: kein Zähler, keine Sensor-Zeile (bis E5)

## 7. Release hinter dem Gütetor (E5)

- `BluetoothSensorQuelle`, `SensorQuelle`, `ZaehlerKoordinator` und eine **Mitgliederfassung** der `SensorZeile` verlassen `#if DEBUG`. Die Mitgliederfassung zeigt: verbinden, Befestigung, „zählt“ / „zählt hier noch nicht“ / „Zahl prüfen“, Akku — keine Hz, keine Diagnose.
- Diagnose-Blatt, 5-Minuten-Test und Aufnahme bleiben Debug. Mitglieder schreiben keine Aufnahmen.
- `Befestigungsart.freigegeben` ist anfangs leer. Jede Art kommt mit einem eigenen Commit hinein, zusammen mit dem Gütebericht, der das Tor zeigt. Der Gütebericht-Test hält sie dort fest (5.5).
- Nicht freigegebene Arten: im Release „zählt hier noch nicht“; im Debug zählt der Zähler trotzdem, damit weiter gesammelt wird.
- FAQ „Wann kommt der Sensor?“ wird angepasst.
- App-Review: Begründung für `bluetooth-central` (Bewegungssensor zählt Wiederholungen bei gesperrtem Bildschirm) in den Review-Notizen.

## 8. Nicht enthalten

- Anzeige von Herkunft oder `rep_events` irgendwo (Portal, Verlauf, Rückblick, Fortschritt)
- Tempo, Phasendauern, Bewegungsumfang als Anzeige oder Auswertung (C); Spiel (D)
- Rohdaten-Upload, Aufnahmen bei Mitgliedern
- NFC-Bindung Sensor ↔ Gerät, Studio-Sensoren, mehrere Sensoren gleichzeitig
- Automatisches Sichern bei erkanntem Satzende
- Erkennen der Befestigungsart aus dem Signal
- Kalibrieren und Speichern aus der App (Spec A §11.4)
- Core-ML-Modell

## 9. Fehlerfälle

| Fall | Verhalten |
|---|---|
| Sensor verbindet sich mitten in der Eingabe-Phase | Zähler startet in diesem Moment in `bereit`; der bisherige Teil ist nicht gezählt — das Mitglied sieht das Rad und korrigiert |
| Verbindung reißt im Satz ab | `.unsicher(.luecke)` → `pruefen(n)`; Satz lässt sich sichern; nach dem Wiederverbinden kein Weiterzählen |
| App im Hintergrund ohne Daten | Abstand > 0,5 s → wie oben |
| Unsicheres Signal | `pruefen(n)` mit Grund |
| Mitglied dreht vor der ersten Wiederholung | keine Korrektur; erste Zählung überschreibt den vorbelegten Wert |
| Übung wechselt im Satz | Satz verworfen, neuer Kontext, neue Prüfung auf Anwendbarkeit |
| Zähler wirft intern / Profil fehlt | nicht möglich nach Typ (reine Funktion, Profil je Art im Code); fehlt die Art, `zaehltNicht(.keineBefestigung)` |
| Domäne lehnt Herkunft ab (z. B. Konsistenz) | wie jeder abgelehnte PUT heute; im Plan wird geprüft, dass das iOS-Modell die Konsistenz vor dem Senden selbst einhält |
| Alter Client oder alter Warteschlangen-Eintrag | `eingegeben` |

## 10. Fertig ist B, wenn

1. E1–E4 gemergt sind, das volle Testset (inkl. `swift test` für `Sensorik`) grün ist und die Geräte-Checkliste aus 6.8 abgehakt ist.
2. 6.6 ausgefüllt ist.
3. `guetebericht.md` für jede Befestigungsart mit echten Sätzen vorliegt.
4. E5 ist für mindestens eine Art ausgelöst — oder die Spec hält fest, welche Art woran scheitert und was für C/D daraus folgt.

## 11. Offene Punkte für später

1. **Anzeige der Herkunft** (z. B. Sensor-Symbol im Verlauf), sobald Mitglieder danach fragen.
2. **Kennzahl im Portal** (Anteil gezählter Sätze), sobald Studios Sensoren ausgeben.
3. **NFC-Bindung**, Studio-Sensoren, Befestigungsart am Gerät im Portal (Spec A §11.5).
4. **Periodizität als Plausibilitätsprüfung** für `taktUnregelmaessig`, falls die Regelkette dort schwach ist.
5. **Aufnahmen bei Mitgliedern** mit Einwilligung, falls die eigenen Aufnahmen für eine Art nicht reichen.

---

## Nachtrag vom 10. Oktober 2026 (Umsetzung E3)

- Die Migration heißt `0049_satz_herkunft.sql`, nicht `0048` (Abschnitt 6.1: „heute wäre es `0048`“ — die Nummer war zur Umsetzung vergeben).
- Die CHECK-Bedingung aus 6.1 enthält in beiden gezählten Zweigen (`gemessen`, `korrigiert`) zusätzlich `volume_counted is not null`, weil eine CHECK-Bedingung bei NULL besteht und `volume_counted = volume` bzw. `volume_counted <> volume` sonst mit NULL durchgehen würde.
