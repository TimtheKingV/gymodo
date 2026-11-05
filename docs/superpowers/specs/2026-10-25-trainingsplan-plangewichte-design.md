# Trainingsplan Etappe 4: Plangewichte

Stand: 2026-10-25. Ergebnis eines Gesprächs mit Tim. Baut auf `2026-10-21-trainingsplan-design.md` (Abschnitt 6 „Gewichte“) und der Übergabe `2026-10-24-trainingsplan-etappe4-uebergabe.md` auf. **Dieses Dokument ändert Abschnitt 6 des Haupt-Specs**, siehe „Verhältnis zum Haupt-Spec“.

## Worum es geht

Heute schlägt die App ein Gewicht aus der Historie vor. `progression.ts` (v2.0.0) steigert nach starrer Regel: alle Sätze am oberen Ende des Wiederholungsbereichs mit Reserve → eine Stufe mehr; zweimal unter dem unteren Ende → eine Stufe weniger. Die Regel kennt den Plan nicht und nimmt den Wiederholungsbereich aus dem Katalog.

Tim hält die starre Steigerung für nicht klug genug: In einem durchgehenden Plan kann ein Tag bewusst leichter und mit mehr Wiederholungen sein, der nächste schwerer mit weniger, auch bei derselben Übung. Deshalb gehört das Gewicht **in den Plan**, nicht in eine plan-blinde Regel. Der Plan soll „interaktiv“ sein: Nach jeder Einheit wird er an das angepasst, was tatsächlich passiert ist.

## Ziele

1. Jede Kraft-Planposition trägt ein **Zielgewicht** (zusätzlich zu Wiederholungsbereich, Zielreserve, Sätzen und Pause aus Etappe 3).
2. Das Zielgewicht der Startversion kommt aus dem, was das Mitglied am Gerät bereits geschafft hat; für Übungen ohne Historie aus der Startschätzung (Haupt-Spec Abschnitt 6).
3. **Nach jeder abgeschlossenen Einheit** rechnet der Server die Zielgewichte der noch nicht begonnenen Einheiten neu, **still im Hintergrund**, ohne Bestätigung durch das Mitglied.
4. Am Gerät steht bei geändertem Gewicht ein **sehr kurzer Hinweis** mit der Änderung, z. B. „+2,5 kg“ und knappem Grund.
5. **Ohne Plan** (freies Training) schlägt die App das **zuletzt benutzte Gewicht** vor.

## Nicht-Ziele

- Keine Periodisierung und keine festen Deloads (Haupt-Spec bleibt). Der Plan *darf* je Position unterschiedliche Bereiche tragen; der Generator erzeugt sie in dieser Etappe nicht neu.
- Keine Bestätigungsdialoge und keine „Vorschlag annehmen“-Schritte für Gewichtsänderungen.
- Keine Gewichtsrechnung in der App (F15 bleibt: nur serverseitig in `packages/domain`).
- Keine automatische Änderung der Satzzahl, keine automatische Übungswahl. Übungstausch bleibt Handarbeit des Mitglieds („Tauschen“, Etappe 3).
- Kein Kilogrammtransfer zwischen Geräten; Historie bleibt je Gerätemodell und Übung.

## Anti-Ziele (wäre ein Fehlschlag, auch wenn es technisch läuft)

- Eine stille Änderung, die das Mitglied nicht nachvollziehen kann: ohne den kurzen Hinweis am Gerät nicht ausliefern.
- Ein Gewicht, das das Gerät nicht einstellen kann, oder eines außerhalb `load_min`/`load_max`.
- Eine Änderung mitten in einer laufenden Einheit: Das Mitglied steht am Gerät, die Zahl darf sich nicht unter ihm ändern.
- Eine Anpassung auf Grundlage von Aufwärmsätzen oder von Sätzen, die das Mitglied nicht bestätigt hat.

## Entscheidungen von Tim

1. Die Gewichtslogik hängt am Plan, nicht an einer plan-blinden Steigerungsregel. `progression.ts` entfällt als Quelle für Planübungen.
2. Beim Planerstellen wird geschaut, was das Mitglied an welchem Gerät geschafft hat; der Plan wird darauf eingestellt.
3. Der Plan ist laufend interaktiv: nach jeder Einheit werden die nächsten zwei bis drei Einheiten angepasst, vor allem die, in denen dieselben Muskelgruppen wieder dran sind.
4. Die Anpassung läuft still im Hintergrund.
5. Am Gerät erscheint bei einer Änderung ein kurzer Hinweis mit der Änderung („+2,5 kg“), Text kurz halten.
6. Ohne Plan: das letzte Gewicht vorschlagen, sonst nichts.
7. Zählen soll, was das Mitglied tatsächlich gemacht hat, nicht das Vorgeschlagene (von Tim bestätigt, als Annahme von Claude genannt).

## Festlegungen von Claude (zur Prüfung durch Tim)

