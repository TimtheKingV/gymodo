# Kettlebell – Vorschlagsliste

Stand 23.11.2026. Vorschläge von Claude, Block C aus `docs/katalog-neue-uebungen-2026-11.md`.
Namen folgen `docs/katalog-stilleitfaden.md`; das Etikett ist bei allen `[Kettlebell]`.
Tim hat am 23.11.2026 alle 23 Übungen und den Typ mit 2-kg-Raster gewählt; sie stehen in
`catalog/gymtavo.json`.

## Gerätetyp

| Feld | Wert | Begründung |
|---|---|---|
| `key` | `kettlebell` | – |
| `name` / `label` | Kettlebell | 10 Zeichen, ohne Zubehör |
| `category` | `kraft` | wie Kurzhantel |
| `group` | `kettlebell` | eigene Kachel „Kettlebell“ in der App; in `GROUPS`, Migration 0051 und iOS schon vorgesehen |
| `load_unit` | `kg` | – |
| `load_step` | `2` | Kettlebells gibt es in festen Stufen. Klassisch sind 4-kg-Schritte (8, 12, 16, 20, 24 …), viele Studios haben dazu die Zwischengrößen 6, 10, 14, 18. Ein 2-kg-Raster trifft beide Sätze; ein 4-kg-Raster könnte 6, 10 oder 14 kg nicht erfassen. |
| `load_min` | `4` | kleinste übliche Kettlebell; darunter gibt es nichts zu greifen |
| `load_max` | `null` | wie Kurzhantel |
| `load_start` | `8` | übliches Einstiegsgewicht, liegt über `load_min` und auf dem Raster (8 − 4 = 2 × 2) |
| `photo` | `null` | noch kein Foto |

Die Last ist das Gewicht **einer** Kettlebell, auch bei Übungen mit zwei (wie bei der Kurzhantel).

Verworfen: `load_step` 4 – passt nur, wenn die Studios ausschließlich den klassischen
4-kg-Satz haben.

## Übungen (23)

Wo nichts steht, zählt die Übung Wiederholungen. „(Sekunden)“ heißt: zählt Sekunden und bekommt
keinen `plan`-Block. Alle anderen bekommen `vorschlag: false` (kein Video).

**Beine – Hüfte**

1. Swing – `kb_swing`
2. Swing – einarmig – `kb_swing_single`
3. Kreuzheben – `kb_deadlift`
4. Rumänisches Kreuzheben – einbeinig – `kb_single_leg_rdl`
5. Clean – `kb_clean` (einarmig aus dem Schwung in die Rack-Position)
6. Snatch – `kb_snatch` (einarmig aus dem Schwung über Kopf)

**Beine – Knie**

7. Goblet Squat – `kb_goblet_squat`
8. Frontkniebeuge – `kb_front_squat` (zwei Kettlebells in der Rack-Position)
9. Ausfallschritt – rückwärts – `kb_reverse_lunge`
10. Thruster – `kb_thruster` (Kniebeuge mit anschließendem Drücken über Kopf)

**Ziehen**

11. Rudern – einarmig, abgestützt – `kb_row_supported`
12. Rudern – vorgebeugt – `kb_row_bent` (zwei Kettlebells)
13. High Pull – `kb_high_pull`

**Drücken**

14. Schulterdrücken – einarmig – `kb_press_single`
15. Push Press – `kb_push_press` (einarmig, mit Beinimpuls)
16. Floor Press – `kb_floor_press` (Drücken in Rückenlage am Boden)

**Schulter**

17. Halo – `kb_halo`

**Rumpf**

18. Turkish Get-up – `kb_turkish_getup`
19. Windmill – `kb_windmill`
20. Russian Twist – `kb_russian_twist`

**Tragen (Sekunden)**

21. Farmer’s Walk – `kb_farmers_walk` (Sekunden)
22. Farmer’s Walk – einseitig – `kb_suitcase_carry` (Sekunden)
23. Overhead Carry – `kb_overhead_carry` (Sekunden, einarmig über Kopf)

## Hinweise

- Clean, Snatch, Thruster und Turkish Get-up sind technisch anspruchsvoll. Ohne Video steht in
  der App nur der Text; dafür sind sie mit der Kettlebell eigenständig.
- Swing, Clean und Snatch hängen am Baustein `beine_huefte` (die Kraft kommt aus der Hüfte),
  High Pull an `ziehen`, Thruster an `beine_knie`.
- Nicht vorgeschlagen, weil die Kurzhantel sie schon gleichwertig abdeckt: Bizepscurl,
  Trizepsstrecken, Seitheben, Wadenheben, Step-up.
