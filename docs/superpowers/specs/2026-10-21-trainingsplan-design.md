# Trainingsplan – Design

Stand: 21.10.2026 · Betrifft: `packages/domain`, `apps/web` (API), `apps/ios-member`, `supabase/migrations`, `catalog/gymtavo.json`

Grundlage: Tims Entwürfe `GYMTAVO_Trainingskonzept.md` (v0.2) und `GYMTAVO_Projektplan_Trainingssystem.md` (v0.1), abgeglichen mit dem Repository am 21.10.2026 und im Brainstorming am selben Tag zugeschnitten. Wo dieses Dokument von den Entwürfen abweicht, gilt dieses Dokument. Wo es schweigt, gelten die Fachregeln aus dem Trainingskonzept als Vorgabe.

## Absicht und Warum

Heute trainiert ein Mitglied frei: Gerät scannen, Sätze eintragen, beim nächsten Mal einen Vorschlag sehen. Es fehlt die Richtung: Was mache ich heute, wie viel, und warum?

Der Trainingsplan gibt diese Richtung, ohne das freie Training einzuschränken. **Das Training passt sich an den Menschen an, nicht der Mensch an das Training.**

Tim misst Erfolg an fünf Erlebnissen:

1. Ein einmaliges Onboarding (ca. 10 Minuten sind in Ordnung) liefert einen Plan, der zu mir passt.
2. Ich komme ins Studio und weiß sofort, was heute dran ist.
3. Es fühlt sich wissenschaftlich fundiert an – die App erklärt, warum der Plan so aussieht und warum ein Gewicht steigt.
4. Spontan etwas anderes machen geht intuitiv und ohne Rückfrage.
5. Gewichte, Wiederholungen und Wiedereinstieg folgen meiner tatsächlichen Leistung.

## Ziele

- Onboarding-Erweiterung, aus der deterministisch ein Plan entsteht.
- Ein Plan aus Einheiten (A/B …), deren Übungszahl realistisch in die angegebene Zeit passt.
- Drei Ziele: **Muskelaufbau, allgemeine Fitness, Abnehmen**; dazu 0–2 frei wählbare **Fokusbereiche**.
- Flexibler Ablauf im Studio: Reihenfolge egal, ungeplante Übungen zählen und machen eine ähnliche geplante Übung optional.
- Startgewicht ohne Testprotokoll: fragen, schätzen, über die Reserve-Abfrage nachschärfen und auf ähnliche Übungen übertragen.
- Eine Seite „Warum dein Plan so aussieht“ mit regelbasierten Begründungen.
- Zwei Voraussetzungen im Bestand beheben: Blöcke je Einheit statt je Kalendertag, und Aufwärmsätze als eigene Satzrolle.

## Nicht-Ziele (erste Version)

- **Kein Startcoach mit Testsätzen** (aufsteigende Probesätze, 10RM, 1RM). Das ist eine spätere „Expertenvariante“, über die vorher Nutzer befragt werden.
- Kein Ziel „Kraft“ als eigener Plantyp (siehe Festlegung F1).
- Keine Abfrage ungeliebter Übungen im Onboarding. Austausch passiert situativ in der App (siehe Abschnitt 5).
- Keine automatische Erhöhung der Satzzahl (Volumenprogression), keine Periodisierung, keine festen Deloads.
- Keine automatische Planrotation nach Wochen.
- Keine KI-generierten Texte oder Pläne.
- Keine Sensoränderung; manuelle Wiederholungen bleiben die Datenbasis.
- Keine Ernährungsberatung und kein Gewichtsverlust-Versprechen.
- Keine Screen- und Navigationsgestaltung in diesem Dokument (siehe „Dem Umsetzer überlassen“).

## Anti-Ziele (Fehlschlag, auch wenn es technisch läuft)

- Der Plan bremst freies Training: Rückfragen wie „Das steht nicht im Plan, trotzdem?“, Warnungen bei anderer Reihenfolge, blockierte Geräte.
- Eine Einheit dauert regelmäßig deutlich länger oder kürzer als angegeben.
- Die App behauptet Präzision, die sie nicht hat (exakte Maximalkraft, Fettverbrennung durch Bauchübungen, garantierter Gewichtsverlust).
- Bestehende Satzhistorie oder bestehendes freies Training gehen verloren oder verhalten sich anders.
- Zwei Regelimplementierungen (Server und App), die zu unterschiedlichen Vorschlägen kommen.