- **G1 Zwei Schichten.** Die Plan*struktur* (Übungen, Reihenfolge, Sätze, Bereiche) bleibt stabil und versioniert (F14). Die **Zielgewichte** liegen als eigene Schicht darüber und ändern sich laufend, **ohne** neue Planversion. Sonst entstünde nach jeder Einheit eine Planversion, und `swap`/Annehmen/Stand-Logik aus Etappe 3 würden unübersichtlich.
- **G2 Auslöser** ist der Abschluss einer Einheit auf dem Server (ausdrücklich beendet oder nach 4 h Stillstand automatisch, siehe Übergabe Punkt 4). Nicht pro Satz.
- **G3 Welche Einheiten.** Angepasst werden nur Einheiten, die **noch nicht begonnen** sind, und nur Positionen, die dieselbe Übung am selben Gerät haben wie eine gerade abgeschlossene Position, oder (für Übungen ohne Historie) eine Übertragungskorrektur erhalten (G5). Vorausschau: die nächsten drei Einheiten des Plans. Einheiten mit anderen Muskelgruppen bleiben deshalb von selbst unberührt.
- **G4 Rechnung.** Reine Funktion in `packages/domain`, deterministisch, versioniert wie die anderen Regeln. Eingabe: Planposition (Bereich, Zielreserve, Sätze), die tatsächlichen Arbeitssätze der Einheit (Last, Wiederholungen, RIR, Problemmeldung, Aufwärmsätze ausgenommen), Gerätegrenzen (`loadStep`, `loadMin`, `loadMax`). Sie bleibt in der Haltung der heutigen Regel: Problemmeldung schlägt jede Steigerung; „oben erreicht und Reserve ≥ Zielreserve“ → eine Stufe mehr; deutlich unter dem Bereich → Tageslast darf sinken; grobe Stufen (>10 %) öffnen erst den Wiederholungsbereich (F13). Der Unterschied zu heute: Bereich und Zielreserve stammen aus der **jeweiligen Planposition** und der Wert wird dort abgelegt, statt als Vorschlag zu verfallen. Hat dieselbe Übung in zwei Einheiten verschiedene Bereiche, rechnet jede Position gegen ihren eigenen.
- **G5 Übertragung und Wiedereinstieg bleiben** wie in Haupt-Spec Abschnitt 6 (3 % je Wiederholung Abweichung, ±20 %, nur für Übungen ohne eigene Historie; Abstandstabelle F18 für Pausen). Sie fließen als Eingänge in die Zielgewichte ein, nicht mehr in `progression.ts`.
- **G6 Ist-Satz gewinnt.** Wählt das Mitglied am Gerät ein anderes Gewicht als das Ziel, rechnet die nächste Anpassung von diesem tatsächlichen Satz aus. Das Ziel ist ein Vorschlag, keine Vorgabe.
- **G7 Hinweistext.** Er wird aus dem Grund-Code der Rechnung gebaut (feste Textbausteine, keine KI, F10), Länge: ein Halbsatz. Verglichen wird mit dem **letzten tatsächlich benutzten Gewicht** an diesem Gerät und dieser Übung; ist es gleich, steht kein Hinweis. Senkungen bekommen denselben Hinweis („−2,5 kg“).
- **G8 Offline.** Die Zielgewichte kommen im Bootstrap an der Planposition. Die App zeigt sie offline an; neu berechnet wird erst, wenn die Einheit auf dem Server abgeschlossen ist. Bis dahin gilt das zuletzt gelieferte Ziel.
- **G9 Planwechsel bewahrt Gewichte.** Bei einem dauerhaften Tausch (neue Planversion) übernehmen Positionen mit gleicher Übung und gleichem Gerät ihr Zielgewicht. Die neue Übung bekommt Startschätzung bzw. Übertragung.
- **G10 Wiederholbar und gleichzeitig sicher.** Die Neuberechnung nach einer Einheit ist idempotent (derselbe Abschluss zweimal ergibt dasselbe) und folgt dem Muster „nur höherer Stand gewinnt“ aus 0063. Schreibwege nur über `security definer`-Funktionen, wie bei `training_plans` (0062).
- **G11 Freies Training.** Eine Übung ohne Plan oder außerhalb des Plans bekommt das Gewicht des letzten Satzes (Arbeitssatz) am selben Gerät und derselben Übung. Gibt es keinen, gilt die Startschätzung.

## Festlegungen aus der Prüfung (Claude, zur Prüfung durch Tim)

