# Stilleitfaden Übungskatalog

Gilt für jede Übung in `catalog/gymtavo.json`. Die Regeln werden in
`packages/domain/src/gymtavo-katalog.test.ts` geprüft, soweit sie sich prüfen lassen.

## Grundsatz

Die App zeigt eine Übung als **Name + Geräte-Etikett**, zum Beispiel `Bizepscurl [Kurzhantel]`.
Das Etikett kommt vom Gerätetyp (`equipment[].label`), nicht aus dem Namen.

## Name

- Aufbau: `Übung` oder `Übung – Variante`. Einziges Trennzeichen ist „ – “ (Halbgeviertstrich mit Leerzeichen).
- Kein Gerät im Namen: nicht „Kurzhantel“, „Langhantel“, „SZ“, „Kabel“, „am Gerät“, „Maschine“.
  Ausnahme: Die Übung heißt im Studio wie das Gerät (Beinpresse, Brustpresse, Beinstrecker, Butterfly).
- Variante ist Griff, Körperlage, Winkel, Zubehör am Kabel (Seil, Stange) oder einarmig/einbeinig.
  Die Standardausführung bekommt keine Variante. Zwei Varianten mit Komma: `Rudern – einarmig, abgestützt`.
- Gleiche Bewegung, gleiches Wort, egal an welchem Gerät: Bizepscurl, Hammercurl, Scottcurl,
  Trizepsdrücken, Trizepsstrecken, Bankdrücken, Schulterdrücken, Flys, Rudern, Latzug, Überzüge,
  Seitheben, Frontheben, Schulterheben, Kniebeuge, Ausfallschritt, Kreuzheben, Crunch.
- Etablierte englische Begriffe bleiben (Hip Thrust, Face Pull, Goblet Squat, Pallof Press,
  Reverse Curl, Step-up). Sonst deutsch.
- Das Paar aus Name und Etikett ist eindeutig.
- Der `key` einer bestehenden Übung wird nie geändert.

## Etikett des Gerätetyps

- Kurz, höchstens 20 Zeichen, ohne Zubehör und ohne Variante: `Kabelzug`, `Beinpresse 45°`, `Rudermaschine`.
- Mehrere Typen dürfen dasselbe Etikett tragen (Beinpresse und Beinpresse einbeinig).

## Beschreibung

- Genau drei Abschnitte in dieser Reihenfolge: `Einstellen:`, `Bewegung:`, `Achte auf:`.
- Je Abschnitt 1–3 Punkte mit „- “, ein kurzer Satz pro Punkt. Richtwert 250–450 Zeichen, Obergrenze 500.
- Infinitiv-Stil ohne Anrede: „Rücken anlehnen.“, „Knie folgen der Fußrichtung.“
- `Bewegung` in natürlicher Reihenfolge, unabhängig vom Startbild des Videos.
- `Achte auf` sagt, was richtig ist. Fehler werden als positive Anweisung formuliert
  („Fersen bleiben am Boden“ statt „Fersen abheben“).
- Nicht in den Text gehören: Ausstattungslisten, Start-/Endposition, Hinweise zur Erfassung von
  Gewicht oder Messwerten, Verweise auf Video oder „Vorschau“, alles, was Name, Etikett oder
  Muskelkarte schon sagen.

Beispiel:

```
Einstellen:
- Kurzhantel senkrecht mit beiden Händen vor der Brust halten.
- Schulterbreit stehen.

Bewegung:
- Knie und Hüfte beugen, so tief wie Fersen und Rumpf stabil bleiben.
- Über die ganzen Füße aufrichten.

Achte auf:
- Knie folgen der Fußrichtung.
- Fersen bleiben am Boden, Rücken bleibt lang.
```

## Neue Übung anlegen

Pflicht: `key`, `name`, `description`, `volume_kind`, `target_min`/`target_max`, `grip`, `muscles`
(mindestens ein primärer), `plan`-Block, `sources`, `review: "draft"`, Eintrag in genau einem nicht
abgelösten `equipment[].exercises`. `video` darf `null` sein. `review` wird erst nach Tims Durchsicht
`reviewed`.

- Ohne Video steht im `plan`-Block `vorschlag: false`: Die Übung ist wählbar und tauschbar, der
  Generator setzt sie aber nicht von selbst in einen Plan.
- Halteübungen zählen Sekunden (`volume_kind: "seconds"`) und haben keinen `plan`-Block.
- Übungen ohne Gerät hängen am Typ `bodyweight` (Etikett `Körpergewicht`), der Schlüssel beginnt mit `bw_`.
- `sources` bleibt leer, solange keine Quelle geprüft wurde.