## Bestand, auf dem aufgebaut wird

| Baustein | Ort | Bedeutung |
|---|---|---|
| Studio-Inventar | `machines` (studio_id, equipment_model_id, status) | Der Plan wählt nur aktive Geräte des Studios |
| Gerät → Übungen | `equipment_model_exercises` | Welche Übungen ein Gerät erlaubt |
| Muskeldaten | `catalog/gymtavo.json` `muscles[].role`, Migration `0056_exercise_muscles` | Grundlage der Ähnlichkeitsregel |
| Profilfelder | `0041_profil_stammdaten`: sex, age_band, height_cm, training_goal, onboarding_completed_at | Werden wiederverwendet |
| Trainingstage | `member_goals` kind `weekly_days` | Wird wiederverwendet |
| Körpergewicht | `body_measurements` | Für die Startgewicht-Schätzung |
| Progressionsregel | `packages/domain/src/progression.ts` v2.0.0 | Wird erweitert, nicht ersetzt |
| Vorschlagsprotokoll | `progression_suggestions` | Bleibt, bekommt Planbezug |
| Pausensumme | `0053_pausensumme` | Echte Dauer für spätere Kalibrierung der Zeitrechnung |
| Startwerte-Drawer | iOS, fragt nur das Gewicht (Commit `7b8aa80`) | Wird vorausgefüllt statt ersetzt |
| Mini-Zirkel | `docs/superpowers/specs/2026-10-21-mini-zirkel-design.md` | Zirkelsätze zählen für den Plan wie normale Sätze |

**Regeln laufen auf dem Server** (`packages/domain`, aufgerufen aus `apps/web`), wie heute die Progression: Planerstellung, Gewichtsvorschläge, Startschätzung, Übertragung, Wiedereinstieg. Die App rechnet keine Gewichte.

**Ausnahme Ablaufstatus (F17):** Abhaken, „optional“ und „nächste Einheit“ müssen offline im Studio sofort reagieren. Diese Statuslogik ist reiner Ablaufzustand der laufenden Session (wie heute die Blöcke) und lebt in der App. Der Server liefert dafür mit dem Plan je Planposition die Hauptmuskeln der geplanten Übung und für jede Übung des Studios deren Hauptmuskeln; die App vergleicht nur Mengen. Die App schickt den Status beim Sync mit; der Server speichert ihn und bestimmt daraus beim nächsten Laden die nächste Einheit. Ein Testfallsatz (gleiche Eingaben → gleicher Status) wird in TypeScript und Swift gegen dieselben Beispieldaten geprüft.

**Befunde, die vorher zu beheben sind:**

- `toBlocks` (`progression.ts`) und `progress.ts` gruppieren Sätze nach `performed_at.slice(0, 10)`, also UTC-Kalendertag. Zwei Einheiten am selben Tag verschmelzen, späte Einheiten landen am falschen Tag. Künftig: Block = (session_id, machine_id, exercise_id).
- Es gibt keine Satzrolle. Ein leichterer Aufwärmsatz macht den Block uneinheitlich (`uniformLoad` → null), und es entsteht kein Vorschlag.
- `rir` wird nie erfasst (`WorkoutSessionStore.swift` setzt immer `rir: nil`). Die Regel läuft heute nur über ihren Ersatzpfad.

## 1. Onboarding

Bestandsfragen bleiben; neu hinzu kommt ein Block „Dein Trainingsplan“. Bestandsnutzer (onboarding_completed_at gesetzt) bekommen diesen Block einmalig als „Plan einrichten“, vorausgefüllt mit vorhandenen Angaben. Ohne Plan bleibt alles wie heute.

| Angabe | Neu? | Werte | Wirkung |
|---|---|---|---|
| Ziel | vorhanden | Muskelaufbau, Fitness, Abnehmen | Zielprofil (Abschnitt 3) |
| Tage pro Woche | vorhanden (`weekly_days`) | 1–6 | Planstruktur (Abschnitt 2) |
| Minuten pro Training | neu | 30, 45, 60, 75, 90 | Anzahl Übungen |
| Fokusbereiche | neu | 0–2 aus Brust, Rücken, Schultern, Arme, Po, Beine, Bauch | Zusatzübung je Einheit |
| Erfahrung | neu | „neu“, „schon trainiert, aber nicht regelmäßig/systematisch“, „regelmäßig seit über 6 Monaten“ | Satzzahl, Reserve, Startschätzung |
| Geschlecht, Altersgruppe, Größe, Gewicht | vorhanden | – | **nur** Startgewicht-Schätzung, nicht der Plan |
| Beschwerden | neu | Körperbereiche Knie, Hüfte, unterer Rücken, Schulter, Ellenbogen/Handgelenk; je „meiden“ oder „vorsichtig“ | Übungsausschluss bzw. -auswahl |

