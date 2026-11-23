# Übungskatalog glattziehen – Kurzdesign

Plan: `docs/superpowers/plans/2026-11-22-katalog-glattziehen.md`.
Regeln: `docs/katalog-stilleitfaden.md`. Namensvorschlag: `docs/katalog-namen-2026-11.md`.

## Absicht

Der Gymtavo-Katalog (162 Übungen) soll einheitlich und kurz werden. Tim stören drei Dinge:
zu lange Beschreibungen, interne Notizen im Nutzertext und Namen ohne Schema. Danach kommen
weitere Übungen dazu, die von Anfang an denselben Regeln folgen.

## Ziele

- Übungsname ohne Gerät; das Gerät steht als Etikett daneben (`Bizepscurl [Kurzhantel]`).
- Etikett ist der Gerätetyp aus dem Katalog und steht immer da, auch bei `Beinpresse [Beinpresse]`.
- Beschreibung mit drei Abschnitten (Einstellen, Bewegung, Achte auf), etwa halbe Länge.
- Ein Stilleitfaden und Prüfungen im Test, damit es so bleibt.

## Nicht-Ziele

- Videos für neue Übungen.
- Eine Pflegeoberfläche für den Katalog.
- Die Eingabehilfe „Gewicht pro Kurzhantel“ am Gewichtsfeld.

## Was nicht passieren darf

- Ein geänderter `key`: Sätze, Pläne und Videos hingen dann an einer verwaisten Übung.
- Gleichnamige Übungen ohne Etikett in der App. Deshalb zuerst das Etikett ausliefern, dann die Namen.

## Wege, die zur Wahl standen

1. **Gerät im Namen lassen, nur Schema vereinheitlichen** („Bankdrücken – Kurzhanteln“).
   Keine Codeänderung, aber das Gerät steht doppelt, sobald der Gerätekontext sichtbar ist.
2. **Name ohne Gerät, Etikett aus dem Gerätetyp** (gewählt, Tims Vorschlag).
   Kürzere Namen, Varianten einer Bewegung heißen gleich. Kostet eine Spalte und Anzeige-Arbeit in der App.
3. **Name ohne Gerät, Etikett aus dem Studiogerät.** Passt genau zum Gerät vor Ort, ist aber lang
   und im Katalog selbst nicht bekannt.

## Entscheidungen zur Umsetzung (meine, nicht Tims)

- Das Etikett steht als `exercises.geraet_label` an der Übung (Migration 0076). Der Import füllt es aus
  `equipment[].label` des einen nicht abgelösten Typs. So bekommt es jede Stelle, die eine Übung liest.
- Karten zeigen das Etikett als kleine Kapsel (`GeraetEtikett`), Fließtext hängt es in Klammern an
  („statt Bankdrücken (Langhantel)“).
- Stellen mit sichtbarem Gerätekontext (Workout-Screen, Einweisung, Verlauf) bleiben unverändert.
- Die Überschrift der Einweisung heißt „So geht’s“ statt „Worauf du achten musst“.

## Offen für Tim

- Durchsicht der Namenstabelle (alle 162), danach erst Änderung der Katalogdatei.
- Bestätigung des Textumfangs anhand von 10 Musterübungen.
- Wunschliste neuer Übungen.