- **G12 Startwert mit Historie** ist das Gewicht der Arbeitssätze des **letzten Blocks** an diesem Gerät und dieser Übung (bei uneinheitlichem Block: Last des letzten Arbeitssatzes), auf die Gerätestufe gerastet. Nicht der beste Satz und nicht der alte `progression.ts`-Vorschlag. Ohne Historie: Startschätzung nach Abschnitt 6, ohne Rücksicht auf andere Planübungen.
- **G13 Wann gesetzt:** beim Annehmen eines Plans (`accept_training_plan`) und beim dauerhaften Tausch. Bestehende Pläne aus Etappe 1 bis 3 ohne Zielgewichte werden **nicht per SQL nachgefüllt**: Der Server setzt fehlende Zielgewichte beim Lesen des Bootstraps bzw. spätestens beim nächsten Einheitenabschluss nach G12. Positionen ohne Ziel zeigt die App wie freies Training (letztes Gewicht).
- **G14 Schlüssel und Stand:** Ein Zielgewicht gehört zu (Mitglied, Studio, Plan-Version, Positionsschlüssel). Dieselbe Übung in zwei Einheiten ist **zwei** Ziele, weil die Bereiche verschieden sein dürfen. Als „Stand“ dient der Abschluss der Einheit (die Session-Kennung mit ihrem Abschlusszeitpunkt), nicht das Gewicht: Ein späterer Abschluss überschreibt einen früheren, auch wenn das Gewicht dabei sinkt. Ein älterer Abschluss, der verspätet eintrifft, ändert nichts.
- **G15 „Begonnen“** heißt: Für die Einheit existiert eine Session (Erstellung, nicht erst der erste Satz). Deren Zielgewichte sind eingefroren, auch wenn die Session bis zum automatischen Abschluss nach 4 h offen bleibt.
- **G16 „Ähnlich“** für die Übertragung (G3/G5) nutzt die vorhandenen Muskeldaten: mindestens ein gemeinsamer Hauptmuskel, wie im Haupt-Spec (F3). Es entsteht keine neue Zuordnung.
- **G17 Hinweis:** Der Server liefert je Planposition im Bootstrap das Zielgewicht, einen Änderungswert gegenüber dem letzten benutzten Gewicht und einen Grund-Code. Die App baut den Halbsatz aus festen Texten und rechnet nichts. Der Hinweis gilt, bis die Position in einer Einheit einen Satz hat; danach vergleicht die App-Anzeige nicht mehr.
- **G18 Schwellen** der Rechnung übernimmt der Umsetzer aus `progression.ts` v2.0.0 (Bereichsgrenzen, erster Satz zählt für „unten verfehlt“, Reserve ≥ Zielreserve), mit der Änderung, dass Bereich und Zielreserve aus der Position kommen. Abweichungen sind zu begründen.
- **G19 Abschluss-Screen:** Die Annahme aus „Zu klären durch den Umsetzer“ gilt. Die Änderung des Screens gehört in diese Etappe (Server und iOS). `progression_suggestions` bleibt für Altdaten lesbar und wird nicht gelöscht.
- **G20 Umfang der Fallstricke:** Übergabe Punkt 2 (Tausch über die Typgrenze) und Punkt 5 (Planversion der Session ≠ Bootstrap) gehören in diese Etappe, weil sie bestimmen, gegen welchen Bereich gerechnet wird. Punkt 3 (`completeSession` über die Warteschlange) und Punkt 4 (4-Stunden-Konstanten) nicht; sie werden nur dokumentiert.
- **G21 Vorausschau:** Gibt es weniger als drei weitere Einheiten, werden alle vorhandenen angepasst.

## Verhältnis zum Haupt-Spec

Ersetzt wird der Absatz „Fortlaufende Anpassung“ in Abschnitt 6 („die bestehende doppelte Progression bleibt … Zielbereich und Zielreserve kommen aus der Planposition“). Stattdessen: Zielgewichte je Planposition, laufend neu gerechnet (G1 bis G4). Alles andere in Abschnitt 6 (Startgewicht, Reserve-Abfrage, Übertragung, Wiedereinstieg) bleibt, siehe G5. Das Vorschlagsprotokoll `progression_suggestions` wird nicht mehr für Planübungen befüllt; was mit dem Abschluss-Screen geschieht, der es heute liest, ist unten offen.

## Zu klären durch den Umsetzer

- Tabellen- und Spaltennamen, Migration (nach `0063`), API-Form.
- Wo die Zielgewichte liegen (eigene Tabelle je Mitglied/Studio/Position oder Feld am Plan), solange G1, G9 und G10 gelten.
- Konkrete Schwellen der Rechnung (G4), solange sie versioniert und im Test mit festen Fällen belegt sind. Die gemeinsamen Testfälle gehören in `packages/domain/fixtures`.
- Abschluss-Screen: zeigt er künftig das neue Zielgewicht der nächsten Planeinheit? **Annahme von Claude:** ja, wo der Plan eine nächste Einheit mit dieser Übung hat; sonst wie bei freiem Training das letzte Gewicht.
- Reihenfolge der Auslieferung: Prod braucht `0059`–`0063` vor dem API-Deploy (Übergabe Punkt 1); jede Prod-Aktion nur mit ausdrücklicher Freigabe von Tim.

## Bekannte Fallstricke aus der Übergabe

- Punkt 2: Tausch über die Typgrenze übernimmt Bereich und Pause der alten Position. Beeinflusst, gegen welchen Bereich ein getauschter Eintrag rechnet. Mit dieser Etappe mitklären.
- Punkt 3 und 4: `completeSession` läuft nicht über die Warteschlange; drei gekoppelte 4-Stunden-Konstanten. Die Neuberechnung (G2) hängt am Server-Abschluss und erbt diese Verzögerung.
- Punkt 5: Nach einem dauerhaften Tausch mitten in der Einheit weicht die Planversion der Session vom Bootstrap ab. Die Neuberechnung muss mit dieser Abweichung umgehen können.