**Beschwerden sind Gesundheitsdaten (DSGVO Art. 9).** Erhoben nur mit ausdrücklicher, separater Einwilligung; überspringbar; kein Freitext, keine Diagnose. Bei Auswahl erscheint der Hinweis, akute oder unklare Schmerzen ärztlich abklären zu lassen. „Meiden“ schließt Übungen aus, die den Bereich wesentlich belasten; „vorsichtig“ bevorzugt geführte, gelenkschonende Varianten. Dafür bekommt jede Planübung im Katalog ein Feld der belasteten Bereiche (fachlich zu prüfen, Abschnitt 8).

Profiländerungen erzeugen einen neuen Planvorschlag, den das Mitglied bestätigt. Laufende Einheiten bleiben unverändert, die Historie bleibt.

## 2. Planstruktur

| Tage/Woche | Struktur |
|---|---|
| 1 | Ganzkörper (eine Einheit) |
| 2–3 | Ganzkörper A/B im Wechsel |
| 4 | Oberkörper/Unterkörper A/B (je zweimal) |
| 5–6 | Ganzkörper A/B/C im Wechsel |

Grundlage: Bei gleicher Satzmenge unterscheiden sich Ganzkörper- und Splitprogramme nicht relevant (Ramos-Campo et al. 2024). Ganzkörper verzeiht ausgefallene Termine am besten.

**Reihenfolge der Einheiten ist eine Folge, kein Kalender.** Nach A kommt B, egal an welchem Wochentag. Ausgefallene Termine erzeugen keine Nachholschuld. Eine Einheit gilt als erledigt, sobald ein Training mit mindestens einer erledigten oder optional gewordenen Planübung beendet wird (Festlegung F5); danach ist die nächste Einheit dran.

### Bausteine

Eine Einheit besteht aus **Bausteinen**, nicht aus festen Übungen. Der Generator belegt jeden Baustein mit einer Übung, für die es im Studio ein aktives Gerät gibt.

| Baustein | Typ | Kandidaten (Katalog-Keys, Beispiele) |
|---|---|---|
| Beine – Knie | Mehrgelenk | leg_press_45, leg_press_horizontal, hack/belt squat |
| Beine – Hüfte | Mehrgelenk/Isolation | hip_thrust_machine, leg_curl_seated, leg_curl_prone |
| Drücken | Mehrgelenk | chest_press_*, incline_chest_press, shoulder_press_machine |
| Ziehen | Mehrgelenk | row_machine_*, cable_row_*, lat_pulldown_*, high_row_machine |
| Schulter | Isolation | lateral_raise_machine, cable_lateral_raise |
| Arme | Isolation | preacher_curl_machine, triceps_extension_machine, Kabelvarianten |
| Rumpf | Isolation | ab_crunch_machine, cable_crunch_kneeling, back_extension |
| Beine – Ergänzung | Isolation | leg_extension_machine, Waden |

**Pflichtbausteine je Ganzkörpereinheit:** Beine–Knie, Beine–Hüfte, Drücken, Ziehen. Über A/B wechseln die Übungen innerhalb der Bausteine (z. B. A: Beinpresse/Beinbeuger/Brustpresse/Rudern, B: Beinstrecker oder Hackenschmidt/Hip Thrust/Schrägbankpresse/Latzug), damit sich über die Woche Druck- und Zugrichtungen sowie Knie- und Hüftarbeit ergänzen. Ober-/Unterkörper verteilt dieselben Bausteine auf zwei Einheitstypen.

Übungen bleiben im Plan stabil, bis das Mitglied etwas ändert oder einen neuen Plan anfordert. Zufällige Variation erschwert Gewichtsfindung und Fortschrittsvergleich.

### Zeitrechnung

Die Übungszahl ergibt sich aus der Zeit, nicht umgekehrt. Weniger Zeit bedeutet weniger Übungen, **nie** kürzere Pausen.

| Baustein der Rechnung | Vorgabe v1 |
|---|---|
| Allgemeines Aufwärmen | 5 min |
| Arbeitszeit je Satz | 45 s |
| Pause Mehrgelenkübung | 2,5 min (zwischen Sätzen) |
| Pause Isolationsübung | 1,5 min |
| Aufwärmsatz | 1 je Mehrgelenkübung, 1,5 min inkl. Pause |
| Gerät wechseln und einstellen | 1,5 min je Übung |
| Cardio-Block (nur Abnehmen) | 20 min |

Daraus: Mehrgelenkübung mit 3 Sätzen ≈ 10 min, Isolationsübung mit 3 Sätzen ≈ 7 min. **60 Minuten Muskelaufbau = 3 Mehrgelenk- + 3 Isolationsübungen à 3 Sätze (≈ 56–58 min).** Der Generator füllt bis zum Budget und darf es um höchstens 5 % überschreiten. Die Vorgaben sind versionierte Konstanten; sie werden später mit den gemessenen Dauern (Pausensumme, Satzzeitpunkte) nachjustiert.

**Knappe Budgets (F16).** Reicht die Zeit nicht für alle Pflichtbausteine mit Zielsatzzahl, gibt in dieser Reihenfolge nach:

1. Ergänzungs- und Fokusübungen entfallen.
2. Sätze sinken auf 2 je Übung.
3. Cardio (nur Abnehmen) schrumpft: 60 min → 20, 45 min → 10, 30 min → kein Cardio im Studio (Hinweis auf Alltagsbewegung).
4. Bei 30 min entfällt das allgemeine Aufwärmen; der Aufwärmsatz der ersten Mehrgelenkübung bleibt.

Pflichtbausteine entfallen nie. Richtwert: 4 Pflichtbausteine × 2 Sätze ≈ 28 min. Jeder dieser Schritte erzeugt einen eigenen Textbaustein auf der Erklärseite.

Grundlage der Pausen: Längere Pausen (2–3 min) bei Mehrgelenkübungen bringen für Muskelaufbau mehr als sehr kurze (Schoenfeld et al. 2016).

Der Pausentimer verwendet bei Planübungen die Pause der Planposition, sonst wie heute die Satzpause aus dem Profil (Festlegung F6).

## 3. Zielprofile

| Ziel | Wiederholungen | Sätze je Übung | Zielreserve | Besonderheit |
|---|---|---|---|---|
| Muskelaufbau | Mehrgelenk 8–12, Isolation 10–15 | 3 | 1–3 | – |
| Allgemeine Fitness | 10–15 | 2–3 | 2–3 | Lieber eine Übung mehr als ein Satz mehr |
| Abnehmen | 10–15 | 2–3 | 2–3 | 20 min Cardio am Ende, im Zeitbudget enthalten |
| Anfänger (Erfahrung „neu“), erste 4 Wochen bzw. 8 Einheiten | wie Ziel | 2 | 3–4 | Dafür ggf. eine Übung mehr |

Wöchentlicher Richtwert für Muskelaufbau: etwa 10 gezählte Sätze je großer Muskelgruppe (Hauptmuskel 1, Nebenmuskel 0,5), mit abnehmendem Zusatznutzen darüber (Pelland et al. 2025/26). Der Generator prüft diese Bilanz als Plausibilität, optimiert aber nicht darauf.

Zielbereiche und Zielreserve stehen an der **Planposition**, nicht am Katalog. Der Katalog liefert heute für alle Übungen 8–12; das bleibt der Wert fürs freie Training.

**Abnehmen – was die App sagt und warum:**

- Krafttraining bleibt Kern, weil es im Kaloriendefizit die Muskulatur erhält.
- Cardio in moderater Intensität (Faustregel: in ganzen Sätzen sprechen können). Die Intensitätszone ist für den Fettverlust nachrangig: gleichmäßiges Ausdauertraining und Intervalle führen zu ähnlichem Fettverlust (Wewege et al. 2017). Moderat wird gewählt, weil es durchhaltbar und gelenkschonend ist.
- Spürbarer Gewichtsverlust durch Bewegung braucht über 150, eher 225–300 Minuten pro Woche (Donnelly et al. 2009, ACSM). Drei Einheiten mit 20 Minuten Cardio liegen deutlich darunter; die App sagt offen, dass Alltagsbewegung und Ernährung den größeren Teil ausmachen.
- Bauchübungen reduzieren kein Bauchfett gezielt (Vispute et al. 2011). Wer Abnehmen und Fokus Bauch wählt, bekommt diesen Hinweis.

### Fokusbereiche

0–2 frei wählbar. Jeder Fokusbereich bekommt in jeder Einheit eine eigene Übung, die einen Hauptmuskel des Bereichs trainiert. Dafür entfällt eine Ergänzungsübung (Schulter, Arme, Rumpf, Beine–Ergänzung), damit die Zeit gleich bleibt. Pflichtbausteine entfallen nie. Ergebnis: ca. 14–16 Wochensätze im Fokusbereich statt ca. 10. Reicht die Zeit nicht für Pflicht + Fokus, wird das auf der Erklärseite gesagt und der zweite Fokus nicht berücksichtigt.

## 4. „Warum dein Plan so aussieht“

Nach dem Erstellen und jederzeit aus dem Plan erreichbar. Kurze Absätze, je einer pro Entscheidung, zusammengesetzt aus festen, fachlich geprüften Textbausteinen, die der Generator mit den Gründen seiner Entscheidungen auswählt (z. B. `struktur_ganzkoerper_ab`, `zeit_6_uebungen`, `fokus_po`, `abnehmen_cardio_zone`, `bauch_kein_fettabbau`, `anfaenger_reserve`). Keine KI-Texte. Textbausteine sind versioniert wie die Regeln.

Gleiches Prinzip für Gewichtsvorschläge: Der vorhandene `reasonCode` wird als kurzer Satz angezeigt („+2,5 kg, weil du in allen Sätzen 12 Wiederholungen mit 2 in Reserve geschafft hast“).

## 5. Ablauf im Studio

- Die App zeigt die heutige Einheit mit ihren Übungen. Gestartet wird wie heute über Scan oder Geräteauswahl; es gibt keinen zweiten Trainingsmodus. Session, Sätze und Synchronisation bleiben dieselben.
- `workout_sessions` bekommt einen Bezug zur Planeinheit, die bei Start dieser Session die aktuelle war.
- **Geplante Übung gemacht** (gleiche `exercise_id`, egal an welchem Gerät des Studios): Planposition abgehakt. Reihenfolge ist egal, keine Hinweise.
- **Ungeplante Übung gemacht:** wird normal gespeichert und zählt fürs Training. Teilt sie mindestens einen Hauptmuskel mit einer noch offenen geplanten Übung, wird **genau eine** davon „optional“: die mit den meisten gemeinsamen Hauptmuskeln; bei Gleichstand die zuerst im Plan stehende. Ein gewisser Schwund ist gewollt (Tim: „sonst ist die Flexibilität nur im Plan und nicht in der Realität vorhanden“). Optionale Übungen bleiben sichtbar und können trotzdem gemacht werden.
- **Situativer Austausch:** An einer offenen Planposition kann das Mitglied „andere Übung“ wählen; angeboten werden Kandidaten desselben Bausteins im Studio. Mit „dauerhaft tauschen“ ändert das die Planposition für künftige Einheiten (neue Planversion); ohne gilt es nur heute.
- Mini-Zirkel-Sätze zählen wie normale Sätze.
- **Cardio-Block (F19)** ist eine normale Planposition mit einer Cardio-Übung des Katalogs an einem Cardiogerät des Studios; Vorgabe ist Dauer statt Wiederholungen. Erledigt, sobald dort ein Satz gespeichert ist. Ein anderes Cardiogerät erfüllt ihn ebenfalls (Cardio gilt untereinander als gleichwertig). Cardio nimmt nicht an der Hauptmuskel-Regel für Kraftübungen teil, in beide Richtungen. Hat das Studio kein aktives Cardiogerät, entfällt der Block und die Zeit geht an Kraftübungen; die Erklärseite sagt das.
- Keine Rückfrage, keine Sperre, keine Warnung wegen Abweichungen.

## 6. Gewichte

### Startgewicht (Übung ohne eigene Historie an diesem Gerätemodell)

1. Der Startwerte-Drawer fragt wie heute nach dem Gewicht, ist aber **vorausgefüllt** mit einer Schätzung.
2. Schätzung v1: Gerätestartwert (`load_start`) skaliert mit einem konservativen Faktor aus Erfahrung, Geschlecht, Altersgruppe und Körpergewicht, gerundet auf die Gerätestufe und begrenzt durch `load_min`/`load_max`. Lieber zu leicht als zu schwer. Die Faktortabelle ist eine versionierte Konstante (dem Umsetzer überlassen, Abschnitt „Dem Umsetzer überlassen“).
3. Liegt eine **Übertragungskorrektur** vor (unten), wird sie auf die Schätzung angewendet.
4. Ein vom Mitglied eingetragenes Gewicht hat immer Vorrang.

### Reserve-Abfrage

- Nach dem letzten Satz einer Übung, auf dem Screen vor „weiter mit nächster Übung“: „Wie viele Wiederholungen wären im letzten Satz noch drin gewesen?“ Skala 0, 1, 2, 3, 4, 5+ und „weiß nicht“. Überspringbar; gilt für alle Übungen, nicht nur Planübungen.
- Gespeichert in `workout_sets.rir` am letzten Arbeitssatz. „Weiß nicht“ und Überspringen bleiben `null`, nie 0.
- Kurze Erklärung beim ersten Mal (sauber ausgeführte Wiederholungen, gleiches Gewicht, keine Pause).

### Übertragung auf ähnliche Übungen

Für die ersten Übungen einer Muskelregion zeigt die Reserve, ob sich das Mitglied unter- oder überschätzt. Übertragen wird **keine Kilogrammzahl**, sondern eine prozentuale Korrektur:

- Geschätzte mögliche Wiederholungen = gemachte Wiederholungen + Reserve. Abweichung zur Mitte des Zielbereichs plus Zielreserve ergibt die Korrektur, v1: 3 % Last je Wiederholung Abweichung, gedeckelt auf ±20 %.
- Gilt für alle Übungen, die mindestens einen Hauptmuskel mit der gemessenen Übung teilen **und keine eigene Historie haben**. Sobald eine Übung eigene Sätze hat, entscheidet nur noch ihre eigene Historie.
- Mehrere Messungen für dieselbe Zielübung: die jüngste gilt.

Grundlage und Grenze: Der Zusammenhang Wiederholungen ↔ Last schwankt zwischen Personen und Übungen (Nuzzo et al. 2023), RIR-Schätzungen sind ungenau (Halperin et al. 2022). Das ist eine grobe Annäherung, ausdrücklich besser als jedes Gerät einzeln zu testen, und wird im Training sofort weiter korrigiert.

### Fortlaufende Anpassung

- **Zielgewichte je Planposition (ersetzt die frühere Fortschreibung der doppelten Progression):** Das Gewicht gehört in den Plan und wird nach jeder abgeschlossenen Einheit neu gerechnet. Regeln G1 bis G4 und das Verhalten in Randfällen stehen in `2026-10-25-trainingsplan-plangewichte-design.md`. Startgewicht, Reserve-Abfrage, Übertragung und Wiedereinstieg unten bleiben (dort G5).
- **Grobe Gerätestufen:** Wäre der nächste Schritt mehr als 10 % der aktuellen Last (häufig bei 2,5-kg-Stufen unter 25 kg), wird statt der Last zuerst der Wiederholungsbereich nach oben geöffnet (z. B. 10–15 → bis 18, dann Laststufe mit Rückkehr in den Bereich). Keine automatische Blockade ohne Ausweg.
- Erster Arbeitssatz deutlich unter dem Bereich: Tageslast darf sinken, die Referenz bleibt. Dauerhafte Senkung erst bei wiederholter Unterschreitung (wie heute zwei Blöcke).
- **Wiedereinstieg nach Pausen (F18).** Gemessen je Übung am Gerätemodell: Abstand zwischen heute und dem letzten Block dieser Übung. Keine Rückfrage an das Mitglied in v1.

  | Abstand | Vorschlag |
  |---|---|
  | bis 7 Tage | normale Regel |
  | 8–14 Tage | letzte bewährte Last halten, keine Steigerung |
  | 15–28 Tage | Last −7,5 % (auf Gerätestufe abgerundet), 1 Satz weniger (min. 1) |
  | 29–42 Tage | Last −12,5 %, 1 Satz weniger |
  | über 42 Tage | wie Übung ohne Historie (Startschätzung), alte Last nur als Hinweis |

  Eine vorgemerkte Steigerung verfällt. Nach einem Wiedereinstiegsblock gilt beim nächsten Kontakt wieder die normale Regel. Die Werte sind unvalidierte Puffer, keine behaupteten Kraftverluste; sie sind versionierte Konstanten.
- Lasthistorie bleibt pro Gerätemodell + Übung (wie heute in `machine-context.ts`). Kein Kilogrammtransfer zwischen Geräten.

## 7. Datenänderungen (Umriss)

Die genaue Ausgestaltung gehört dem Umsetzer; diese Verantwortungen müssen abgebildet sein:

- **Trainingsprofil:** Minuten je Training, Erfahrung, Fokusbereiche, Beschwerden (getrennt, mit Einwilligungszeitpunkt). Ziel und Tage aus den vorhandenen Feldern.
- **Plan mit Version:** Parameter, Regelversion, Einheiten in Reihenfolge, Planpositionen (Baustein, Übung, bevorzugtes Gerät, Sätze, Wiederholungsbereich, Zielreserve, Pause, Typ Mehrgelenk/Isolation). Ein aktiver Plan je Mitglied und Studio (F20): Das Profil gilt für alle Studios; ein Plan entsteht für das Studio, in dem „Plan einrichten“ bzw. das Onboarding abgeschlossen wird, und für weitere Studios erst auf Wunsch. Die Einheitenfolge läuft je Studio. Eine Session hängt am Plan ihres `studio_id`. Historische Versionen bleiben.
- **Session ↔ Planeinheit** und Status je Planposition in dieser Session (offen, erledigt, optional, getauscht).
- **Satzrolle** an `workout_sets`: `arbeit` (Default, auch für alle Altdaten) oder `aufwaermen`. Bei Planübungen mit Aufwärmsatz ist der erste Satz als Aufwärmsatz vorbelegt; im freien Training kann ein Satz als Aufwärmsatz markiert werden. Progression und Bilanz ignorieren Aufwärmsätze.
- **Blöcke je Session** statt je UTC-Tag in `toBlocks` und `progress.ts`.
- **Vorschlagsprotokoll** um Planversion und Übertragungskorrektur ergänzen.
- **Katalog:** pro Übung Baustein-Zuordnung, Typ (Mehrgelenk/Isolation), belastete Körperbereiche, Freigabe für Pläne.
- `training_goal` `get_stronger` bleibt in der Datenbank gültig, wird im Onboarding nicht mehr angeboten und wie Muskelaufbau geplant (F1).

## 8. Fachliche Freigabe

Bausteinzuordnung, belastete Körperbereiche und Planfreigabe der Übungen werden für die erste Version nur für die Übungen gepflegt, die als Kandidaten in Abschnitt 2 dienen (ca. 30). Alle 162 Katalogeinträge stehen heute auf `review: draft`; für Planübungen wird ein eigenes Freigabe-Kennzeichen gesetzt.

## Entscheidungen von Tim

1. Plan aus Ziel, Häufigkeit, Zeit pro Training und weiteren Profilangaben; Ablauf im Studio flexibel.
2. Reihenfolge egal; ungeplante Übung macht eine ähnliche geplante optional; spontanes Training wird nie aufgehalten.
3. Ähnlich = mindestens ein gemeinsamer Hauptmuskel. Schwund wird akzeptiert.
4. Onboarding darf ca. 10 Minuten dauern, einmalig.
5. Kein Startcoach mit Testsätzen in v1; Expertenvariante später nach Nutzerbefragung.
6. Startgewicht: fragen, Schätzung aus Fitnesszustand; Reserve nach jeder Übung auf dem letzten Screen per Skala; Übertragung auf ähnliche Übungen ausdrücklich gewünscht, obwohl unsauber.
7. Ziele: Muskelaufbau, allgemeine Fitness, Abnehmen; 1–2 frei wählbare Fokusbereiche.
8. Übungsanzahl, Dauer und Pausen müssen realistisch in die angegebene Zeit passen.
9. Hinweis „Bauchübungen bauen kein Bauchfett ab“ ist wichtig; Abnehmen bekommt mehr Cardio; Aussagen wissenschaftlich prüfen.
10. Ziel des Mitglieds wird analysiert, der Planaufbau erklärt.
11. Onboarding fragt Erfahrung, Alter, Geschlecht, Beschwerden; ungeliebte Übungen nicht, das passiert situativ.

## Festlegungen von Claude (zur Prüfung durch Tim)

- **F1** Ziel „Kraft“ wird nicht angeboten; Bestandswert `get_stronger` wird wie Muskelaufbau geplant.
- **F2** Eine ungeplante Übung macht höchstens eine geplante optional (meiste gemeinsame Hauptmuskeln, dann Planreihenfolge).
- **F3** Die Ähnlichkeit nutzt die vorhandenen Muskeldaten; kein neues Bewegungsmuster-Feld für die Ähnlichkeit.
- **F4** Übertragung als prozentuale Korrektur (3 %/Wdh., max. ±20 %), nur für Übungen ohne eigene Historie.
- **F5** Einheit gilt als erledigt, sobald ein Training mit mindestens einer erledigten/optionalen Planposition endet.
- **F6** Pausentimer nutzt bei Planübungen die Planpause, sonst die Profil-Satzpause.
- **F7** Alter und Geschlecht beeinflussen nur die Startschätzung, nicht den Plan (Frauen und Männer bauen relativ ähnlich auf, Roberts et al. 2020).
- **F8** Abnehmen: 20 min moderates Cardio je Einheit.
- **F9** Fokus: eine eigene Übung je Einheit statt einer Ergänzungsübung.
- **F10** Begründungstexte regelbasiert, keine KI.
- **F11** Anfängerphase: 4 Wochen bzw. 8 Einheiten mit 2 Sätzen und 3–4 Reserve.
- **F12** Zeitkonstanten wie in Abschnitt 2; Budget darf um höchstens 5 % überschritten werden.
- **F13** Grobe Stufen (>10 %): Wiederholungsbereich nach oben öffnen statt blockieren.
- **F14** Pläne bleiben stabil, keine automatische Rotation.
- **F15** Gewichts- und Planregeln laufen nur serverseitig in `packages/domain`.
- **F16** Knappe Zeitbudgets: erst Ergänzungen streichen, dann 2 Sätze, dann Cardio kürzen; Pflichtbausteine bleiben.
- **F17** Ablaufstatus (abhaken, optional, nächste Einheit) rechnet die App offline aus vom Server gelieferten Muskeldaten; gemeinsame Testfälle TS/Swift.
- **F18** Wiedereinstieg je Übung nach Abstand zum letzten Block, ohne Rückfrage; Werte wie in Abschnitt 6.
- **F19** Cardio-Block als Planposition an einem beliebigen Cardiogerät; außerhalb der Hauptmuskel-Regel.
- **F20** Ein Plan je Studio, Profil studioübergreifend, weitere Studios auf Wunsch.

Alle F-Punkte sind Vorschläge; Tim prüft sie beim Lesen dieses Dokuments. F4, F5, F17 prägen das Datenmodell, eine spätere Umkehr ist teuer.

## Dem Umsetzer überlassen

- Screens, Platzierung in der Navigation und Gestaltung von Onboarding-Block, Planansicht, Erklärseite und Reserve-Skala (eigenes Design vor der UI-Umsetzung).
- Tabellen- und Spaltennamen, Migrationen, API-Form.
- Faktortabelle der Startschätzung (konservativ, nachvollziehbar, versioniert).
- Wortlaut der Textbausteine (fachlich gegenlesen lassen).
- Genaue Auswahlreihenfolge der Kandidaten innerhalb eines Bausteins.
- Aufteilung in Etappen; sinnvoll ist, die Voraussetzungen (Blöcke je Session, Satzrolle, Reserve-Abfrage) zuerst zu liefern, da sie auch ohne Plan Nutzen bringen.

## Quellen

Wie im Trainingskonzept v0.2 (S1–S10), zusätzlich:

- Schoenfeld et al. (2016), *Longer Interset Rest Periods Enhance Muscle Strength and Hypertrophy in Resistance-Trained Men*, J Strength Cond Res.
- Wewege et al. (2017), *The effects of high-intensity interval training vs. moderate-intensity continuous training on body composition in overweight and obese adults*, Obesity Reviews.
- Donnelly et al. (2009), ACSM Position Stand, *Appropriate Physical Activity Intervention Strategies for Weight Loss and Prevention of Weight Regain for Adults*, Med Sci Sports Exerc.
- Vispute et al. (2011), *The effect of abdominal exercise on abdominal fat*, J Strength Cond Res.
- Roberts et al. (2020), *Sex Differences in Resistance Training: A Systematic Review and Meta-Analysis*, J Strength Cond Res.
